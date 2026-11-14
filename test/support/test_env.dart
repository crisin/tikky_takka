import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/clock.dart';
import 'package:tikky_takka/core/db/app_database.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/repo/session_store.dart';
import 'package:tikky_takka/core/services/alarms/alarm_service.dart';

/// A fully wired repository layer on an in-memory database with a fake
/// clock, deterministic ids and a recording alarm service.
class TestEnv {
  TestEnv({int startMs = 1000000})
    : db = AppDatabase.inMemory(),
      clock = FakeClock(startMs),
      alarms = RecordingAlarmService() {
    // Every in-memory database is independent; several per test are fine.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    alarmSync = AlarmSync(SessionStore(db), clock, alarms);
    sets = SetRepository(db, clock, newId, alarmSync);
    tracks = TrackRepository(db, clock, newId, alarmSync);
    commands = TrackCommands(db, clock, newId, alarmSync);
    history = HistoryRepository(db, clock, alarmSync);
    people = PeopleRepository(db, clock, newId);
    backup = BackupRepository(db, clock, history, alarmSync);
  }

  final AppDatabase db;
  final FakeClock clock;
  final RecordingAlarmService alarms;
  late final AlarmSync alarmSync;
  late final SetRepository sets;
  late final TrackRepository tracks;
  late final TrackCommands commands;
  late final HistoryRepository history;
  late final PeopleRepository people;
  late final BackupRepository backup;

  int _id = 0;

  String newId() => 'id-${(++_id).toString().padLeft(4, '0')}';

  /// Creates a set and returns it.
  Future<TrackSet> makeSet([String name = 'Set']) => sets.createSet(name: name);

  /// Creates a track in [set] and returns it.
  Future<Track> makeTrack(
    TrackSet set,
    TrackConfig config, {
    String? name,
  }) => tracks.createTrack(
    setId: set.id,
    name: name ?? config.mode.name,
    config: config,
  );

  /// The derived snapshot of a track's open session at the fake "now".
  Future<TrackSnapshot?> snapshot(String trackId) async {
    final open = await commands.getOpenSession(trackId);
    if (open == null) return null;
    return deriveSnapshot(
      config: open.session.config,
      events: open.events,
      nowMs: clock.nowMs(),
    );
  }

  Future<List<EventType>> eventTypes(String trackId) async {
    final open = await commands.getOpenSession(trackId);
    return [for (final e in open?.events ?? const <TrackEvent>[]) e.type];
  }

  Future<void> dispose() => db.close();
}

/// Registers set-up / tear-down of a fresh [TestEnv] per test.
TestEnv Function() useTestEnv() {
  late TestEnv env;
  setUp(() => env = TestEnv());
  tearDown(() => env.dispose());
  return () => env;
}
