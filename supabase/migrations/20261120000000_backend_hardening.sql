-- =============================================================================
-- Splitsa — Backend hardening (v1.1)
-- Migration: 20261120000000_backend_hardening
--
-- Fixes correctness/security gaps found in 20260927000000_initial_schema:
--   1. updated_at was client-supplied → delta sync watermark could skip rows.
--      Now a BEFORE UPDATE/INSERT trigger makes it server-authoritative.
--   2. A room's creator could never become a member (room_members had no
--      INSERT policy) → the creator couldn't even read the room they made.
--   3. settlements were only readable by payer/payee → every OTHER member
--      computed wrong room balances. Now readable by all room members.
--   4. profiles.id cascaded from auth.users → deleting the auth identity
--      would delete the profile, which shared expenses reference. Account
--      deletion must anonymize, never cascade (PRODUCT_LOGIC.md §6).
--   5. room_balances_mv double-counted (expenses × settlements cross join)
--      and, as a materialized view, bypassed RLS while exposed via PostgREST.
--   6. expense_splits had no UPDATE policy; pot_contributions INSERT didn't
--      check the caller could see the pot.
--   7. Adds monthly_budget_paise (Home hero card) + server RPCs used by Edge
--      Functions (atomic invite redemption, balances, rate limiting, delete).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Server-authoritative updated_at
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := clock_timestamp();
  RETURN NEW;
END;
$$;

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'profiles', 'rooms', 'room_members', 'room_invites', 'expenses',
    'expense_splits', 'personal_expenses', 'settlements', 'pots',
    'pot_contributions', 'device_tokens'
  ] LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I_set_updated_at ON public.%I', t, t);
    EXECUTE format(
      'CREATE TRIGGER %I_set_updated_at BEFORE INSERT OR UPDATE ON public.%I
         FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()', t, t);
    -- Delta-sync pulls filter on updated_at — index it.
    EXECUTE format('CREATE INDEX IF NOT EXISTS %I_updated_at_idx ON public.%I(updated_at)', t, t);
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2. Room creator membership
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_room_creator(p_room_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.rooms r
    WHERE r.id = p_room_id
      AND r.created_by = (SELECT auth.uid())
  );
$$;

DROP POLICY IF EXISTS "rooms_insert_auth" ON public.rooms;
CREATE POLICY "rooms_insert_self" ON public.rooms FOR INSERT
  WITH CHECK (created_by = (SELECT auth.uid()));

-- The creator may add exactly one row: themselves. Everyone else joins via
-- the room-invite Edge Function (service role → redeem_room_invite()).
CREATE POLICY "room_members_insert_creator_self" ON public.room_members FOR INSERT
  WITH CHECK (user_id = (SELECT auth.uid()) AND public.is_room_creator(room_id));

-- ---------------------------------------------------------------------------
-- 3. Settlements visible to the whole room (balances need all of them)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "settlements_select_parties" ON public.settlements;
CREATE POLICY "settlements_select_members" ON public.settlements FOR SELECT
  USING (public.is_room_member(room_id));

-- ---------------------------------------------------------------------------
-- 4. Profiles survive auth-identity deletion (anonymize, never cascade)
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_id_fkey;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS monthly_budget_paise BIGINT
    CHECK (monthly_budget_paise IS NULL OR monthly_budget_paise >= 0);

-- ---------------------------------------------------------------------------
-- 5. Correct, locked-down balance materialized view
-- ---------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS public.room_balances_mv;

CREATE MATERIALIZED VIEW public.room_balances_mv AS
WITH paid AS (
  SELECT e.room_id, e.paid_by AS user_id, SUM(e.amount_paise) AS amt
  FROM public.expenses e
  WHERE e.deleted_at IS NULL
  GROUP BY 1, 2
), owed AS (
  SELECT e.room_id, es.user_id, SUM(es.amount_paise) AS amt
  FROM public.expense_splits es
  JOIN public.expenses e ON e.id = es.expense_id
  WHERE e.deleted_at IS NULL AND es.deleted_at IS NULL
  GROUP BY 1, 2
), sent AS (
  SELECT room_id, payer_id AS user_id, SUM(amount_paise) AS amt
  FROM public.settlements WHERE deleted_at IS NULL GROUP BY 1, 2
), received AS (
  SELECT room_id, payee_id AS user_id, SUM(amount_paise) AS amt
  FROM public.settlements WHERE deleted_at IS NULL GROUP BY 1, 2
)
SELECT
  rm.room_id,
  rm.user_id,
  COALESCE(p.amt, 0) - COALESCE(o.amt, 0)
    + COALESCE(s.amt, 0) - COALESCE(r.amt, 0) AS net_balance_paise
FROM public.room_members rm
LEFT JOIN paid     p ON p.room_id = rm.room_id AND p.user_id = rm.user_id
LEFT JOIN owed     o ON o.room_id = rm.room_id AND o.user_id = rm.user_id
LEFT JOIN sent     s ON s.room_id = rm.room_id AND s.user_id = rm.user_id
LEFT JOIN received r ON r.room_id = rm.room_id AND r.user_id = rm.user_id
WITH NO DATA;

CREATE UNIQUE INDEX room_balances_mv_pk ON public.room_balances_mv(room_id, user_id);
REFRESH MATERIALIZED VIEW public.room_balances_mv;

-- Materialized views ignore RLS — never expose this one to client roles.
REVOKE ALL ON public.room_balances_mv FROM anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. Missing write policies
-- ---------------------------------------------------------------------------
-- Payer can correct the shares on their own expense.
CREATE POLICY "expense_splits_update_payer" ON public.expense_splits FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.expenses e
      WHERE e.id = expense_splits.expense_id
        AND e.paid_by = (SELECT auth.uid())
        AND public.is_room_member(e.room_id)
    )
  );

