import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/features/tracks/timeline/strip/strip_axis.dart';
import 'package:tikky_takka/features/tracks/timeline/strip/strip_viewport.dart';
import 'package:tikky_takka/l10n/formatters.dart';

import '../../../../support/events.dart';

/// A local instant (the tests must not depend on the machine's zone).
int _at(int day, int hour, [int minute = 0, int second = 0]) =>
    DateTime(2026, 11, day, hour, minute, second).millisecondsSinceEpoch;

void main() {
  group('pickAxisStep', () {
    test('seconds, minutes, hours and days as the zoom goes out', () {
      // 100 px between two ticks at least.
      expect(pickAxisStep(10, 100), sec);
      expect(pickAxisStep(11, 100), 2 * sec);
      expect(pickAxisStep(40, 100), 5 * sec);
      expect(pickAxisStep(250, 100), 30 * sec);
      expect(pickAxisStep(600, 100), min);
      expect(pickAxisStep(2.0 * sec, 100), 5 * min);
      expect(pickAxisStep(15.0 * sec, 100), 30 * min);
      expect(pickAxisStep(36.0 * sec, 100), hour);
      expect(pickAxisStep(3.0 * min, 100), 6 * hour);
      expect(pickAxisStep(10.0 * min, 100), stripDayMs);
      expect(pickAxisStep(60.0 * min, 100), 7 * stripDayMs);
      // Beyond the table: whole blocks of four weeks.
      expect(pickAxisStep(40.0 * hour, 100), 6 * 28 * stripDayMs);
    });

    test('the step never puts two ticks closer than asked', () {
      for (final msPerPx in <double>[1, 7.5, 33, 480, 9000, 123456, 5e6, 9e8]) {
        for (final spacing in <double>[60, 84, 140]) {
          final step = pickAxisStep(msPerPx, spacing);
          expect(
            step / msPerPx,
            greaterThanOrEqualTo(spacing),
            reason: '$msPerPx ms/px, $spacing px',
          );
        }
      }
    });
  });

  group('computeAxis', () {
    test('minutes on round local times, labelled without seconds', () {
      final axis = computeAxis(
        startMs: _at(14, 14, 2, 30).toDouble(),
        msPerPx: 2 * sec.toDouble(),
        width: 900,
        minSpacingPx: 100,
      );
      expect(axis.stepMs, 5 * min);
      expect(axis.ticks.map((t) => t.label), [
        '14:05',
        '14:10',
        '14:15',
        '14:20',
        '14:25',
        '14:30',
      ]);
      expect(axis.ticks.first.ms, _at(14, 14, 5));
      // (14:05 - 14:02:30) / 2 s per px.
      expect(axis.ticks.first.x, closeTo(75, 1e-9));
      expect(axis.ticks[1].x - axis.ticks[0].x, closeTo(150, 1e-9));
      expect(axis.days, isEmpty);
    });

    test('seconds when zoomed in; the 12-hour clock is honoured', () {
      final axis = computeAxis(
        startMs: _at(14, 21, 4, 57).toDouble(),
        msPerPx: 10,
        width: 1000,
        minSpacingPx: 90,
        use24h: false,
      );
      expect(axis.stepMs, sec);
      expect(axis.ticks, hasLength(11));
      expect(axis.ticks.first.label, '9:04:57 PM');
      expect(axis.ticks.last.label, '9:05:07 PM');

      final hours = computeAxis(
        startMs: _at(14, 8).toDouble(),
        msPerPx: 36 * sec.toDouble(),
        width: 400,
        minSpacingPx: 100,
        use24h: false,
      );
      expect(hours.ticks.map((t) => t.label), [
        '8:00 AM',
        '9:00 AM',
        '10:00 AM',
        '11:00 AM',
        '12:00 PM',
      ]);
    });

    test('across midnight: a day separator with the date', () {
      final axis = computeAxis(
        startMs: _at(14, 22, 30).toDouble(),
        msPerPx: 18 * sec.toDouble(),
        width: 800,
        minSpacingPx: 100,
      );
      expect(axis.stepMs, 30 * min);
      expect(axis.ticks.map((t) => t.label), [
        '22:30',
        '23:00',
        '23:30',
        'So. 15.11.',
        '00:30',
        '01:00',
        '01:30',
        '02:00',
        '02:30',
      ]);
      final day = axis.days.single;
      expect(day.ms, _at(15, 0));
      expect(day.label, stripDayLabel(_at(15, 0)));
      expect(day.x, closeTo(90 * min / (18 * sec), 1e-9));
    });

    test('no separator while the range stays inside one day', () {
      final axis = computeAxis(
        startMs: _at(14, 9).toDouble(),
        msPerPx: 36 * sec.toDouble(),
        width: 1000,
        minSpacingPx: 100,
      );
      expect(axis.days, isEmpty);
      expect(axis.ticks.first.label, '09:00');
    });

    test('whole days: every tick is a local midnight', () {
      final axis = computeAxis(
        startMs: _at(10, 6).toDouble(),
        msPerPx: 10 * min.toDouble(),
        width: 1000,
        minSpacingPx: 100,
      );
      expect(axis.stepMs, stripDayMs);
      expect(axis.ticks.map((t) => t.ms), [
        for (var day = 11; day <= 17; day++) _at(day, 0),
      ]);
      expect(axis.ticks.every((t) => t.isDay), isTrue);
      expect(axis.ticks.first.label, 'Mi. 11.11.');
    });

    test('several days per tick stay put while panning', () {
      List<int> ticks(int startHour) => [
        for (final t in computeAxis(
          startMs: _at(2, startHour).toDouble(),
          msPerPx: 30 * min.toDouble(),
          width: 1200,
          minSpacingPx: 100,
        ).ticks)
          t.ms,
      ];
      final a = ticks(1);
      final b = ticks(20);
      expect(a.length, greaterThan(2));
      // The same midnights, wherever the view starts.
      expect(b.toSet().intersection(a.toSet()), isNotEmpty);
      expect(a[1] - a[0], closeTo(7 * stripDayMs, hour));
      for (final ms in b) {
        if (ms >= a.first && ms <= a.last) expect(a, contains(ms));
      }
    });

    test('only ticks inside the width; nothing for an empty viewport', () {
      final axis = computeAxis(
        startMs: _at(14, 14, 0, 1).toDouble(),
        msPerPx: sec.toDouble(),
        width: 300,
        minSpacingPx: 60,
      );
      for (final tick in axis.ticks) {
        expect(tick.x, inInclusiveRange(0, 300));
      }
      expect(
        computeAxis(
          startMs: 0,
          msPerPx: 1000,
          width: 0,
          minSpacingPx: 60,
        ).ticks,
        isEmpty,
      );
    });

    test('labels are the formatter\'s, so they say what the instant is', () {
      final axis = computeAxis(
        startMs: _at(14, 13, 59).toDouble(),
        msPerPx: 600,
        width: 600,
        minSpacingPx: 100,
      );
      for (final tick in axis.ticks) {
        expect(tick.label, Fmt.time(tick.ms));
      }
    });
  });

  group('time and pixels', () {
    test('xOf and timeAt are inverse', () {
      final v = StripViewport()
        ..setExtent(0, hour, live: false)
        ..setWidth(1000)
        ..fit();
      for (final ms in [0, 1234, 30 * min, hour]) {
        expect(v.timeAt(v.xOf(ms)), closeTo(ms, 1e-6));
      }
      expect(v.xOf(v.startMs), 0);
      expect(v.xOf(v.endMs), closeTo(1000, 1e-9));
      expect(v.spanMs, closeTo(v.endMs - v.startMs, 1e-9));
    });
  });
}
