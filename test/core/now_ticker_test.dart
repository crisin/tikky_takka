import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/clock.dart';
import 'package:tikky_takka/core/now_ticker.dart';

void main() {
  test('FakeClock', () {
    final clock = FakeClock(1000);
    expect(clock.nowMs(), 1000);
    clock.advance(const Duration(seconds: 2));
    expect(clock.nowMs(), 3000);
    clock.advanceMs(-500);
    expect(clock.nowMs(), 2500);
    clock.setMs(42);
    expect(
      clock.nowUtc(),
      DateTime.fromMillisecondsSinceEpoch(42, isUtc: true),
    );
    expect(clock.nowUtc().isUtc, isTrue);
    expect(clock.nowLocal().isUtc, isFalse);
    expect(FakeClock.at(DateTime.utc(1970, 1, 1, 0, 0, 1)).nowMs(), 1000);
    expect(const SystemClock().nowMs(), greaterThan(1700000000000));
  });

  // testWidgets runs in a fake-async zone: `tester.pump(d)` advances timers,
  // and a timer that is still pending at the end fails the test - which is
  // exactly the guarantee wanted here.
  testWidgets('ticks only while listened to, from the injected clock', (
    tester,
  ) async {
    final clock = FakeClock(1000);
    final ticker = NowTicker(clock);
    final seen = <int>[];
    void listener() => seen.add(ticker.value);

    // No listener: nothing runs, but the value is always fresh.
    clock.advanceMs(500);
    await tester.pump(const Duration(seconds: 1));
    expect(ticker.value, 1500);

    ticker.addListener(listener);
    clock.advanceMs(100);
    await tester.pump(const Duration(milliseconds: 100));
    clock.advanceMs(100);
    await tester.pump(const Duration(milliseconds: 100));
    expect(seen, [1600, 1700]);

    // The clock did not move: nothing to announce.
    await tester.pump(const Duration(milliseconds: 300));
    expect(seen, [1600, 1700]);

    // Removing the last listener cancels the timer (else the test fails
    // with a pending timer).
    ticker.removeListener(listener);
    clock.advanceMs(1000);
    await tester.pump(const Duration(seconds: 1));
    expect(seen, [1600, 1700]);
    ticker.dispose();
  });

  testWidgets('suspend stops the timer, resume emits at once', (tester) async {
    final clock = FakeClock(0);
    final ticker = NowTicker(clock);
    final seen = <int>[];
    ticker.addListener(() => seen.add(ticker.value));

    ticker.suspended = true;
    expect(ticker.suspended, isTrue);
    clock.advanceMs(60000);
    await tester.pump(const Duration(minutes: 1));
    expect(seen, isEmpty);

    ticker.suspended = false;
    expect(seen, [60000]);

    clock.advanceMs(5);
    ticker.tickNow();
    expect(seen, [60000, 60005]);

    clock.advanceMs(100);
    await tester.pump(const Duration(milliseconds: 100));
    expect(seen, [60000, 60005, 60105]);

    // Dispose with a listener still attached must cancel the timer too.
    ticker.dispose();
  });

  testWidgets('NowBuilder rebuilds only its subtree on a tick', (tester) async {
    final clock = FakeClock(1000);
    var outerBuilds = 0;
    var innerBuilds = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clockProvider.overrideWithValue(clock)],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              outerBuilds++;
              return NowBuilder(
                builder: (context, now, child) {
                  innerBuilds++;
                  return Text('$now');
                },
              );
            },
          ),
        ),
      ),
    );
    expect(find.text('1000'), findsOneWidget);

    clock.advanceMs(250);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1250'), findsOneWidget);
    expect(outerBuilds, 1);
    expect(innerBuilds, 2);
  });

  testWidgets('a disabled NowBuilder does not subscribe', (tester) async {
    final clock = FakeClock(1000);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clockProvider.overrideWithValue(clock)],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: NowBuilder(
            enabled: false,
            builder: (context, now, child) => Text('$now'),
          ),
        ),
      ),
    );
    clock.advanceMs(250);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1000'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
