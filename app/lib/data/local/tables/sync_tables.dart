import 'package:drift/drift.dart';

/// sync_queue — outbox for offline-first writes.
/// Every insert/update/delete on a syncable table writes a row here first.
/// The SyncEngine drains this queue when connectivity is available.
/// See docs/OFFLINE_SYNC.md §3.
class SyncQueueTable extends Table {
  @override
  String get tableName => 'sync_queue';

  TextColumn     get opId        => text()();          // UUIDv7 idempotency key
  TextColumn     get tableName_  => text().named('table_name')(); // target remote table
  TextColumn     get rowId       => text()();          // the affected row's id
  TextColumn     get operation   => text()();          // 'insert' | 'update' | 'delete'
  TextColumn     get payloadJson => text()();          // JSON of the row at write time
  DateTimeColumn get createdAt   => dateTime()();
  IntColumn      get retryCount  => integer().withDefault(const Constant(0))();
  TextColumn     get lastError   => text().nullable()();

  @override
  Set<Column> get primaryKey => {opId};
}

/// sync_state — per-table high-water mark for delta sync.
/// Stores the latest updatedAt seen from the server per table.
/// See docs/OFFLINE_SYNC.md §4.
class SyncStateTable extends Table {
  @override
  String get tableName => 'sync_state';

  TextColumn     get tableName_     => text().named('table_name')();
  DateTimeColumn get lastSyncedAt   => dateTime()();
  // lastRowCount is a cheap sanity check — mismatches trigger a full re-sync
  IntColumn      get lastRowCount   => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {tableName_};
}
