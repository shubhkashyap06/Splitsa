import { corsHeaders, handleCors } from '../_shared/cors.ts';
import { createServiceClient, createUserClient } from '../_shared/supabase_client.ts';

/**
 * settle-intent — validates and records a debt settlement.
 *
 * Called by the Flutter app's Settle Up flow BEFORE opening the UPI deep link.
 * The app must receive and display the server-validated amount from this
 * response — it must NOT use a locally-computed amount for the final
 * settlement numeral (see docs/UI_UX_SPEC.md §4 "Settle Up").
 *
 * POST body:
 *   { op_id: string (UUIDv7), room_id: string, payee_id: string, amount_paise: number }
 *
 * Response:
 *   200 { op_id, validated_amount_paise, upi_id, payee_display_name }
 *   4xx { error: string }
 */
Deno.serve(async (req: Request) => {
  const corsResponse = handleCors(req);
  if (corsResponse) return corsResponse;

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
      status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const body = await req.json() as {
      op_id: string;
      room_id: string;
      payee_id: string;
      amount_paise: number;
    };

    const { op_id, room_id, payee_id, amount_paise } = body;

    if (!op_id || !room_id || !payee_id || !amount_paise) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (amount_paise <= 0 || amount_paise > 10_000_000_00) {
      return new Response(JSON.stringify({ error: 'Amount out of range' }), {
        status: 422, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const userClient   = createUserClient(authHeader);
    const adminClient  = createServiceClient();

    // Resolve the caller's user ID from JWT
    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Verify caller is a member of this room
    const { data: membership } = await adminClient
      .from('room_members')
      .select('id')
      .eq('room_id', room_id)
      .eq('user_id', user.id)
      .is('deleted_at', null)
      .single();

    if (!membership) {
      return new Response(JSON.stringify({ error: 'Not a room member' }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Idempotency: if op_id already exists, return the existing settlement
    const { data: existing } = await adminClient
      .from('settlements')
      .select('id, amount_paise')
      .eq('id', op_id)
      .single();

    if (existing) {
      const { data: payeeProfile } = await adminClient
        .from('profiles')
        .select('display_name, upi_id')
        .eq('id', payee_id)
        .single();
      return new Response(JSON.stringify({
        op_id,
        validated_amount_paise: existing.amount_paise,
        upi_id: payeeProfile?.upi_id ?? null,
        payee_display_name: payeeProfile?.display_name ?? 'Unknown',
      }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    // Fetch payee's UPI ID and display name
    const { data: payeeProfile, error: profileError } = await adminClient
      .from('profiles')
      .select('display_name, upi_id')
      .eq('id', payee_id)
      .single();

    if (profileError || !payeeProfile) {
      return new Response(JSON.stringify({ error: 'Payee not found' }), {
        status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Insert settlement (service role bypasses RLS — settlements are service-role only)
    const { error: insertError } = await adminClient
      .from('settlements')
      .insert({
        id:           op_id,
        room_id,
        payer_id:     user.id,
        payee_id,
        amount_paise,
      });

    if (insertError) {
      console.error('settle-intent insert error:', insertError);
      return new Response(JSON.stringify({ error: 'Failed to record settlement' }), {
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Write to audit_log
    await adminClient.from('audit_log').insert({
      actor_id:     user.id,
      action:       'settle.confirm',
      table_name:   'settlements',
      row_id:       op_id,
      payload_json: { room_id, payer_id: user.id, payee_id, amount_paise },
    });

    return new Response(JSON.stringify({
      op_id,
      validated_amount_paise: amount_paise,
      upi_id: payeeProfile.upi_id ?? null,
      payee_display_name: payeeProfile.display_name,
    }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

  } catch (err) {
    console.error('settle-intent error:', err);
    return new Response(JSON.stringify({ error: 'Internal server error' }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
