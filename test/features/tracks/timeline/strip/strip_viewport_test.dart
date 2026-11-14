import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/features/tracks/timeline/strip/strip_viewport.dart';

import '../../../../support/events.dart';

StripViewport _viewport({
  int start = 0,
  int end = 2 * hour,
  bool live = false,
  int now = 2 * hour,
  double width = 1000,
}) => StripViewport()
  ..setNow(now)
  ..setExtent(start, end, live: live)
  ..setWidth(width);

void main() {
  test('fit shows the whole range with a little air on both sides', () {
    final v = _viewport()..fit();
    expect(v.xOf(0), greaterThan(0));
    expect(v.xOf(2 * hour), lessThan(1000));
    // The same air left and right.
    expect(v.xOf(0), closeTo(1000 - v.xOf(2 * hour), 1e-6));
    expect(v.xOf(0), closeTo(1000 * 0.06 / 1.12, 1e-6));
    expect(v.following, isFalse);
  });

  test('fit never shows less than a minute', () {
    final v = _viewport(end: 3 * sec, now: 3 * sec)..fit();
    expect(v.spanMs, closeTo(min, 1e-6));
    // Centred on what there is.
    expect((v.xOf(0) + v.xOf(3 * sec)) / 2, closeTo(500, 1e-6));
  });

  test('a live range is fitted up to now, an ended one to its end', () {
    final ended = _viewport(end: hour, now: 5 * hour)..fit();
    expect(ended.xOf(hour), lessThan(1000));
    expect(ended.xOf(5 * hour), greaterThan(1000));
    final live = _viewport(end: hour, now: 5 * hour, live: true)..fit();
    expect(live.xOf(5 * hour), lessThan(1000));
    expect(live.xOf(5 * hour), greaterThan(900));
  });

  test('zooming keeps the instant under the pointer where it is', () {
    final v = _viewport()..fit();
    for (final x in [0.0, 250.0, 777.0]) {
      final before = v.timeAt(x);
      final scale = v.msPerPx;
      v.zoomAround(x, 2);
      expect(v.msPerPx, closeTo(scale / 2, 1e-9));
      expect(v.timeAt(x), closeTo(before, 1e-6));
      v.zoomAround(x, 0.5);
      expect(v.msPerPx, closeTo(scale, 1e-9));
      expect(v.timeAt(x), closeTo(before, 1e-6));
    }
  });

  test('the zoom stops at ten seconds across the width and at the whole '
      'range', () {
    final v = _viewport()..fit();
    for (var i = 0; i < 60; i++) {
      v.zoomAround(500, 2);
    }
    expect(v.spanMs, closeTo(10 * sec, 1e-6));
    expect(v.msPerPx, v.minMsPerPx);
    for (var i = 0; i < 60; i++) {
      v.zoomAround(500, 0.5);
    }
    // Two hours plus the air of "Alles zeigen".
    expect(v.spanMs, closeTo(2 * hour * 1.12, 1e-3));
    expect(v.msPerPx, v.maxMsPerPx);

    // A tiny range can still be zoomed out to ten minutes.
    final tiny = _viewport(end: 2 * sec, now: 2 * sec)..fit();
    for (var i = 0; i < 60; i++) {
      tiny.zoomBy(0.5);
    }
    expect(tiny.spanMs, closeTo(10 * min, 1e-6));
  });

  test('panning is clamped: the middle of the view stays in the range', () {
    final v = _viewport()
      ..fit()
      ..zoomAround(500, 8);
    final span = v.spanMs;
    v.panBy(1e9);
    expect(v.startMs, closeTo(0 - span / 2, 1e-6));
    expect(v.timeAt(500), closeTo(0, 1e-6));
    v.panBy(-1e9);
    expect(v.timeAt(500), closeTo(2 * hour, 1e-6));
    // A drag to the right shows earlier times.
    final before = v.startMs;
    v.panBy(100);
    expect(v.startMs, closeTo(before - 100 * v.msPerPx, 1e-6));
  });

  test('now is always reachable, also long after the last event', () {
    final v = _viewport(end: hour, now: 6 * hour)
      ..fit()
      ..panBy(-1e9);
    expect(v.timeAt(500), closeTo(6 * hour, 1e-6));
    expect(v.extentEnd, 6 * hour);
    expect(v.fitEnd, hour);
  });

  test('"Jetzt" pins now and follows it; panning ends that', () {
    final v = _viewport(live: true)
      ..fit()
      ..zoomAround(500, 4);
    var notified = 0;
    v.addListener(() => notified++);

    v.jumpToNow();
    expect(v.following, isTrue);
    expect(v.xOf(2 * hour), closeTo(820, 1e-6));
    expect(notified, 1);

    // Time passes: the view moves, now stays where it is.
    v.setNow(2 * hour + 30 * sec);
    expect(v.xOf(v.nowMs), closeTo(820, 1e-6));
    expect(notified, 2);

    // Zooming while following keeps now pinned, not the pointer.
    v.zoomAround(100, 2);
    expect(v.following, isTrue);
    expect(v.xOf(v.nowMs), closeTo(820, 1e-6));

    v.panBy(40);
    expect(v.following, isFalse);
    final start = v.startMs;
    final before = notified;
    v.setNow(2 * hour + 60 * sec);
    expect(v.startMs, start);
    // Not following: time passing moves nothing and notifies nobody (the
    // painter follows the ticker itself).
    expect(notified, before);

    v.jumpToNow();
    expect(v.following, isTrue);
    expect(v.xOf(v.nowMs), closeTo(820, 1e-6));
  });

  test('"Alles zeigen" ends following', () {
    final v = _viewport(live: true)
      ..jumpToNow()
      ..fit();
    expect(v.following, isFalse);
    expect(v.xOf(0), greaterThan(0));
  });

  test('showRange zooms onto a stretch', () {
    final v = _viewport()
      ..fit()
      ..showRange(30 * min, 40 * min);
    expect(v.xOf(30 * min), closeTo(1000 * 0.06 / 1.12, 1e-6));
    expect(v.xOf(40 * min), closeTo(1000 - 1000 * 0.06 / 1.12, 1e-6));
    // Never closer than the closest zoom.
    v.showRange(30 * min, 30 * min + 5);
    expect(v.spanMs, closeTo(10 * sec, 1e-6));
  });

  test('a new width keeps the left edge and the zoom', () {
    final v = _viewport()
      ..fit()
      ..zoomAround(500, 4);
    final start = v.startMs;
    final scale = v.msPerPx;
    v.setWidth(600);
    expect(v.startMs, closeTo(start, 1e-6));
    expect(v.msPerPx, scale);
    expect(v.spanMs, closeTo(600 * scale, 1e-6));
  });

  test('silent changes do not notify; nothing happens without a width', () {
    final v = StripViewport();
    var notified = 0;
    v
      ..addListener(() => notified++)
      ..setNow(hour, notify: false)
      ..setExtent(0, hour, live: true, notify: false)
      ..setWidth(800, notify: false)
      ..fit(notify: false);
    expect(notified, 0);
    expect(v.xOf(0), greaterThan(0));
    v.zoomBy(2);
    expect(notified, 1);

    final blank = StripViewport()
      ..fit()
      ..zoomAround(10, 2)
      ..panBy(10);
    expect(blank.msPerPx, 1000);
  });
}
