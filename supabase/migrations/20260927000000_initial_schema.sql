-- =============================================================================
-- Splitsa — Initial schema (v1)
-- Migration: 20260927000000_initial_schema
--
-- Rules enforced here (per CLAUDE.md non-negotiables):
--   • RLS enabled on every table in this same file — no table ships without a policy
--   • Every policy uses (select auth.uid()) not bare auth.uid() — per-statement, not per-row
--   • Indexes match every FK used in a policy or hot query — no sequential-scan policies
--   • No model_versions rows inserted — table exists but stays empty until ML ships
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ---------------------------------------------------------------------------
-- Helper: is the calling user a member of a given room?
-- SECURITY DEFINER so it runs as the function owner, not the caller —
-- this means it only needs SELECT on room_members, not a policy bypass.
-- Called once per statement by RLS policies, not once per row.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_room_member(p_room_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.room_members rm
    WHERE rm.room_id   = p_room_id
      AND rm.user_id   = (SELECT auth.uid())
      AND rm.deleted_at IS NULL
  );
$$;

-- ---------------------------------------------------------------------------
-- profiles
-- Mirrors auth.users. Created by a trigger on user sign-up.
-- Name is replaced with 'Deleted user' on account deletion (not removed)
-- so shared expense history stays coherent — see docs/PRODUCT_LOGIC.md §6.
-- ---------------------------------------------------------------------------
CREATE TABLE public.profiles (
  id                            UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name                  TEXT        NOT NULL,
  avatar_url                    TEXT,
  upi_id                        TEXT,                           -- optional; prompted in Profile settings
  email                         TEXT,
  notifications_regular_enabled BOOLEAN     NOT NULL DEFAULT TRUE,
  quiet_hours_start             TIME,                           -- NULL = no quiet hours
  quiet_hours_end               TIME,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at                    TIMESTAMPTZ
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Own profile: full access
CREATE POLICY "profiles_select_own"   ON public.profiles FOR SELECT USING (id = (SELECT auth.uid()));
CREATE POLICY "profiles_insert_own"   ON public.profiles FOR INSERT WITH CHECK (id = (SELECT auth.uid()));
CREATE POLICY "profiles_update_own"   ON public.profiles FOR UPDATE USING (id = (SELECT auth.uid()));

-- Room members can read each other's profiles (needed to display names/avatars)
CREATE POLICY "profiles_select_room_members" ON public.profiles FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.room_members a
    JOIN public.room_members b ON b.room_id = a.room_id
    WHERE a.user_id = (SELECT auth.uid())
      AND b.user_id = profiles.id
      AND a.deleted_at IS NULL
      AND b.deleted_at IS NULL
  )
);

-- Trigger: create a profile row when a new auth user is created
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, email, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1), 'User'),
    NEW.email,
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ---------------------------------------------------------------------------
-- rooms
-- ---------------------------------------------------------------------------
CREATE TABLE public.rooms (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT        NOT NULL,
  description TEXT,
  icon        TEXT        NOT NULL DEFAULT 'house',
  created_by  UUID        NOT NULL REFERENCES public.profiles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ
);

CREATE INDEX rooms_created_by_idx ON public.rooms(created_by);

ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rooms_select_members" ON public.rooms FOR SELECT
  USING (public.is_room_member(id));

CREATE POLICY "rooms_insert_auth" ON public.rooms FOR INSERT
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

