import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/features/tracks/timeline/timeline_logic.dart';
import 'package:tikky_takka/features/tracks/tracks_strings.dart';
import 'package:tikky_takka/l10n/strings.dart';

import '../../../support/events.dart';
import '../../../support/test_env.dart';

Track _track(String id, TrackConfig config, {String? name, int sort = 0}) =>
    Track(
      id: id,
      setId: 'set',
      name: name ?? id,
      config: config,
      sortIndex: sort,
    );

HistorySession _session(Track? track, EventLog log, {int nowMs = 0}) {
  final config = track?.config ?? const CounterConfig();
  int? endedAt;
  for (final e in log.events) {
    if (e.type == EventType.stop) endedAt = e.at;
  }
  return HistorySession(
    session: Session(
      id: log.sessionId,
      trackId: log.trackId,
      config: config,
      startedAt: log.events.first.at,
      endedAt: endedAt,
    ),
    events: log.events,
    summary: summarizeSession(config: config, events: log.events, nowMs: nowMs),
    track: track,
  );
}

List<String> _texts(Iterable<TimelineRow> rows) => [
  for (final r in rows) '${r.track.name}: ${r.text}',
];

void main() {
  final birds = _track(
    'birds',
    const CounterConfig(labels: ['Reiher', 'Ente']),
    name: 'Vögel',
    sort: 0,
  );
  final watch = _track('watch', const StopwatchConfig(), name: 'Uhr', sort: 1);
  final pill = _track(
    'pill',
    const ReminderConfig(intervalMs: 10 * min),
    name: 'Pille',
    sort: 2,
  );
  final tent = _track('tent', const ProtocolConfig(), name: 'Zelt', sort: 3);

  const persons = {'jacke': 'Jacke', 'kim': 'Kim'};
  const substances = {'gbl': 'GBL', 'water': 'Wasser'};

  HistorySession birdSession() => _session(
    birds,
    EventLog(sessionId: 'sb', trackId: birds.id)
      ..start(0)
      ..tick(0, label: 'Reiher')
      ..tick(2 * min, label: 'Ente')
      ..tick(3 * min, label: 'Reiher')
      ..tick(4 * min)
      ..tick(20 * min, label: 'Reiher'),
  );

  HistorySession watchSession() => _session(
    watch,
    EventLog(sessionId: 'sw', trackId: watch.id)
      ..start(1 * min)
      ..lap(2 * min + 30 * sec)
      ..pause(5 * min)
      ..resume(6 * min)
      ..lap(7 * min, label: 'Bergauf')
      ..stop(8 * min),
    nowMs: 30 * min,
  );

  HistorySession tentSession() => _session(
    tent,
    EventLog(sessionId: 'st', trackId: tent.id)
      ..start(90 * sec)
      ..entry(90 * sec, person: 'jacke', substance: 'gbl', amount: '1 ml')
      ..entry(10 * min, person: 'kim', substance: 'water')
      ..entry(11 * min, person: 'jacke', substance: 'gbl')
      ..entry(12 * min, person: 'jacke', substance: 'water', amount: '0,5 l')
      ..entry(13 * min)
      ..entry(14 * min, person: 'gone', substance: 'gone'),
  );

  group('buildTimelineRows', () {
    test('one chronological list across all tracks, newest first by '
        'default', () {
      final rows = buildTimelineRows(sessions: [birdSession(), watchSession()]);
      final times = [for (final r in rows) r.at];
      expect(times, [...times]..sort((a, b) => b.compareTo(a)));
      expect(rows.first.text, 'Reiher · 3');
      expect(rows.first.track, birds);

      final oldest = buildTimelineRows(
        sessions: [birdSession(), watchSession()],
        newestFirst: false,
      );
      expect(_texts(oldest), [
        'Vögel: ${TracksStrings.timelineStarted}',
        'Vögel: Reiher · 1',
        'Uhr: ${TracksStrings.timelineStarted}',
        'Vögel: Ente · 1',
        'Uhr: Runde 1 · 01:30.0',
        'Vögel: Reiher · 2',
        'Vögel: Tipp 4',
        'Uhr: ${TracksStrings.timelinePaused}',
        'Uhr: ${TracksStrings.timelineResumed}',
        'Uhr: Runde 2 · 03:30.0 · Bergauf',
        'Uhr: ${TracksStrings.timelineStopped}',
        'Vögel: Reiher · 3',
      ]);
      expect(
        oldest.reversed.map((r) => r.event.id),
        rows.map((r) => r.event.id),
      );
    });

    test('kinds: lifecycle rows are marked, the rest is content', () {
      final rows = buildTimelineRows(
        sessions: [watchSession()],
        newestFirst: false,
      );
      expect(
        [for (final r in rows) r.kind],
        [
          TimelineRowKind.lifecycle,
          TimelineRowKind.lap,
          TimelineRowKind.lifecycle,
          TimelineRowKind.lifecycle,
          TimelineRowKind.lap,
          TimelineRowKind.lifecycle,
        ],
      );
      expect(rows.first.isLifecycle, isTrue);
      expect(rows[1].isLifecycle, isFalse);
    });

    test('protocol entries read "Person · Substanz · Menge" and never '
        'more', () {
      final rows = buildTimelineRows(
        sessions: [tentSession()],
        personNames: persons,
        substanceNames: substances,
        newestFirst: false,
      );
      expect(_texts(rows.where((r) => r.kind == TimelineRowKind.entry)), [
        'Zelt: Jacke · GBL · 1 ml',
        'Zelt: Kim · Wasser',
        'Zelt: Jacke · GBL',
        'Zelt: Jacke · Wasser · 0,5 l',
        'Zelt: ${Strings.protocolNoPerson} · ${Strings.protocolNoSubstance}',
        'Zelt: ${Strings.unknown} · ${Strings.unknown}',
      ]);
    });

    test('a reminder acknowledgement shows how late it came', () {
      final session = _session(
        pill,
        EventLog(sessionId: 'sp', trackId: pill.id)
          ..start(0)
          ..ack(12 * min)
          ..ack(15 * min),
      );
      final rows = buildTimelineRows(sessions: [session], newestFirst: false);
      expect(_texts(rows), [
        'Pille: ${TracksStrings.timelineStarted}',
        'Pille: Erledigt · 2 min nach Fälligkeit',
        // Early: no delay to report.
        'Pille: ${TracksStrings.timelineAck}',
      ]);
    });

    test('the range cuts the list but not the running numbers', () {
      final rows = buildTimelineRows(
        sessions: [birdSession()],
        sinceMs: 3 * min,
        newestFirst: false,
      );
      expect(_texts(rows), [
        'Vögel: Reiher · 2',
        'Vögel: Tipp 4',
        'Vögel: Reiher · 3',
      ]);
      // With an end: what came at or after it is left out.
      final evening = buildTimelineRows(
        sessions: [birdSession()],
        sinceMs: 3 * min,
        untilMs: rows[1].at,
        newestFirst: false,
      );
      expect(_texts(evening), ['Vögel: Reiher · 2']);
    });

    test('sessions of a deleted track are left out', () {
      final orphan = _session(
        null,
        EventLog(sessionId: 'so', trackId: 'gone')
          ..start(0)
          ..tick(0),
      );
      expect(buildTimelineRows(sessions: [orphan]), isEmpty);
    });
  });

  group('filterTimelineRows', () {
    test('lifecycle events are hidden unless asked for', () {
      final rows = buildTimelineRows(
        sessions: [birdSession(), watchSession()],
        newestFirst: false,
      );
      final hidden = filterTimelineRows(rows);
      expect(hidden.any((r) => r.isLifecycle), isFalse);
      expect(hidden, hasLength(7));
      expect(filterTimelineRows(rows, showLifecycle: true), hasLength(12));
    });

    test('tracks can be hidden', () {
      final rows = buildTimelineRows(sessions: [birdSession(), watchSession()]);
      final onlyWatch = filterTimelineRows(
        rows,
        showLifecycle: true,
        hiddenTrackIds: {birds.id},
      );
      expect(onlyWatch.every((r) => r.track == watch), isTrue);
      expect(onlyWatch, hasLength(6));
    });
  });

  group('withGapMarkers', () {
    test('a marker where more than the threshold passed, in both '
        'directions', () {
      final rows = filterTimelineRows(
        buildTimelineRows(sessions: [birdSession()], newestFirst: false),
      );
      // 0, 2, 3, 4 min ... 20 min.
      final items = withGapMarkers(rows);
      expect(items, hasLength(6));
      expect(items[4], isA<TimelineGapItem>());
      expect((items[4] as TimelineGapItem).ms, 16 * min);
      expect(items.whereType<TimelineGapItem>(), hasLength(1));

      final reversed = withGapMarkers(rows.reversed.toList());
      expect(reversed[1], isA<TimelineGapItem>());
      expect((reversed[1] as TimelineGapItem).ms, 16 * min);
    });

    test('exactly the threshold is no gap; the threshold can be chosen', () {
      final rows = filterTimelineRows(
        buildTimelineRows(sessions: [birdSession()], newestFirst: false),
      );
      expect(
        withGapMarkers(
          rows,
          thresholdMs: 16 * min,
        ).whereType<TimelineGapItem>(),
        isEmpty,
      );
      expect(
        withGapMarkers(
          rows,
          thresholdMs: 90 * sec,
        ).whereType<TimelineGapItem>(),
        hasLength(2),
      );
      expect(withGapMarkers(const []), isEmpty);
    });
  });

  test('tickLabelChoices: the track labels plus an old label still in use', () {
    expect(tickLabelChoices(birds, 'Ente'), ['Reiher', 'Ente']);
    expect(tickLabelChoices(birds, 'Uhu'), ['Reiher', 'Ente', 'Uhu']);
    expect(tickLabelChoices(birds, null), ['Reiher', 'Ente']);
    expect(tickLabelChoices(watch, null), isEmpty);
  });

  group('HistoryRepository.getSetActivity', () {
    final env = useTestEnv();

    test('open sessions of ONE set; with a range also what ended inside '
        'it', () async {
      final e = env();
      final set = await e.makeSet('Park');
      final other = await e.makeSet('Küche');
      final counter = await e.makeTrack(set, const CounterConfig());
      final watch = await e.makeTrack(set, const StopwatchConfig());
      final foreign = await e.makeTrack(other, const CounterConfig());

      // An old, closed session.
      await e.commands.tick(counter.id);
      await e.commands.stopTrack(counter.id);
      final oldEnd = e.clock.nowMs();
      e.clock.advance(const Duration(hours: 30));

      // A session that ended recently.
      await e.commands.startTrack(watch.id);
      e.clock.advance(const Duration(minutes: 5));
      await e.commands.stopTrack(watch.id);
      e.clock.advance(const Duration(minutes: 5));

      // Open ones - in this set and in another.
      await e.commands.tick(counter.id);
      await e.commands.tick(foreign.id);

      final open = await e.history.getSetActivity(set.id);
      expect(open, hasLength(1));
      expect(open.single.track!.id, counter.id);
      expect(open.single.session.isOpen, isTrue);
      expect(open.single.set!.id, set.id);

      final since = e.clock.nowMs() - 24 * hour;
      final day = await e.history.getSetActivity(set.id, sinceMs: since);
      expect([for (final s in day) s.track!.id], [watch.id, counter.id]);
      expect(day.every((s) => s.track!.setId == set.id), isTrue);
      expect(day.first.events.last.type, EventType.stop);

      // Reaching far enough back brings the old session in as well.
      final all = await e.history.getSetActivity(set.id, sinceMs: oldEnd);
      expect(all, hasLength(3));

      expect(await e.history.getSetActivity('no-such-set'), isEmpty);
    });

    test('watchSetActivity re-emits on a write and asks for the range '
        'again', () async {
      final e = env();
      final set = await e.makeSet();
      final counter = await e.makeTrack(set, const CounterConfig());
      var asked = 0;
      final emitted = <int>[];
      final sub = e.history
          .watchSetActivity(
            set.id,
            sinceMs: () {
              asked++;
              return 0;
            },
          )
          .listen((sessions) => emitted.add(sessions.length));
      Future<void> until(bool Function() done) async {
        for (var i = 0; i < 200 && !done(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }

      await until(() => emitted.isNotEmpty);
      expect(emitted, [0]);
      await e.commands.tick(counter.id);
      await until(() => emitted.last == 1);
      expect(emitted.last, 1);
      expect(asked, greaterThanOrEqualTo(2));
      await sub.cancel();
    });
  });
}
