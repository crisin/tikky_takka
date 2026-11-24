import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection/connection.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The single local database of the app.
///
/// The schema is FROZEN: do not change tables or re-run build_runner without
/// adding a migration step in [migration] and bumping [schemaVersion].
@DriftDatabase(
  tables: [
    TrackSets,
    Tracks,
    Sessions,
    Events,
    Entries,
    Persons,
    Substances,
    Settings,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the database on the given executor (used by tests and tools).
  AppDatabase(super.e);

  /// Name of the on-device database (file `tikky_takka.sqlite`).
  static const String fileBaseName = 'tikky_takka';

  /// Opens the on-device database file (`tikky_takka.sqlite`) in the app's
  /// private application-support directory - NOT the documents directory,
  /// which the OS synchronises (OneDrive, iCloud). A database created there
  /// by an earlier version is moved over once (see `DatabaseLocation`).
  /// On the web: SQLite-WASM in the browser, see `connection_web.dart`.
  AppDatabase.defaults() : super(openDefaultConnection(fileBaseName));

  /// Opens a fresh in-memory database. Use in tests.
  AppDatabase.inMemory() : super(openInMemoryConnection());

  static const int currentSchemaVersion = 2;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Migrations scaffold: run every step between the stored version and
      // the current one, in order. Add `if (step == 1) { ... }` blocks here
      // when the schema version is bumped (step = version migrated FROM).
      for (var step = from; step < to; step++) {
        await _migrateFrom(m, step);
      }
    },
  );

  Future<void> _migrateFrom(Migrator m, int fromVersion) async {
    switch (fromVersion) {
      case 1:
        // Protocol entries get a table of their own.
        await m.createTable(entries);
      default:
        break;
    }
  }
}

/// The app database. `main.dart` overrides this with the opened instance;
/// tests override it with [AppDatabase.inMemory].
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.defaults();
  ref.onDispose(db.close);
  return db;
});
