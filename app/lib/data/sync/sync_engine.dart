/// SyncEngine — reconciles the local Drift DB with Supabase
/// (OFFLINE_SYNC.md §2–§4). Own code, deliberately not a pub.dev package.
///
///   push: drain `sync_queue` FIFO. Every op carries its row id (= the
///         idempotency key), so a replay after a flaky connection is a
///         no-op server-side. Transient failure → stop and back off with
///         jitter; permanent failure → count toward dead-letter, continue.
///   pull: per table, fetch `updated_at > watermark` (never a full table),
///         upsert locally, advance the watermark. Rows with a pending local
///         write are skipped so an older server copy can't clobber them.
///   backfill: a room we just joined has history *older* than our
///         watermark — delta sync alone would never fetch it, so the first
///         time a membership appears we pull that room's rows by id.
///
/// The UI never calls this directly; it watches Drift streams that update
/// the moment a pull transaction commits.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../local/database.dart';
import '../remote/remote_gateway.dart';
import 'synced_tables.dart';

enum SyncPhase { idle, syncing, offline, unauthorized }

class SyncStatus {
  const SyncStatus({required this.phase, this.lastSyncedAt, this.lastError});

  final SyncPhase phase;
  final DateTime? lastSyncedAt;
  final String? lastError;

  static const initial = SyncStatus(phase: SyncPhase.idle);
}

