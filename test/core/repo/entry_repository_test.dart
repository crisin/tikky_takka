import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/engine/engine.dart';

import '../../support/test_env.dart';

const _minute = 60 * 1000;
const _hour = 60 * _minute;

void main() {
  final env = useTestEnv();

  test('add, edit, delete and restore keep the same entry', () async {
    final e = env();
    final added = await e.entries.add(
      personId: 'p1',
      substanceId: 's1',
      amount: '  0,5 l ',
      note: ' ',
    );
    expect(added.at, e.clock.nowMs());
    expect(added.amount, '0,5 l');
    expect(added.note, isNull);

    e.clock.advanceMs(_minute);
    final moved = added.copyWith(at: added.at - 10 * _minute, personId: 'p2');
    expect(await e.entries.update(moved), isTrue);
    final stored = await e.entries.get(added.id);
    expect(stored!.personId, 'p2');
    expect(stored.at, added.at - 10 * _minute);

    final deleted = await e.entries.delete(added.id);
    expect(deleted, stored);
    expect(await e.entries.get(added.id), isNull);
    expect(await e.entries.delete(added.id), isNull);

    await e.entries.restore(deleted!);
    expect(await e.entries.get(added.id), stored);
  });

  test('range is half open and oldest first', () async {
    final e = env();
    await e.entries.add(personId: 'p1', substanceId: 's1', at: 300);
    await e.entries.add(personId: 'p1', substanceId: 's2', at: 100);
    await e.entries.add(personId: 'p2', substanceId: 's1', at: 200);
    final range = await e.entries.getRange(100, 300);
    expect([for (final x in range) x.at], [100, 200]);
    expect((await e.entries.getAll()).length, 3);
  });

  test('last entries and use are grouped by person and thing', () async {
    final e = env();
    await e.entries.add(personId: 'p1', substanceId: 'bier', at: 100);
    await e.entries.add(personId: 'p1', substanceId: 'bier', at: 400);
    await e.entries.add(personId: 'p1', substanceId: 'wasser', at: 200);
    await e.entries.add(personId: 'p2', substanceId: 'bier', at: 300);

    final facts = await e.entries.getLastEntries();
    expect(
      facts,
      containsAll(const [
        LastEntryFact(personId: 'p1', substanceId: 'bier', at: 400),
        LastEntryFact(personId: 'p1', substanceId: 'wasser', at: 200),
        LastEntryFact(personId: 'p2', substanceId: 'bier', at: 300),
      ]),
    );
    final use = await e.entries.getUse();
    final p1Bier = use.firstWhere(
      (u) => u.personId == 'p1' && u.substanceId == 'bier',
    );
    expect(p1Bier.count, 2);
    expect(p1Bier.lastAt, 400);

    expect((await e.entries.lastOfPerson('p1'))!.at, 400);
    expect((await e.entries.previousOf('p1', 'bier', 400))!.at, 100);
    expect(await e.entries.previousOf('p2', 'bier', 300), isNull);
  });

  test('amounts are the own earlier inputs of that thing', () async {
    final e = env();
    Future<void> add(String person, String thing, int at, String amount) =>
        e.entries.add(
          personId: person,
          substanceId: thing,
          at: at,
          amount: amount,
        );
    await add('p1', 'bier', 1, '0,3');
    await add('p2', 'bier', 2, '0,5');
    await add('p1', 'bier', 3, '0,3');
    await add('p1', 'mate', 4, '1');
    expect(await e.entries.getAmounts('bier'), ['0,3', '0,5']);
  });

  test('a lockout keeps running across the start of the day', () async {
    final e = env();
    final start = e.clock.nowMs();
    await e.entries.add(personId: 'p1', substanceId: 'kippe');
    e.clock.advanceMs(7 * _hour);
    final stand = personStand(
      'p1',
      await e.entries.getLastEntries(),
      e.clock.nowMs(),
      lockoutMsBySubstance: const {'kippe': 8 * _hour},
    );
    expect(stand.lockout, isNotNull);
    expect(stand.lockout!.remainingMs, _hour);
    expect(stand.lastAt, start);
  });
}
