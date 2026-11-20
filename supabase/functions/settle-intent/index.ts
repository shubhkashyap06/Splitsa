import { handleCors } from '../_shared/cors.ts';
import { authenticate, error, isUuid, json, rateLimit, readJsonObject } from '../_shared/http.ts';
import { createServiceClient } from '../_shared/supabase_client.ts';
import { fetchNetBalances, simplify } from '../_shared/balances.ts';

/**
 * settle-intent — validates and records a debt settlement.
 *
 * Called by the app's Settle Up flow BEFORE opening the UPI deep link. The
 * app displays the server-validated amount from this response — never its
 * own locally computed number (UI_UX_SPEC.md §4 "Settle Up").
 *
 * POST { op_id: uuid, room_id: uuid, payee_id: uuid, amount_paise: int }
 *
 * 200 { op_id, validated_amount_paise, upi_id, payee_display_name, created_at }
 * 400 malformed · 401 unauthenticated · 403 not a member · 404 payee unknown
 * 409 { error, owed_paise } — amount exceeds what the caller owes the payee
 *     (stale local balance); the client must refresh and retry.
 * 429 rate limited
 *
 * Idempotent on op_id (OFFLINE_SYNC.md §4): replaying a request returns the
 * settlement already recorded, never a second one.
 */
const MAX_PAISE = 10_000_000_00; // ₹1 crore sanity ceiling

Deno.serve(async (req: Request) => {
  const cors = handleCors(req);
  if (cors) return cors;

  const user = await authenticate(req);
  if (!user) return error(req, 401, 'Unauthorized');

  const limited = await rateLimit(req, `settle:${user.id}`, 20, 60);
  if (limited) return limited;

  const body = await readJsonObject(req);
  if (!body) return error(req, 400, 'Expected a JSON object body');

  const { op_id, room_id, payee_id, amount_paise } = body;
  if (!isUuid(op_id) || !isUuid(room_id) || !isUuid(payee_id)) {
    return error(req, 400, 'op_id, room_id and payee_id must be UUIDs');
  }
  if (typeof amount_paise !== 'number' || !Number.isInteger(amount_paise) ||
      amount_paise <= 0 || amount_paise > MAX_PAISE) {
    return error(req, 400, 'amount_paise must be a positive integer');
  }
  if (payee_id === user.id) return error(req, 400, 'Cannot settle with yourself');

  const admin = createServiceClient();

  try {
    const { data: members } = await admin
      .from('room_members')
      .select('user_id')
      .eq('room_id', room_id)
      .in('user_id', [user.id, payee_id])
      .is('deleted_at', null);
    const memberIds = new Set((members ?? []).map((m) => m.user_id as string));
    if (!memberIds.has(user.id)) return error(req, 403, 'Not a room member');
    if (!memberIds.has(payee_id)) return error(req, 404, 'Payee is not in this room');

    const { data: payee } = await admin
      .from('profiles')
      .select('display_name, upi_id')
      .eq('id', payee_id)
      .maybeSingle();
    if (!payee) return error(req, 404, 'Payee not found');

    const respond = (amount: number, createdAt: string) =>
      json(req, 200, {
        op_id,
        validated_amount_paise: amount,
        upi_id: payee.upi_id ?? null,
        payee_display_name: payee.display_name,
        created_at: createdAt,
      });

    // Idempotent replay.
    const existing = await findSettlement(admin, op_id);
    if (existing) {
      if (existing.payer_id !== user.id) return error(req, 409, 'op_id already used');
      return respond(Number(existing.amount_paise), existing.created_at);
    }

    // Validate against the live simplified balance, not the client's number.
    const transfers = simplify(await fetchNetBalances(admin, room_id));
    const owed = transfers
      .filter((t) => t.from === user.id && t.to === payee_id)
      .reduce((s, t) => s + t.amount, 0);
    if (amount_paise > owed) {
      return json(req, 409, {
        error: 'Amount is more than you currently owe — refresh and try again',
        owed_paise: owed,
      });
    }

    const { data: inserted, error: insertError } = await admin
      .from('settlements')
      .insert({ id: op_id, room_id, payer_id: user.id, payee_id, amount_paise })
      .select('created_at')
      .single();

    if (insertError) {
      // Concurrent replay of the same op_id raced us — return the winner.
      if (insertError.code === '23505') {
        const winner = await findSettlement(admin, op_id);
        if (winner && winner.payer_id === user.id) {
          return respond(Number(winner.amount_paise), winner.created_at);
        }
      }
      console.error('settle-intent insert error', insertError.code);
      return error(req, 500, 'Failed to record settlement');
    }

    await admin.from('audit_log').insert({
      actor_id: user.id,
      action: 'settle.confirm',
      table_name: 'settlements',
      row_id: op_id,
      payload_json: { room_id, payer_id: user.id, payee_id, amount_paise },
    });

    return respond(amount_paise, inserted.created_at);
  } catch (err) {
    // Never log amounts or UPI IDs (SECURITY.md §2 "Storage").
    console.error('settle-intent error', (err as Error).message);
    return error(req, 500, 'Internal server error');
  }
});

// deno-lint-ignore no-explicit-any
async function findSettlement(admin: any, opId: string) {
  const { data } = await admin
    .from('settlements')
    .select('payer_id, amount_paise, created_at')
    .eq('id', opId)
    .maybeSingle();
  return data as { payer_id: string; amount_paise: number; created_at: string } | null;
}
