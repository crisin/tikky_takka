import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/clock.dart';
import 'package:tikky_takka/core/db/app_database.dart';
import 'package:tikky_takka/core/now_ticker.dart';
import 'package:tikky_takka/core/repo/watch.dart';

import '../support/test_env.dart';

/// Wall-clock jumps (NowTicker) and the pausable table watcher.
void main() {
  group('FakeClock', () {
    test('advance moves wall and monotonic time, setMs only the wall', () {
      final clock = FakeClock(1000);
      final mono = clock.monotonicMs();
      clock.advanceMs(500);
      expect(clock.nowMs(), 1500);
      expect(clock.monotonicMs(), mono + 500);
      clock.setMs(99000);
      expect(clock.nowMs(), 99000);
      expect(clock.monotonicMs(), mono + 500);
    });

    test('the system clock has a monotonic source that moves forward', () {
      const clock = SystemClock();
      final a = clock.monotonicMs();
      final b = clock.monotonicMs();
      expect(b, greaterThanOrEqualTo(a));
    });
  });

  group('NowTicker clock jumps', () {
    late FakeClock clock;
    late NowTicker ticker;
    late List<int> jumps;
    late StreamSubscription<int> sub;

    setUp(() {
      clock = FakeClock(1700000000000);
      ticker = NowTicker(clock);
      jumps = [];
      sub = ticker.clockJumps.listen(jumps.add);
    });

    tearDown(() async {
      await sub.cancel();
      ticker.dispose();
    });

    Future<void> tick() async {
      ticker.tickNow();
      await Future<void>.delayed(Duration.zero);
    }

    test('time that simply passes is never a jump, however long', () async {
      clock.advanceMs(100);
      await tick();
      clock.advance(const Duration(hours: 5));
      await tick();
      expect(jumps, isEmpty);
    });

    test('a forward and a backward change of the system time are reported '
        'with their size', () async {
      clock.advanceMs(100);
      await tick();

      clock.setMs(clock.nowMs() + 3600000);
      await tick();
      expect(jumps, [3600000]);

      clock.advanceMs(100);
      await tick();
      expect(jumps, hasLength(1), reason: 'reported once, not on every tick');

      clock.setMs(clock.nowMs() - 600000);
      await tick();
      expect(jumps, [3600000, -600000]);
    });

    test('small corrections below the threshold are ignored', () async {
      clock.setMs(clock.nowMs() + NowTicker.clockJumpThresholdMs - 1);
      await tick();
      clock.setMs(clock.nowMs() - (NowTicker.clockJumpThresholdMs - 1));
      await tick();
      expect(jumps, isEmpty);

      clock.setMs(clock.nowMs() + NowTicker.clockJumpThresholdMs);
      await tick();
      expect(jumps, [NowTicker.clockJumpThresholdMs]);
    });

    test('nothing is compared across a trip to the background', () async {
      ticker.suspended = true;
      // The wall clock moved on while the monotonic clock stood still
      // (device asleep) - or the user really changed the time meanwhile.
      clock.setMs(clock.nowMs() + 7200000);
      await tick();
      ticker.suspended = false;
      await Future<void>.delayed(Duration.zero);
      expect(jumps, isEmpty);

      // Back in the foreground the detection works again.
      clock.advanceMs(100);
      await tick();
      clock.setMs(clock.nowMs() + 5000);
      await tick();
      expect(jumps, [5000]);
    });

    test('the value keeps following the wall clock (history is not '
        'rewritten, nothing is compensated)', () async {
      void listener() {}
      ticker.addListener(listener);
      clock.setMs(42);
      await tick();
      expect(ticker.value, 42);
      ticker.removeListener(listener);
    });
  });

  group('watchTables', () {
    test('a paused subscription loads nothing and catches up with ONE '
        'reload on resume', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final e = TestEnv();
      addTearDown(e.dispose);
      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 20));

      var loads = 0;
      final seen = <int>[];
      final AppDatabase db = e.db;
      final sub = watchTables(db, [db.trackSets], () async {
        loads++;
        return (await db.select(db.trackSets).get()).length;
      }).listen(seen.add);
      await settle();
      expect(loads, 1);
      expect(seen, [0]);

      await e.makeSet('a');
      await settle();
      expect(loads, 2);
      expect(seen, [0, 1]);

      sub.pause();
      await e.makeSet('b');
      await e.makeSet('c');
      await e.makeSet('d');
      await settle();
      expect(loads, 2, reason: 'no query while paused');

      sub.resume();
      await settle();
      expect(loads, 3, reason: 'one reload for all missed changes');
      expect(seen.last, 4);

      // Paused without changes: resuming does not reload.
      sub.pause();
      await settle();
      sub.resume();
      await settle();
      expect(loads, 3);

      await sub.cancel();
      await e.makeSet('e');
      await settle();
      expect(loads, 3);
    });
  });
}
