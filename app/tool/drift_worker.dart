// Source for web/drift_worker.js — the shared/dedicated worker that hosts
// SQLite for the PWA (OFFLINE_SYNC.md §1). Rebuild after a drift upgrade:
//   dart compile js -O4 tool/drift_worker.dart -o web/drift_worker.js
// web/sqlite3.wasm comes from the matching drift package
// (extension/devtools/build/sqlite3.wasm) — keep the two versions in step.
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
