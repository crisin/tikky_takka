import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../clock.dart';
import '../db/app_database.dart';
import '../domain/domain.dart';
import '../engine/engine.dart';
import '../services/alarms/alarm_service.dart';
import 'backup_repository.dart';
import 'history_repository.dart';
import 'models.dart';
import 'people_repository.dart';
import 'session_store.dart';
import 'set_repository.dart';
import 'settings_store.dart';
import 'track_commands.dart';
import 'track_repository.dart';

// ------------------------------------------------------------ infrastructure

/// Id generator (UUID v4). Override in tests for deterministic ids.
final idGeneratorProvider = Provider<IdGenerator>((ref) {
  const uuid = Uuid();
  return uuid.v4;
});

final alarmSyncProvider = Provider<AlarmSync>(
  (ref) => AlarmSync(
    SessionStore(ref.watch(appDatabaseProvider)),
    ref.watch(clockProvider),
    ref.watch(alarmServiceProvider),
  ),
);

// -------------------------------------------------------------- repositories

final setRepositoryProvider = Provider<SetRepository>(
  (ref) => SetRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
    ref.watch(alarmSyncProvider),
  ),
);

final trackRepositoryProvider = Provider<TrackRepository>(
  (ref) => TrackRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
    ref.watch(alarmSyncProvider),
  ),
);

/// The timer commands (start, pause, lap, tick, ack, addEntry, stop, ...).
final trackCommandsProvider = Provider<TrackCommands>(
  (ref) => TrackCommands(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
    ref.watch(alarmSyncProvider),
  ),
);

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(alarmSyncProvider),
  ),
);

final peopleRepositoryProvider = Provider<PeopleRepository>(
  (ref) => PeopleRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(idGeneratorProvider),
  ),
);

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => BackupRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(clockProvider),
    ref.watch(historyRepositoryProvider),
    ref.watch(alarmSyncProvider),
  ),
);

// ---------------------------------------------------------------------- sets

/// All non-archived sets, ordered.
final setsProvider = StreamProvider<List<TrackSet>>(
  (ref) => ref.watch(setRepositoryProvider).watchSets(),
);

/// All sets including archived ones (for name lookups in history).
final allSetsProvider = StreamProvider<List<TrackSet>>(
  (ref) => ref.watch(setRepositoryProvider).watchSets(includeArchived: true),
);

/// The stored id of the active set (may be `null` or stale; read
/// [activeSetProvider] for the resolved set).
class ActiveSetController extends Notifier<String?> {
  @override
  String? build() =>
      ref.watch(settingsStoreProvider).getString(SettingsKeys.activeSetId);

  /// Makes [setId] the active set and remembers it.
  Future<void> select(String setId) async {
    state = setId;
    await ref
        .read(settingsStoreProvider)
        .setString(SettingsKeys.activeSetId, setId);
  }
}

final activeSetIdProvider = NotifierProvider<ActiveSetController, String?>(
  ActiveSetController.new,
);

/// The set shown on the tracks screen: the stored one if it still exists,
/// otherwise the first set; `null` while loading or when there is no set.
final activeSetProvider = Provider<TrackSet?>((ref) {
  final sets = ref.watch(setsProvider).value ?? const <TrackSet>[];
  if (sets.isEmpty) return null;
  final id = ref.watch(activeSetIdProvider);
  for (final set in sets) {
    if (set.id == id) return set;
  }
  return sets.first;
});

/// A single set by id (archived ones included); `null` if unknown or while
/// loading. Protocol lanes read the scene of their set from it.
final setProvider = Provider.family<TrackSet?, String>((ref, setId) {
  final sets = ref.watch(allSetsProvider).value ?? const <TrackSet>[];
  for (final set in sets) {
    if (set.id == setId) return set;
  }
  return null;
});

// -------------------------------------------------------------------- tracks

/// Non-archived tracks of one set, ordered.
final tracksInSetProvider = StreamProvider.family<List<Track>, String>(
  (ref, setId) => ref.watch(trackRepositoryProvider).watchTracks(setId),
);

/// Non-archived tracks of the active set, ordered. Empty while loading.
final activeTracksProvider = Provider<List<Track>>((ref) {
  final set = ref.watch(activeSetProvider);
  if (set == null) return const [];
  return ref.watch(tracksInSetProvider(set.id)).value ?? const [];
});

/// Every track of every set, archived ones included.
final allTracksProvider = StreamProvider<List<Track>>(
  (ref) => ref.watch(trackRepositoryProvider).watchAllTracks(),
);

/// A single track by id (archived ones included); `null` if unknown or
/// while loading.
final trackProvider = Provider.family<Track?, String>((ref, trackId) {
  final tracks = ref.watch(allTracksProvider).value ?? const <Track>[];
  for (final track in tracks) {
    if (track.id == trackId) return track;
  }
  return null;
});

// ------------------------------------------------------------- live sessions

