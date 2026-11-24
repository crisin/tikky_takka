import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';

const _minute = 60 * 1000;

LastEntryFact _fact(String person, String thing, int at) =>
    LastEntryFact(personId: person, substanceId: thing, at: at);

Entry _entry(String person, String thing, DateTime at) => Entry(
  id: '$person-$thing-${at.millisecondsSinceEpoch}',
  at: at.millisecondsSinceEpoch,
  personId: person,
  substanceId: thing,
);

void main() {
  group('personStand', () {
    final facts = [
      _fact('k', 'bier', 100 * _minute),
      _fact('k', 'kippe', 90 * _minute),
      _fact('j', 'wasser', 50 * _minute),
    ];

    test('no entry: nothing to show', () {
      final stand = personStand('x', facts, 120 * _minute);
      expect(stand.hasEntry, isFalse);
      expect(stand.sinceMs, isNull);
    });

    test('without a lockout the latest entry decides', () {
      final stand = personStand('k', facts, 120 * _minute);
      expect(stand.substanceId, 'bier');
      expect(stand.sinceMs, 20 * _minute);
      expect(stand.lockout, isNull);
    });

    test('a running lockout of the user decides, even if older', () {
      final stand = personStand(
        'k',
        facts,
        120 * _minute,
        lockoutMsBySubstance: const {'kippe': 60 * _minute},
      );
      expect(stand.substanceId, 'kippe');
      expect(stand.sinceMs, 30 * _minute);
      expect(stand.lockout!.remainingMs, 30 * _minute);
    });

    test('a lockout that ran out no longer decides', () {
      final stand = personStand(
        'k',
        facts,
        200 * _minute,
        lockoutMsBySubstance: const {'kippe': 60 * _minute},
      );
      expect(stand.substanceId, 'bier');
      expect(stand.lockout, isNull);
    });

    test('filtered to one thing', () {
      final stand = personStand(
        'k',
        facts,
        120 * _minute,
        onlySubstanceId: 'kippe',
      );
      expect(stand.substanceId, 'kippe');
      final none = personStand(
        'j',
        facts,
        120 * _minute,
        onlySubstanceId: 'bier',
      );
      expect(none.hasEntry, isFalse);
    });

    test('an entry in the future never shows a negative time', () {
      expect(personStand('k', facts, 95 * _minute).sinceMs, 0);
    });
  });

  test('counts of the day start anew at the start of the logical day', () {
    final entries = [
      _entry('k', 'bier', DateTime(2026, 11, 14, 22)),
      _entry('k', 'bier', DateTime(2026, 11, 15, 1)),
      _entry('k', 'wasser', DateTime(2026, 11, 15, 2)),
      _entry('j', 'bier', DateTime(2026, 11, 15, 5, 59)),
      _entry('k', 'bier', DateTime(2026, 11, 15, 6)),
    ];
    final night = entryCountsOfDay(
      entries,
      DateTime(2026, 11, 15, 3).millisecondsSinceEpoch,
      6 * 60,
    );
    expect(night['k'], {'bier': 2, 'wasser': 1});
    expect(night['j'], {'bier': 1});
    final morning = entryCountsOfDay(
      entries,
      DateTime(2026, 11, 15, 7).millisecondsSinceEpoch,
      6 * 60,
    );
    expect(morning, {
      'k': {'bier': 1},
    });
  });
}
