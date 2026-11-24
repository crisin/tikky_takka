import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/l10n/strings.dart';

import '../../support/events.dart';
import '../../support/test_env.dart';

void main() {
  final env = useTestEnv();

  group('seed data', () {
    test('first launch creates Allgemein with three tracks, once', () async {
      final e = env();
      expect(await e.sets.ensureSeedData(), isTrue);
      final sets = await e.sets.getSets();
      expect(sets.single.name, Strings.seedSetName);
      final tracks = await e.tracks.getTracks(sets.single.id);
      expect(tracks.map((t) => t.mode), [
        TrackMode.stopwatch,
        TrackMode.countdown,
        TrackMode.counter,
      ]);
      expect((tracks[1].config as CountdownConfig).durationMs, 10 * 60 * 1000);
      expect(tracks.map((t) => t.sortIndex), [0, 1, 2]);
      expect(tracks.every((t) => t.logEnabled && !t.archived), isTrue);

      // Never again, even after the user deleted everything.
      await e.sets.deleteSet(sets.single.id);
      expect(await e.sets.ensureSeedData(), isFalse);
      expect(await e.sets.getSets(), isEmpty);
    });
  });

  group('sets', () {
    test('create, rename, update overrides, reorder, archive', () async {
      final e = env();
      final a = await e.sets.createSet(name: 'Küche');
      final b = await e.sets.createSet(name: 'Training');
      final c = await e.sets.createSet(
        name: 'Festival',
        themeId: 'preset.black',
        uiPrefsOverride: {'layout': 'tiles'},
      );
      expect((await e.sets.getSets()).map((s) => s.name), [
        'Küche',
        'Training',
        'Festival',
      ]);

      await e.sets.renameSet(a.id, 'Kochen');
      e.clock.advanceMs(5);
      await e.sets.updateSet(
        b.copyWith(themeId: () => 'preset.dark', uiPrefsOverride: () => null),
      );
      final stored = await e.sets.getSet(b.id);
      expect(stored!.themeId, 'preset.dark');
      expect(stored.uiPrefsOverride, isNull);
      expect(stored.updatedAt, e.clock.nowMs());
      expect((await e.sets.getSet(c.id))!.uiPrefsOverride, {'layout': 'tiles'});
      expect((await e.sets.getSet(c.id))!.themeId, 'preset.black');

      await e.sets.reorderSets([c.id, a.id]);
      expect((await e.sets.getSets()).map((s) => s.name), [
        'Festival',
        'Kochen',
        'Training',
      ]);

      await e.sets.setArchived(c.id, archived: true);
      expect((await e.sets.getSets()).length, 2);
      expect((await e.sets.getSets(includeArchived: true)).length, 3);
    });

    test('deleteSet removes tracks, sessions, events and alarms', () async {
      final e = env();
      final set = await e.makeSet();
      final keep = await e.makeSet('keep');
      final timer = await e.makeTrack(
        set,
        const CountdownConfig(durationMs: min),
      );
      final kept = await e.makeTrack(keep, const StopwatchConfig());
      await e.commands.startTrack(timer.id);
      await e.commands.startTrack(kept.id);

      await e.sets.deleteSet(set.id);
      expect(await e.tracks.getTrack(timer.id), isNull);
      expect((await e.commands.getOpenSessions()).keys, [kept.id]);
      expect(e.alarms.scheduled, isEmpty);
      expect((await e.db.select(e.db.events).get()).length, 1);
    });

    test('watchSets re-emits on change', () async {
      final e = env();
      final seen = <int>[];
      final sub = e.sets.watchSets().listen((sets) => seen.add(sets.length));
      await pumpEventQueue();
      await e.sets.createSet(name: 'A');
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, [0, 1]);
    });
  });

  group('tracks', () {
    test(
      'create appends, cycles colours and round-trips every field',
      () async {
        final e = env();
        final set = await e.makeSet();
        final a = await e.makeTrack(
          set,
          const StopwatchConfig(exclusive: true),
        );
        final b = await e.tracks.createTrack(
          setId: set.id,
          name: 'Tabata',
          config: const IntervalConfig(workMs: 20000, restMs: 10000, rounds: 8),
          customColor: 0xFF112233,
          alarmSound: false,
          vibration: false,
        );
        expect((a.sortIndex, a.colorIndex), (0, 0));
        expect((b.sortIndex, b.colorIndex), (1, 1));

        final stored = await e.tracks.getTrack(b.id);
        expect(stored, b);
        expect(stored!.mode, TrackMode.interval);
        expect(stored.customColor, 0xFF112233);
        expect(stored.alarmSound, isFalse);
        expect(stored.vibration, isFalse);
        expect(stored.logEnabled, isTrue);
        expect((await e.tracks.getTrack(a.id))!.config, a.config);
      },
    );

    test('reorder, move, duplicate, archive', () async {
      final e = env();
      final set = await e.makeSet();
      final other = await e.makeSet('Other');
      final a = await e.makeTrack(set, const StopwatchConfig(), name: 'A');
      final b = await e.makeTrack(set, const StopwatchConfig(), name: 'B');
      final c = await e.makeTrack(set, const StopwatchConfig(), name: 'C');
      final x = await e.makeTrack(other, const StopwatchConfig(), name: 'X');

      await e.tracks.reorderTracks(set.id, [c.id, a.id, 'unknown', x.id]);
      expect((await e.tracks.getTracks(set.id)).map((t) => t.name), [
        'C',
        'A',
        'B',
      ]);
      // A track of another set in the list is ignored.
      expect((await e.tracks.getTrack(x.id))!.sortIndex, 0);

      await e.tracks.moveTrackToSet(b.id, other.id);
      expect((await e.tracks.getTracks(other.id)).map((t) => t.name), [
        'X',
        'B',
      ]);

      final copy = await e.tracks.duplicateTrack(c.id, name: 'C2');
      expect(copy!.config, c.config);
      expect((await e.tracks.getTracks(set.id)).map((t) => t.name), [
        'C',
        'A',
        'C2',
      ]);
      expect(await e.tracks.duplicateTrack('missing'), isNull);

      await e.tracks.setArchived(a.id, archived: true);
      expect((await e.tracks.getTracks(set.id)).map((t) => t.name), [
        'C',
        'C2',
      ]);
      expect(
        (await e.tracks.getTracks(
          set.id,
          includeArchived: true,
        )).map((t) => t.name),
        ['C', 'A', 'C2'],
      );
      expect((await e.tracks.getAllTracks()).length, 5);
      expect((await e.tracks.getAllTracks(includeArchived: false)).length, 4);
    });
  });

  group('history', () {
    Future<String> run(
      TestEnv e,
      Track track, {
      required DateTime at,
      required int durationMs,
    }) async {
      e.clock.setMs(at.millisecondsSinceEpoch);
      await e.commands.startTrack(track.id);
      e.clock.advanceMs(durationMs);
      return (await e.commands.stopTrack(track.id))!;
    }

    test('filters by track, set, date range, protocol and open', () async {
      final e = env();
      final work = await e.makeSet('Arbeit');
      final fest = await e.makeSet('Festival');
      final projectA = await e.makeTrack(
        work,
        const StopwatchConfig(),
        name: 'A',
      );
      final projectB = await e.makeTrack(
        work,
        const StopwatchConfig(),
        name: 'B',
      );
      final log = await e.makeTrack(fest, const ProtocolConfig(), name: 'Log');

      final s1 = await run(
        e,
        projectA,
        at: DateTime(2026, 11, 9, 9),
        durationMs: 2 * hour,
      );
      final s2 = await run(
        e,
        projectB,
        at: DateTime(2026, 11, 10, 9),
        durationMs: 1 * hour,
      );
      final s3 = await run(
        e,
        projectA,
        at: DateTime(2026, 11, 11, 9),
        durationMs: 3 * hour,
      );
      e.clock.setMs(DateTime(2026, 11, 11, 20).millisecondsSinceEpoch);
      await e.commands.addEntry(log.id, personId: 'p');
      e.clock.advanceMs(hour);
      final s4 = (await e.commands.stopTrack(log.id))!;
      // Still running.
      await e.commands.startTrack(projectB.id);
      e.clock.advanceMs(min);

      Future<List<String>> ids(HistoryFilter f) async => [
        for (final s in await e.history.getSessions(f)) s.session.id,
      ];

      expect(await ids(HistoryFilter.all), [s4, s3, s2, s1]);
      expect(await ids(HistoryFilter(trackIds: {projectA.id})), [s3, s1]);
      expect(await ids(HistoryFilter(setId: work.id)), [s3, s2, s1]);
      expect(await ids(HistoryFilter(setId: fest.id)), [s4]);
      expect(await ids(const HistoryFilter(includeProtocol: false)), [
        s3,
        s2,
        s1,
      ]);
      expect(
        await ids(
          HistoryFilter(
            fromMs: DateTime(2026, 11, 10).millisecondsSinceEpoch,
            toMs: DateTime(2026, 11, 11).millisecondsSinceEpoch,
          ),
        ),
        [s2],
      );
      expect((await ids(const HistoryFilter(includeOpen: true))).length, 5);

      final all = await e.history.getSessions(HistoryFilter.all);
      expect(all.last.track!.name, 'A');
      expect(all.last.set!.name, 'Arbeit');
      expect(all.last.summary.netMs, 2 * hour);
      expect(all.first.summary.entryCount, 1);

      final days = groupSessionsByDay(all);
      expect(days.map((d) => d.day.toString()), [
        '2026-11-11',
        '2026-11-10',
        '2026-11-09',
      ]);
      expect(days.first.totalNetMs, 4 * hour);

      final weekly = await e.history.getWeeklySums(
        HistoryFilter(setId: work.id),
      );
      expect(weekly.map((w) => (w.track!.name, w.netMs)), [
        ('A', 5 * hour),
        ('B', 1 * hour),
      ]);
      final daily = await e.history.getDailySums(
        HistoryFilter(trackIds: {projectA.id}),
      );
      expect(daily.map((d) => d.netMs), [3 * hour, 2 * hour]);
    });

    test('filter equality (provider family key)', () {
      expect(
        HistoryFilter(trackIds: {'a', 'b'}, fromMs: 1),
        HistoryFilter(trackIds: {'b', 'a'}, fromMs: 1),
      );
      expect(
        HistoryFilter(trackIds: {'a', 'b'}).hashCode,
        HistoryFilter(trackIds: {'b', 'a'}).hashCode,
      );
      expect(
        const HistoryFilter(setId: 'x'),
        isNot(const HistoryFilter(setId: 'y')),
      );
      expect(HistoryFilter.all.isUnrestricted, isTrue);
      expect(
        const HistoryFilter(setId: 'x')
            .copyWith(setId: () => null)
            .isUnrestricted,
        isTrue,
      );
    });

    test('note editing, delete with undo', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      await e.commands.startTrack(track.id);
      e.clock.advanceMs(sec);
      await e.commands.lap(track.id);
      final id = (await e.commands.stopTrack(track.id))!;

      await e.history.updateSessionNote(id, '  Meeting  ');
      expect((await e.history.getSession(id))!.session.note, 'Meeting');
      await e.history.updateSessionNote(id, ' ');
      expect((await e.history.getSession(id))!.session.note, isNull);

      final deleted = await e.history.deleteSession(id);
      expect(deleted!.events.length, 3);
      expect(await e.history.getSession(id), isNull);
      expect(await e.db.select(e.db.events).get(), isEmpty);
      expect(await e.history.deleteSession(id), isNull);

      await e.history.restoreSession(deleted);
      final restored = await e.history.getSession(id);
      expect(restored!.session, deleted.session);
      expect(restored.events, deleted.events);
    });

    test('restoring an open session next to a newer one closes it', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      await e.commands.startTrack(track.id);
      e.clock.advanceMs(5 * sec);
      final discarded = await e.commands.resetTrack(track.id, discard: true);
      await e.commands.startTrack(track.id);
      await e.history.restoreSession(discarded!);

      final open = await e.commands.getOpenSessions();
      expect(open.length, 1);
      expect(open[track.id]!.session.id, isNot(discarded.session.id));
      final restored = await e.history.getSession(discarded.session.id);
      expect(restored!.session.isOpen, isFalse);
      expect(restored.events.last.type, EventType.stop);
    });

    test('editing event times keeps the session bounds in sync', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      final t0 = e.clock.nowMs();
      await e.commands.startTrack(track.id);
      e.clock.advanceMs(10 * min);
      final id = (await e.commands.stopTrack(track.id))!;
      final detail = await e.history.getSession(id);
      final start = detail!.events.first;
      final stop = detail.events.last;

      await e.history.updateEvent(start.copyWith(at: t0 - 5 * min));
      await e.history.updateEvent(stop.copyWith(at: t0 + 20 * min));
      final edited = await e.history.getSession(id);
      expect(edited!.session.startedAt, t0 - 5 * min);
      expect(edited.session.endedAt, t0 + 20 * min);
      expect(edited.summary.netMs, 25 * min);

      // Start and stop define the session and cannot be deleted singly.
      expect(await e.history.deleteEvent(start.id), isNull);
      expect(await e.history.deleteEvent(stop.id), isNull);
    });

    test('watchSessions follows edits', () async {
      final e = env();
      final track = await e.makeTrack(
        await e.makeSet(),
        const StopwatchConfig(),
      );
      final seen = <int>[];
      final sub = e.history
          .watchSessions(HistoryFilter.all)
          .listen((list) => seen.add(list.length));
      await pumpEventQueue();
      await e.commands.startTrack(track.id);
      await e.commands.stopTrack(track.id);
      await pumpEventQueue();
      await sub.cancel();
      expect(seen.first, 0);
      expect(seen.last, 1);
    });
  });

  group('persons and substances', () {
    test('CRUD, ordering, archive, delete with undo', () async {
      final e = env();
      final alex = await e.people.createPerson(
        name: ' Alex ',
        color: 0xFF010203,
      );
      final kim = await e.people.createPerson(name: 'Kim');
      expect(alex.name, 'Alex');
      expect((await e.people.getPersons()).map((p) => p.name), ['Alex', 'Kim']);

      await e.people.updatePerson(
        kim.copyWith(name: 'Kimi', color: 0xFFAABBCC),
      );
      await e.people.reorderPersons([kim.id, alex.id]);
      final persons = await e.people.getPersons();
      expect(persons.map((p) => p.name), ['Kimi', 'Alex']);
      expect(persons.first.color, 0xFFAABBCC);
      expect(persons.last.color, 0xFF010203);

      await e.people.setPersonArchived(alex.id, archived: true);
      expect((await e.people.getPersons()).length, 1);
      expect((await e.people.getPersons(includeArchived: true)).length, 2);

      final deleted = await e.people.deletePerson(kim.id);
      expect(await e.people.getPersons(), isEmpty);
      await e.people.restorePerson(deleted!);
      expect((await e.people.getPersons()).single.name, 'Kimi');
      expect(await e.people.deletePerson('missing'), isNull);
    });

    test(
      'substances keep the user-set lockout; none is ever invented',
      () async {
        final e = env();
        expect(await e.people.getSubstances(), isEmpty);
        final plain = await e.people.createSubstance(name: 'A');
        final locked = await e.people.createSubstance(
          name: 'B',
          lockoutMs: 2 * hour,
        );
        expect(plain.lockoutMs, isNull);
        expect((await e.people.getSubstances()).map((s) => s.lockoutMs), [
          null,
          2 * hour,
        ]);

        await e.people.updateSubstance(locked.copyWith(lockoutMs: () => null));
        expect(
          (await e.people.getSubstances()).every((s) => s.lockoutMs == null),
          isTrue,
        );

        await e.people.reorderSubstances([locked.id, plain.id]);
        expect((await e.people.getSubstances()).map((s) => s.name), ['B', 'A']);
        await e.people.setSubstanceArchived(plain.id, archived: true);
        expect((await e.people.getSubstances()).single.name, 'B');
        final deleted = await e.people.deleteSubstance(locked.id);
        await e.people.restoreSubstance(deleted!);
        expect((await e.people.getSubstances()).single, deleted);
      },
    );
  });

  group('settings store', () {
    test('typed access, persistence, change stream, reload', () async {
      final e = env();
      final store = await SettingsStore.load(e.db, clock: e.clock);
      expect(store.getString('a'), isNull);
      expect(store.getBool('flag'), isFalse);
      expect(store.getBool('flag', fallback: true), isTrue);

      final changes = <String>[];
      final sub = store.changes.listen(changes.add);
      await store.setString('a', '1');
      await store.setBool('flag', true);
      await store.setInt('n', 42);
      await store.setJson('obj', {'x': 1});
      // Unchanged value: no event.
      await store.setString('a', '1');
      await pumpEventQueue();
      expect(changes, ['a', 'flag', 'n', 'obj']);
      expect(store.getBool('flag'), isTrue);
      expect(store.getInt('n'), 42);
      expect(store.getJson('obj'), {'x': 1});
      expect(store.getJson('a'), isNull);
      expect(store.withPrefix('fl'), {'flag': 'true'});
      expect(store.contains('n'), isTrue);

      // A second store sees what the first one wrote.
      final second = await SettingsStore.load(e.db, clock: e.clock);
      expect(second.all, store.all);

      await second.remove('n');
      await second.setString('a', '2');
      await store.reload();
      await pumpEventQueue();
      expect(store.getInt('n'), isNull);
      expect(store.getString('a'), '2');
      expect(changes.sublist(4).toSet(), {'a', 'n'});
      await sub.cancel();
    });

    test('watch emits the current value first', () async {
      final e = env();
      final store = await SettingsStore.load(e.db, clock: e.clock);
      await store.setString('k', 'v1');
      final seen = <String?>[];
      final sub = store.watch('k').listen(seen.add);
      await pumpEventQueue();
      await store.setString('k', 'v2');
      await store.setString('other', 'x');
      await store.remove('k');
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, ['v1', 'v2', null]);
    });
  });

  group('backup', () {
    Future<void> populate(TestEnv e) async {
      await e.sets.ensureSeedData();
      final set = (await e.sets.getSets()).single;
      final tracks = await e.tracks.getTracks(set.id);
      final alex = await e.people.createPerson(name: 'Alex');
      final thing = await e.people.createSubstance(name: 'X', lockoutMs: hour);
      await e.commands.startTrack(tracks[0].id);
      e.clock.advanceMs(min);
      await e.commands.lap(tracks[0].id);
      await e.commands.stopTrack(tracks[0].id);
      await e.commands.tick(tracks[2].id, label: 'Hund');
      await e.entries.add(
        personId: alex.id,
        substanceId: thing.id,
        amount: '1',
      );
      final store = await SettingsStore.load(e.db, clock: e.clock);
      await store.setString(SettingsKeys.uiPrefs, '{"layout":"tiles"}');
    }

    test('protocol data is excluded unless opted in', () async {
      final e = env();
      await populate(e);

      final plain = await e.backup.readAll();
      expect(plain.entries, isEmpty);
      expect(plain.persons, isEmpty);
      expect(plain.substances, isEmpty);
      expect(plain.sessions.length, 2);
      expect(plain.settings[SettingsKeys.uiPrefs], '{"layout":"tiles"}');

      final full = await e.backup.readAll(includeProtocol: true);
      expect(full.tracks.length, 3);
      expect(full.sessions.length, 2);
      expect(full.entries.single.amount, '1');
      expect(full.persons.single.name, 'Alex');
      expect(full.substances.single.lockoutMs, hour);
    });

    test(
      'JSON round trip into an empty database restores everything',
      () async {
        final e = env();
        await populate(e);
        final data = await e.backup.readAll(includeProtocol: true);
        final json = jsonEncode(data.toJson());

        final target = TestEnv();
        addTearDown(target.dispose);
        final parsed = BackupData.fromJson(jsonMap(jsonDecode(json)));
        expect(parsed.schemaVersion, BackupData.currentSchemaVersion);
        final report = await target.backup.merge(parsed);
        expect(report.inserted['sets'], 1);
        expect(report.inserted['tracks'], 3);
        expect(report.inserted['sessions'], 2);
        expect(report.inserted['events'], data.events.length);
        expect(report.inserted['entries'], 1);
        expect(report.inserted['persons'], 1);
        expect(report.inserted['substances'], 1);
        expect(report.updatedTotal, 0);

        final again = await target.backup.readAll(includeProtocol: true);
        expect(again.sets, data.sets);
        expect(again.tracks.toSet(), data.tracks.toSet());
        expect(again.sessions.toSet(), data.sessions.toSet());
        expect(again.events.toSet(), data.events.toSet());
        expect(again.entries, data.entries);
        expect(again.persons, data.persons);
        expect(again.substances, data.substances);
        expect(again.settings[SettingsKeys.uiPrefs], '{"layout":"tiles"}');
        // The seed flag is never imported.
        expect(again.settings.containsKey(SettingsKeys.seedDone), isFalse);
      },
    );

    test(
      'a protocol track of an earlier version is skipped on import',
      () async {
        final e = env();
        final set = await e.makeSet('Festival');
        final data = BackupData(
          sets: [set],
          tracks: [
            Track(
              id: 'old-protocol',
              setId: set.id,
              name: 'Zelt',
              config: const ProtocolConfig(),
              updatedAt: 5,
            ),
          ],
          sessions: const [
            Session(
              id: 'old-session',
              trackId: 'old-protocol',
              config: ProtocolConfig(),
              startedAt: 1,
              updatedAt: 5,
            ),
          ],
          events: const [
            TrackEvent(
              id: 'old-entry',
              sessionId: 'old-session',
              trackId: 'old-protocol',
              type: EventType.entry,
              at: 2,
              personId: 'p',
              updatedAt: 5,
            ),
          ],
        );

        final report = await e.backup.merge(data);
        expect(report.inserted['tracks'], 0);
        expect(report.inserted['sessions'], 0);
        expect(report.inserted['events'], 0);
        expect(await e.tracks.getTracks(set.id), isEmpty);
        expect(await e.entries.getAll(), isEmpty);
      },
    );

    test('merge by id never destroys newer or unrelated local data', () async {
      final e = env();
      await populate(e);
      final data = await e.backup.readAll(includeProtocol: true);

      // Local changes after the backup was taken.
      e.clock.advanceMs(hour);
      final set = (await e.sets.getSets()).single;
      await e.sets.renameSet(set.id, 'Umbenannt');
      final extra = await e.makeTrack(
        set,
        const StopwatchConfig(),
        name: 'Neu',
      );
      final store = await SettingsStore.load(e.db, clock: e.clock);
      await store.setString(SettingsKeys.uiPrefs, '{"layout":"rows"}');

      final report = await e.backup.merge(data);
      expect(report.insertedTotal, 0);
      expect(report.updatedTotal, 0);
      expect((await e.sets.getSets()).single.name, 'Umbenannt');
      expect(await e.tracks.getTrack(extra.id), isNotNull);
      await store.reload();
      expect(store.getString(SettingsKeys.uiPrefs), '{"layout":"rows"}');

      // A backup that is newer wins for the rows it contains.
      final newer = BackupData(
        sets: [
          data.sets.single.copyWith(
            name: 'Aus Backup',
            updatedAt: e.clock.nowMs() + 1,
          ),
        ],
        settings: {SettingsKeys.uiPrefs: '{"layout":"tiles"}'},
      );
      final second = await e.backup.merge(newer, overwriteSettings: true);
      expect(second.updated['sets'], 1);
      expect(second.updated['settings'], 1);
      expect((await e.sets.getSets()).single.name, 'Aus Backup');
      expect(await e.tracks.getTrack(extra.id), isNotNull);
    });

    test('merge never leaves a track with two open sessions', () async {
      final source = TestEnv();
      addTearDown(source.dispose);
      await source.sets.ensureSeedData();
      final set = (await source.sets.getSets()).single;
      final watch = (await source.tracks.getTracks(set.id)).first;
      final seed = await source.backup.readAll();

      // Same data on both devices, then each starts the stopwatch.
      final e = env();
      await e.backup.merge(seed);
      await source.commands.startTrack(watch.id);
      e.clock.advanceMs(min);
      await e.commands.startTrack(watch.id);

      final report = await e.backup.merge(await source.backup.readAll());
      expect(report.inserted['sessions'], 1);
      final open = await e.commands.getOpenSessions();
      expect(open.length, 1);
      final all = await e.history.getSessions(
        const HistoryFilter(includeOpen: true),
      );
      expect(all.length, 2);
      expect(all.where((s) => s.session.isOpen).length, 1);
      expect(
        all.firstWhere((s) => !s.session.isOpen).events.last.type,
        EventType.stop,
      );
    });

    test('rejects foreign or too new files', () {
      expect(
        () => BackupData.fromJson({'app': 'other', 'schemaVersion': 1}),
        throwsFormatException,
      );
      expect(
        () => BackupData.fromJson({
          'app': BackupData.appId,
          'schemaVersion': BackupData.currentSchemaVersion + 1,
        }),
        throwsFormatException,
      );
      expect(
        BackupData.fromJson({'app': BackupData.appId, 'schemaVersion': 1}).sets,
        isEmpty,
      );
    });
  });
}
