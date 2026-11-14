import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';

import '../../support/events.dart';

void main() {
  group('sortEvents', () {
    test('orders by time, then seq, and leaves the input untouched', () {
      final log = EventLog()
        ..add(EventType.pause, 500, seq: 2)
        ..add(EventType.start, 100, seq: 0)
        ..add(EventType.lap, 500, seq: 1);
      final original = List.of(log.events);
      final sorted = sortEvents(log.events);
      expect(sorted.map((e) => e.type), [
        EventType.start,
        EventType.lap,
        EventType.pause,
      ]);
      expect(log.events, original);
    });

    test('is deterministic for full ties', () {
      const a = TrackEvent(
        id: 'b',
        sessionId: 's',
        trackId: 't',
        type: EventType.tick,
        at: 1,
      );
      const b = TrackEvent(
        id: 'a',
        sessionId: 's',
        trackId: 't',
        type: EventType.tick,
        at: 1,
      );
      expect(sortEvents([a, b]).map((e) => e.id), ['a', 'b']);
      expect(sortEvents([b, a]).map((e) => e.id), ['a', 'b']);
    });
  });

  group('Timeline', () {
    test('empty log is idle', () {
      final t = Timeline.build(const [], 1000);
      expect(t.isStarted, isFalse);
      expect(t.baseState, RunState.idle);
      expect(t.activeMs, 0);
      expect(t.wallMs, 0);
      expect(t.pausedMs, 0);
      expect(t.wallAtActive(10), isNull);
    });

    test('running: active time equals wall time', () {
      final log = EventLog()..start(1000);
      final t = Timeline.build(log.events, 4000);
      expect(t.baseState, RunState.running);
      expect(t.activeMs, 3000);
      expect(t.wallMs, 3000);
      expect(t.pausedMs, 0);
    });

    test('pause freezes active time', () {
      final log = EventLog()
        ..start(1000)
        ..pause(3000);
      final t = Timeline.build(log.events, 10000);
      expect(t.baseState, RunState.paused);
      expect(t.activeMs, 2000);
      expect(t.pausedMs, 7000);
      expect(t.wallMs, 9000);
    });

    test('multiple pause / resume cycles', () {
      final log = EventLog()
        ..start(0)
        ..pause(1000)
        ..resume(3000)
        ..pause(4000)
        ..resume(10000);
      final t = Timeline.build(log.events, 10500);
      expect(t.baseState, RunState.running);
      expect(t.activeMs, 1000 + 1000 + 500);
      expect(t.pausedMs, 2000 + 6000);
      expect(t.activeSpans, const [
        TimeSpan(0, 1000),
        TimeSpan(3000, 4000),
        TimeSpan(10000, 10500),
      ]);
    });

    test('stop ends the session; later now does not matter', () {
      final log = EventLog()
        ..start(0)
        ..pause(1000)
        ..resume(2000)
        ..stop(5000);
      final a = Timeline.build(log.events, 5000);
      final b = Timeline.build(log.events, 999999);
      expect(a.baseState, RunState.stopped);
      expect(a.activeMs, 4000);
      expect(b.activeMs, 4000);
      expect(b.endAt, 5000);
      expect(b.pausedMs, 1000);
    });

    test('stop while paused does not count the pause as active', () {
      final log = EventLog()
        ..start(0)
        ..pause(1000)
        ..stop(5000);
      final t = Timeline.build(log.events, 9000);
      expect(t.activeMs, 1000);
      expect(t.pausedMs, 4000);
      expect(t.isPaused, isFalse);
      expect(t.baseState, RunState.stopped);
    });

    test('activeMsAt clamps into the session', () {
      final log = EventLog()
        ..start(1000)
        ..pause(2000)
        ..resume(5000);
      final t = Timeline.build(log.events, 6000);
      expect(t.activeMsAt(0), 0);
      expect(t.activeMsAt(1000), 0);
      expect(t.activeMsAt(1500), 500);
      expect(t.activeMsAt(3000), 1000);
      expect(t.activeMsAt(5500), 1500);
      expect(t.activeMsAt(99999), 2000);
    });

    test('wallAtActive finds past and future instants', () {
      final log = EventLog()
        ..start(1000)
        ..pause(2000)
        ..resume(5000);
      final t = Timeline.build(log.events, 6000);
      expect(t.wallAtActive(0), 1000);
      expect(t.wallAtActive(500), 1500);
      expect(t.wallAtActive(1000), 2000);
      expect(t.wallAtActive(1500), 5500);
      expect(t.wallAtActive(2000), 6000);
      expect(t.wallAtActive(3000), 7000);
    });

    test('wallAtActive is null for the future while paused or stopped', () {
      final paused = EventLog()
        ..start(0)
        ..pause(1000);
      expect(Timeline.build(paused.events, 5000).wallAtActive(2000), isNull);
      expect(Timeline.build(paused.events, 5000).wallAtActive(1000), 1000);
      final stopped = EventLog()
        ..start(0)
        ..stop(1000);
      expect(Timeline.build(stopped.events, 5000).wallAtActive(2000), isNull);
    });

    group('defensive handling', () {
      test('now before the last event (clock jumped back) is clamped', () {
        final log = EventLog()
          ..start(10000)
          ..lap(12000);
        final t = Timeline.build(log.events, 5000);
        expect(t.endAt, 12000);
        expect(t.activeMs, 2000);
        expect(t.wallMs, 2000);
      });

      test('events sorting before the start are moved onto the start', () {
        final log = EventLog()
          ..start(10000)
          // Clock jumped back before this pause was logged.
          ..pause(4000)
          ..resume(11000);
        final t = Timeline.build(log.events, 12000);
        expect(t.startAt, 10000);
        expect(t.activeMs, 1000);
        expect(t.pausedMs, 1000);
        expect(t.events.every((e) => e.at >= 10000), isTrue);
      });

      test('missing start: the first event starts the session', () {
        final log = EventLog()
          ..tick(2000)
          ..tick(3000);
        final t = Timeline.build(log.events, 4000);
        expect(t.startAt, 2000);
        expect(t.baseState, RunState.running);
        expect(t.activeMs, 2000);
      });

      test('duplicate pause and stray resume are ignored', () {
        final log = EventLog()
          ..start(0)
          ..resume(500)
          ..pause(1000)
          ..pause(2000)
          ..resume(3000)
          ..resume(3500);
        final t = Timeline.build(log.events, 4000);
        expect(t.activeMs, 1000 + 1000);
        expect(t.pausedMs, 2000);
        expect(t.baseState, RunState.running);
      });

      test('a second start acts as resume', () {
        final log = EventLog()
          ..start(0)
          ..pause(1000)
          ..start(2000);
        final t = Timeline.build(log.events, 3000);
        expect(t.baseState, RunState.running);
        expect(t.activeMs, 2000);
        expect(t.startAt, 0);
      });

      test('events after the stop are ignored', () {
        final log = EventLog()
          ..start(0)
          ..stop(1000)
          ..resume(2000)
          ..lap(3000);
        final t = Timeline.build(log.events, 9000);
        expect(t.baseState, RunState.stopped);
        expect(t.events.length, 2);
        expect(t.activeMs, 1000);
      });

      test('durations are never negative for shuffled input', () {
        final log = EventLog()
          ..stop(100)
          ..pause(900)
          ..start(500)
          ..resume(50)
          ..lap(700);
        for (final now in [0, 100, 500, 1000, 5000]) {
          final t = Timeline.build(log.events, now);
          expect(t.activeMs, greaterThanOrEqualTo(0));
          expect(t.pausedMs, greaterThanOrEqualTo(0));
          expect(t.wallMs, greaterThanOrEqualTo(0));
        }
      });
    });
  });
}
