import { corsHeadersFor } from './cors.ts';
import { createServiceClient, createUserClient } from './supabase_client.ts';

export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUuid(v: unknown): v is string {
  return typeof v === 'string' && UUID_RE.test(v);
}

export function json(req: Request, status: number, body: unknown, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeadersFor(req), 'Content-Type': 'application/json', ...extra },
  });
}

export function error(req: Request, status: number, message: string, extra: Record<string, string> = {}): Response {
  return json(req, status, { error: message }, extra);
}

/** Parses the body as a JSON object; returns null for anything else. */
export async function readJsonObject(req: Request): Promise<Record<string, unknown> | null> {
  if (req.method !== 'POST') return null;
  try {
    const body = await req.json();
    return body !== null && typeof body === 'object' && !Array.isArray(body)
      ? body as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}

/**
 * Resolves the caller from their JWT. Returns null when the token is missing,
 * expired or revoked — callers must answer 401 (fail closed, SECURITY.md §7.3).
 */
export async function authenticate(req: Request) {
  const authHeader = req.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) return null;
  const { data, error: err } = await createUserClient(authHeader).auth.getUser();
  if (err || !data.user) return null;
  return data.user;
}

/**
 * Fixed-window rate limit via public.hit_rate_limit (rate_limits table).
 * Returns a 429 Response when over the limit, otherwise null.
 */
export async function rateLimit(
  req: Request,
  key: string,
  max: number,
  windowSeconds: number,
): Promise<Response | null> {
  const admin = createServiceClient();
  const { data: allowed, error: err } = await admin.rpc('hit_rate_limit', {
    p_key: key,
    p_max: max,
    p_window_seconds: windowSeconds,
  });
  if (err) {
    // Fail open on limiter infrastructure errors, but log loudly — a broken
    // limiter must not take settle-up down with it.
    console.error('rate limiter error', err);
    return null;
  }
  if (allowed === false) {
    return error(req, 429, 'Too many requests — try again shortly', {
      'Retry-After': String(windowSeconds),
    });
  }
  return null;
}
