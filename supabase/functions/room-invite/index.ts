import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { createServiceClient, createUserClient } from '../_shared/supabase_client.ts';

/** 6-char uppercase alphanumeric display code */
function generateDisplayCode(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1 — easy to read aloud
  return Array.from({ length: 6 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
}

/** Cryptographically random token (32 bytes → 64-char hex) */
function generateToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, b => b.toString(16).padStart(2, '0')).join('');
}

/**
 * room-invite — create or redeem room invites.
 *
 * POST { action: 'create', room_id: string, max_uses?: number }
 *   → 200 { invite_id, token, display_code, expires_at }
 *
 * POST { action: 'join', code: string }   (display_code or token)
 *   → 200 { room_id, room_name, member_count }
 *
 * POST { action: 'confirm_join', code: string }
 *   → 200 { room_id }
 */
Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const body = await req.json() as { action: string; room_id?: string; max_uses?: number; code?: string };
    const userClient  = createUserClient(authHeader);
    const adminClient = createServiceClient();

    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // --- create ---
    if (body.action === 'create') {
      const { room_id, max_uses = 10 } = body;
      if (!room_id) return new Response(JSON.stringify({ error: 'room_id required' }), { status: 400, headers: corsHeaders });

      // Must be a room member to invite
      const { data: member } = await adminClient.from('room_members').select('id').eq('room_id', room_id).eq('user_id', user.id).is('deleted_at', null).single();
      if (!member) return new Response(JSON.stringify({ error: 'Not a room member' }), { status: 403, headers: corsHeaders });

      const token       = generateToken();
      let   displayCode = generateDisplayCode();
      // Retry on collision (astronomically unlikely but safe)
      for (let i = 0; i < 5; i++) {
        const { data: collision } = await adminClient.from('room_invites').select('id').eq('display_code', displayCode).single();
        if (!collision) break;
        displayCode = generateDisplayCode();
      }

      const { data: invite, error: inviteErr } = await adminClient.from('room_invites').insert({
        room_id, token, display_code: displayCode,
        created_by: user.id, max_uses,
        expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
      }).select().single();

      if (inviteErr) return new Response(JSON.stringify({ error: 'Failed to create invite' }), { status: 500, headers: corsHeaders });
      return new Response(JSON.stringify({ invite_id: invite.id, token, display_code: displayCode, expires_at: invite.expires_at }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    // --- preview join ---
    if (body.action === 'join') {
      const code = body.code?.trim().toUpperCase();
      if (!code) return new Response(JSON.stringify({ error: 'code required' }), { status: 400, headers: corsHeaders });

      const { data: invite } = await adminClient.from('room_invites')
        .select('id, room_id, expires_at, max_uses, used_count')
        .or(`display_code.eq.${code},token.eq.${code.toLowerCase()}`)
        .is('deleted_at', null)
        .single();

      if (!invite) return new Response(JSON.stringify({ error: 'Invalid or expired code' }), { status: 404, headers: corsHeaders });
      if (new Date(invite.expires_at) < new Date()) return new Response(JSON.stringify({ error: 'Invite expired' }), { status: 410, headers: corsHeaders });
      if (invite.used_count >= invite.max_uses) return new Response(JSON.stringify({ error: 'Invite fully used' }), { status: 410, headers: corsHeaders });

      const { data: room } = await adminClient.from('rooms').select('name, icon').eq('id', invite.room_id).single();
      const { count: memberCount } = await adminClient.from('room_members').select('id', { count: 'exact', head: true }).eq('room_id', invite.room_id).is('deleted_at', null);

      return new Response(JSON.stringify({ room_id: invite.room_id, room_name: room?.name, room_icon: room?.icon, member_count: memberCount ?? 0 }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    // --- confirm join ---
    if (body.action === 'confirm_join') {
      const code = body.code?.trim().toUpperCase();
      if (!code) return new Response(JSON.stringify({ error: 'code required' }), { status: 400, headers: corsHeaders });

      const { data: invite } = await adminClient.from('room_invites')
        .select('id, room_id, expires_at, max_uses, used_count')
        .or(`display_code.eq.${code},token.eq.${code.toLowerCase()}`)
        .is('deleted_at', null)
        .single();

      if (!invite) return new Response(JSON.stringify({ error: 'Invalid code' }), { status: 404, headers: corsHeaders });
      if (new Date(invite.expires_at) < new Date() || invite.used_count >= invite.max_uses) {
        return new Response(JSON.stringify({ error: 'Invite expired or fully used' }), { status: 410, headers: corsHeaders });
      }

      // Idempotent: already a member is OK
      const { data: existing } = await adminClient.from('room_members').select('id').eq('room_id', invite.room_id).eq('user_id', user.id).is('deleted_at', null).single();
      if (!existing) {
        await adminClient.from('room_members').insert({ room_id: invite.room_id, user_id: user.id });
        await adminClient.from('room_invites').update({ used_count: invite.used_count + 1 }).eq('id', invite.id);
      }

      return new Response(JSON.stringify({ room_id: invite.room_id }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    return new Response(JSON.stringify({ error: 'Unknown action' }), { status: 400, headers: corsHeaders });

  } catch (err) {
    console.error('room-invite error:', err);
    return new Response(JSON.stringify({ error: 'Internal server error' }), { status: 500, headers: corsHeaders });
  }
});