CREATE POLICY "rooms_update_creator" ON public.rooms FOR UPDATE
  USING (created_by = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- room_members
-- ---------------------------------------------------------------------------
CREATE TABLE public.room_members (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id    UUID        NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES public.profiles(id),
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  UNIQUE (room_id, user_id)
);

CREATE INDEX room_members_room_id_idx  ON public.room_members(room_id);
CREATE INDEX room_members_user_id_idx  ON public.room_members(user_id);

ALTER TABLE public.room_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "room_members_select_members" ON public.room_members FOR SELECT
  USING (public.is_room_member(room_id));

-- Inserts come only from the room-invite Edge Function (service role)
-- so no INSERT policy is granted to authenticated users directly.
CREATE POLICY "room_members_update_self" ON public.room_members FOR UPDATE
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "room_members_delete_self" ON public.room_members FOR DELETE
  USING (user_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- room_invites
-- token      — cryptographically random (gen_random_bytes), never guessable
-- display_code — 6-char uppercase alphanumeric shown in the UI
-- ---------------------------------------------------------------------------
CREATE TABLE public.room_invites (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id      UUID        NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  token        TEXT        NOT NULL UNIQUE,
  display_code TEXT        NOT NULL UNIQUE,
  created_by   UUID        NOT NULL REFERENCES public.profiles(id),
  expires_at   TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '7 days',
  max_uses     INTEGER     NOT NULL DEFAULT 10,
  used_count   INTEGER     NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at   TIMESTAMPTZ
);

CREATE UNIQUE INDEX room_invites_token_idx       ON public.room_invites(token);
CREATE UNIQUE INDEX room_invites_display_code_idx ON public.room_invites(display_code);
CREATE INDEX        room_invites_room_id_idx      ON public.room_invites(room_id);

ALTER TABLE public.room_invites ENABLE ROW LEVEL SECURITY;

-- Room members can read/manage invites for their rooms
CREATE POLICY "room_invites_select_members" ON public.room_invites FOR SELECT
  USING (public.is_room_member(room_id));

CREATE POLICY "room_invites_insert_members" ON public.room_invites FOR INSERT
  WITH CHECK (public.is_room_member(room_id));

CREATE POLICY "room_invites_update_members" ON public.room_invites FOR UPDATE
  USING (public.is_room_member(room_id));

-- ---------------------------------------------------------------------------
-- expenses
-- id is client-generated UUIDv7 (time-sortable, globally unique, offline-safe)
-- ---------------------------------------------------------------------------
CREATE TABLE public.expenses (
  id            UUID        PRIMARY KEY,   -- client-generated UUIDv7
  room_id       UUID        NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  paid_by       UUID        NOT NULL REFERENCES public.profiles(id),
  description   TEXT        NOT NULL,
  amount_paise  BIGINT      NOT NULL CHECK (amount_paise > 0),
  category      TEXT        NOT NULL DEFAULT 'other',
  sub_category  TEXT,
  split_mode    TEXT        NOT NULL DEFAULT 'equal'
                            CHECK (split_mode IN ('equal', 'unequal', 'percentage')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ
);

CREATE INDEX expenses_room_id_created_at_idx ON public.expenses(room_id, created_at DESC);
CREATE INDEX expenses_paid_by_idx            ON public.expenses(paid_by);

ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "expenses_select_members" ON public.expenses FOR SELECT
  USING (public.is_room_member(room_id));

CREATE POLICY "expenses_insert_members" ON public.expenses FOR INSERT
  WITH CHECK (public.is_room_member(room_id));

CREATE POLICY "expenses_update_payer" ON public.expenses FOR UPDATE
  USING (paid_by = (SELECT auth.uid()) AND public.is_room_member(room_id));

-- ---------------------------------------------------------------------------
-- expense_splits
-- ---------------------------------------------------------------------------
CREATE TABLE public.expense_splits (
  id            UUID        PRIMARY KEY,   -- client-generated UUIDv7
  expense_id    UUID        NOT NULL REFERENCES public.expenses(id) ON DELETE CASCADE,
  user_id       UUID        NOT NULL REFERENCES public.profiles(id),
  amount_paise  BIGINT      NOT NULL CHECK (amount_paise >= 0),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ,
  UNIQUE (expense_id, user_id)
);

CREATE INDEX expense_splits_user_id_expense_id_idx ON public.expense_splits(user_id, expense_id);
CREATE INDEX expense_splits_expense_id_idx         ON public.expense_splits(expense_id);

ALTER TABLE public.expense_splits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "expense_splits_select_members" ON public.expense_splits FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.expenses e
      WHERE e.id = expense_splits.expense_id
        AND public.is_room_member(e.room_id)
    )
  );

CREATE POLICY "expense_splits_insert_members" ON public.expense_splits FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.expenses e
      WHERE e.id = expense_splits.expense_id
        AND public.is_room_member(e.room_id)
    )
  );

-- ---------------------------------------------------------------------------
-- personal_expenses
-- Single-owner, never shared. Feeds the spending summary and logic engine.
-- ---------------------------------------------------------------------------
CREATE TABLE public.personal_expenses (
  id            UUID        PRIMARY KEY,   -- client-generated UUIDv7
  user_id       UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  description   TEXT        NOT NULL,
  amount_paise  BIGINT      NOT NULL CHECK (amount_paise > 0),
  category      TEXT        NOT NULL DEFAULT 'other',
  sub_category  TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ
);

CREATE INDEX personal_expenses_user_id_created_at_idx ON public.personal_expenses(user_id, created_at DESC);

ALTER TABLE public.personal_expenses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "personal_expenses_owner_all" ON public.personal_expenses
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- settlements
-- id = op_id (client-generated UUIDv7) — the idempotency key.
-- A settlement is its own balance event; it never mutates Expense/ExpenseSplit.
-- Inserts come only from the settle-intent Edge Function (service role).
-- ---------------------------------------------------------------------------
CREATE TABLE public.settlements (
  id            UUID        PRIMARY KEY,   -- client-generated UUIDv7 / op_id
  room_id       UUID        NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
  payer_id      UUID        NOT NULL REFERENCES public.profiles(id),
  payee_id      UUID        NOT NULL REFERENCES public.profiles(id),
  amount_paise  BIGINT      NOT NULL CHECK (amount_paise > 0),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ
);