DROP POLICY IF EXISTS "pot_contributions_insert_owner" ON public.pot_contributions;
CREATE POLICY "pot_contributions_insert_owner" ON public.pot_contributions FOR INSERT
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.pots p
      WHERE p.id = pot_contributions.pot_id
        AND p.deleted_at IS NULL
        AND (
          (p.owner_type = 'personal' AND p.user_id = (SELECT auth.uid()))
          OR (p.owner_type = 'group' AND public.is_room_member(p.room_id))
        )
    )
  );

-- Contributors can soft-delete (undo) their own contribution.
CREATE POLICY "pot_contributions_update_owner" ON public.pot_contributions FOR UPDATE
  USING (user_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- 7a. Atomic invite redemption (service role only — called by room-invite)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.redeem_room_invite(p_invite_id UUID, p_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_room UUID;
BEGIN
  -- Row lock so two concurrent joins can't both squeeze past max_uses.
  SELECT room_id INTO v_room
  FROM public.room_invites
  WHERE id = p_invite_id
    AND deleted_at IS NULL
    AND expires_at > NOW()
    AND used_count < max_uses
  FOR UPDATE;

  IF v_room IS NULL THEN
    RAISE EXCEPTION 'invite_invalid' USING ERRCODE = 'P0001';
  END IF;

  -- Already an active member → idempotent no-op (don't burn a use).
  IF EXISTS (
    SELECT 1 FROM public.room_members
    WHERE room_id = v_room AND user_id = p_user_id AND deleted_at IS NULL
  ) THEN
    RETURN v_room;
  END IF;

  -- Rejoin after leaving revives the old row (UNIQUE (room_id, user_id)).
  INSERT INTO public.room_members (room_id, user_id)
  VALUES (v_room, p_user_id)
  ON CONFLICT (room_id, user_id)
  DO UPDATE SET deleted_at = NULL, joined_at = NOW();

  UPDATE public.room_invites SET used_count = used_count + 1 WHERE id = p_invite_id;
  RETURN v_room;
END;
$$;

-- ---------------------------------------------------------------------------
-- 7b. Live (non-cached) net balances for one room — used by settle-intent
--     and account-delete to validate amounts server-side.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.room_net_balances(p_room_id UUID)
RETURNS TABLE (user_id UUID, net_balance_paise BIGINT)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH events AS (
    SELECT e.paid_by AS user_id, e.amount_paise AS delta
      FROM public.expenses e
      WHERE e.room_id = p_room_id AND e.deleted_at IS NULL
    UNION ALL
    SELECT es.user_id, -es.amount_paise
      FROM public.expense_splits es
      JOIN public.expenses e ON e.id = es.expense_id
      WHERE e.room_id = p_room_id AND e.deleted_at IS NULL AND es.deleted_at IS NULL
    UNION ALL
    SELECT s.payer_id, s.amount_paise
      FROM public.settlements s
      WHERE s.room_id = p_room_id AND s.deleted_at IS NULL
    UNION ALL
    SELECT s.payee_id, -s.amount_paise
      FROM public.settlements s
      WHERE s.room_id = p_room_id AND s.deleted_at IS NULL
  )
  SELECT user_id, SUM(delta)::BIGINT FROM events GROUP BY user_id;
$$;

-- ---------------------------------------------------------------------------
-- 7c. Fixed-window rate limiter backed by public.rate_limits
--     Returns TRUE if the call is allowed.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.hit_rate_limit(p_key TEXT, p_max INTEGER, p_window_seconds INTEGER)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  INSERT INTO public.rate_limits AS rl (key, count, window_start, updated_at)
  VALUES (p_key, 1, NOW(), NOW())
  ON CONFLICT (key) DO UPDATE SET
    count = CASE
      WHEN rl.window_start < NOW() - make_interval(secs => p_window_seconds) THEN 1
      ELSE rl.count + 1
    END,
    window_start = CASE
      WHEN rl.window_start < NOW() - make_interval(secs => p_window_seconds) THEN NOW()
      ELSE rl.window_start
    END,
    updated_at = NOW()
  RETURNING count INTO v_count;

  RETURN v_count <= p_max;
END;
$$;

-- ---------------------------------------------------------------------------
-- 7d. Account deletion data step (PRODUCT_LOGIC.md §6, SECURITY.md §3b)
--     Hard-deletes personal data, anonymizes shared records. The balance
--     gate and auth-identity deletion happen in the account-delete function.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.anonymize_and_delete_user_data(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Purely personal data → hard delete.
  DELETE FROM public.personal_expenses WHERE user_id = p_user_id;
  DELETE FROM public.device_tokens     WHERE user_id = p_user_id;
  DELETE FROM public.pot_contributions
    WHERE pot_id IN (SELECT id FROM public.pots WHERE owner_type = 'personal' AND user_id = p_user_id);
  DELETE FROM public.pots WHERE owner_type = 'personal' AND user_id = p_user_id;

  -- Leave every room (soft) so they lose read access; shared rows stay.
  UPDATE public.room_members SET deleted_at = NOW()
    WHERE user_id = p_user_id AND deleted_at IS NULL;

  -- Invalidate invites they created.
  UPDATE public.room_invites SET deleted_at = NOW()
    WHERE created_by = p_user_id AND deleted_at IS NULL;

  -- Anonymize the profile other members still see on shared expenses.
  UPDATE public.profiles SET
    display_name         = 'Deleted user',
    email                = NULL,
    upi_id               = NULL,
    avatar_url           = NULL,
    monthly_budget_paise = NULL,
    deleted_at           = NOW()
  WHERE id = p_user_id;

  -- Audit trail retained, actor anonymized.
  UPDATE public.audit_log SET actor_id = NULL WHERE actor_id = p_user_id;
END;
$$;

-- Service-role-only RPCs: never callable by anon/authenticated clients.
REVOKE ALL ON FUNCTION public.redeem_room_invite(UUID, UUID)            FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.room_net_balances(UUID)                   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.hit_rate_limit(TEXT, INTEGER, INTEGER)    FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.anonymize_and_delete_user_data(UUID)      FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_room_invite(UUID, UUID)         TO service_role;
GRANT EXECUTE ON FUNCTION public.room_net_balances(UUID)                TO service_role;
GRANT EXECUTE ON FUNCTION public.hit_rate_limit(TEXT, INTEGER, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION public.anonymize_and_delete_user_data(UUID)   TO service_role;