/// All open sessions keyed by track id. The single live query behind all
/// lanes: it only changes when an event is written, never on a timer.
final openSessionsProvider = StreamProvider<Map<String, OpenSession>>(
  (ref) => ref.watch(trackCommandsProvider).watchOpenSessions(),
);

/// The open session of one track, or `null` when it is idle. A lane watches
/// this and derives its snapshot with `deriveSnapshot` and the shared "now"
/// ticker.
final openSessionProvider = Provider.family<OpenSession?, String>((
  ref,
  trackId,
) {
  return ref.watch(
    openSessionsProvider.select((async) => async.value?[trackId]),
  );
});

// ------------------------------------------------------------------ protocol

/// Non-archived persons, ordered.
final personsProvider = StreamProvider<List<Person>>(
  (ref) => ref.watch(peopleRepositoryProvider).watchPersons(),
);

/// All persons including archived ones (for name lookups).
final allPersonsProvider = StreamProvider<List<Person>>(
  (ref) =>
      ref.watch(peopleRepositoryProvider).watchPersons(includeArchived: true),
);

/// Non-archived substances, ordered.
final substancesProvider = StreamProvider<List<Substance>>(
  (ref) => ref.watch(peopleRepositoryProvider).watchSubstances(),
);

/// All substances including archived ones (for name lookups).
final allSubstancesProvider = StreamProvider<List<Substance>>(
  (ref) => ref
      .watch(peopleRepositoryProvider)
      .watchSubstances(includeArchived: true),
);

/// Person by id for name / colour lookups; empty while loading.
final personsByIdProvider = Provider<Map<String, Person>>((ref) {
  final list = ref.watch(allPersonsProvider).value ?? const <Person>[];
  return {for (final p in list) p.id: p};
});

/// Substance by id for name / colour lookups; empty while loading.
final substancesByIdProvider = Provider<Map<String, Substance>>((ref) {
  final list = ref.watch(allSubstancesProvider).value ?? const <Substance>[];
  return {for (final s in list) s.id: s};
});

/// User-set lockouts (substance id -> milliseconds), the
/// `lockoutMsBySubstance` argument of `deriveSnapshot`.
final lockoutsProvider = Provider<Map<String, int>>((ref) {
  final list = ref.watch(allSubstancesProvider).value ?? const <Substance>[];
  return {
    for (final s in list)
      if (s.lockoutMs != null && s.lockoutMs! > 0) s.id: s.lockoutMs!,
  };
});

// ------------------------------------------------------------------- history

/// The filter currently applied on the history screen. Export reads it too
/// ("export honours the active history filter").
class HistoryFilterController extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => HistoryFilter.all;

  void set(HistoryFilter filter) => state = filter;

  void reset() => state = HistoryFilter.all;
}

final historyFilterProvider =
    NotifierProvider<HistoryFilterController, HistoryFilter>(
      HistoryFilterController.new,
    );

/// Sessions matching a filter, newest first.
final historySessionsProvider = StreamProvider.autoDispose
    .family<List<HistorySession>, HistoryFilter>(
      (ref, filter) =>
          ref.watch(historyRepositoryProvider).watchSessions(filter),
    );

/// Sessions matching the active history filter, grouped by day.
final historyDaysProvider = Provider.autoDispose<AsyncValue<List<HistoryDay>>>((
  ref,
) {
  final filter = ref.watch(historyFilterProvider);
  return ref
      .watch(historySessionsProvider(filter))
      .whenData(groupSessionsByDay);
});

/// Daily net sums per track for the active history filter.
final historyDailySumsProvider =
    Provider.autoDispose<AsyncValue<List<TrackPeriodSum>>>((ref) {
      final filter = ref.watch(historyFilterProvider);
      return ref
          .watch(historySessionsProvider(filter))
          .whenData(sumPerTrackPerDay);
    });

/// Weekly net sums per track for the active history filter.
final historyWeeklySumsProvider =
    Provider.autoDispose<AsyncValue<List<TrackPeriodSum>>>((ref) {
      final filter = ref.watch(historyFilterProvider);
      return ref
          .watch(historySessionsProvider(filter))
          .whenData(sumPerTrackPerWeek);
    });

/// One session with its events for the detail view.
final sessionDetailProvider = StreamProvider.autoDispose
    .family<HistorySession?, String>(
      (ref, sessionId) =>
          ref.watch(historyRepositoryProvider).watchSession(sessionId),
    );

// ----------------------------------------------------------------- bootstrap

/// One-time start-up work: seed data, alarm service init, rebuilding the OS
/// alarms from the event log. The app shell waits for it before showing the
/// tracks.
final appBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.watch(setRepositoryProvider).ensureSeedData();
  final alarms = ref.watch(alarmServiceProvider);
  try {
    await alarms.init();
    // Before anything is scheduled: with the app lock on, notifications
    // hide their text on the lock screen.
    await alarms.setContentHidden(
      ref.read(settingsStoreProvider).getBool(SettingsKeys.appLock),
    );
  } catch (_) {
    // Alarms are optional; the app must start without them.
  }
  await ref.watch(trackCommandsProvider).rescheduleAllAlarms();
});