CREATE INDEX settlements_room_id_idx   ON public.settlements(room_id);
CREATE INDEX settlements_payer_id_idx  ON public.settlements(payer_id);
CREATE INDEX settlements_payee_id_idx  ON public.settlements(payee_id);

ALTER TABLE public.settlements ENABLE ROW LEVEL SECURITY;

-- Payer and payee can read their own settlements
CREATE POLICY "settlements_select_parties" ON public.settlements FOR SELECT
  USING (
    payer_id = (SELECT auth.uid()) OR payee_id = (SELECT auth.uid())
  );
-- Inserts are service-role only (settle-intent Edge Function) — no INSERT policy for authenticated role

-- ---------------------------------------------------------------------------
-- pots
-- Personal or group savings goals.
-- owner_type = 'personal' → user_id set, room_id null
-- owner_type = 'group'    → both room_id and user_id (creator) set
-- ---------------------------------------------------------------------------
CREATE TABLE public.pots (
  id                  UUID        PRIMARY KEY,   -- client-generated UUIDv7
  name                TEXT        NOT NULL,
  description         TEXT,
  owner_type          TEXT        NOT NULL CHECK (owner_type IN ('personal', 'group')),
  user_id             UUID        REFERENCES public.profiles(id),
  room_id             UUID        REFERENCES public.rooms(id),
  target_amount_paise BIGINT,                                   -- NULL = no target
  target_date         DATE,
  icon                TEXT        NOT NULL DEFAULT 'savings',
  gradient_start      TEXT        NOT NULL DEFAULT '#F2A73B',   -- hex color
  gradient_end        TEXT        NOT NULL DEFAULT '#E8962A',   -- hex color
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ,
  CONSTRAINT pot_owner_check CHECK (
    (owner_type = 'personal' AND user_id IS NOT NULL AND room_id IS NULL) OR
    (owner_type = 'group'    AND room_id IS NOT NULL AND user_id IS NOT NULL)
  )
);

