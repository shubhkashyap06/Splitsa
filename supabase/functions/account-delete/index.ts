import { handleCors } from '../_shared/cors.ts';
import { authenticate, error, json, rateLimit, readJsonObject } from '../_shared/http.ts';
import { createServiceClient } from '../_shared/supabase_client.ts';
import { fetchNetBalances, simplify } from '../_shared/balances.ts';

/**
 * account-delete — the only path allowed to delete an account
 * (PRODUCT_LOGIC.md §6, SECURITY.md §3b, ARCHITECTURE.md §4).
 *
 * POST { confirm: string, forfeit_owed?: boolean }
 *   confirm      — the account's email, typed by the user (type-to-confirm)
 *   forfeit_owed — explicit acknowledgement to write off money owed TO them
 *
 * 200 { deleted: true }
 * 409 { error, blocking: [{ room_id, room_name, net_balance_paise }] }
 *     – any room where they OWE money always blocks (settle first)
 *     – rooms where they're OWED block unless forfeit_owed is true
 *
 * The client-side check in the app is a courtesy; this is the real gate.
 */
Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  const user = await authenticate(req);
  if (!user) return error(req, 401, 'Unauthorized');

  const limited = await rateLimit(req, `account-delete:${user.id}`, 5, 3600);
  if (limited) return limited;

  const body = await readJsonObject(req);
  if (!body) return error(req, 400, 'Expected a JSON object body');

  const confirm = typeof body.confirm === 'string' ? body.confirm.trim().toLowerCase() : '';
  if (!user.email || confirm !== user.email.toLowerCase()) {
    return error(req, 400, 'Confirmation text does not match your email');
  }
  const forfeit = body.forfeit_owed === true;

  const admin = createServiceClient();

  try {
    const { data: memberships, error: mErr } = await admin
      .from('room_members')
      .select('room_id, rooms(name)')
      .eq('user_id', user.id)
      .is('deleted_at', null);
    if (mErr) throw mErr;

    const blocking: { room_id: string; room_name: string; net_balance_paise: number }[] = [];
    const writeOffs: { roomId: string; from: string; amount: number }[] = [];

    for (const m of memberships ?? []) {
      const roomId = m.room_id as string;
      // deno-lint-ignore no-explicit-any
      const roomName = ((m as any).rooms?.name as string) ?? 'Room';
      const balances = await fetchNetBalances(admin, roomId);
      const net = balances.get(user.id) ?? 0;
      if (net === 0) continue;

      if (net < 0 || !forfeit) {
        blocking.push({ room_id: roomId, room_name: roomName, net_balance_paise: net });
        continue;
      }
      for (const t of simplify(balances)) {
        if (t.to === user.id) writeOffs.push({ roomId, from: t.from, amount: t.amount });
      }
    }

    if (blocking.length > 0) {
      return json(req, 409, { error: 'Settle these balances first', blocking });
    }

    // Forfeit: record write-off settlements so other members' balances zero
    // out instead of showing a debt to "Deleted user" forever.
    for (const w of writeOffs) {
      const id = crypto.randomUUID();
      const { error: sErr } = await admin.from('settlements').insert({
        id, room_id: w.roomId, payer_id: w.from, payee_id: user.id, amount_paise: w.amount,
      });
      if (sErr) throw sErr;
      await admin.from('audit_log').insert({
        actor_id: user.id,
        action: 'settle.forfeit',
        table_name: 'settlements',
        row_id: id,
        payload_json: { room_id: w.roomId, payer_id: w.from, payee_id: user.id, amount_paise: w.amount },
      });
    }

    const { error: anonErr } = await admin.rpc('anonymize_and_delete_user_data', { p_user_id: user.id });
    if (anonErr) throw anonErr;

    // Profile no longer FK-cascades from auth.users (migration 20261120…),
    // so deleting the identity leaves the anonymized profile in place.
    const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
    if (delErr) throw delErr;

    return json(req, 200, { deleted: true });
  } catch (err) {
    console.error('account-delete error', (err as Error).message);
    return error(req, 500, 'Internal server error');
  }
});
