import 'package:drift/drift.dart';

// SCHEMA NOTE
// -----------
// The schema is frozen at version 1. All ids are UUID strings, all instants
// are UTC milliseconds stored as INTEGER, JSON payloads are TEXT. Every
// entity table carries an `extra_json` column for forward-compatible
// additions that do not need a migration.
//
// There are deliberately no SQL foreign keys: referential clean-up is done
// by the repositories inside transactions, which keeps backup import
// ("merge by id") independent of insertion order.

/// Track sets ("Sets").
@DataClassName('SetRow')
@TableIndex(name: 'idx_sets_sort', columns: {#sortIndex})
class TrackSets extends Table {
  @override
  String get tableName => 'track_sets';

  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  /// Optional theme override (id of a preset or custom theme).
  TextColumn get themeId => text().nullable()();

  /// Optional partial UiPrefs override as a JSON object.
  TextColumn get uiPrefsOverrideJson => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  TextColumn get extraJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Tracks ("Spuren").
@DataClassName('TrackRow')
@TableIndex(name: 'idx_tracks_set', columns: {#setId, #sortIndex})
class Tracks extends Table {
  @override
  String get tableName => 'tracks';

  TextColumn get id => text()();
  TextColumn get setId => text()();
  TextColumn get name => text()();

  /// Index into the theme's track palette.
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();

  /// Custom ARGB colour; wins over [colorIndex] when set.
  IntColumn get customColor => integer().nullable()();

  /// `TrackMode.name`.
  TextColumn get mode => text()();

  /// Mode-specific configuration as a JSON object.
  TextColumn get configJson => text().withDefault(const Constant('{}'))();
  BoolColumn get alarmSound => boolean().withDefault(const Constant(true))();
  BoolColumn get vibration => boolean().withDefault(const Constant(true))();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
  BoolColumn get logEnabled => boolean().withDefault(const Constant(true))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  TextColumn get extraJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Sessions: one run of a track.
@DataClassName('SessionRow')
@TableIndex(name: 'idx_sessions_track', columns: {#trackId, #startedAt})
@TableIndex(name: 'idx_sessions_started', columns: {#startedAt})
@TableIndex(name: 'idx_sessions_ended', columns: {#endedAt})
class Sessions extends Table {
  @override
  String get tableName => 'sessions';

  TextColumn get id => text()();
  TextColumn get trackId => text()();

  /// `TrackMode.name` at the time of the session.
  TextColumn get mode => text()();

  /// Snapshot of the track configuration used by this session.
  TextColumn get configJson => text().withDefault(const Constant('{}'))();
  IntColumn get startedAt => integer()();

  /// NULL while the session is open.
  IntColumn get endedAt => integer().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  TextColumn get extraJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The event log.
@DataClassName('EventRow')
@TableIndex(name: 'idx_events_session', columns: {#sessionId, #at, #seq})
@TableIndex(name: 'idx_events_track', columns: {#trackId, #at})
@TableIndex(name: 'idx_events_at', columns: {#at})
@TableIndex(name: 'idx_events_person', columns: {#personId})
@TableIndex(name: 'idx_events_substance', columns: {#substanceId})
class Events extends Table {
  @override
  String get tableName => 'events';

  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get trackId => text()();

  /// `EventType.name`.
  TextColumn get type => text()();

  /// UTC milliseconds.
  IntColumn get at => integer()();

  /// Insertion order inside the session (tie-breaker for equal `at`).
  IntColumn get seq => integer().withDefault(const Constant(0))();
  TextColumn get label => text().nullable()();
  TextColumn get personId => text().nullable()();
  TextColumn get substanceId => text().nullable()();

  /// Free text.
  TextColumn get amount => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  TextColumn get extraJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Persons for protocol entries.
/// Protocol entries: who had what, when. Not tied to a set, track or
/// session (see `Entry`).
@DataClassName('EntryRow')
@TableIndex(name: 'idx_entries_at', columns: {#at})
@TableIndex(name: 'idx_entries_person', columns: {#personId, #at})
@TableIndex(name: 'idx_entries_substance', columns: {#substanceId})
class Entries extends Table {
  @override
  String get tableName => 'entries';

  TextColumn get id => text()();

  /// Wall time, UTC milliseconds.
  IntColumn get at => integer()();
  TextColumn get personId => text()();
  TextColumn get substanceId => text()();

  /// Free text; never summed up.
  TextColumn get amount => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  TextColumn get extraJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PersonRow')
class Persons extends Table {
  @override
  String get tableName => 'persons';

  TextColumn get id => text()();
  TextColumn get name => text()();

  /// ARGB.
  IntColumn get color => integer().withDefault(const Constant(0xFF888888))();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  TextColumn get extraJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Substances for protocol entries.
@DataClassName('SubstanceRow')
class Substances extends Table {
  @override
  String get tableName => 'substances';

  TextColumn get id => text()();
  TextColumn get name => text()();

  /// ARGB.
  IntColumn get color => integer().withDefault(const Constant(0xFF888888))();

  /// User-set lockout in milliseconds; NULL = none.
  IntColumn get lockoutMs => integer().nullable()();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  TextColumn get extraJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Key-value settings (theme selection, custom themes, UI prefs, ...).
@DataClassName('SettingRow')
class Settings extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
