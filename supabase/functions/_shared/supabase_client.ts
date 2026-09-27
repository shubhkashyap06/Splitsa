import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

/**
 * Creates a Supabase client with SERVICE_ROLE key for Edge Function use.
 * Never expose the service role key to the client.
 */
export function createServiceClient() {
  const url = Deno.env.get('SUPABASE_URL')!;
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  return createClient(url, key, {
    auth: { persistSession: false },
  });
}

/**
 * Creates a Supabase client scoped to the calling user's JWT.
 * Use for operations that should respect RLS.
 */
export function createUserClient(authHeader: string) {
  const url = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  return createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
}
