/**
 * Server-side mirror of the client's debt simplification
 * (app/lib/features/recommendations/logic_engine/debt_simplifier.dart,
 * PRODUCT_LOGIC.md §2). Used to validate settle amounts and to write off
 * balances on account deletion — never to *display* anything.
 */
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface Transfer {
  from: string;
  to: string;
  amount: number;
}

export async function fetchNetBalances(
  admin: SupabaseClient,
  roomId: string,
): Promise<Map<string, number>> {
  const { data, error } = await admin.rpc('room_net_balances', { p_room_id: roomId });
  if (error) throw error;
  const out = new Map<string, number>();
  for (const row of (data ?? []) as { user_id: string; net_balance_paise: number | string }[]) {
    out.set(row.user_id, Number(row.net_balance_paise));
  }
  return out;
}

export function simplify(balances: Map<string, number>): Transfer[] {
  const owers = [...balances].filter(([, v]) => v < 0).map(([id, v]) => ({ id, amt: -v }));
  const owed = [...balances].filter(([, v]) => v > 0).map(([id, v]) => ({ id, amt: v }));
  owers.sort((a, b) => b.amt - a.amt);
  owed.sort((a, b) => b.amt - a.amt);

  const transfers: Transfer[] = [];
  let i = 0, j = 0;
  while (i < owers.length && j < owed.length) {
    const amount = Math.min(owers[i].amt, owed[j].amt);
    if (amount > 0) transfers.push({ from: owers[i].id, to: owed[j].id, amount });
    owers[i].amt -= amount;
    owed[j].amt -= amount;
    if (owers[i].amt === 0) i++;
    if (owed[j].amt === 0) j++;
  }
  return transfers;
}
