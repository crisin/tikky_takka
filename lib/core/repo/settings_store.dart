import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../domain/json_utils.dart';

/// Well-known keys of the key-value settings table.
abstract final class SettingsKeys {
  /// Id of the set shown on the tracks screen.
  static const activeSetId = 'ui.activeSetId';

  /// Prefix of the view shown on the tracks screen per set
  /// (`ui.tracksView.<setId>` -> `TracksView.name`).
  static const tracksViewPrefix = 'ui.tracksView.';

  /// Prefix of the mode of the timeline view per set
  /// (`ui.timelineMode.<setId>` -> `TimelineMode.name`).
  static const timelineModePrefix = 'ui.timelineMode.';

  /// `UiPrefs` as a JSON object.
  static const uiPrefs = 'ui.prefs';

  /// `ThemeSettings` as a JSON object.
  static const themeSettings = 'theme.settings';

  /// Custom themes: JSON object `{ "themes": [ TikkyTheme, ... ] }`.
  static const customThemes = 'theme.custom';

  /// `"true"` when the app lock is enabled.
  static const appLock = 'privacy.appLock';

  /// `"true"` once the first-launch seed data has been written.
  static const seedDone = 'seed.done';

  /// Prefix for export sheet preferences (owned by the export feature).
  static const exportPrefix = 'export.';

  /// Prefix of internal bookkeeping rows that share the table (deleted
  /// event ids, see `EventTombstones`). Not settings: never cached here,
  /// never exported, never imported.
  static const internalPrefix = 'tombstone.';

  /// Whether [key] is an internal bookkeeping row, see [internalPrefix].
  static bool isInternal(String key) => key.startsWith(internalPrefix);

  /// Settings that describe THIS device / installation and therefore never
  /// travel through a backup import: the seed flag and the app lock (an
  /// imported file must neither switch the lock off nor lock the user out
  /// on a device that cannot authenticate).
  static bool isDeviceLocal(String key) =>
      key == seedDone || key == appLock || isInternal(key);
}

/// Key-value settings backed by the database, with a synchronous in-memory
/// cache (same idea as SharedPreferences): reads are synchronous, writes
/// update the cache immediately and persist asynchronously-awaitable.
///
/// Create with [SettingsStore.load] before `runApp` and inject through
/// [settingsStoreProvider].
class SettingsStore {
  SettingsStore._(this._db, this._clock, this._cache);

  /// Loads all settings into memory.
  static Future<SettingsStore> load(
    AppDatabase db, {
    Clock clock = const SystemClock(),
  }) async {
    final rows = await db.select(db.settings).get();
    return SettingsStore._(db, clock, {
      for (final r in rows)
        if (!SettingsKeys.isInternal(r.key)) r.key: r.value,
    });
  }

  final AppDatabase _db;
  final Clock _clock;
  final Map<String, String> _cache;
  final StreamController<String> _changes = StreamController.broadcast();

  /// Emits the key of every setting that changes (including removals).
  Stream<String> get changes => _changes.stream;

  /// Snapshot of all settings.
  Map<String, String> get all => Map.unmodifiable(_cache);

  bool contains(String key) => _cache.containsKey(key);

  String? getString(String key) => _cache[key];

  bool getBool(String key, {bool fallback = false}) =>
      jsonBool(_cache[key], fallback);

  int? getInt(String key) => jsonIntOrNull(_cache[key]);

  /// Decodes a JSON object value; `null` when missing or malformed.
  JsonMap? getJson(String key) {
    final raw = _cache[key];
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? jsonMap(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  /// All entries whose key starts with [prefix].
  Map<String, String> withPrefix(String prefix) => {
    for (final e in _cache.entries)
      if (e.key.startsWith(prefix)) e.key: e.value,
  };

  Future<void> setString(String key, String value) async {
    if (_cache[key] == value) return;
    _cache[key] = value;
    _changes.add(key);
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingRow(key: key, value: value, updatedAt: _clock.nowMs()),
        );
  }

  Future<void> setBool(String key, bool value) =>
      setString(key, value ? 'true' : 'false');

  Future<void> setInt(String key, int value) => setString(key, '$value');

  Future<void> setJson(String key, JsonMap value) =>
      setString(key, jsonEncode(value));

  Future<void> remove(String key) async {
    if (_cache.remove(key) == null) return;
    _changes.add(key);
    await (_db.delete(_db.settings)..where((t) => t.key.equals(key))).go();
  }

  /// Emits the current value of [key] and then every change.
  Stream<String?> watch(String key) => Stream<String?>.multi((controller) {
    controller.add(_cache[key]);
    final sub = _changes.stream
        .where((changed) => changed == key)
        .listen((_) => controller.add(_cache[key]));
    controller.onCancel = sub.cancel;
  });

  /// Re-reads everything from the database (call after a backup import) and
  /// notifies listeners of every key that differs.
  Future<void> reload() async {
    final rows = await _db.select(_db.settings).get();
    final fresh = {
      for (final r in rows)
        if (!SettingsKeys.isInternal(r.key)) r.key: r.value,
    };
    final changed = <String>{
      for (final k in {..._cache.keys, ...fresh.keys})
        if (_cache[k] != fresh[k]) k,
    };
    _cache
      ..clear()
      ..addAll(fresh);
    changed.forEach(_changes.add);
  }
}

/// The loaded settings store. Must be overridden (see `main.dart` and
/// `test/support/test_app.dart`); there is no lazy default because loading
/// is asynchronous.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError(
    'settingsStoreProvider must be overridden with a loaded SettingsStore',
  ),
);
