import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// The browser database: SQLite compiled to WebAssembly, stored in OPFS or
/// IndexedDB (whatever the browser supports). Needs `web/sqlite3.wasm` and
/// `web/drift_worker.js`, see README ("Web").
QueryExecutor openDefaultConnection(String name) => driftDatabase(
  name: name,
  web: DriftWebOptions(
    sqlite3Wasm: Uri.parse('sqlite3.wasm'),
    driftWorker: Uri.parse('drift_worker.js'),
  ),
);

/// Not available in the browser; tests run on the VM.
QueryExecutor openInMemoryConnection() =>
    throw UnsupportedError('In-memory database is not available on the web');