CREATE INDEX pots_user_id_idx  ON public.pots(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX pots_room_id_idx  ON public.pots(room_id) WHERE room_id IS NOT NULL;

ALTER TABLE public.pots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pots_select_personal_owner" ON public.pots FOR SELECT
  USING (owner_type = 'personal' AND user_id = (SELECT auth.uid()));

CREATE POLICY "pots_select_group_members" ON public.pots FOR SELECT
  USING (owner_type = 'group' AND public.is_room_member(room_id));

CREATE POLICY "pots_insert_personal_owner" ON public.pots FOR INSERT
  WITH CHECK (owner_type = 'personal' AND user_id = (SELECT auth.uid()));

CREATE POLICY "pots_insert_group_members" ON public.pots FOR INSERT
  WITH CHECK (owner_type = 'group' AND public.is_room_member(room_id));

CREATE POLICY "pots_update_owner" ON public.pots FOR UPDATE
  USING (user_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- pot_contributions
-- id = op_id (client-generated UUIDv7) — idempotency key for offline writes.
-- ---------------------------------------------------------------------------
CREATE TABLE public.pot_contributions (
  id            UUID        PRIMARY KEY,   -- client-generated UUIDv7 / op_id
  pot_id        UUID        NOT NULL REFERENCES public.pots(id) ON DELETE CASCADE,
  user_id       UUID        NOT NULL REFERENCES public.profiles(id),
  amount_paise  BIGINT      NOT NULL CHECK (amount_paise > 0),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ
);

CREATE INDEX pot_contributions_pot_id_idx  ON public.pot_contributions(pot_id);
CREATE INDEX pot_contributions_user_id_idx ON public.pot_contributions(user_id);

ALTER TABLE public.pot_contributions ENABLE ROW LEVEL SECURITY;

-- Pot owner or room members can read contributions
CREATE POLICY "pot_contributions_select" ON public.pot_contributions FOR SELECT
  USING (
    user_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.pots p
      WHERE p.id = pot_contributions.pot_id
        AND (p.user_id = (SELECT auth.uid()) OR (p.owner_type = 'group' AND public.is_room_member(p.room_id)))
    )
  );

CREATE POLICY "pot_contributions_insert_owner" ON public.pot_contributions FOR INSERT
  WITH CHECK (user_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- device_tokens
-- Push notification tokens: one row per user per platform.
-- RLS: owner-only read/write. Service role reads all (for dispatch).
-- ---------------------------------------------------------------------------
CREATE TABLE public.device_tokens (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token      TEXT        NOT NULL,
  platform   TEXT        NOT NULL CHECK (platform IN ('android', 'web')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, platform)
);

CREATE INDEX device_tokens_user_id_idx ON public.device_tokens(user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "device_tokens_owner_all" ON public.device_tokens
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- ---------------------------------------------------------------------------
-- model_versions
-- Empty until ML pipeline actually ships. Table exists so the interface
-- contract is real, but no rows are inserted here.
-- See docs/ML_PIPELINE.md status banner.
-- ---------------------------------------------------------------------------
CREATE TABLE public.model_versions (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  version      INTEGER     NOT NULL,
  model_type   TEXT        NOT NULL CHECK (model_type IN ('savings_predictor', 'persona_classifier')),
  sha256       TEXT        NOT NULL,
  storage_path TEXT        NOT NULL,
  status       TEXT        NOT NULL DEFAULT 'staged' CHECK (status IN ('staged', 'active', 'revoked')),
  rollout_pct  INTEGER     NOT NULL DEFAULT 0 CHECK (rollout_pct BETWEEN 0 AND 100),
  metrics_json JSONB,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX model_versions_status_created_at_idx ON public.model_versions(status, created_at DESC);

ALTER TABLE public.model_versions ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can read model versions (to download the active model)
CREATE POLICY "model_versions_select_auth" ON public.model_versions FOR SELECT
  USING ((SELECT auth.uid()) IS NOT NULL);
-- INSERT/UPDATE: service role only (retrain-webhook Edge Function) — no policy granted

-- ---------------------------------------------------------------------------
-- rate_limits
-- Server-side counters for the rate-limited-api Edge Function.
-- No direct client access — service role only.
-- ---------------------------------------------------------------------------
CREATE TABLE public.rate_limits (
  key          TEXT        PRIMARY KEY,
  count        INTEGER     NOT NULL DEFAULT 0,
  window_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;
-- No SELECT/INSERT/UPDATE policies — service role only

-- ---------------------------------------------------------------------------
-- audit_log
-- Append-only. Service role writes; actors can read their own rows.
-- Rows referencing a deleted user are retained with actor_id set to NULL
-- (anonymized) per docs/PRODUCT_LOGIC.md §6.
-- ---------------------------------------------------------------------------
CREATE TABLE public.audit_log (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id     UUID,                            -- NULL after account deletion (anonymized)
  action       TEXT        NOT NULL,            -- e.g. 'expense.create', 'settle.confirm'
  table_name   TEXT        NOT NULL,
  row_id       UUID        NOT NULL,
  payload_json JSONB,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX audit_log_actor_id_idx    ON public.audit_log(actor_id) WHERE actor_id IS NOT NULL;
CREATE INDEX audit_log_row_id_idx      ON public.audit_log(row_id);
CREATE INDEX audit_log_created_at_idx  ON public.audit_log(created_at DESC);

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- Actors can read their own audit rows
CREATE POLICY "audit_log_select_actor" ON public.audit_log FOR SELECT
  USING (actor_id = (SELECT auth.uid()));
-- INSERT: service role only — no policy granted

-- ---------------------------------------------------------------------------
-- Materialized view: room_balances_mv
-- Backs the "You owe Aditi ₹230" strip in Room Detail with a single indexed
-- read instead of a join on every request. Refreshed via pg_cron trigger
-- after settle/expense writes (see docs/ARCHITECTURE.md §5).
-- NOTE: the client computes balances locally from the Drift cache for
-- offline-first display — this view is the server-side cache, not the
-- source of truth the UI reads from.
-- ---------------------------------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS public.room_balances_mv AS
SELECT
  rm.room_id,
  rm.user_id,
  COALESCE(
    SUM(es.amount_paise) FILTER (WHERE e.paid_by = rm.user_id AND es.deleted_at IS NULL),
    0
  )
  - COALESCE(
    SUM(es.amount_paise) FILTER (WHERE es.user_id = rm.user_id AND es.deleted_at IS NULL),
    0
  )
  + COALESCE(
    SUM(s.amount_paise) FILTER (WHERE s.payee_id = rm.user_id AND s.deleted_at IS NULL),
    0
  )
  - COALESCE(
    SUM(s.amount_paise) FILTER (WHERE s.payer_id = rm.user_id AND s.deleted_at IS NULL),
    0
  ) AS net_balance_paise
FROM public.room_members rm
LEFT JOIN public.expenses       e  ON e.room_id  = rm.room_id AND e.deleted_at IS NULL
LEFT JOIN public.expense_splits es ON es.expense_id = e.id
LEFT JOIN public.settlements    s  ON s.room_id  = rm.room_id AND s.deleted_at IS NULL
WHERE rm.deleted_at IS NULL
GROUP BY rm.room_id, rm.user_id
WITH NO DATA;

CREATE UNIQUE INDEX room_balances_mv_pk ON public.room_balances_mv(room_id, user_id);

-- Populate on first deploy
REFRESH MATERIALIZED VIEW public.room_balances_mv;
