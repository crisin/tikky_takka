import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/protocol/protocol_logic.dart';

SubstanceUse _use(String? person, String? substance, int count, int lastAt) =>
    SubstanceUse(
      personId: person,
      substanceId: substance,
      count: count,
      lastAt: lastAt,
    );

void main() {
  group('topSubstanceIds', () {
    const all = {'a', 'b', 'c', 'd', 'e', 'f', 'g'};

    test('scene substances first, in scene order', () {
      expect(
        topSubstanceIds(
          sceneSubstanceIds: const ['c', 'a'],
          use: [_use('p', 'b', 9, 10), _use('p', 'a', 99, 10)],
          personId: 'p',
          available: all,
        ),
        ['c', 'a', 'b'],
      );
    });

    test('then the most used of this person, most recent on a tie', () {
      expect(
        topSubstanceIds(
          sceneSubstanceIds: const [],
          use: [
            _use('p', 'a', 2, 100),
            _use('p', 'b', 5, 50),
            _use('p', 'c', 2, 300),
            _use('p', 'd', 2, 200),
            // Somebody else's habits do not count.
            _use('q', 'e', 50, 999),
            // Entries without a substance are no button.
            _use('p', null, 70, 999),
          ],
          personId: 'p',
          available: all,
        ),
        ['b', 'c', 'd', 'a'],
      );
    });

    test('never more than five; the scene alone can fill them', () {
      expect(
        topSubstanceIds(
          sceneSubstanceIds: const ['a', 'b', 'c'],
          use: [
            _use('p', 'd', 1, 1),
            _use('p', 'e', 3, 1),
            _use('p', 'f', 2, 1),
          ],
          personId: 'p',
          available: all,
        ),
        ['a', 'b', 'c', 'e', 'f'],
      );
      expect(
        topSubstanceIds(
          sceneSubstanceIds: const ['a', 'b', 'c', 'd', 'e', 'f'],
          use: [_use('p', 'g', 100, 1)],
          personId: 'p',
          available: all,
        ),
        ['a', 'b', 'c', 'd', 'e'],
      );
      expect(
        topSubstanceIds(
          sceneSubstanceIds: const ['a', 'b'],
          use: const [],
          personId: 'p',
          available: all,
          limit: 1,
        ),
        ['a'],
      );
    });

    test('removed substances and duplicates are left out', () {
      expect(
        topSubstanceIds(
          sceneSubstanceIds: const ['gone', 'a', 'a'],
          use: [_use('p', 'gone2', 9, 1), _use('p', 'a', 9, 1)],
          personId: 'p',
          available: all,
        ),
        ['a'],
      );
    });

    test('entries without a person have their own ranking', () {
      expect(
        topSubstanceIds(
          sceneSubstanceIds: const [],
          use: [_use(null, 'a', 1, 1), _use('p', 'b', 5, 1)],
          personId: null,
          available: all,
        ),
        ['a'],
      );
    });

    test('nothing chosen and nothing logged: no buttons', () {
      expect(
        topSubstanceIds(
          sceneSubstanceIds: const [],
          use: const [],
          personId: 'p',
          available: all,
        ),
        isEmpty,
      );
    });
  });

  group('keepButtonOrder', () {
    test('shown buttons stay in place; new ones fill up', () {
      expect(
        keepButtonOrder(
          const ['a', 'b'],
          const ['b', 'c', 'a', 'd'],
          available: const {'a', 'b', 'c', 'd'},
        ),
        ['a', 'b', 'c', 'd'],
      );
    });

    test('a removed substance frees its place; the limit holds', () {
      expect(
        keepButtonOrder(
          const ['a', 'gone', 'b'],
          const ['c', 'd', 'e', 'f'],
          available: const {'a', 'b', 'c', 'd', 'e', 'f'},
        ),
        ['a', 'b', 'c', 'd', 'e'],
      );
    });
  });

  test('sessionCounts counts one person in the open session', () {
    TrackEvent entry(int seq, String? person, String? substance) => TrackEvent(
      id: 'e$seq',
      sessionId: 's',
      trackId: 't',
      type: EventType.entry,
      at: seq,
      seq: seq,
      personId: person,
      substanceId: substance,
    );
    const session = Session(
      id: 's',
      trackId: 't',
      config: ProtocolConfig(),
      startedAt: 0,
    );
    final open = OpenSession(
      session: session,
      events: [
        const TrackEvent(
          id: 'start',
          sessionId: 's',
          trackId: 't',
          type: EventType.start,
          at: 0,
          seq: 0,
        ),
        entry(1, 'p', 'a'),
        entry(2, 'p', 'a'),
        entry(3, 'q', 'a'),
        entry(4, 'p', 'b'),
        entry(5, 'p', null),
        entry(6, null, 'a'),
      ],
    );
    expect(sessionCounts(open, 'p'), {'a': 2, 'b': 1});
    expect(sessionCounts(open, null), {'a': 1});
    expect(sessionCounts(null, 'p'), isEmpty);
  });
}
