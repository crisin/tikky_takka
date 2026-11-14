import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/models.dart';
import 'package:tikky_takka/features/history/history_filter_logic.dart';
import 'package:tikky_takka/features/history/history_sums_view.dart';
import 'package:tikky_takka/l10n/strings.dart';

int _at(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    DateTime(year, month, day, hour, minute).millisecondsSinceEpoch;

void main() {
  // Wednesday, 11.11.2026, 14:30 local time.
  final now = _at(2026, 11, 11, 14, 30);

  group('date presets', () {
    test('all and custom are unbounded', () {
      expect(
        HistoryFilterLogic.spanOf(DatePreset.all, now),
        DateSpan.unbounded,
      );
      expect(
        HistoryFilterLogic.spanOf(DatePreset.custom, now),
        DateSpan.unbounded,
      );
    });

    test('today and yesterday are whole local days', () {
      expect(
        HistoryFilterLogic.spanOf(DatePreset.today, now),
        DateSpan(_at(2026, 11, 11), _at(2026, 11, 12)),
      );
      expect(
        HistoryFilterLogic.spanOf(DatePreset.yesterday, now),
        DateSpan(_at(2026, 11, 10), _at(2026, 11, 11)),
      );
    });

    test('this week runs from Monday to the next Monday', () {
      expect(
        HistoryFilterLogic.spanOf(DatePreset.thisWeek, now),
        DateSpan(_at(2026, 11, 9), _at(2026, 11, 16)),
      );
      // On a Sunday the week is the one ending that day.
      expect(
        HistoryFilterLogic.spanOf(DatePreset.thisWeek, _at(2026, 11, 15, 23)),
        DateSpan(_at(2026, 11, 9), _at(2026, 11, 16)),
      );
    });

    test('last 7 days include today', () {
      expect(
        HistoryFilterLogic.spanOf(DatePreset.last7Days, now),
        DateSpan(_at(2026, 11, 5), _at(2026, 11, 12)),
      );
    });

    test('months, also across the turn of the year', () {
      expect(
        HistoryFilterLogic.spanOf(DatePreset.thisMonth, now),
        DateSpan(_at(2026, 11, 1), _at(2026, 12, 1)),
      );
      expect(
        HistoryFilterLogic.spanOf(DatePreset.lastMonth, now),
        DateSpan(_at(2026, 10, 1), _at(2026, 11, 1)),
      );
      final january = _at(2027, 1, 3, 8);
      expect(
        HistoryFilterLogic.spanOf(DatePreset.lastMonth, january),
        DateSpan(_at(2026, 12, 1), _at(2027, 1, 1)),
      );
      expect(
        HistoryFilterLogic.spanOf(DatePreset.thisMonth, _at(2026, 12, 31, 23)),
        DateSpan(_at(2026, 12, 1), _at(2027, 1, 1)),
      );
    });

    test('a day with a daylight saving change is still one local day', () {
      // 25.10.2026 has 25 hours in Central Europe; whatever the zone of
      // the test machine, the span must end at the next local midnight.
      final span = HistoryFilterLogic.spanOf(
        DatePreset.today,
        _at(2026, 10, 25, 12),
      );
      expect(span.fromMs, _at(2026, 10, 25));
      expect(span.toMs, _at(2026, 10, 26));
    });

    test('spanOfDays is inclusive and order independent', () {
      final expected = DateSpan(_at(2026, 11, 1), _at(2026, 11, 12));
      expect(
        HistoryFilterLogic.spanOfDays(
          DateTime(2026, 11, 1),
          DateTime(2026, 11, 11),
        ),
        expected,
      );
      expect(
        HistoryFilterLogic.spanOfDays(
          DateTime(2026, 11, 11, 17),
          DateTime(2026, 11, 1, 3),
        ),
        expected,
      );
      // A single day.
      expect(
        HistoryFilterLogic.spanOfDays(
          DateTime(2026, 11, 11),
          DateTime(2026, 11, 11),
        ),
        DateSpan(_at(2026, 11, 11), _at(2026, 11, 12)),
      );
    });

    test('presetOf recognises every preset and falls back to custom', () {
      for (final preset in DatePreset.choices) {
        if (preset == DatePreset.custom) continue;
        final span = HistoryFilterLogic.spanOf(preset, now);
        expect(
          HistoryFilterLogic.presetOf(
            HistoryFilter(fromMs: span.fromMs, toMs: span.toMs),
            now,
          ),
          preset,
        );
      }
      expect(
        HistoryFilterLogic.presetOf(
          HistoryFilter(fromMs: _at(2026, 11, 2), toMs: _at(2026, 11, 4)),
          now,
        ),
        DatePreset.custom,
      );
    });
  });

  group('descriptions', () {
    const office = TrackSet(id: 's1', name: 'Büro');
    const kitchen = TrackSet(id: 's2', name: 'Küche');
    const work = Track(
      id: 't1',
      setId: 's1',
      name: 'Arbeit',
      config: StopwatchConfig(),
    );
    const tea = Track(
      id: 't2',
      setId: 's2',
      name: 'Tee',
      config: CountdownConfig(durationMs: 1000),
    );

    test('dates: preset names and custom ranges', () {
      expect(
        HistoryFilterLogic.describeDates(HistoryFilter.all, now),
        Strings.allTime,
      );
      final today = HistoryFilterLogic.spanOf(DatePreset.today, now);
      expect(
        HistoryFilterLogic.describeDates(
          HistoryFilter(fromMs: today.fromMs, toMs: today.toMs),
          now,
        ),
        Strings.today,
      );
      expect(
        HistoryFilterLogic.describeDates(
          HistoryFilter(fromMs: _at(2026, 11, 2), toMs: _at(2026, 11, 5)),
          now,
        ),
        '02.11.2026 – 04.11.2026',
      );
      // A custom single day shows once.
      expect(
        HistoryFilterLogic.describeDates(
          HistoryFilter(fromMs: _at(2026, 11, 2), toMs: _at(2026, 11, 3)),
          now,
        ),
        '02.11.2026',
      );
      expect(
        HistoryFilterLogic.describeDates(
          HistoryFilter(fromMs: _at(2026, 11, 2)),
          now,
        ),
        'ab 02.11.2026',
      );
      expect(
        HistoryFilterLogic.describeDates(
          HistoryFilter(toMs: _at(2026, 11, 3)),
          now,
        ),
        'bis 02.11.2026',
      );
    });

    test('set and tracks', () {
      expect(
        HistoryFilterLogic.describeSet(HistoryFilter.all, [office]),
        Strings.allSets,
      );
      expect(
        HistoryFilterLogic.describeSet(const HistoryFilter(setId: 's2'), [
          office,
          kitchen,
        ]),
        'Küche',
      );
      expect(
        HistoryFilterLogic.describeSet(const HistoryFilter(setId: 'gone'), [
          office,
        ]),
        Strings.unknown,
      );
      expect(
        HistoryFilterLogic.describeTracks(HistoryFilter.all, [work, tea]),
        Strings.allTracks,
      );
      expect(
        HistoryFilterLogic.describeTracks(
          const HistoryFilter(trackIds: {'t2'}),
          [work, tea],
        ),
        'Tee',
      );
      expect(
        HistoryFilterLogic.describeTracks(
          const HistoryFilter(trackIds: {'t1', 't2'}),
          [work, tea],
        ),
        '2 Spuren',
      );
    });

    test('describe joins the active parts and is null without a filter', () {
      expect(
        HistoryFilterLogic.describe(
          HistoryFilter.all,
          nowMs: now,
          sets: [office],
          tracks: [work],
        ),
        isNull,
      );
      final today = HistoryFilterLogic.spanOf(DatePreset.today, now);
      expect(
        HistoryFilterLogic.describe(
          HistoryFilter(
            fromMs: today.fromMs,
            toMs: today.toMs,
            setId: 's1',
            trackIds: const {'t1'},
          ),
          nowMs: now,
          sets: [office, kitchen],
          tracks: [work, tea],
        ),
        'Heute · Büro · Arbeit',
      );
      expect(
        HistoryFilterLogic.describe(
          const HistoryFilter(setId: 's2'),
          nowMs: now,
          sets: [office, kitchen],
          tracks: [work, tea],
        ),
        'Küche',
      );
    });

    test('choosing a set drops selected tracks of other sets', () {
      const filter = HistoryFilter(trackIds: {'t1', 't2'});
      final inKitchen = HistoryFilterLogic.withSet(filter, 's2', [work, tea]);
      expect(inKitchen.setId, 's2');
      expect(inKitchen.trackIds, {'t2'});
      final allSets = HistoryFilterLogic.withSet(inKitchen, null, [work, tea]);
      expect(allSets.setId, isNull);
      expect(allSets.trackIds, {'t2'});
    });
  });

  group('weeks', () {
    test('ISO week numbers', () {
      expect(HistoryFilterLogic.isoWeekNumber(const LocalDay(2026, 11, 9)), 46);
      // 29.12.2025 starts week 1 of 2026 (its Thursday is 1 January).
      expect(HistoryFilterLogic.isoWeekNumber(const LocalDay(2025, 12, 29)), 1);
      // 28.12.2026 starts week 53 of 2026.
      expect(
        HistoryFilterLogic.isoWeekNumber(const LocalDay(2026, 12, 28)),
        53,
      );
      expect(HistoryFilterLogic.isoWeekNumber(const LocalDay(2027, 1, 4)), 1);
    });

    test('a week ends on its Sunday', () {
      expect(
        HistoryFilterLogic.weekEnd(const LocalDay(2026, 11, 9)),
        const LocalDay(2026, 11, 15),
      );
      expect(
        HistoryFilterLogic.weekEnd(const LocalDay(2026, 12, 28)),
        const LocalDay(2027, 1, 3),
      );
    });
  });

  group('groupSumsByPeriod', () {
    test('groups by period, newest first, with totals', () {
      const monday = LocalDay(2026, 11, 9);
      const earlier = LocalDay(2026, 11, 2);
      final groups = groupSumsByPeriod(const [
        TrackPeriodSum(
          period: earlier,
          trackId: 'a',
          netMs: 1000,
          sessionCount: 1,
        ),
        TrackPeriodSum(
          period: monday,
          trackId: 'a',
          netMs: 2000,
          sessionCount: 2,
        ),
        TrackPeriodSum(
          period: monday,
          trackId: 'b',
          netMs: 500,
          sessionCount: 1,
        ),
      ]);
      expect(groups.map((g) => g.period), [monday, earlier]);
      expect(groups.first.totalNetMs, 2500);
      expect(groups.first.sums.map((s) => s.trackId), ['a', 'b']);
      expect(groups.last.totalNetMs, 1000);
    });
  });
}
