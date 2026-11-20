import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/sync_tables.dart';

part 'sync_dao.g.dart';

/// Ops that hit a permanent server error this many times are parked
/// (dead-lettered) so one bad row can't block the whole outbox forever.
const int kMaxSyncRetries = 5;

@DriftAccessor(tables: [SyncQueueTable, SyncStateTable])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  // ── Outbox (sync_queue) ──────────────────────────────────────────────────

  Future<void> enqueue(SyncQueueTableCompanion op) =>
      into(syncQueueTable).insert(op);

  /// Pending (non-dead-lettered) operations in strict insertion order —
  /// FIFO keeps a parent row (expense) ahead of its children (splits).
  ///
  /// Ordered by SQLite's implicit `rowid`, not `created_at`: Drift stores
  /// DateTimes at second precision, so an expense and its splits written in
  /// the same second would otherwise tie and could push out of order.
  Future<List<SyncQueueTableData>> pendingOps({int limit = 50}) => customSelect(
    'SELECT * FROM sync_queue WHERE retry_count < ? ORDER BY rowid ASC LIMIT ?',
    variables: [Variable.withInt(kMaxSyncRetries), Variable.withInt(limit)],
    readsFrom: {syncQueueTable},
  ).asyncMap((row) => syncQueueTable.map(row.data)).get();

  Future<void> markSuccess(String opId) =>
      (delete(syncQueueTable)..where((t) => t.opId.equals(opId))).go();

  Future<void> recordFailure(String opId, String error) async {
    await customUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1, last_error = ? '
      'WHERE op_id = ?',
      variables: [Variable.withString(error), Variable.withString(opId)],
      updates: {syncQueueTable},
    );
  }

  Future<int> queueLength() async {
    final count = syncQueueTable.opId.count();
    final row =
        await (selectOnly(syncQueueTable)
              ..addColumns([count])
              ..where(
                syncQueueTable.retryCount.isSmallerThanValue(kMaxSyncRetries),
              ))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Row ids with an unsynced local write — the UI marks these "pending"
  /// and the delta pull must not overwrite them with older server state.
  Stream<Set<String>> watchPendingRowIds() =>
      (selectOnly(syncQueueTable)..addColumns([syncQueueTable.rowId]))
          .map((r) => r.read(syncQueueTable.rowId)!)
          .watch()
          .map((ids) => ids.toSet());

  Future<Set<String>> pendingRowIds() async {
    final rows = await (selectOnly(
      syncQueueTable,
    )..addColumns([syncQueueTable.rowId])).get();
    return rows.map((r) => r.read(syncQueueTable.rowId)!).toSet();
  }

  // ── Watermark (sync_state) ───────────────────────────────────────────────

  Future<DateTime?> getWatermark(String tableName) async {
    final row = await (select(
      syncStateTable,
    )..where((t) => t.tableName_.equals(tableName))).getSingleOrNull();
    return row?.lastSyncedAt;
  }

  Future<void> setWatermark(
    String tableName,
    DateTime syncedAt,
    int rowCount,
  ) => into(syncStateTable).insertOnConflictUpdate(
    SyncStateTableCompanion(
      tableName_: Value(tableName),
      lastSyncedAt: Value(syncedAt),
      lastRowCount: Value(rowCount),
    ),
  );
}
