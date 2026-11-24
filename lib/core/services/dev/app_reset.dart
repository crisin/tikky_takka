import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../db/app_database.dart';
import '../../repo/settings_store.dart';
import '../alarms/alarm_service.dart';
import 'dev_tools.dart';

/// Number of rows per table, for the developer page.
typedef TableCounts = ({
  int sets,
  int tracks,
  int sessions,
  int events,
  int entries,
  int persons,
  int substances,
  int settings,
});

/// Puts the app back to the state of a first start: every table emptied,
/// OS alarms cancelled, and on the web the offline caches, the service
/// worker and the page storage removed.
///
/// There is no undo. The caller confirms first and afterwards either
/// reloads the page (web) or re-runs the start-up work.
class AppReset {
  AppReset(this._db, this._settings, this._alarms, this._tools);

  final AppDatabase _db;
  final SettingsStore _settings;
  final AlarmService _alarms;
  final DevTools _tools;

  Future<TableCounts> counts() async => (
    sets: await _db.trackSets.count().getSingle(),
    tracks: await _db.tracks.count().getSingle(),
    sessions: await _db.sessions.count().getSingle(),
    events: await _db.events.count().getSingle(),
    entries: await _db.entries.count().getSingle(),
    persons: await _db.persons.count().getSingle(),
    substances: await _db.substances.count().getSingle(),
    settings: await _db.settings.count().getSingle(),
  );

  /// [offlineCache]: also drop the cached app files (web). Pass false
  /// without a network connection, or the app could not start again.
  Future<void> wipe({bool offlineCache = true}) async {
    try {
      await _alarms.cancelAll();
    } catch (_) {
      // Alarms are optional; the data goes either way.
    }
    await _db.transaction(() async {
      // Children before parents.
      final tables = <TableInfo<Table, Object?>>[
        _db.events,
        _db.entries,
        _db.sessions,
        _db.tracks,
        _db.trackSets,
        _db.persons,
        _db.substances,
        _db.settings,
      ];
      for (final table in tables) {
        await _db.delete(table).go();
      }
    });
    await _settings.reload();
    await _tools.clearPageStorage();
    if (offlineCache) await _tools.clearOfflineCache();
  }
}

final appResetProvider = Provider<AppReset>(
  (ref) => AppReset(
    ref.watch(appDatabaseProvider),
    ref.watch(settingsStoreProvider),
    ref.watch(alarmServiceProvider),
    ref.watch(devToolsProvider),
  ),
);
