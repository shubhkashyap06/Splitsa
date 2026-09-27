-- Splitsa seed data — development environment only
-- Run via: supabase db seed (or psql against the dev project)

-- NOTE: These are synthetic users that match the reference prototype's
-- mock data (reference/figma-export/src/lib/data.ts).
-- DO NOT run against staging or production.

-- Profiles are auto-created by the handle_new_user trigger on auth.users insert,
-- so we insert into auth.users first (only possible with service role / seed script).

-- Dev test accounts (phone replaced with email-OTP)
-- The test OTP for local dev was replaced with email-OTP for hosted dev.
-- Seed data below uses service role to bypass RLS.

DO $$
DECLARE
  uid_shubh  UUID := 'a1000000-0000-0000-0000-000000000001';
  uid_aditi  UUID := 'a1000000-0000-0000-0000-000000000002';
  uid_rahul  UUID := 'a1000000-0000-0000-0000-000000000003';
  room_flat  UUID := 'b1000000-0000-0000-0000-000000000001';
  room_goa   UUID := 'b1000000-0000-0000-0000-000000000002';
BEGIN

  -- Profiles (trigger should have created these from auth.users, but in seed we insert directly)
  INSERT INTO public.profiles (id, display_name, email, created_at, updated_at)
  VALUES
    (uid_shubh, 'Shubh', 'shubh@splitsa.dev',  NOW(), NOW()),
    (uid_aditi, 'Aditi', 'aditi@splitsa.dev', NOW(), NOW()),
    (uid_rahul, 'Rahul', 'rahul@splitsa.dev', NOW(), NOW())
  ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name;

  -- Rooms
  INSERT INTO public.rooms (id, name, description, icon, created_by, created_at, updated_at)
  VALUES
    (room_flat, 'Flat 4B',    '3 BHK, Koramangala', 'house', uid_shubh, NOW(), NOW()),
    (room_goa,  'Goa Trip 🌴', 'March trip',         'plane', uid_aditi, NOW(), NOW())
  ON CONFLICT (id) DO NOTHING;

  -- Room members
  INSERT INTO public.room_members (room_id, user_id, joined_at, updated_at)
  VALUES
    (room_flat, uid_shubh, NOW(), NOW()),
    (room_flat, uid_aditi, NOW(), NOW()),
    (room_flat, uid_rahul, NOW(), NOW()),
    (room_goa,  uid_aditi, NOW(), NOW()),
    (room_goa,  uid_shubh, NOW(), NOW())
  ON CONFLICT (room_id, user_id) DO NOTHING;

  -- A few expenses so balances aren't zero
  INSERT INTO public.expenses (id, room_id, paid_by, description, amount_paise, category, split_mode, created_at, updated_at)
  VALUES
    (gen_random_uuid(), room_flat, uid_aditi, 'Electricity bill', 360000, 'home', 'equal', NOW() - INTERVAL '3 days', NOW()),
    (gen_random_uuid(), room_flat, uid_shubh, 'Swiggy dinner',    125000, 'food', 'equal', NOW() - INTERVAL '1 day',  NOW()),
    (gen_random_uuid(), room_goa,  uid_aditi, 'Flight tickets',  1200000, 'travel', 'equal', NOW() - INTERVAL '5 days', NOW())
  ON CONFLICT (id) DO NOTHING;

  -- Dev pots
  INSERT INTO public.pots (id, name, owner_type, user_id, target_amount_paise, icon, gradient_start, gradient_end, created_at, updated_at)
  VALUES
    (gen_random_uuid(), 'Rainy Day Fund', 'personal', uid_shubh, 5000000, 'savings', '#2F9E8F', '#1F7A6E', NOW(), NOW())
  ON CONFLICT (id) DO NOTHING;

END $$;
