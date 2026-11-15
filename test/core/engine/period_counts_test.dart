import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';

import '../../support/events.dart';

/// Counting entries per logical day, for "Woche" and "Monat".
void main() {
  const six = 6 * 60;
  const tent = Track(
    id: 'tent',
    setId: 'set',
    name: 'Zelt',
    config: ProtocolConfig(),
  );
  int at(int d, int h, [int m = 0]) =>
      DateTime(2026, 11, d, h, m).millisecondsSinceEpoch;

  HistorySession session(EventLog log) => HistorySession(
    session: Session(
      id: log.sessionId,
      trackId: 'tent',
      config: tent.config,
      startedAt: log.events.first.at,
    ),
    events: log.events,
    summary: summarizeSession(
      config: tent.config,
      events: log.events,
      nowMs: at(30, 12),
    ),
    track: tent,
  );

  final log = EventLog(sessionId: 's', trackId: 'tent')
    ..start(at(3, 20))
    ..entry(at(3, 21), person: 'k', substance: 'beer')
    // After midnight: still the 3rd.
    ..entry(at(4, 1, 30), person: 'k', substance: 'beer')
    ..entry(at(6, 22), person: 'k', substance: 'mate')
    ..entry(at(6, 23), person: 'j', substance: 'beer')
    ..entry(at(7, 20), person: 'j', amount: 'ein Schluck')
    ..entry(at(12, 21), person: 'k', substance: 'beer');

  test('entries by the logical day they belong to', () {
    final byDay = entriesByLogicalDay([session(log)], six);
    expect(byDay.keys.toSet(), {
      const LocalDay(2026, 11, 3),
      const LocalDay(2026, 11, 6),
      const LocalDay(2026, 11, 7),
      const LocalDay(2026, 11, 12),
    });
    expect(byDay[const LocalDay(2026, 11, 3)], hasLength(2));
    // With the day starting at midnight the second one moves.
    expect(
      entriesByLogicalDay([session(log)], 0)[const LocalDay(2026, 11, 4)],
      hasLength(1),
    );
  });

  test('totals per thing, most first', () {
    final all = log.events.where((e) => e.type == EventType.entry);
    expect(thingTotals(all), [
      ('s:beer', 4),
      ('s:mate', 1),
      ('a:ein Schluck', 1),
    ]);
  });

  test('month figures: count, days with an entry, the longest pause', () {
    final byDay = entriesByLogicalDay([session(log)], six);
    final counts = {for (final e in byDay.entries) e.key: e.value.length};
    final f = monthFigures(
      counts,
      const LocalDay(2026, 11, 1),
      const LocalDay(2026, 11, 14),
    );
    expect(f.count, 6);
    expect(f.daysWithEntry, 4);
    // 8. to 11.
    expect(f.longestPauseDays, 4);
    final empty = monthFigures(
      const {},
      const LocalDay(2026, 2, 1),
      const LocalDay(2026, 2, 28),
    );
    expect(empty.count, 0);
    expect(empty.longestPauseDays, 28);
  });

  test('four steps by the most of the month', () {
    expect([for (var n = 0; n <= 5; n++) countLevel(n, 5)], [0, 1, 1, 2, 2, 3]);
    expect(countLevel(1, 1), 3);
    expect(countLevel(3, 0), 0);
  });

  test('ISO week numbers', () {
    expect(isoWeekNumber(const LocalDay(2026, 11, 9)), 46);
    expect(isoWeekNumber(const LocalDay(2025, 12, 29)), 1);
    expect(isoWeekNumber(const LocalDay(2026, 12, 28)), 53);
  });

  test('the evening, the week and the month count the same', () {
    final sessions = [session(log)];
    final byDay = entriesByLogicalDay(sessions, six);
    // The evening of the 6th, as the evening and the list read it.
    final from = logicalDayStartMs(const LocalDay(2026, 11, 6), six);
    final to = logicalDayEndMs(const LocalDay(2026, 11, 6), six);
    final evening = [
      for (final e in log.events)
        if (e.type == EventType.entry && e.at >= from && e.at < to) e,
    ];
    expect(byDay[const LocalDay(2026, 11, 6)], evening);
    // The week of the 2nd to the 8th and the whole month.
    var week = 0;
    for (var d = 2; d <= 8; d++) {
      week += byDay[LocalDay(2026, 11, d)]?.length ?? 0;
    }
    expect(week, 5);
    final counts = {for (final e in byDay.entries) e.key: e.value.length};
    expect(
      monthFigures(
        counts,
        const LocalDay(2026, 11, 1),
        const LocalDay(2026, 11, 30),
      ).count,
      6,
    );
  });
}
