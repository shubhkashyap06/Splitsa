/**
 * CORS — locked to an allow-list, never `*` (SECURITY.md §2 "Network").
 *
 * Set ALLOWED_ORIGINS as a comma-separated Edge Function secret, e.g.
 *   supabase secrets set ALLOWED_ORIGINS=https://app.splitsa.in,https://staging.splitsa.in
 *
 * Native Android requests carry no Origin header, so CORS doesn't apply to
 * them. With ALLOWED_ORIGINS unset, only http://localhost:* is allowed so the
 * PWA can be developed locally without opening the API to every website.
 */
const allowList = (Deno.env.get('ALLOWED_ORIGINS') ?? '')
  .split(',')
  .map((o) => o.trim())
  .filter((o) => o.length > 0);

function isAllowed(origin: string): boolean {
  if (allowList.includes(origin)) return true;
  return allowList.length === 0 && /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
}

export function corsHeadersFor(req: Request): Record<string, string> {
  const origin = req.headers.get('Origin');
  const headers: Record<string, string> = {
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  };
  if (origin && isAllowed(origin)) {
    headers['Access-Control-Allow-Origin'] = origin;
  }
  return headers;
}

export function handleCors(req: Request): Response | null {
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeadersFor(req) });
  }
  return null;
}
