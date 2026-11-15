import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/features/tracks/timeline/evening/evening_layout.dart';
import 'package:tikky_takka/l10n/strings.dart';

import '../../../../support/events.dart';

/// "Abend" (Pult 3.2): the time runs downwards, a column per person.
void main() {
  const metrics = EveningMetrics(
    axisWidth: 42,
    trackBar: 8,
    trackGap: 4,
    minTracksWidth: 46,
    chipHeight: 20,
    chipInset: 18,
    slotGap: 22,
    minPxPerHour: 60,
    minColumnWidth: 120,
  );
  const tent = Track(
    id: 'tent',
    setId: 'set',
    name: 'Zelt',
    config: ProtocolConfig(),
  );
  const watch = Track(
    id: 'watch',
    setId: 'set',
    name: 'Uhr',
    config: StopwatchConfig(),
  );
  const krille = Person(id: 'k', name: 'Krille', color: 0xFF00AAAA);
  const jacke = Person(id: 'j', name: 'Jacke', color: 0xFFAA00AA);
  const beer = Substance(
    id: 'beer',
    name: 'Bier',
    color: 0xFFAA8800,
    lockoutMs: hour,
  );
  const mate = Substance(id: 'mate', name: 'Mate', color: 0xFF00AA00);
  const persons = {'k': krille, 'j': jacke};
  const substances = {'beer': beer, 'mate': mate};

  // An evening from 06:00 to 06:00; entries from 20:50 on.
  final from = DateTime(2026, 11, 14, 6).millisecondsSinceEpoch;
  final to = DateTime(2026, 11, 15, 6).millisecondsSinceEpoch;
  int at(int h, int m) => DateTime(2026, 11, 14, h, m).millisecondsSinceEpoch;

  HistorySession session(Track track, EventLog log, {int? endedAt}) =>
      HistorySession(
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
          nowMs: to,
        ),
        track: track,
      );

  final protocol = EventLog(sessionId: 'p', trackId: 'tent')
    ..start(at(20, 0))
    ..entry(at(20, 50), person: 'k', substance: 'mate')
    ..entry(at(21, 10), person: 'j', substance: 'beer')
    ..entry(at(21, 20), person: 'k', substance: 'beer')
    // 2 minutes later: closer than 22 px at 60 px per hour.
    ..entry(at(21, 22), person: 'k', substance: 'mate')
    ..entry(at(22, 15), person: 'k', substance: 'beer')
    ..entry(at(22, 30), substance: 'mate')
    // Before the evening: belongs to the day before.
    ..entry(at(5, 0), person: 'k', substance: 'beer');

  EveningLayout layout({int? now, double height = 300}) => layoutEvening(
    sessions: [session(tent, protocol)],
    fromMs: from,
    toMs: to,
    nowMs: now ?? at(23, 41),
    width: 375,
    height: height,
    metrics: metrics,
    persons: persons,
    substances: substances,
  );

  test('the scale runs from the half hour before the first entry to the '
      'full hour after now', () {
    final l = layout();
    expect(l.firstAt, at(20, 50));
    expect(l.startMs, at(20, 30));
    expect(l.endMs, at(24, 0));
    // 3.5 hours in 300 px: more than 60 px per hour, so it fills.
    expect(l.height, 300);
    expect(l.yOf(at(20, 30)), 0);
    expect(l.yOf(at(24, 0)), 300);
    expect(l.hours.map((h) => h.ms), [
      at(21, 0),
      at(22, 0),
      at(23, 0),
      at(24, 0),
    ]);
    // Too little room for 60 px per hour: it grows and scrolls.
    expect(layout(height: 100).height, closeTo(3.5 * 60, 1e-9));
    // An evening that is over ends at the hour after its last entry.
    expect(layout(now: to + hour).endMs, at(23, 0));
  });

  test('a column per person in the order of their first entry, without a '
      'person at the end; counts most first', () {
    final l = layout();
    expect(l.columns.map((c) => c.name), [
      'Krille',
      'Jacke',
      Strings.protocolNoPerson,
    ]);
    final k = l.columns.first;
    expect(k.colorArgb, 0xFF00AAAA);
    // Bier 2, Mate 2: the same count in the order of the first entry.
    expect(k.counts, [('Mate', 2), ('Bier', 2)]);
    // The entry of 05:00 belongs to the day before.
    expect(k.chips, hasLength(4));
    // No other track: the columns start right after the hours.
    expect(l.tracksWidth, 0);
    expect(k.left, 42);
    // Three columns of 111 px would be narrower than 120: it scrolls.
    expect(k.width, 120);
    expect(l.width, 42 + 3 * 120);
    expect(l.columns[1].left, closeTo(42 + k.width, 1e-9));
  });

  test('two chips closer than 22 px take the two places of the column', () {
    final chips = layout().columns.first.chips;
    final left = chips.first.x;
    expect(left, 42 + 18);
    expect(chips[1].x, left);
    // 21:22 is 2 min after 21:20.
    expect(chips[2].x, greaterThan(left));
    expect(chips[3].x, left);
    expect(chips.map((c) => c.label), ['Mate', 'Bier', 'Mate', 'Bier']);
    expect(chips[1].colorArgb, 0xFFAA8800);
  });

  test('the chain of a thing and the lockout the user set on it', () {
    final k = layout().columns.first;
    final beers = eveningChain(k, 's:beer', substances: substances);
    expect(beers.entries.map((e) => e.at), [at(21, 20), at(22, 15)]);
    expect(beers.lockoutUntil, at(23, 15));
    final mates = eveningChain(k, 's:mate', substances: substances);
    expect(mates.entries, hasLength(2));
    expect(mates.lockoutUntil, isNull);
  });

  test('other tracks are bars in their own column, their laps marked', () {
    final w = EventLog(sessionId: 'w', trackId: 'watch')
      ..start(at(21, 0))
      ..lap(at(21, 30))
      ..pause(at(22, 0))
      ..resume(at(22, 30));
    final l = layoutEvening(
      sessions: [session(tent, protocol), session(watch, w)],
      fromMs: from,
      toMs: to,
      nowMs: at(23, 0),
      width: 375,
      height: 300,
      metrics: metrics,
      persons: persons,
      substances: substances,
    );
    expect(l.tracksWidth, 46);
    expect(l.columns.first.left, 42 + 46);
    final bar = l.trackBars.single;
    expect(bar.track.id, 'watch');
    expect(bar.spans, hasLength(2));
    expect(bar.spans.first.$1, closeTo(l.yOf(at(21, 0)), 1e-9));
    expect(bar.spans.first.$2, closeTo(l.yOf(at(22, 0)), 1e-9));
    expect(bar.spans.last.$2, closeTo(l.yOf(at(23, 0)), 1e-9));
    expect(bar.running, isTrue);
    expect(bar.marks.single, closeTo(l.yOf(at(21, 30)), 1e-9));
    // Hidden: gone.
    expect(
      layoutEvening(
        sessions: [session(watch, w)],
        fromMs: from,
        toMs: to,
        nowMs: at(23, 0),
        width: 375,
        height: 300,
        metrics: metrics,
        hiddenTrackIds: const {'watch'},
      ).isEmpty,
      isTrue,
    );
  });

  test('many persons: the columns keep their width and the evening gets '
      'wider than the screen', () {
    final log = EventLog(sessionId: 'many', trackId: 'tent')..start(at(20, 0));
    for (var i = 0; i < 5; i++) {
      log.entry(at(21, i), person: 'p$i', substance: 'mate');
    }
    final l = layoutEvening(
      sessions: [session(tent, log)],
      fromMs: from,
      toMs: to,
      nowMs: at(22, 0),
      width: 375,
      height: 300,
      metrics: metrics,
    );
    expect(l.columns, hasLength(5));
    expect(l.columns.first.width, 120);
    expect(l.width, 42 + 5 * 120);
    expect(l.columns.first.name, Strings.unknown);
  });

  test('nothing in the evening: empty', () {
    expect(
      layoutEvening(
        sessions: const [],
        fromMs: from,
        toMs: to,
        nowMs: at(22, 0),
        width: 375,
        height: 300,
        metrics: metrics,
      ).isEmpty,
      isTrue,
    );
  });
}
