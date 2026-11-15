import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/features/tracks/timeline/strip/strip_axis.dart';
import 'package:tikky_takka/features/tracks/timeline/strip/strip_model.dart';
import 'package:tikky_takka/features/tracks/timeline/strip/strip_viewport.dart';

import '../../../../support/events.dart';

/// Folds of the strip (Pult 3.1): a stretch without any event is drawn
/// 24 px wide; the scale before and after it is the same.
void main() {
  List<StripFold> folds(List<int> times, {required int now}) => computeFolds(
    times,
    nowMs: now,
    minGapMs: 20 * min,
    keepRecentMs: 10 * min,
    padMs: 2 * min,
  );

  group('computeFolds', () {
    test('every gap of 20 min or more, less the room next to the events', () {
      expect(folds([0, 30 * min, 40 * min, 50 * min], now: 55 * min), [
        const StripFold(2 * min, 28 * min),
      ]);
      // In any order; a gap below 20 min stays.
      expect(folds([50 * min, 0, 19 * min], now: 61 * min), [
        const StripFold(21 * min, 48 * min),
      ]);
    });

    test('never the last ten minutes before now', () {
      // From the last event up to "now": folded until ten minutes before.
      expect(folds([0], now: hour), [const StripFold(2 * min, 50 * min)]);
      // A gap that reaches into the last ten minutes ends there.
      expect(folds([0, 55 * min], now: hour), [
        const StripFold(2 * min, 50 * min),
      ]);
      // Too short once the last ten minutes are left out.
      expect(folds([0], now: 25 * min), isEmpty);
      expect(folds(const [], now: hour), isEmpty);
    });
  });

  group('TimeScale', () {
    // 10 px per minute; a fold of 40 min from 10 to 50 min.
    final scale = TimeScale(
      startMs: 0,
      msPerPx: 6000,
      folds: const [StripFold(10 * min, 50 * min)],
      foldPx: 24,
    );

    test('a fold is drawn 24 px wide; the scale is the same on both '
        'sides', () {
      expect(scale.xOf(10 * min), closeTo(100, 1e-9));
      expect(scale.xOf(50 * min), closeTo(124, 1e-9));
      expect(scale.xOf(60 * min) - scale.xOf(50 * min), closeTo(100, 1e-9));
      expect(scale.xOf(30 * min), closeTo(112, 1e-9));
      expect(scale.isFolded(30 * min), isTrue);
      expect(scale.isFolded(5 * min), isFalse);
    });

    test('time -> x -> time is the identity, x is monotonic', () {
      var last = double.negativeInfinity;
      for (var t = 0; t <= 90 * min; t += 37 * sec) {
        final x = scale.xOf(t);
        expect(x, greaterThan(last));
        last = x;
        expect(scale.timeAt(x), closeTo(t, 1e-6));
      }
    });

    test('a fold that would be narrower than 24 px stays as it is', () {
      // 1 px = 10 min: the 40 min are only 4 px.
      final far = TimeScale(
        startMs: 0,
        msPerPx: 10 * min.toDouble(),
        folds: const [StripFold(10 * min, 50 * min)],
        foldPx: 24,
      );
      expect(far.folds, isEmpty);
      expect(far.xOf(50 * min), closeTo(5, 1e-9));
    });
  });

  test('the axis leaves out ticks in and next to a fold and marks the '
      'fold with its length', () {
    final start = DateTime(2026, 11, 14, 20).millisecondsSinceEpoch;
    final scale = TimeScale(
      startMs: start.toDouble(),
      msPerPx: 6000,
      folds: [StripFold(start + 30 * min, start + 90 * min)],
      foldPx: 24,
    );
    final axis = computeAxis(scale: scale, width: 800, minSpacingPx: 60);
    final mark = axis.folds.single;
    expect(mark.ms, hour);
    expect(mark.left, closeTo(300, 1e-9));
    expect(mark.right, closeTo(324, 1e-9));
    for (final tick in axis.ticks) {
      expect(
        tick.x <= mark.left - 30 || tick.x >= mark.right + 30,
        isTrue,
        reason: tick.label,
      );
    }
    // The ticks go on behind the fold, on round times.
    expect(axis.ticks.map((t) => t.label), containsAll(['20:20', '21:40']));
  });

  group('viewport', () {
    StripViewport viewport() {
      final v = StripViewport(foldPx: 24)
        ..setNow(2 * hour)
        ..setExtent(0, 2 * hour, live: true)
        ..setWidth(600)
        ..setFolds(const [StripFold(10 * min, 90 * min)]);
      return v;
    }

    test('"Alles" needs less room with a fold', () {
      final plain = StripViewport()
        ..setNow(2 * hour)
        ..setExtent(0, 2 * hour, live: true)
        ..setWidth(600)
        ..fit();
      final folded = viewport()..fit();
      expect(folded.msPerPx, lessThan(plain.msPerPx));
      expect(folded.xOf(0), greaterThanOrEqualTo(0));
      expect(folded.xOf(2 * hour), lessThanOrEqualTo(600));
    });

    test('"Jetzt" keeps now at its place; panning crosses a fold as fast '
        'as its 24 px', () {
      final v = viewport()..jumpToNow();
      expect(v.xOf(2 * hour), closeTo(600 * 0.82, 1e-6));
      final before = v.xOf(5 * min);
      v.panBy(24);
      expect(v.xOf(5 * min), closeTo(before + 24, 1e-6));
      expect(v.following, isFalse);
    });

    test('zooming keeps the instant under the pointer', () {
      final v = viewport()..fit();
      final at = v.timeAt(400);
      v.zoomAround(400, 1.6);
      expect(v.xOf(at), closeTo(400, 1e-6));
    });
  });

  test('the strip: no marker in a fold, markers on both sides are not '
      'bundled, the bar runs through', () {
    const watch = Track(
      id: 'w',
      setId: 'set',
      name: 'Uhr',
      config: StopwatchConfig(),
    );
    final log = EventLog(sessionId: 'w-s', trackId: 'w')
      ..start(0)
      ..lap(min)
      ..lap(hour);
    final data = buildStripData(
      tracks: [watch],
      sessions: [
        HistorySession(
          session: Session(
            id: 'w-s',
            trackId: 'w',
            config: watch.config,
            startedAt: 0,
          ),
          events: log.events,
          summary: summarizeSession(
            config: watch.config,
            events: log.events,
            nowMs: 2 * hour,
          ),
          track: watch,
        ),
      ],
      nowMs: 2 * hour,
    );
    final times = stripKeepTimes(data).toSet();
    // The running bar keeps no moment of its own between its ends.
    expect(times, containsAll([0, min, hour]));
    expect(times.any((t) => t > hour), isFalse);

    final found = computeFolds(
      times,
      nowMs: 2 * hour,
      minGapMs: 20 * min,
      keepRecentMs: 10 * min,
      padMs: 2 * min,
    );
    expect(found, const [
      StripFold(3 * min, 58 * min),
      StripFold(62 * min, 110 * min),
    ]);
    // 1 px = 6 s: without folds the two laps would be 590 px apart. At a
    // zoom that bundles them by time they still stand apart.
    final scale = TimeScale(
      startMs: 0,
      msPerPx: 3 * min.toDouble(),
      folds: found,
      foldPx: 24,
    );
    final layout = layoutStrip(
      data: data,
      scale: scale,
      width: 600,
      nowMs: 2 * hour,
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
      ),
    );
    final laps = [
      for (final m in layout.markers)
        if (m.event != null) m.center.dx,
    ];
    expect(laps, hasLength(2));
    expect(layout.clusters, isEmpty);
    for (final x in laps) {
      expect(scale.isFolded(scale.timeAt(x)), isFalse);
    }
    // One bar from the start up to the now line.
    final bar = layout.bars.single.rect;
    expect(bar.left, closeTo(0, 1e-6));
    expect(bar.right, closeTo(layout.nowX, 1e-6));
  });
}
