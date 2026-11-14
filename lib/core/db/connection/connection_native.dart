import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../database_location.dart';

/// The on-device database file `<name>.sqlite`, see [DatabaseLocation].
QueryExecutor openDefaultConnection(String name) => driftDatabase(
  name: name,
  native: DriftNativeOptions(
    databasePath: () => DatabaseLocation.resolveDatabasePath(name),
  ),
);

/// A fresh in-memory database (tests and tools).
QueryExecutor openInMemoryConnection() => NativeDatabase.memory();
