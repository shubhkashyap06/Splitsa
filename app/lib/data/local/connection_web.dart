import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// PWA storage: SQLite compiled to WASM, persisted in OPFS or IndexedDB
/// (drift picks the best the browser supports). Replaces the deprecated
/// `drift/web.dart` backend, which needed a sql.js script that was never
/// added to index.html — the web DB had never actually opened.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'splitsa',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