class SyncEngine {
  SyncEngine({
    required this.db,
    required this.remote,
    required this.currentUserId,
    DateTime Function()? clock,
    Random? random,
    this.pageSize = 500,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random();

  final AppDatabase db;
  final RemoteGateway remote;
  final String? Function() currentUserId;
  final int pageSize;
  final DateTime Function() _clock;
  final Random _random;

  final _status = StreamController<SyncStatus>.broadcast();
  SyncStatus _current = SyncStatus.initial;

  bool _running = false;
  bool _rerunRequested = false;
  int _consecutiveFailures = 0;
  DateTime? _nextAttemptAt;

  Stream<SyncStatus> get statusStream => _status.stream;
  SyncStatus get status => _current;

  /// Runs push then pull. Concurrent calls coalesce into one extra pass.
  /// [force] ignores the backoff window (pull-to-refresh, sign-in).
  Future<void> sync({bool force = false}) async {
    if (currentUserId() == null) return;
    if (_running) {
      _rerunRequested = true;
      return;
    }
    final now = _clock();
    if (!force && _nextAttemptAt != null && now.isBefore(_nextAttemptAt!)) {
      return;
    }

    _running = true;
    _emit(
      SyncStatus(phase: SyncPhase.syncing, lastSyncedAt: _current.lastSyncedAt),
    );
    try {
      do {
        _rerunRequested = false;
        await _push();
        await _pull();
      } while (_rerunRequested);

      _consecutiveFailures = 0;
      _nextAttemptAt = null;
      _emit(SyncStatus(phase: SyncPhase.idle, lastSyncedAt: _clock()));
    } on RemoteFailure catch (e) {
      if (e.kind == RemoteFailureKind.unauthorized) {
        _emit(
          SyncStatus(
            phase: SyncPhase.unauthorized,
            lastSyncedAt: _current.lastSyncedAt,
            lastError: e.message,
          ),
        );
      } else {
        _consecutiveFailures++;
        _nextAttemptAt = _clock().add(backoffFor(_consecutiveFailures));
        _emit(
          SyncStatus(
            phase: SyncPhase.offline,
            lastSyncedAt: _current.lastSyncedAt,
            lastError: e.message,
          ),
        );
      }
    } finally {
      _running = false;
    }
  }

  /// Exponential backoff with full jitter, capped at 5 minutes — avoids every
  /// queued client hammering the API in lockstep on reconnect.
  Duration backoffFor(int failures) {
    final capSeconds = min(300, pow(2, min(failures, 9)).toInt());
    final jittered = (capSeconds * (0.5 + _random.nextDouble() * 0.5)).round();
    return Duration(seconds: max(1, jittered));
  }

  Future<void> dispose() => _status.close();

  void _emit(SyncStatus s) {
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  // ── Push ──────────────────────────────────────────────────────────────────

  Future<void> _push() async {
    final attempted = <String>{};
    while (true) {
      final batch = (await db.syncDao.pendingOps(
        limit: 50,
      )).where((op) => !attempted.contains(op.opId)).toList();
      if (batch.isEmpty) return;

      for (final op in batch) {
        attempted.add(op.opId);
        try {
          await _apply(op);
          await db.syncDao.markSuccess(op.opId);
        } on RemoteFailure catch (e) {
          if (e.kind != RemoteFailureKind.permanent) rethrow;
          await db.syncDao.recordFailure(op.opId, e.message);
        }
      }
    }
  }

  Future<void> _apply(SyncQueueTableData op) async {
    final payload = Map<String, dynamic>.from(
      jsonDecode(op.payloadJson) as Map,
    );
    switch (op.operation) {
      case 'insert':
        await remote.insert(op.tableName_, payload);
      case 'update':
      case 'delete': // soft delete = update carrying deleted_at
        payload
          ..remove('id')
          ..remove('created_at');
        await remote.update(op.tableName_, op.rowId, payload);
      default:
        throw RemoteFailure(
          RemoteFailureKind.permanent,
          'Unknown operation ${op.operation}',
        );
    }
  }

  // ── Pull ──────────────────────────────────────────────────────────────────

  Future<void> _pull() async {
    final pending = await db.syncDao.pendingRowIds();
    for (final table in kSyncedTables) {
      if (table.name == roomMembersSync.name) {
        await _pullMembersWithBackfill(pending);
      } else {
        await _pullTable(table, pending);
      }
    }
  }

  Future<void> _pullTable(
    SyncedTable<dynamic> table,
    Set<String> pending,
  ) async {
    var since = await db.syncDao.getWatermark(table.name);
    while (true) {
      final rows = await remote.fetchSince(table.name, since, pageSize);
      if (rows.isEmpty) return;
      since = await _upsertBatch(table, rows, pending, since);
      if (rows.length < pageSize) return;
    }
  }

  /// Upserts [rows] and advances the watermark. Returns the new in-memory
  /// watermark (full precision — the stored one may be truncated).
  Future<DateTime?> _upsertBatch(
    SyncedTable<dynamic> table,
    List<Json> rows,
    Set<String> pending,
    DateTime? since,
  ) async {
    var watermark = since;
    await db.transaction(() async {
      for (final row in rows) {
        final updatedAt = DateTime.parse(row['updated_at'] as String);
        if (watermark == null || updatedAt.isAfter(watermark!)) {
          watermark = updatedAt;
        }
        if (pending.contains(row['id'])) {
          continue; // local write wins until pushed
        }
        await table.upsertRemote(db, row);
      }
      if (watermark != null) {
        await db.syncDao.setWatermark(table.name, watermark!, rows.length);
      }
    });
    return watermark;
  }

  Future<void> _upsertAll(
    SyncedTable<dynamic> table,
    List<Json> rows,
    Set<String> pending,
  ) => db.transaction(() async {
    for (final row in rows) {
      if (pending.contains(row['id'])) continue;
      await table.upsertRemote(db, row);
    }
  });

  Future<void> _pullMembersWithBackfill(Set<String> pending) async {
    final me = currentUserId();
    if (me == null) return;

    final roomsBefore = await _activeRoomIds(me);
    await _pullTable(roomMembersSync, pending);
    final roomsAfter = await _activeRoomIds(me);
    final newRooms = roomsAfter.difference(roomsBefore).toList();

    if (newRooms.isNotEmpty) {
      await _backfillRooms(newRooms, pending);
    }
    await _backfillMissingProfiles(pending);
  }

  Future<Set<String>> _activeRoomIds(String userId) async {
    final rows =
        await (db.select(db.roomMembersTable)
              ..where((t) => t.userId.equals(userId))
              ..where((t) => t.deletedAt.isNull()))
            .get();
    return rows.map((r) => r.roomId).toSet();
  }

  Future<void> _backfillRooms(List<String> roomIds, Set<String> pending) async {
    await _upsertAll(
      roomsSync,
      await remote.fetchWhereIn('rooms', 'id', roomIds),
      pending,
    );
    await _upsertAll(
      roomMembersSync,
      await remote.fetchWhereIn('room_members', 'room_id', roomIds),
      pending,
    );

    final expenses = await remote.fetchWhereIn('expenses', 'room_id', roomIds);
    await _upsertAll(expensesSync, expenses, pending);
    final expenseIds = expenses.map((e) => e['id'] as String).toList();
    for (final chunk in _chunks(expenseIds, 100)) {
      await _upsertAll(
        expenseSplitsSync,
        await remote.fetchWhereIn('expense_splits', 'expense_id', chunk),
        pending,
      );
    }

    await _upsertAll(
      settlementsSync,
      await remote.fetchWhereIn('settlements', 'room_id', roomIds),
      pending,
    );

    final pots = await remote.fetchWhereIn('pots', 'room_id', roomIds);
    await _upsertAll(potsSync, pots, pending);
    final potIds = pots.map((p) => p['id'] as String).toList();
    for (final chunk in _chunks(potIds, 100)) {
      await _upsertAll(
        potContributionsSync,
        await remote.fetchWhereIn('pot_contributions', 'pot_id', chunk),
        pending,
      );
    }
  }

  /// A co-member who joined long ago has an old `profiles.updated_at`, so the
  /// delta pull won't bring their name in — fetch any we don't have yet.
  Future<void> _backfillMissingProfiles(Set<String> pending) async {
    final memberIds = (await db.select(db.roomMembersTable).get())
        .map((m) => m.userId)
        .toSet();
    final known = (await db.select(db.profilesTable).get())
        .map((p) => p.id)
        .toSet();
    final missing = memberIds.difference(known).toList();
    for (final chunk in _chunks(missing, 100)) {
      await _upsertAll(
        profilesSync,
        await remote.fetchWhereIn('profiles', 'id', chunk),
        pending,
      );
    }
  }

  static Iterable<List<String>> _chunks(List<String> ids, int size) sync* {
    for (var i = 0; i < ids.length; i += size) {
      yield ids.sublist(i, min(i + size, ids.length));
    }
  }
}
