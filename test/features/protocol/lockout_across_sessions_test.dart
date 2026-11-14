import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/features/protocol/protocol_logic.dart';
import 'package:tikky_takka/features/protocol/protocol_strings.dart';
import 'package:tikky_takka/l10n/strings.dart';

import '../../support/test_env.dart';
import 'protocol_test_support.dart';

/// A lockout belongs to the person and the substance, not to a session:
/// "frühestens wieder in ..." must survive "Sitzung beenden" and the start
/// of a new session.
void main() {
  group('deriveLockouts (pure)', () {
    const lockouts = {'water': 4 * hourMs, 'tea': 30 * minuteMs, 'zero': 0};
    const facts = [
      LastEntryFact(personId: 'alex', substanceId: 'water', at: 0),
      LastEntryFact(personId: 'alex', substanceId: 'tea', at: hourMs),
      // An older fact for the same pair never wins.
      LastEntryFact(personId: 'alex', substanceId: 'tea', at: 10),
      LastEntryFact(personId: 'sam', substanceId: 'free', at: hourMs),
      LastEntryFact(personId: 'sam', substanceId: 'zero', at: hourMs),
      LastEntryFact(personId: 'sam', substanceId: null, at: 2 * hourMs),
      LastEntryFact(personId: null, substanceId: 'water', at: 3 * hourMs),
    ];

    test('remaining time per person and substance, longest first', () {
      final at = hourMs + 10 * minuteMs;
      final running = deriveLockouts(
        facts,
        at,
        lockoutMsBySubstance: lockouts,
      );
      expect(running.keys.toSet(), {'alex', null});
      final alex = running['alex']!;
      expect(alex.map((l) => l.substanceId), ['water', 'tea']);
      expect(alex.first.remainingMs, 4 * hourMs - at);
      expect(alex.first.untilAt, 4 * hourMs);
      expect(alex.last.remainingMs, 20 * minuteMs);
      // Entries without a person are a group of their own.
      expect(running[null]!.single.lastEntryAt, 3 * hourMs);
    });

    test('expired lockouts vanish; nothing is invented', () {
      expect(
        deriveLockouts(facts, 8 * hourMs, lockoutMsBySubstance: lockouts),
        isEmpty,
      );
      // No lockout data: never a lockout.
      expect(deriveLockouts(facts, hourMs), isEmpty);
      expect(
        deriveLockouts(const [], hourMs, lockoutMsBySubstance: lockouts),
        isEmpty,
      );
    });

    test('lastEntryAtByPerson and lockoutRemainingFor', () {
      expect(lastEntryAtByPerson(facts), {
        'alex': hourMs,
        'sam': 2 * hourMs,
        null: 3 * hourMs,
      });
      expect(
        lockoutRemainingFor(
          facts,
          personId: 'alex',
          substanceId: 'water',
          nowMs: hourMs,
          lockouts: lockouts,
        ),
        3 * hourMs,
      );
      expect(
        lockoutRemainingFor(
          facts,
          personId: 'sam',
          substanceId: 'water',
          nowMs: hourMs,
          lockouts: lockouts,
        ),
        isNull,
      );
    });
  });

  group('HistoryRepository.getLastEntries', () {
    final env = useTestEnv();

    test('covers closed AND open sessions of the track, per pair', () async {
      final e = env();
      final set = await e.makeSet();
      final track = await e.makeTrack(set, const ProtocolConfig());
      final other = await e.makeTrack(set, const ProtocolConfig(), name: 'o');
      final t0 = e.clock.nowMs();

      await e.commands.addEntry(track.id, personId: 'alex', substanceId: 'w');
      e.clock.advanceMs(minuteMs);
      await e.commands.addEntry(track.id, personId: 'alex', substanceId: 'w');
      await e.commands.addEntry(track.id, personId: 'sam');
      await e.commands.stopTrack(track.id);
      e.clock.advanceMs(hourMs);
      // A new session of the same track, and noise on another track.
      await e.commands.addEntry(track.id, personId: 'alex', substanceId: 't');
      await e.commands.addEntry(other.id, personId: 'alex', substanceId: 'w');

      final facts = await e.history.getLastEntries(track.id);
      expect(facts.toSet(), {
        LastEntryFact(personId: 'alex', substanceId: 'w', at: t0 + minuteMs),
        LastEntryFact(personId: 'sam', substanceId: null, at: t0 + minuteMs),
        LastEntryFact(
          personId: 'alex',
          substanceId: 't',
          at: t0 + minuteMs + hourMs,
        ),
      });
      expect(await e.history.getLastEntries('missing'), isEmpty);
    });
  });

  testWidgets('the lane keeps showing the lockout after "Sitzung beenden" '
      'and in the next session', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final sam = await f.person('Sam');
    final water = await f.substance('Wasser', lockoutMs: 4 * hourMs);
    final tea = await f.substance('Tee');

    await f.entry(personId: alex.id, substanceId: water.id, amount: '0,5 l');
    await f.settle();
    await f.advance(const Duration(hours: 1));
    expect(
      find.text(ProtocolStrings.lockoutFor('Wasser', '3 h')),
      findsOneWidget,
    );

    // "Sitzung beenden": the track is idle, the lockout is not over.
    await f.tap(find.byTooltip(ProtocolStrings.finishSession));
    expect(await f.run(() => f.commands.getOpenSession(f.track.id)), isNull);
    expect(find.byTooltip(ProtocolStrings.finishSession), findsNothing);
    expect(find.text('Zelt · ${Strings.modeProtocol}'), findsOneWidget);
    expect(find.text(Strings.protocolEmpty), findsNothing);
    expect(find.text('Alex · vor 1 h'), findsOneWidget);
    expect(
      find.text(ProtocolStrings.lockoutFor('Wasser', '3 h')),
      findsOneWidget,
    );

    // It keeps counting down ...
    await f.advance(const Duration(minutes: 30));
    expect(
      find.text(ProtocolStrings.lockoutFor('Wasser', '2 h 30 min')),
      findsOneWidget,
    );

    // ... also when somebody else starts the next session.
    await f.entry(personId: sam.id, substanceId: tea.id);
    await f.settle();
    expect(find.text('Sam · gerade eben'), findsOneWidget);
    expect(find.text('Alex · vor 1 h 30 min'), findsOneWidget);
    expect(find.textContaining('frühestens wieder in'), findsOneWidget);

    // Over: Alex's card no longer shows anything from the earlier session.
    // (The card itself stays: without a scene everybody is listed.)
    await f.advance(const Duration(hours: 2, minutes: 31));
    expect(find.textContaining('frühestens wieder in'), findsNothing);
    expect(find.textContaining('Alex ·'), findsNothing);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.textContaining('Sam'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an idle lane without running lockouts still invites the '
      'first entry', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final water = await f.substance('Wasser', lockoutMs: hourMs);
    await f.entry(personId: alex.id, substanceId: water.id);
    await f.settle();
    await f.run(() => f.commands.stopTrack(f.track.id));
    await f.settle();
    expect(find.textContaining('frühestens wieder in'), findsOneWidget);

    await f.advance(const Duration(hours: 1, minutes: 1));
    expect(find.text(Strings.protocolEmpty), findsOneWidget);
    expect(find.textContaining('frühestens wieder in'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the entry sheet shows the lockout of an earlier session',
      (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final water = await f.substance('Wasser', lockoutMs: 2 * hourMs);
    await f.entry(personId: alex.id, substanceId: water.id, amount: '0,5 l');
    await f.settle();
    await f.advance(const Duration(minutes: 30));
    await f.run(() => f.commands.stopTrack(f.track.id));
    await f.settle();

    // The locked-out person's card, then "+": the sheet for that person.
    await f.tap(find.text('Alex · vor 30 min'));
    await f.tap(find.byKey(const ValueKey('protocol-add')));
    await f.tap(find.byKey(ValueKey('substance-${water.id}')));
    expect(
      find.text('Alex · ${Strings.lockoutRemaining('1 h 30 min')}'),
      findsOneWidget,
    );

    // Informational only: saving works and opens a new session.
    await f.tap(find.byKey(const ValueKey('save-entry')));
    expect(await f.entries(), hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
