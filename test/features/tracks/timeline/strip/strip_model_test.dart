import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/features/tracks/timeline/strip/strip_model.dart';
import 'package:tikky_takka/features/tracks/timeline/strip/strip_viewport.dart';
import 'package:tikky_takka/l10n/strings.dart';

import '../../../../support/events.dart';

Track _track(String id, TrackConfig config, {String? name}) =>
    Track(id: id, setId: 'set', name: name ?? id, config: config);

HistorySession _session(Track track, EventLog log, {int nowMs = 0}) {
  int? endedAt;
  for (final e in log.events) {
    if (e.type == EventType.stop) endedAt = e.at;
  }
  return HistorySession(
    session: Session(
      id: log.sessionId,
      trackId: track.id,
      config: track.config,
      startedAt: log.events.first.at,
      endedAt: endedAt,
    ),
    events: log.events,
    summary: summarizeSession(
      config: track.config,
      events: log.events,
      nowMs: nowMs,
    ),
    track: track,
  );
}

EventLog _log(Track track, [String session = 's']) =>
    EventLog(sessionId: '${track.id}-$session', trackId: track.id);

const _metrics = StripMetrics(
  laneHeight: 40,
  subLaneHeight: 30,
  barHeight: 20,
  subBarHeight: 10,
  markerRadius: 5,
  markerGap: 16,
  clusterHeight: 20,
  clusterMinWidth: 26,
  labelGap: 4,
);

/// 10 px per minute.
const double _perMinute = 6000;

StripLayout _layout(
  StripData data, {
  double startMs = 0,
  double msPerPx = _perMinute,
  double width = 600,
  required int nowMs,
}) => layoutStrip(
  data: data,
  scale: TimeScale.linear(startMs: startMs, msPerPx: msPerPx),
  width: width,
  nowMs: nowMs,
  metrics: _metrics,
);

List<String> _bars(StripLayout layout, [int? row]) => [
  for (final b in layout.bars)
    if (row == null || b.rowIndex == row)
      '${b.kind.name} ${b.rect.left.toStringAsFixed(0)}-'
          '${b.rect.right.toStringAsFixed(0)}',
];

