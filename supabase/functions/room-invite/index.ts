import { handleCors } from '../_shared/cors.ts';
import { authenticate, error, isUuid, json, rateLimit, readJsonObject } from '../_shared/http.ts';
import { createServiceClient } from '../_shared/supabase_client.ts';

/**
 * room-invite — create, preview and redeem room invites (SECURITY.md §3a).
 *
 * POST { action: 'create', room_id: uuid, max_uses?: 1..50 }
 *   → 200 { invite_id, token, display_code, expires_at, max_uses }
 * POST { action: 'preview', code }           (alias: 'join')
 *   → 200 { room_id, room_name, room_icon, member_count, member_names[] }
 * POST { action: 'confirm_join', code }
 *   → 200 { room_id }
 *
 * `code` is either the 6-char display code or the 64-hex token from a link.
 * It is validated against a strict pattern *before* it reaches a query —
 * the previous version interpolated raw input into a PostgREST `.or()`
 * filter string, which let a crafted code rewrite the filter.
 */
const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1
const DISPLAY_CODE_RE = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/;
const TOKEN_RE = /^[0-9a-f]{64}$/;
const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000;

function randomDisplayCode(): string {
  // Rejection sampling over crypto bytes — no modulo bias, no Math.random.
  const out: string[] = [];
  while (out.length < 6) {
    const [b] = crypto.getRandomValues(new Uint8Array(1));
    if (b < 256 - (256 % CODE_ALPHABET.length)) out.push(CODE_ALPHABET[b % CODE_ALPHABET.length]);
  }
  return out.join('');
}

function randomToken(): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(32)), (b) => b.toString(16).padStart(2, '0')).join('');
}

type CodeLookup = { column: 'display_code' | 'token'; value: string };

function parseCode(raw: unknown): CodeLookup | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (TOKEN_RE.test(trimmed.toLowerCase())) return { column: 'token', value: trimmed.toLowerCase() };
  if (DISPLAY_CODE_RE.test(trimmed.toUpperCase())) return { column: 'display_code', value: trimmed.toUpperCase() };
  return null;
}

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  const user = await authenticate(req);
  if (!user) return error(req, 401, 'Unauthorized');

  const body = await readJsonObject(req);
  if (!body) return error(req, 400, 'Expected a JSON object body');

  const admin = createServiceClient();

  try {
    // ── create ──────────────────────────────────────────────────────────────
    if (body.action === 'create') {
      const limited = await rateLimit(req, `invite-create:${user.id}`, 10, 3600);
      if (limited) return limited;

      const roomId = body.room_id;
      if (!isUuid(roomId)) return error(req, 400, 'room_id must be a UUID');
      const maxUses = body.max_uses ?? 10;
      if (typeof maxUses !== 'number' || !Number.isInteger(maxUses) || maxUses < 1 || maxUses > 50) {
        return error(req, 400, 'max_uses must be an integer between 1 and 50');
      }

      const { data: member } = await admin.from('room_members').select('id')
        .eq('room_id', roomId).eq('user_id', user.id).is('deleted_at', null).maybeSingle();
      if (!member) return error(req, 403, 'Not a room member');

      for (let attempt = 0; attempt < 5; attempt++) {
        const { data: invite, error: insertErr } = await admin.from('room_invites').insert({
          room_id: roomId,
          token: randomToken(),
          display_code: randomDisplayCode(),
          created_by: user.id,
          max_uses: maxUses,
          expires_at: new Date(Date.now() + INVITE_TTL_MS).toISOString(),
        }).select('id, token, display_code, expires_at, max_uses').single();

        if (!insertErr) {
          return json(req, 200, {
            invite_id: invite.id,
            token: invite.token,
            display_code: invite.display_code,
            expires_at: invite.expires_at,
            max_uses: invite.max_uses,
          });
        }
        if (insertErr.code !== '23505') throw insertErr; // retry only on code collision
      }
      return error(req, 500, 'Could not allocate an invite code');
    }

    // ── preview / confirm ───────────────────────────────────────────────────
    if (body.action === 'preview' || body.action === 'join' || body.action === 'confirm_join') {
      // Guessing codes is the abuse vector — limit tightly per user.
      const limited = await rateLimit(req, `invite-redeem:${user.id}`, 15, 600);
      if (limited) return limited;

      const code = parseCode(body.code);
      if (!code) return error(req, 400, 'That code doesn\'t look right');

      const { data: invite } = await admin.from('room_invites')
        .select('id, room_id, expires_at, max_uses, used_count')
        .eq(code.column, code.value)
        .is('deleted_at', null)
        .maybeSingle();

      if (!invite) return error(req, 404, 'Invalid or expired code');
      if (new Date(invite.expires_at) <= new Date()) return error(req, 410, 'This invite has expired');
      if (invite.used_count >= invite.max_uses) return error(req, 410, 'This invite has been fully used');

      if (body.action === 'confirm_join') {
        const { data: roomId, error: rpcErr } = await admin.rpc('redeem_room_invite', {
          p_invite_id: invite.id,
          p_user_id: user.id,
        });
        if (rpcErr) {
          if (rpcErr.message?.includes('invite_invalid')) return error(req, 410, 'This invite is no longer valid');
          throw rpcErr;
        }
        return json(req, 200, { room_id: roomId });
      }

      // Preview: enough for the user to recognise the room — never balances.
      const { data: room } = await admin.from('rooms').select('name, icon')
        .eq('id', invite.room_id).is('deleted_at', null).maybeSingle();
      if (!room) return error(req, 404, 'This room no longer exists');

      const { data: members, count } = await admin.from('room_members')
        .select('profiles(display_name)', { count: 'exact' })
        .eq('room_id', invite.room_id)
        .is('deleted_at', null)
        .limit(12);

      const memberNames = (members ?? [])
        // deno-lint-ignore no-explicit-any
        .map((m: any) => m.profiles?.display_name as string | undefined)
        .filter((n): n is string => !!n);

      return json(req, 200, {
        room_id: invite.room_id,
        room_name: room.name,
        room_icon: room.icon,
        member_count: count ?? memberNames.length,
        member_names: memberNames,
      });
    }

    return error(req, 400, 'Unknown action');
  } catch (err) {
    console.error('room-invite error', (err as Error).message);
    return error(req, 500, 'Internal server error');
  }
});
