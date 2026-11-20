/// DemoRemoteGateway — an in-process stand-in for Supabase used only when
/// the app is built with `--dart-define=DEMO=true` (dev builds).
///
/// It accepts every push (so the outbox drains and "pending" markers clear,
/// exactly like a healthy connection), returns nothing on pull (the seeded
/// local DB is the whole world), and answers the Edge Functions with
/// plausible responses so settle-up and invites can be demoed end to end.
/// It is never constructed outside demo mode — see `remoteGatewayProvider`.
library;

import 'dart:math';

import '../local/database.dart';
import 'remote_gateway.dart';

const kDemoUserId = '019a0000-0000-7000-8000-00000000d001';
const kDemoEmail = 'demo@splitsa.local';

class DemoRemoteGateway implements RemoteGateway {
  DemoRemoteGateway(this._db);
  final AppDatabase _db;
  final _random = Random();

  Future<void> _latency() =>
      Future<void>.delayed(Duration(milliseconds: 250 + _random.nextInt(250)));

  @override
  Future<void> insert(String table, Json row) => _latency();

  @override
  Future<void> update(String table, String id, Json values) => _latency();

  @override
  Future<List<Json>> fetchSince(
    String table,
    DateTime? since,
    int limit,
  ) async => const [];

  @override
  Future<List<Json>> fetchWhereIn(
    String table,
    String column,
    List<String> values,
  ) async => const [];

  @override
  Future<Json> invoke(String function, Json body) async {
    await _latency();
    switch (function) {
      case 'settle-intent':
        final payee = await _db.profileDao.getProfile(
          body['payee_id'] as String,
        );
        return {
          'op_id': body['op_id'],
          'validated_amount_paise': body['amount_paise'],
          'upi_id': payee?.upiId,
          'payee_display_name': payee?.displayName ?? 'them',
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
      case 'room-invite':
        if (body['action'] == 'create') {
          const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
          return {
            'invite_id': 'demo',
            'token': List.generate(
              64,
              (_) => '0123456789abcdef'[_random.nextInt(16)],
            ).join(),
            'display_code': List.generate(
              6,
              (_) => alphabet[_random.nextInt(alphabet.length)],
            ).join(),
            'expires_at': DateTime.now()
                .add(const Duration(days: 7))
                .toUtc()
                .toIso8601String(),
            'max_uses': 10,
          };
        }
        throw const RemoteFailure(
          RemoteFailureKind.permanent,
          'Demo mode — joining a real room needs the live backend',
        );
      default:
        throw RemoteFailure(
          RemoteFailureKind.permanent,
          'Demo mode — $function needs the live backend',
        );
    }
  }
}
