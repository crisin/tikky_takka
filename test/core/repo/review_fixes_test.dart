import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/repo/session_store.dart';
import 'package:tikky_takka/core/repo/mappers.dart';

import '../../support/events.dart';
import '../../support/test_env.dart';

/// Regression tests for the reviewed repository defects: archiving,
/// exclusivity, restart, backup merge consistency, tombstones and the
/// device-local settings.
void main() {
  final env = useTestEnv();

  group('archiving a track', () {
    test('ends the running session and cancels its alarms', () async {
      final e = env();
      final set = await e.makeSet();
      final timer = await e.makeTrack(
        set,
        const CountdownConfig(durationMs: 10 * min),
      );
      await e.commands.startTrack(timer.id);
      e.clock.advanceMs(min);

      final stopped = await e.tracks.setArchived(timer.id, archived: true);

      expect(stopped, isNotNull);
      expect(await e.commands.getOpenSession(timer.id), isNull);
      expect(e.alarms.scheduled, isEmpty);
      final history = await e.history.getSessions(HistoryFilter.all);
      expect(history.single.session.id, stopped);
      expect(history.single.session.endedAt, e.clock.nowMs());
      expect(history.single.events.last.type, EventType.stop);

      // Restoring does not make it run again by itself.
      e.clock.advanceMs(hour);
      expect(await e.tracks.setArchived(timer.id, archived: false), isNull);
      expect(await e.commands.getOpenSession(timer.id), isNull);
      expect(e.alarms.scheduled, isEmpty);
    });

    test('an idle track is simply hidden', () async {
      final e = env();
      final set = await e.makeSet();
      final watch = await e.makeTrack(set, const StopwatchConfig());
      expect(await e.tracks.setArchived(watch.id, archived: true), isNull);
      expect(await e.history.getSessions(HistoryFilter.all), isEmpty);
    });

    test('also ends counters and protocol sessions', () async {
      final e = env();
      final set = await e.makeSet();
      final counter = await e.makeTrack(set, const CounterConfig());
      await e.commands.tick(counter.id);
      await e.tracks.setArchived(counter.id, archived: true);
      expect(await e.commands.getOpenSessions(), isEmpty);
    });
  });

  group('exclusive stopwatches', () {
    Future<bool> running(TestEnv e, String id) async =>
        (await e.snapshot(id))?.isRunning ?? false;

    test('switching "exclusive" on for a running stopwatch pauses the '
        'other running exclusive ones of the set', () async {
      final e = env();
      final set = await e.makeSet();
      final a = await e.makeTrack(
        set,
        const StopwatchConfig(exclusive: true),
        name: 'a',
      );
      final b = await e.makeTrack(set, const StopwatchConfig(), name: 'b');
      final free = await e.makeTrack(set, const StopwatchConfig(), name: 'c');
      await e.commands.startTrack(a.id);
      await e.commands.startTrack(b.id);
      await e.commands.startTrack(free.id);
      expect(await running(e, a.id), isTrue);
      expect(await running(e, b.id), isTrue);

      await e.tracks.updateTrack(
        b.copyWith(config: const StopwatchConfig(exclusive: true)),
      );

      expect(await running(e, b.id), isTrue);
      expect((await e.snapshot(a.id))!.isPaused, isTrue);
      // Non-exclusive stopwatches are not touched.
      expect(await running(e, free.id), isTrue);
    });

    test('editing a stopped or paused stopwatch pauses nobody', () async {
      final e = env();
      final set = await e.makeSet();
      final a = await e.makeTrack(set, const StopwatchConfig(exclusive: true));
      final b = await e.makeTrack(set, const StopwatchConfig());
      await e.commands.startTrack(a.id);

      await e.tracks.updateTrack(
        b.copyWith(config: const StopwatchConfig(exclusive: true)),
      );
      expect(await running(e, a.id), isTrue);

      await e.commands.startTrack(b.id); // pauses a
      await e.commands.pauseTrack(b.id);
      await e.commands.resumeTrack(a.id);
      await e.tracks.updateTrack(b.copyWith(name: 'renamed'));
      expect(await running(e, a.id), isTrue);
    });

    test('moving a running exclusive stopwatch into a set pauses the '
        'running exclusive ones there', () async {
      final e = env();
      final home = await e.makeSet('home');
      final target = await e.makeSet('target');
      const exclusive = StopwatchConfig(exclusive: true);
      final mover = await e.makeTrack(home, exclusive, name: 'mover');
      final resident = await e.makeTrack(target, exclusive, name: 'resident');
      final stays = await e.makeTrack(home, exclusive, name: 'stays');
      await e.commands.startTrack(resident.id);
      await e.commands.startTrack(mover.id);
      expect(await running(e, resident.id), isTrue);

      await e.tracks.moveTrackToSet(mover.id, target.id);

      expect(await running(e, mover.id), isTrue);
      expect((await e.snapshot(resident.id))!.isPaused, isTrue);
      expect(await e.snapshot(stays.id), isNull);
    });
  });

  group('restartTrack', () {
    test('is one step: one closed and one fresh session, alarms synced '
        'once', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const CountdownConfig(durationMs: 5 * min),
      );
      await e.commands.startTrack(track.id);
      e.clock.advanceMs(min);
      e.alarms.log.clear();

      expect(await e.commands.restartTrack(track.id), TrackAction.started);

      expect(e.alarms.log, ['schedule:${track.id}:1']);
      expect(
        e.alarms.scheduled[track.id]!.single.at,
        e.clock.nowMs() + 5 * min,
      );
      final all = await e.history.getSessions(
        HistoryFilter.all.copyWith(includeOpen: true),
      );
      expect(all.where((s) => s.session.isOpen), hasLength(1));
      expect(all.where((s) => !s.session.isOpen), hasLength(1));
    });

    test('an idle track is simply started; exclusivity still applies', () async {
      final e = env();
      final set = await e.makeSet();
      const exclusive = StopwatchConfig(exclusive: true);
      final a = await e.makeTrack(set, exclusive);
      final b = await e.makeTrack(set, exclusive);
      await e.commands.startTrack(a.id);
      expect(await e.commands.restartTrack(b.id), TrackAction.started);
      expect((await e.snapshot(a.id))!.isPaused, isTrue);
      expect(await e.commands.restartTrack('missing'), TrackAction.none);
    });
  });

  group('session.updatedAt', () {
    test('is bumped by every appended event and by an undone tick', () async {
      final e = env();
      final track = await e.makeTrack(await e.makeSet(), const CounterConfig());
      await e.commands.tick(track.id);
      Future<int> updatedAt() async =>
          (await e.commands.getOpenSession(track.id))!.session.updatedAt;
      final first = await updatedAt();

      e.clock.advanceMs(sec);
      await e.commands.tick(track.id);
      expect(await updatedAt(), first + sec);

      e.clock.advanceMs(sec);
      await e.commands.undoTick(track.id);
      expect(await updatedAt(), first + 2 * sec);
    });
  });

  group('backup merge consistency', () {
    test('a stop event imported into a still-open session row closes the '
        'session (track can start again)', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      await e.commands.startTrack(track.id);
      final open = (await e.commands.getOpenSession(track.id))!;
      e.clock.advanceMs(min);

      // A backup that knows the stop event but carries an OLDER session
      // row (still open): the row is skipped, the event is inserted.
      final stopAt = e.clock.nowMs();
      final stop = TrackEvent(
        id: 'foreign-stop',
        sessionId: open.session.id,
        trackId: track.id,
        type: EventType.stop,
        at: stopAt,
        seq: 5,
        createdAt: stopAt,
        updatedAt: stopAt,
      );
      await e.backup.merge(
        BackupData(
          sessions: [open.session.copyWith(updatedAt: 0)],
          events: [stop],
        ),
      );

      final session = (await e.history.getSession(open.session.id))!.session;
      expect(session.endedAt, stopAt);
      expect(await e.commands.getOpenSession(track.id), isNull);
      // Not stuck: it starts a fresh session.
      expect(await e.commands.startTrack(track.id), TrackAction.started);
      expect((await e.snapshot(track.id))!.isRunning, isTrue);
    });

    test('a closed session row imported without its stop event gets one '
        'and is not reopened', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      await e.commands.startTrack(track.id);
      final open = (await e.commands.getOpenSession(track.id))!;
      e.clock.advanceMs(min);
      final endedAt = e.clock.nowMs();

      await e.backup.merge(
        BackupData(
          sessions: [
            open.session.copyWith(
              endedAt: () => endedAt,
              updatedAt: endedAt + 1,
            ),
          ],
        ),
      );

      final merged = (await e.history.getSession(open.session.id))!;
      expect(merged.session.endedAt, endedAt);
      expect(merged.events.last.type, EventType.stop);
      expect(merged.events.last.at, endedAt);
      // The summary no longer grows with the clock.
      e.clock.advanceMs(hour);
      expect(
        (await e.history.getSession(open.session.id))!.summary.netMs,
        min,
      );
      expect(await e.commands.startTrack(track.id), TrackAction.started);
    });

    test('a session that is already stuck heals itself on start', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const CounterConfig(),
      );
      await e.commands.tick(track.id);
      final open = (await e.commands.getOpenSession(track.id))!;
      // Simulates the state an old import left behind: row open, stop in
      // the log.
      await e.db
          .into(e.db.events)
          .insert(
            TrackEvent(
              id: 'stray-stop',
              sessionId: open.session.id,
              trackId: track.id,
              type: EventType.stop,
              at: e.clock.nowMs(),
              seq: 9,
            ).toRow(),
          );
      e.clock.advanceMs(min);

      expect(await e.commands.tick(track.id), isNotNull);
      final fresh = (await e.commands.getOpenSession(track.id))!;
      expect(fresh.session.id, isNot(open.session.id));
      expect((await e.snapshot(track.id))!.state, RunState.running);
      expect(
        (await e.history.getSession(open.session.id))!.session.isOpen,
        isFalse,
      );
    });
  });

  group('event tombstones', () {
    test('an undone tick is not resurrected by an older backup', () async {
      final e = env();
      final track = await e.makeTrack(await e.makeSet(), const CounterConfig());
      await e.commands.tick(track.id);
      await e.commands.tick(track.id);
      final backup = await e.backup.readAll();
      expect(backup.events.where((x) => x.type == EventType.tick).length, 2);

      e.clock.advanceMs(sec);
      final undone = await e.commands.undoTick(track.id);
      final report = await e.backup.merge(backup);

      final open = (await e.commands.getOpenSession(track.id))!;
      expect(open.events.map((x) => x.id), isNot(contains(undone!.id)));
      expect(open.events.where((x) => x.type == EventType.tick).length, 1);
      expect(report.inserted['events'], 0);
    });

    test('a deleted event stays deleted, a restored one may come back', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      await e.commands.startTrack(track.id);
      final lap = (await e.commands.lap(track.id))!;
      final backup = await e.backup.readAll();

      await e.history.deleteEvent(lap.id);
      await e.backup.merge(backup);
      expect(await e.eventTypes(track.id), [EventType.start]);

      // Undo of the deletion lifts the tombstone again.
      await e.history.restoreEvent(lap);
      await e.history.deleteSession(
        (await e.commands.getOpenSession(track.id))!.session.id,
      );
      await e.backup.merge(backup);
      expect(await e.eventTypes(track.id), [EventType.start, EventType.lap]);
    });

    test('a reopened session is not closed again by an older backup', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      await e.commands.startTrack(track.id);
      e.clock.advanceMs(min);
      final sessionId = (await e.commands.stopTrack(track.id))!;
      final backup = await e.backup.readAll();

      e.clock.advanceMs(sec);
      expect(await e.commands.reopenSession(sessionId), isTrue);
      await e.backup.merge(backup);

      final open = await e.commands.getOpenSession(track.id);
      expect(open?.session.id, sessionId);
      expect(open!.events.map((x) => x.type), isNot(contains(EventType.stop)));
      expect((await e.snapshot(track.id))!.isRunning, isTrue);
    });

    test('tombstones are device-local: not exported, not in the settings '
        'store, bounded', () async {
      final e = env();
      await EventTombstones.add(e.db, ['a', 'b'], 1);
      expect(await EventTombstones.load(e.db), {'a', 'b'});
      expect((await e.backup.readAll()).settings.keys, isEmpty);
      final store = await SettingsStore.load(e.db, clock: e.clock);
      expect(store.all, isEmpty);

      await EventTombstones.add(e.db, [
        for (var i = 0; i < EventTombstones.maxCount; i++) 'n$i',
      ], 2);
      final all = await EventTombstones.load(e.db);
      expect(all, hasLength(EventTombstones.maxCount));
      expect(all, isNot(contains('a')));

      await EventTombstones.remove(e.db, ['n0']);
      expect(await EventTombstones.load(e.db), isNot(contains('n0')));
    });
  });

  group('device-local settings', () {
    test('an import never changes the app lock, in either direction', () async {
      final e = env();
      final store = await SettingsStore.load(e.db, clock: e.clock);

      // Lock off locally (no row at all), backup says "on".
      var report = await e.backup.merge(
        const BackupData(
          settings: {
            SettingsKeys.appLock: 'true',
            SettingsKeys.seedDone: 'true',
            'ui.other': 'x',
          },
        ),
        overwriteSettings: true,
      );
      await store.reload();
      expect(store.contains(SettingsKeys.appLock), isFalse);
      expect(store.getBool(SettingsKeys.appLock), isFalse);
      expect(store.getString('ui.other'), 'x');
      expect(report.inserted['settings'], 1);
      expect(report.skipped['settings'], 2);

      // Lock on locally, backup says "off" and may overwrite settings.
      await store.setBool(SettingsKeys.appLock, true);
      report = await e.backup.merge(
        const BackupData(settings: {SettingsKeys.appLock: 'false'}),
        overwriteSettings: true,
      );
      await store.reload();
      expect(store.getBool(SettingsKeys.appLock), isTrue);
      expect(report.updated['settings'], 0);
    });
  });
}
