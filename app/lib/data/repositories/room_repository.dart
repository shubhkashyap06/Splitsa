import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/ids.dart';
import '../local/database.dart';
import '../remote/remote_gateway.dart';
import '../remote/session.dart';
import '../sync/outbox.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_providers.dart';
import '../sync/synced_tables.dart';

part 'room_repository.g.dart';

class InviteCode {
  const InviteCode({
    required this.displayCode,
    required this.token,
    required this.expiresAt,
  });
  final String displayCode;
  final String token;
  final DateTime expiresAt;

  /// Deep link handled by the app's `/join` route, or null when no public
  /// web origin is configured (then only the short code is shared).
  String? linkFor(String webOrigin) =>
      webOrigin.isEmpty ? null : '$webOrigin/join?code=$token';
}

class RoomPreview {
  const RoomPreview({
    required this.roomId,
    required this.name,
    required this.icon,
    required this.memberCount,
    required this.memberNames,
  });
  final String roomId;
  final String name;
  final String icon;
  final int memberCount;
  final List<String> memberNames;
}

/// User-facing failure for online-only room actions (invites/joins).
class RoomActionError implements Exception {
  const RoomActionError(this.message);
  final String message;
  @override
  String toString() => message;
}

class RoomRepository {
  RoomRepository(
    this._db,
    this._remote,
    this._engine, {
    void Function()? onWrite,
  }) : _outbox = Outbox(_db),
       _onWrite = onWrite ?? _noop;

  final AppDatabase _db;
  final RemoteGateway _remote;
  final SyncEngine _engine;
  final Outbox _outbox;
  final void Function() _onWrite;

  static void _noop() {}

  /// Creates a room offline-first: the room and the creator's own
  /// membership are written locally and queued (room first — FIFO — so the
  /// membership insert passes the `is_room_creator` policy).
  Future<String> createRoom({
    required String name,
    required String createdBy,
    String icon = 'house',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const RoomActionError('Give the room a name');
    final now = DateTime.now();
    final room = RoomsTableData(
      id: newId(),
      name: trimmed,
      icon: icon,
      createdBy: createdBy,
      createdAt: now,
      updatedAt: now,
    );
    final member = RoomMembersTableData(
      id: newId(),
      roomId: room.id,
      userId: createdBy,
      joinedAt: now,
      updatedAt: now,
    );
    await _db.transaction(() async {
      await _db.into(_db.roomsTable).insert(room);
      await _outbox.insert(roomsSync.name, room.id, roomsSync.toRemote(room));
      await _db.into(_db.roomMembersTable).insert(member);
      await _outbox.insert(
        roomMembersSync.name,
        member.id,
        roomMembersSync.toRemote(member),
      );
    });
    _onWrite();
    return room.id;
  }

  // ── Online-only: invites need the server to mint/validate tokens ─────────

  Future<InviteCode> createInvite(String roomId) async {
    // A room created offline must exist server-side before it can be shared.
    await _engine.sync(force: true);
    final res = await _call('room-invite', {
      'action': 'create',
      'room_id': roomId,
    });
    return InviteCode(
      displayCode: res['display_code'] as String,
      token: res['token'] as String,
      expiresAt: DateTime.parse(res['expires_at'] as String),
    );
  }

  Future<RoomPreview> previewInvite(String code) async {
    final res = await _call('room-invite', {'action': 'preview', 'code': code});
    return RoomPreview(
      roomId: res['room_id'] as String,
      name: res['room_name'] as String? ?? 'Room',
      icon: res['room_icon'] as String? ?? 'house',
      memberCount: (res['member_count'] as num?)?.toInt() ?? 0,
      memberNames: List<String>.from(res['member_names'] as List? ?? const []),
    );
  }

  /// Joins, then pulls immediately so the room (and its backfilled history)
  /// is in the local DB before the caller navigates to it.
  Future<String> joinWithCode(String code) async {
    final res = await _call('room-invite', {
      'action': 'confirm_join',
      'code': code,
    });
    await _engine.sync(force: true);
    return res['room_id'] as String;
  }

  Future<Json> _call(String fn, Json body) async {
    try {
      return await _remote.invoke(fn, body);
    } on RemoteFailure catch (e) {
      if (e.kind == RemoteFailureKind.transient) {
        throw const RoomActionError(
          'You\'re offline — invites need a connection',
        );
      }
      throw RoomActionError(e.message);
    }
  }
}

@Riverpod(keepAlive: true)
RoomRepository roomRepository(Ref ref) => RoomRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(remoteGatewayProvider),
  ref.watch(syncEngineProvider),
  onWrite: () => ref.read(syncSchedulerProvider).kick(),
);
