import 'dart:convert';

import '../../core/utils/ids.dart';
import '../local/database.dart';

/// Appends a mutation to `sync_queue` (OFFLINE_SYNC.md §2 step 2).
///
/// Always call inside the same `db.transaction` as the local row write, so
/// the UI's watch() stream and the outbox can never disagree.
class Outbox {
  const Outbox(this.db);
  final AppDatabase db;

  Future<void> insert(String table, String rowId, Map<String, dynamic> row) =>
      _enqueue(table, rowId, 'insert', row);

  Future<void> update(String table, String rowId, Map<String, dynamic> row) =>
      _enqueue(table, rowId, 'update', row);

  /// Soft delete — the payload carries `deleted_at` so it propagates through
  /// delta sync like any other update.
  Future<void> softDelete(String table, String rowId, DateTime deletedAt) =>
      _enqueue(table, rowId, 'delete', {
        'deleted_at': deletedAt.toUtc().toIso8601String(),
      });

  Future<void> _enqueue(
    String table,
    String rowId,
    String operation,
    Map<String, dynamic> payload,
  ) => db.syncDao.enqueue(
    SyncQueueTableCompanion.insert(
      opId: newId(),
      tableName_: table,
      rowId: rowId,
      operation: operation,
      payloadJson: jsonEncode(payload),
      createdAt: DateTime.now(),
    ),
  );
}