void main() {
  final watch = _track('watch', const StopwatchConfig(), name: 'Uhr');
  final birds = _track(
    'birds',
    const CounterConfig(labels: ['Reiher', 'Ente']),
    name: 'Vögel',
  );
  final tent = _track('tent', const ProtocolConfig(), name: 'Zelt');
  const jacke = Person(id: 'p1', name: 'Jacke', color: 0xFF00AA00);
  const mo = Person(id: 'p2', name: 'Mo');
  const gbl = Substance(
    id: 'gbl',
    name: 'GBL',
    color: 0xFF112233,
    lockoutMs: 2 * hour,
  );
  const water = Substance(id: 'water', name: 'Wasser', color: 0xFF445566);
  const persons = {'p1': jacke, 'p2': mo};
  const substances = {'gbl': gbl, 'water': water};

  group('session bars', () {
    test('a bar from start to stop; the pause in between is its own, '
        'hatched piece', () {
      final log = _log(watch)
        ..start(0)
        ..pause(10 * min)
        ..resume(15 * min)
        ..stop(30 * min);
      final data = buildStripData(
        tracks: [watch],
        sessions: [_session(watch, log)],
        nowMs: hour,
      );
      expect(data.rows.single.title, 'Uhr');
      expect(data.live, isFalse);
      expect(data.firstAt, 0);
      expect(data.lastAt, 30 * min);

      final layout = _layout(data, nowMs: hour);
      expect(_bars(layout), [
        'active 0-100',
        'active 150-300',
        'paused 100-150',
      ]);
      // Centred in the lane, as high as the bar token.
      final bar = layout.bars.first.rect;
      expect(bar.top, 10);
      expect(bar.bottom, 30);
      expect(layout.bars.every((b) => !b.touchesNow), isTrue);
      expect(layout.rowTops, [0]);
      expect(layout.rowHeights, [40]);
    });

    test('a running session grows to the now line', () {
      final log = _log(watch)..start(0);
      final data = buildStripData(
        tracks: [watch],
        sessions: [_session(watch, log)],
        nowMs: 5 * min,
      );
      expect(data.live, isTrue);
      final at5 = _layout(data, nowMs: 5 * min);
      expect(_bars(at5), ['active 0-50']);
      expect(at5.bars.single.touchesNow, isTrue);
      expect(at5.nowX, 50);
      // The same data, later: no rebuild needed for the bar to grow.
      final at8 = _layout(data, nowMs: 8 * min);
      expect(_bars(at8), ['active 0-80']);
      expect(at8.nowX, 80);
    });

    test('an open pause grows instead of the bar', () {
      final log = _log(watch)
        ..start(0)
        ..pause(2 * min);
      final data = buildStripData(
        tracks: [watch],
        sessions: [_session(watch, log)],
        nowMs: 3 * min,
      );
      final layout = _layout(data, nowMs: 5 * min);
      expect(_bars(layout), ['active 0-20', 'paused 20-50']);
      expect(layout.bars.any((b) => b.touchesNow), isFalse);
      final session = data.rows.single.sessions.single;
      expect(session.isRunning, isFalse);
      expect(session.netMs(5 * min), 2 * min);
      expect(session.pausedMs(5 * min), 3 * min);
    });

    test('net and paused time of a session', () {
      final log = _log(watch)
        ..start(0)
        ..pause(10 * min)
        ..resume(15 * min);
      final session = StripSession.from(_session(watch, log), 20 * min);
      expect(session.isRunning, isTrue);
      expect(session.netMs(20 * min), 15 * min);
      expect(session.pausedMs(20 * min), 5 * min);
      expect(session.netMs(40 * min), 35 * min);
      expect(session.activeAt(12 * min, 40 * min), 10 * min);
      expect(session.wallAtActive(12 * min, 40 * min), 17 * min);
      expect(session.wallAtActive(hour, 40 * min), isNull);
    });

    test('interval phases alternate along the counting time, a flag marks '
        'the end of the programme', () {
      final interval = _track(
        'hiit',
        const IntervalConfig(workMs: 2 * min, restMs: min, rounds: 3),
      );
      final log = _log(interval)
        ..start(0)
        ..stop(12 * min);
      final data = buildStripData(
        tracks: [interval],
        sessions: [_session(interval, log)],
        nowMs: hour,
      );
      final layout = _layout(data, nowMs: hour);
      expect(_bars(layout), [
        'active 0-20',
        'phaseAlt 20-30',
        'active 30-50',
        'phaseAlt 50-60',
        'active 60-80',
        // Past the programme: it rang until it was stopped.
        'active 80-120',
      ]);
      final flag = layout.markers.single;
      expect(flag.kind, StripMarkerKind.finish);
      expect(flag.center.dx, 80);
      expect(flag.event, isNull);
      expect(flag.session, isNotNull);
    });

    test('a pause shifts the phases: they follow the net time', () {
      final interval = _track(
        'hiit',
        const IntervalConfig(workMs: 2 * min, restMs: min, rounds: 2),
      );
      final log = _log(interval)
        ..start(0)
        ..pause(min)
        ..resume(4 * min)
        ..stop(9 * min);
      final layout = _layout(
        buildStripData(
          tracks: [interval],
          sessions: [_session(interval, log)],
          nowMs: hour,
        ),
        nowMs: hour,
      );
      expect(_bars(layout), [
        'active 0-10',
        'active 40-50',
        'phaseAlt 50-60',
        'active 60-80',
        'active 80-90',
        'paused 10-40',
      ]);
      expect(layout.markers.single.center.dx, 80);
    });

    test('phases thinner than a few pixels are drawn as one bar', () {
      final interval = _track(
        'hiit',
        const IntervalConfig(workMs: 20 * sec, restMs: 10 * sec, rounds: 8),
      );
      final log = _log(interval)
        ..start(0)
        ..stop(3 * min);
      final layout = _layout(
        buildStripData(
          tracks: [interval],
          sessions: [_session(interval, log)],
          nowMs: hour,
        ),
        nowMs: hour,
      );
      expect(_bars(layout), ['active 0-30']);
    });

    test('a countdown gets a flag where it ran out; a repeating one for '
        'every cycle', () {
      final timer = _track('egg', const CountdownConfig(durationMs: 5 * min));
      final once = _log(timer)
        ..start(0)
        ..stop(7 * min);
      var layout = _layout(
        buildStripData(
          tracks: [timer],
          sessions: [_session(timer, once)],
          nowMs: hour,
        ),
        nowMs: hour,
      );
      expect(_bars(layout), ['active 0-70']);
      expect(layout.markers.single.kind, StripMarkerKind.finish);
      expect(layout.markers.single.center.dx, 50);

      final repeating = _track(
        'tea',
        const CountdownConfig(durationMs: 5 * min, autoRestart: true),
      );
      final many = _log(repeating)
        ..start(0)
        ..stop(12 * min);
      layout = _layout(
        buildStripData(
          tracks: [repeating],
          sessions: [_session(repeating, many)],
          nowMs: hour,
        ),
        nowMs: hour,
      );
      expect(layout.markers.map((m) => m.center.dx), [50, 100]);

      // Not reached yet: no flag.
      final early = _log(timer)..start(0);
      layout = _layout(
        buildStripData(
          tracks: [timer],
          sessions: [_session(timer, early)],
          nowMs: 2 * min,
        ),
        nowMs: 2 * min,
      );
      expect(layout.markers, isEmpty);
      // The same data three minutes later: reached.
      expect(
        _layout(
          buildStripData(
            tracks: [timer],
            sessions: [_session(timer, early)],
            nowMs: 2 * min,
          ),
          nowMs: 6 * min,
        ).markers.single.center.dx,
        50,
      );
    });
  });

  group('lanes', () {
    StripData mixed({
      bool expand = true,
      bool lifecycle = false,
      Set<String> hidden = const {},
      int? since,
      Set<String>? open,
    }) {
      final w = _log(watch)
        ..start(0)
        ..lap(2 * min)
        ..pause(3 * min);
      final b = _log(birds)
        ..start(min)
        ..tick(min, label: 'Reiher')
        ..tick(2 * min, label: 'Ente')
        ..tick(3 * min)
        ..tick(4 * min, label: 'Reiher');
      final t = _log(tent)
        ..start(min)
        ..entry(2 * min, person: 'p2', substance: 'water')
        ..entry(3 * min, person: 'p1', substance: 'gbl', amount: '1 ml')
        ..entry(4 * min, substance: 'water')
        ..entry(5 * min, person: 'p2', amount: 'ein Schluck');
      return buildStripData(
        // Track order, not session order.
        tracks: [birds, tent, watch],
        sessions: [_session(watch, w), _session(tent, t), _session(birds, b)],
        nowMs: 10 * min,
        persons: persons,
        substances: substances,
        expandCounterLabels: expand,
        showLifecycle: lifecycle,
        hiddenTrackIds: hidden,
        sinceMs: since,
        openPersons: open,
      );
    }

    test('the persons first, each with a lane per substance; then one '
        'lane per track in track order, a counter one per label', () {
      final data = mixed();
      expect(
        [for (final r in data.rows) '${'  ' * r.indent}${r.title}'],
        [
          'Mo',
          '  Wasser',
          '  ${Strings.protocolNoSubstance}',
          'Jacke',
          '  GBL',
          Strings.protocolNoPerson,
          '  Wasser',
          'Vögel',
          '  Reiher',
          '  Ente',
          'Uhr',
        ],
      );
      expect(data.rows.map((r) => r.id), [
        'tent/p/p2',
        'tent/p/p2/s/water',
        'tent/p/p2/s/',
        'tent/p/p1',
        'tent/p/p1/s/gbl',
        'tent/p/',
        'tent/p//s/water',
        'birds',
        'birds/l/Reiher',
        'birds/l/Ente',
        'watch',
      ]);
      expect(data.rows.map((r) => r.kind).take(3), [
        StripRowKind.person,
        StripRowKind.thing,
        StripRowKind.thing,
      ]);
      // The person's and the substance's own colours mark the lanes.
      expect(data.rows[3].dotArgb, 0xFF00AA00);
      expect(data.rows[1].dotArgb, 0xFF445566);
      expect(data.rows[7].dotArgb, isNull);
      expect(data.contentHeight(_metrics), 2 * 40 + 9 * 30);
      // Unlabelled taps stay on the track's own lane.
      expect(data.rows[7].events.single.row.text, 'Tipp 3');
      // Per label the marker carries the running count.
      expect(data.rows[8].events.map((e) => e.label), ['1', '2']);
      expect(data.rows[9].events.map((e) => e.label), ['1']);
      expect(data.eventCount, 4 + 4 + 1);
      expect(data.live, isTrue);
      expect(data.firstAt, 0);
    });

    test('a folded person carries all its entries on one lane, named by '
        'their substance; nothing remembered = all open', () {
      final data = mixed(open: {'tent/p/p1'});
      expect(data.rows.map((r) => r.id).take(4), [
        'tent/p/p2',
        'tent/p/p1',
        'tent/p/p1/s/gbl',
        'tent/p/',
      ]);
      final mo = data.rows.first;
      expect(mo.folded, isTrue);
      expect(mo.events.map((e) => e.label), ['Wasser', 'ein Schluck']);
      expect(data.rows[1].folded, isFalse);
      expect(data.rows[1].events, isEmpty);
      expect(data.rows[3].folded, isTrue);
      expect(data.contentHeight(_metrics), 2 * 40 + 6 * 30);
      expect(mixed().rows.where((r) => r.folded), isEmpty);
    });

    test('without room a counter keeps one lane; the labels become the '
        'text of the markers', () {
      final data = mixed(expand: false);
      final birdsRow = data.rows.firstWhere((r) => r.id == 'birds');
      expect(data.rows.where((r) => r.id.startsWith('birds/')), isEmpty);
      expect(birdsRow.events.map((e) => e.label), [
        'Reiher',
        'Ente',
        '3',
        'Reiher',
      ]);
      expect(birdsRow.events.map((e) => e.row.text), [
        'Reiher · 1',
        'Ente · 1',
        'Tipp 3',
        'Reiher · 2',
      ]);
    });

    test('entries: the substance names the marker and gives its colour; '
        'the amount is only ever shown', () {
      final data = mixed();
      // What has no substance has its own lane (the amount is its text);
      // a substance lane names the substance, so its markers need no text.
      final moNone = data.rows[2];
      expect(moNone.title, Strings.protocolNoSubstance);
      expect(moNone.events.map((e) => e.label), ['ein Schluck']);
      expect(moNone.events.single.colorArgb, isNull);
      final moWater = data.rows[1];
      expect(moWater.events.single.label, isNull);
      expect(moWater.events.single.colorArgb, 0xFF445566);
      expect(moWater.events.map((e) => e.kind).toSet(), {
        StripMarkerKind.entry,
      });
      final jackeRow = data.rows[4];
      expect(jackeRow.events.single.row.text, 'Jacke · GBL · 1 ml');
      expect(jackeRow.events.single.label, isNull);
      // An open person has only its name; the protocol has no lane of its
      // own once it has entries.
      expect(data.rows[0].events, isEmpty);
      expect(data.rows.any((r) => r.id == 'tent'), isFalse);
      expect(jackeRow.sessions, hasLength(1));
      // The line of a substance starts with its first entry.
      expect(jackeRow.barFrom, 3 * min);
    });

    test('start, pause and stop are markers only when asked for', () {
      expect(mixed().rows.last.events.map((e) => e.kind), [
        StripMarkerKind.lap,
      ]);
      final shown = mixed(lifecycle: true);
      expect(shown.rows.last.events.map((e) => e.row.text), [
        'Gestartet',
        'Runde 1 · 02:00.0',
        'Pausiert',
      ]);
      expect(shown.rows.last.events.first.kind, StripMarkerKind.lifecycle);
      // With start and stop the protocol keeps its own lane for them.
      expect(
        shown.rows.firstWhere((r) => r.id == 'tent').events.single.row.text,
        'Gestartet',
      );
    });

    test('hidden tracks have no lane; a set without activity is empty', () {
      final data = mixed(hidden: {'birds', 'tent'});
      expect(data.rows.map((r) => r.id), ['watch']);
      expect(data.hasActivity, isTrue);
      final none = mixed(hidden: {'birds', 'tent', 'watch'});
      expect(none.isEmpty, isTrue);
      expect(none.hasActivity, isTrue);

      final nothing = buildStripData(
        tracks: [watch],
        sessions: const [],
        nowMs: 0,
      );
      expect(nothing.isEmpty, isTrue);
      expect(nothing.hasActivity, isFalse);
      // A track without a session has no lane either.
      expect(
        buildStripData(
          tracks: [watch, birds],
          sessions: [_session(watch, _log(watch)..start(0))],
          nowMs: 0,
        ).rows.map((r) => r.id),
        ['watch'],
      );
    });

    test('events before the scope are left out, but still counted', () {
      final data = mixed(since: 3 * min + 1);
      expect(data.rows.map((r) => r.id), [
        'tent/p/',
        'tent/p//s/water',
        'tent/p/p2',
        'tent/p/p2/s/',
        'birds',
        'birds/l/Reiher',
        'watch',
      ]);
      expect(data.rows[5].events.single.label, '2');
      expect(data.rows[5].events.single.row.text, 'Reiher · 2');
      // The bars are still there; the range starts with the scope.
      expect(data.rows.last.sessions, hasLength(1));
      expect(data.firstAt, 3 * min + 1);
    });
  });

  group('markers and clusters', () {
    StripData ticks(List<int> at, {bool labels = false}) {
      final log = _log(birds)..start(0);
      for (final t in at) {
        log.tick(t, label: labels ? 'Reiher' : null);
      }
      return buildStripData(
        tracks: [birds],
        sessions: [_session(birds, log)],
        nowMs: hour,
        expandCounterLabels: false,
      );
    }

    test('markers that would overlap become one cluster with their number; '
        'zooming in takes them apart', () {
      final data = ticks([min, min + 2 * sec, min + 4 * sec, 5 * min]);
      // 1 px per second: 2 px apart.
      final far = _layout(data, msPerPx: 1000, nowMs: hour);
      expect(far.clusters, hasLength(1));
      final cluster = far.clusters.single;
      expect(cluster.count, 3);
      expect(cluster.fromMs, min);
      expect(cluster.toMs, min + 4 * sec);
      // The pill covers its markers and is never narrower than the token.
      expect(cluster.rect.center.dx, 62);
      expect(cluster.rect.width, 26);
      expect(cluster.rect.height, 20);
      expect(cluster.rect.center.dy, 20);
      expect(far.markers.single.center, const Offset(300, 20));
      expect(far.markers.single.event!.row.text, 'Tipp 4');

      // 10 px per second: 20 px apart.
      final near = _layout(data, msPerPx: 100, width: 1200, nowMs: hour);
      expect(near.clusters, isEmpty);
      expect(near.markers.map((m) => m.center.dx), [600, 620, 640]);
      expect(near.markers.map((m) => m.kind).toSet(), {StripMarkerKind.tick});

      // In between: exactly at the gap they are separate, just below not.
      expect(
        _layout(data, msPerPx: 125, width: 1200, nowMs: hour).clusters,
        isEmpty,
      );
      expect(
        _layout(
          data,
          msPerPx: 126,
          width: 1200,
          nowMs: hour,
        ).clusters.single.count,
        3,
      );
    });

    test('a wide cluster spans its markers', () {
      final data = ticks([for (var i = 0; i < 20; i++) min + i * 10 * sec]);
      final layout = _layout(data, msPerPx: 1000, nowMs: hour);
      final cluster = layout.clusters.single;
      expect(cluster.count, 20);
      expect(cluster.rect.left, 60 - 5);
      expect(cluster.rect.right, 250 + 5);
      expect(layout.markers, isEmpty);
    });

    test('a cluster that starts outside the viewport still counts all of '
        'its events', () {
      final data = ticks([for (var i = 0; i < 100; i++) i * 5 * sec]);
      // The view starts in the middle of the chain.
      final layout = _layout(
        data,
        startMs: 4 * min.toDouble(),
        msPerPx: 1000,
        width: 100,
        nowMs: hour,
      );
      expect(layout.clusters.single.count, 100);
      // Clipped to the viewport plus its margin.
      expect(layout.clusters.single.rect.left, greaterThanOrEqualTo(-48 - 5));
      expect(layout.clusters.single.rect.right, lessThanOrEqualTo(148 + 5));
    });

    test('the text of a marker gets the room up to the next one', () {
      final data = ticks([min, 2 * min, 10 * min], labels: true);
      final layout = _layout(data, msPerPx: 1000, width: 1000, nowMs: hour);
      expect(layout.markers.map((m) => m.event!.label), [
        'Reiher',
        'Reiher',
        'Reiher',
      ]);
      // 60 px to the next marker, minus both radii and the gaps.
      expect(layout.markers[0].labelRoom, 60 - 5 - 5 - 8);
      expect(layout.markers[1].labelRoom, 480 - 5 - 5 - 8);
      expect(layout.markers[2].labelRoom, double.infinity);
    });

    test('laps, acknowledgements and entries keep their kind', () {
      final pill = _track('pill', const ReminderConfig(intervalMs: 10 * min));
      final w = _log(watch)
        ..start(0)
        ..lap(5 * min, label: 'Bergauf');
      final p = _log(pill)
        ..start(0)
        ..ack(11 * min);
      final data = buildStripData(
        tracks: [watch, pill],
        sessions: [_session(watch, w), _session(pill, p)],
        nowMs: 20 * min,
      );
      final layout = _layout(data, nowMs: 20 * min);
      expect(layout.markers.map((m) => m.kind), [
        StripMarkerKind.lap,
        StripMarkerKind.ack,
      ]);
      expect(layout.markers.first.event!.label, 'Bergauf');
      expect(layout.markers.first.center, const Offset(50, 20));
      expect(layout.markers.last.center, const Offset(110, 60));
      expect(
        layout.markers.last.event!.row.text,
        'Erledigt · 1 min nach Fälligkeit',
      );
    });

    test('hit test: the nearest marker, a cluster, else the bar of the '
        'lane', () {
      final data = ticks([min, min + 2 * sec, 5 * min, 5 * min + 20 * sec]);
      final layout = _layout(data, msPerPx: 1000, nowMs: 8 * min);
      final hit = layout.hitTest(const Offset(304, 22), slop: 14);
      expect(hit, isA<StripMarkerHit>());
      expect((hit! as StripMarkerHit).marker.event!.row.text, 'Tipp 3');
      // Between two markers: the nearer one.
      expect(
        (layout.hitTest(const Offset(312, 20), slop: 14)! as StripMarkerHit)
            .marker
            .event!
            .row
            .text,
        'Tipp 4',
      );
      final cluster = layout.hitTest(const Offset(61, 20), slop: 14);
      expect(cluster, isA<StripClusterHit>());
      expect((cluster! as StripClusterHit).cluster.count, 2);
      final bar = layout.hitTest(const Offset(200, 20), slop: 14);
      expect(bar, isA<StripBarHit>());
      expect((bar! as StripBarHit).bar.session.startAt, 0);
      // Right of "now" there is nothing.
      expect(layout.hitTest(const Offset(560, 20), slop: 14), isNull);
      // Below the lanes neither.
      expect(layout.hitTest(const Offset(200, 90), slop: 14), isNull);
    });
  });

  group('lockout bands', () {
    StripData protocol(Map<String, Substance> known) {
      final log = _log(tent)
        ..start(0)
        ..entry(10 * min, person: 'p1', substance: 'gbl')
        ..entry(20 * min, person: 'p1', substance: 'water')
        ..entry(30 * min, person: 'p2', substance: 'water')
        ..entry(40 * min, person: 'p1');
      return buildStripData(
        tracks: [tent],
        sessions: [_session(tent, log)],
        nowMs: hour,
        persons: persons,
        substances: known,
      );
    }

    test('only where the user set a lockout on the substance', () {
      final data = protocol(substances);
      expect(data.rows.map((r) => r.id), [
        'tent/p/p1',
        'tent/p/p1/s/gbl',
        'tent/p/p1/s/water',
        'tent/p/p1/s/',
        'tent/p/p2',
        'tent/p/p2/s/water',
      ]);
      final gblRow = data.rows[1];
      expect(gblRow.title, 'GBL');
      expect(gblRow.bands, hasLength(1));
      expect(gblRow.bands.single.from, 10 * min);
      expect(gblRow.bands.single.to, 10 * min + 2 * hour);
      expect(gblRow.bands.single.colorArgb, 0xFF112233);
      expect(gblRow.lockoutUntil, 10 * min + 2 * hour);
      expect(gblRow.events.single.lockoutUntil, 10 * min + 2 * hour);
      // Water has no lockout, an entry without a substance neither.
      expect(data.rows[2].bands, isEmpty);
      expect(data.rows[2].lockoutUntil, isNull);
      expect(data.rows[3].events.single.lockoutUntil, isNull);
      expect(data.rows[3].bands, isEmpty);
      expect(data.rows[5].bands, isEmpty);
      expect(data.rows[0].bands, isEmpty);

      final layout = _layout(data, nowMs: hour);
      final band = layout.bands.single;
      expect(band.rowIndex, 1);
      expect(band.rect.left, 100);
      // Two hours later - beyond the viewport, clipped at its margin.
      expect(band.rect.right, 648);
      // Without a band height: the whole height of the substance's lane.
      expect(band.rect.top, 30);
      expect(band.rect.bottom, 60);
      expect(band.colorArgb, 0xFF112233);

      // With one: around the line of the lane.
      final narrow = layoutStrip(
        data: data,
        scale: TimeScale.linear(startMs: 0, msPerPx: _perMinute),
        width: 600,
        nowMs: hour,
        metrics: const StripMetrics(
          laneHeight: 40,
          subLaneHeight: 30,
          barHeight: 20,
          subBarHeight: 10,
          markerRadius: 5,
          markerGap: 16,
          clusterHeight: 20,
          clusterMinWidth: 26,
          labelGap: 4,
          bandHeight: 10,
        ),
      );
      expect(narrow.bands.single.rect.top, 40);
      expect(narrow.bands.single.rect.bottom, 50);
    });

    test('no lockout set anywhere: no band at all', () {
      final none = protocol({
        'gbl': gbl.copyWith(lockoutMs: () => null),
        'water': water,
      });
      expect(none.rows.expand((r) => r.bands), isEmpty);
      expect(_layout(none, nowMs: hour).bands, isEmpty);
      // A lockout of zero is none.
      final zero = protocol({
        'gbl': gbl.copyWith(lockoutMs: () => 0),
        'water': water,
      });
      expect(zero.rows.expand((r) => r.bands), isEmpty);
    });

    test('a band that began before the viewport still reaches into it; '
        'one that is over is not drawn at all', () {
      final data = protocol(substances);
      final inside = _layout(
        data,
        startMs: 90 * min.toDouble(),
        width: 600,
        nowMs: 100 * min,
      );
      expect(inside.bands.single.rect.left, -48);
      expect(inside.bands.single.rect.right, 400);
      // The lockout ran out at 2:10: nothing, wherever the view is.
      expect(_layout(data, nowMs: 3 * hour).bands, isEmpty);
      final after = _layout(
        data,
        startMs: 3 * hour.toDouble(),
        width: 300,
        nowMs: 4 * hour,
      );
      expect(after.bands, isEmpty);
    });
  });

  group('substance lanes: timer and the time between entries', () {
    // One person: the substance lanes follow the track directly.
    StripData single({bool stopped = false}) {
      final log = _log(tent)
        ..start(0)
        ..entry(10 * min, person: 'p1', substance: 'gbl')
        ..entry(11 * min, person: 'p1', substance: 'gbl')
        ..entry(40 * min, person: 'p1', substance: 'gbl')
        ..entry(20 * min, person: 'p1', substance: 'water');
      if (stopped) log.stop(50 * min);
      return buildStripData(
        tracks: [tent],
        sessions: [_session(tent, log)],
        nowMs: hour,
        persons: persons,
        substances: substances,
      );
    }

    test('one person: its lane, below it a lane per substance with a timer '
        'from its last entry while the session is open', () {
      final data = single();
      expect(
        [for (final r in data.rows) '${'  ' * r.indent}${r.title}'],
        ['Jacke', '  GBL', '  Wasser'],
      );
      expect(data.rows[1].timerFrom, 40 * min);
      expect(data.rows[2].timerFrom, 20 * min);
      expect(data.rows[0].timerFrom, isNull);
      expect(data.rows[1].showGaps, isTrue);
      expect(data.rows[0].showGaps, isFalse);
      // Each entry knows the one before it on its lane.
      expect(data.rows[1].events.map((e) => e.previousAt), [
        null,
        10 * min,
        11 * min,
      ]);
      expect(data.rows[2].events.single.previousAt, isNull);
      // A finished session has nothing that counts on.
      expect(single(stopped: true).rows[1].timerFrom, isNull);
    });

    test('the time between neighbours where it has room, and the running '
        'time from the last entry up to now', () {
      final layout = _layout(single(), nowMs: hour);
      final gbl = [
        for (final g in layout.gaps)
          if (g.rowIndex == 1) g,
      ];
      // 10 -> 11 min is 10 px: too close for a text. 11 -> 40 min is 29
      // minutes; 40 min -> now the running timer.
      expect(gbl.map((g) => (g.ms, g.live)), [
        (29 * min, false),
        (20 * min, true),
      ]);
      expect(gbl.first.fromX, 110);
      expect(gbl.first.toX, 400);
      expect(gbl.last.toX, layout.nowX);
      expect(gbl.first.centerY, 30 + 15);
      // Water: a single entry, only its timer.
      final water = [
        for (final g in layout.gaps)
          if (g.rowIndex == 2) g,
      ];
      expect(water.single.live, isTrue);
      expect(water.single.ms, 40 * min);
      // The person's own lane has none.
      expect(layout.gaps.where((g) => g.rowIndex == 0), isEmpty);
    });

    test('no timer and no running gap after the session ended; gaps only '
        'for what touches the viewport', () {
      final stopped = _layout(single(stopped: true), nowMs: hour);
      expect(stopped.gaps.where((g) => g.live), isEmpty);
      expect(stopped.gaps.where((g) => g.rowIndex == 1), hasLength(1));
      final later = _layout(
        single(),
        startMs: 2 * hour.toDouble(),
        nowMs: 3 * hour,
      );
      // Only the running timer reaches into a viewport after the entries.
      expect(later.gaps.every((g) => g.live), isTrue);
    });
  });

  group('culling', () {
    test('only what touches the viewport is produced', () {
      final log = _log(birds)..start(0);
      for (var i = 1; i <= 5000; i++) {
        log.tick(i * min);
      }
      final old = _log(watch, 'old')
        ..start(0)
        ..stop(10 * min);
      final late = _log(watch, 'late')
        ..start(4000 * min)
        ..stop(4010 * min);
      final data = buildStripData(
        tracks: [birds, watch],
        sessions: [
          _session(birds, log),
          _session(watch, old),
          _session(watch, late),
        ],
        nowMs: 6000 * min,
      );
      expect(data.rows.first.events, hasLength(5000));

      // Ten minutes around minute 2000, 60 px per minute.
      final layout = _layout(
        data,
        startMs: 2000 * min.toDouble(),
        msPerPx: 1000,
        width: 600,
        nowMs: 6000 * min,
      );
      expect(layout.clusters, isEmpty);
      expect(layout.markers.length, inInclusiveRange(10, 12));
      for (final m in layout.markers) {
        expect(m.center.dx, inInclusiveRange(-48, 648));
      }
      // The counter's bar, clipped; none of the stopwatch sessions.
      expect(layout.bars, hasLength(1));
      expect(layout.bars.single.rowIndex, 0);
      expect(layout.bars.single.rect.left, -48);
      expect(layout.bars.single.rect.right, 648);
      // Now is far to the right.
      expect(layout.nowX, greaterThan(600));

      // Zoomed all the way out everything is one cluster.
      final all = _layout(
        data,
        msPerPx: 6000 * min / 600,
        width: 600,
        nowMs: 6000 * min,
      );
      expect(all.markers, isEmpty);
      expect(all.clusters.single.count, 5000);
      expect(all.bars, hasLength(3));
    });

    test('nothing for an empty viewport, but the lanes keep their places', () {
      final data = buildStripData(
        tracks: [watch],
        sessions: [_session(watch, _log(watch)..start(0))],
        nowMs: min,
      );
      final layout = _layout(data, width: 0, nowMs: min);
      expect(layout.bars, isEmpty);
      expect(layout.markers, isEmpty);
      expect(layout.rowTops, [0]);
    });

    test('a few thousand events lay out quickly', () {
      final log = _log(birds)..start(0);
      for (var i = 1; i <= 6000; i++) {
        log.tick(i * 7 * sec, label: i.isEven ? 'Reiher' : 'Ente');
      }
      final data = buildStripData(
        tracks: [birds],
        sessions: [_session(birds, log)],
        nowMs: 12 * hour,
      );
      final watchTime = Stopwatch()..start();
      var produced = 0;
      for (var i = 0; i < 200; i++) {
        final layout = _layout(
          data,
          startMs: i * min.toDouble(),
          msPerPx: 1000.0 + i * 50,
          width: 1200,
          nowMs: 12 * hour,
        );
        produced += layout.markers.length + layout.clusters.length;
      }
      watchTime.stop();
      expect(produced, greaterThan(0));
      // Far below a frame per layout even on a slow machine.
      expect(watchTime.elapsedMilliseconds, lessThan(2000));
    });
  });

  test('the range of the strip', () {
    expect(stripExtent(StripData.empty), isNull);
    final log = _log(watch)
      ..start(5 * min)
      ..stop(9 * min);
    final data = buildStripData(
      tracks: [watch],
      sessions: [_session(watch, log)],
      nowMs: hour,
    );
    expect(stripExtent(data), (start: 5 * min, end: 9 * min));
  });
}
