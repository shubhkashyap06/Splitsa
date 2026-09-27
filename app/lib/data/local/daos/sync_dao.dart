import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/sync_tables.dart';

part 'sync_dao.g.dart';

@DriftAccessor(tables: [SyncQueueTable, SyncStateTable])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  // ── Outbox (sync_queue) ──────────────────────────────────────────────────

  Future<void> enqueue(SyncQueueTableCompanion op) =>
      into(syncQueueTable).insertOnConflictUpdate(op);

  /// Returns up to [limit] pending operations, oldest first.
  Future<List<SyncQueueTableData>> pendingOps({int limit = 50}) =>
      (select(syncQueueTable)
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
        ..limit(limit))
          .get();

  Future<void> markSuccess(String opId) =>
      (delete(syncQueueTable)..where((t) => t.opId.equals(opId))).go();

  Future<void> incrementRetry(String opId, String error) =>
      (update(syncQueueTable)..where((t) => t.opId.equals(opId))).write(
        SyncQueueTableCompanion(
          retryCount: Value(
            // The actual value is incremented in the SyncEngine before calling this
            // — we just persist the updated count and error message.
            (select(syncQueueTable)..where((t) => t.opId.equals(opId)))
                .getSingleOrNull()
                .then((r) => (r?.retryCount ?? 0) + 1) as dynamic,
          ),
          lastError: Value(error),
        ),
      );

  Future<int> queueLength() => syncQueueTable.count().getSingle();

  // ── Watermark (sync_state) ───────────────────────────────────────────────

  Future<DateTime?> getWatermark(String tableName) async {
    final row = await (select(syncStateTable)
      ..where((t) => t.tableName_.equals(tableName)))
        .getSingleOrNull();
    return row?.lastSyncedAt;
  }

  Future<void> setWatermark(String tableName, DateTime syncedAt, int rowCount) =>
      into(syncStateTable).insertOnConflictUpdate(
        SyncStateTableCompanion(
          tableName_:   Value(tableName),
          lastSyncedAt: Value(syncedAt),
          lastRowCount: Value(rowCount),
        ),
      );
}
