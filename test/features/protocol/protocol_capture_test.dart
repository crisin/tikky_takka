import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/protocol/protocol_lane.dart';
import 'package:tikky_takka/features/protocol/protocol_strings.dart';
import 'package:tikky_takka/features/protocol/protocol_widgets.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../../support/test_app.dart';
import '../tracks/tracks_harness.dart';
import 'protocol_test_support.dart';

const _add = ValueKey('protocol-add');
const _back = ValueKey('capture-back');
const _others = ValueKey('capture-others');

Key _card(Person p) => ProtocolFixture.card(p);
Key _button(Substance s) => ProtocolFixture.button(s);

/// Whether [a] comes before [b] in reading order.
bool _before(WidgetTester tester, Finder a, Finder b) {
  final pa = tester.getTopLeft(a);
  final pb = tester.getTopLeft(b);
  return pa.dy < pb.dy || (pa.dy == pb.dy && pa.dx < pb.dx);
}

void main() {
  testWidgets('scene with several persons: who, then one tap writes exactly '
      'one entry; undo removes it', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final uli = await f.person('Uli');
    final water = await f.substance('Wasser');
    final gbl = await f.substance('GBL');
    final tea = await f.substance('Tee');
    // Scene order differs from the order of the lists.
    await f.scene(persons: [kim, jacke], substances: [gbl, water]);

    // Step 1: only the scene's persons, in the scene's order.
    expect(find.text(ProtocolStrings.whoAreYou), findsOneWidget);
    expect(find.byKey(_card(jacke)), findsOneWidget);
    expect(find.byKey(_card(kim)), findsOneWidget);
    expect(find.byKey(_card(uli)), findsNothing);
    expect(find.byKey(_others), findsOneWidget);
    expect(_before(tester, find.byKey(_card(kim)), find.byKey(_card(jacke))),
        isTrue);
    expect(find.byKey(_button(gbl)), findsNothing);
    expect(await f.run(() => f.commands.getOpenSession(f.track.id)), isNull);

    // Step 2: the scene's substances as buttons, in the scene's order.
    await f.tap(find.byKey(_card(jacke)));
    expect(find.text(ProtocolStrings.whoAreYou), findsNothing);
    expect(find.byKey(_button(gbl)), findsOneWidget);
    expect(find.byKey(_button(water)), findsOneWidget);
    expect(find.byKey(_button(tea)), findsNothing);
    expect(
      _before(tester, find.byKey(_button(gbl)), find.byKey(_button(water))),
      isTrue,
    );
    // Nothing written by looking.
    expect(await f.entries(), isEmpty);

    // One tap: the entry is there. No sheet, no dialog, no session needed.
    await f.advance(const Duration(minutes: 3));
    await f.tap(find.byKey(_button(gbl)));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(Strings.protocolNewEntry), findsNothing);
    expect(find.text(Strings.protocolEditEntry), findsNothing);
    final entries = await f.entries();
    expect(entries, hasLength(1));
    expect(entries.single.personId, jacke.id);
    expect(entries.single.substanceId, gbl.id);
    expect(entries.single.at, f.app.clock.nowMs());
    // The app fills in nothing the user did not choose.
    expect(entries.single.amount, isNull);
    expect(entries.single.note, isNull);
    expect(entries.single.label, isNull);
    expect(await f.run(() => f.commands.getOpenSession(f.track.id)), isNotNull);

    // Snackbar with both actions; the lane is back at "Wer bist du?".
    expect(find.text('Jacke · GBL eingetragen'), findsOneWidget);
    expect(find.text(Strings.undo), findsOneWidget);
    expect(find.text(ProtocolStrings.details), findsOneWidget);
    expect(find.text(ProtocolStrings.whoAreYou), findsOneWidget);
    expect(find.byKey(_button(gbl)), findsNothing);
    expect(find.text('Jacke · gerade eben'), findsOneWidget);
    expect(find.text('GBL'), findsOneWidget);

    // "Rückgängig" removes the event - and the session it had opened.
    await f.tap(find.text(Strings.undo));
    expect(await f.entries(), isEmpty);
    expect(await f.run(() => f.commands.getOpenSession(f.track.id)), isNull);
    expect(find.text('Jacke'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hasty second tap does not write a second entry', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final gbl = await f.substance('GBL');
    await f.scene(persons: [jacke, kim], substances: [gbl]);

    await f.tap(find.byKey(_card(jacke)));
    await tester.tap(find.byKey(_button(gbl)));
    await tester.tap(find.byKey(_button(gbl)));
    await tester.pump();
    await tester.tap(find.byKey(_button(gbl)), warnIfMissed: false);
    await f.settle();

    expect(await f.entries(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Andere" lists the persons outside the scene', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final uli = await f.person('Uli');
    final gbl = await f.substance('GBL');
    await f.scene(persons: [jacke, kim], substances: [gbl]);

    await f.tap(find.byKey(_others));
    expect(find.byKey(_card(uli)), findsOneWidget);
    expect(find.byKey(_others), findsNothing);
    // The scene's persons stay first.
    expect(_before(tester, find.byKey(_card(kim)), find.byKey(_card(uli))),
        isTrue);

    // Somebody from outside the scene gets the scene's substances too.
    await f.tap(find.byKey(_card(uli)));
    await f.tap(find.byKey(_button(gbl)));
    final entries = await f.entries();
    expect(entries.single.personId, uli.id);
    expect(entries.single.substanceId, gbl.id);
    expect(find.text('Uli · GBL eingetragen'), findsOneWidget);
    // Back at step 1, folded again.
    expect(find.byKey(_card(uli)), findsNothing);
    expect(find.byKey(_others), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a scene with exactly one person skips "Wer bist du?"', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final gbl = await f.substance('GBL');
    final water = await f.substance('Wasser');
    await f.scene(persons: [jacke], substances: [gbl, water]);

    expect(find.text(ProtocolStrings.whoAreYou), findsNothing);
    expect(find.byKey(_card(jacke)), findsNothing);
    expect(find.byKey(_button(gbl)), findsOneWidget);
    expect(find.byKey(_button(water)), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(_back), matching: find.text('Jacke')),
      findsOneWidget,
    );

    // One tap; the lane stays on the buttons and counts.
    await f.tap(find.byKey(_button(gbl)));
    await f.tap(find.byKey(_button(gbl)));
    final entries = await f.entries();
    expect(entries, hasLength(2));
    expect(entries.every((e) => e.personId == jacke.id), isTrue);
    expect(find.text(ProtocolStrings.whoAreYou), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(_button(gbl)),
        matching: find.text(ProtocolStrings.timesCount(2)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(_button(water)),
        matching: find.text(ProtocolStrings.timesCount(0)),
      ),
      findsOneWidget,
    );

    // The person's name leads back to the choice, for somebody else.
    await f.tap(find.byKey(_back));
    expect(find.text(ProtocolStrings.whoAreYou), findsOneWidget);
    expect(find.byKey(_card(jacke)), findsOneWidget);
    await f.tap(find.byKey(_others));
    await f.tap(find.byKey(_card(kim)));
    await f.tap(find.byKey(_button(water)));
    expect((await f.entries()).last.personId, kim.id);
    // Afterwards the single scene person is the default again.
    expect(find.text(ProtocolStrings.whoAreYou), findsNothing);
    expect(
      find.descendant(of: find.byKey(_back), matching: find.text('Jacke')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a scene everybody is listed and the buttons are the '
      "person's own most used substances", (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final sam = await f.person('Sam');
    final water = await f.substance('Wasser');
    final tea = await f.substance('Tee');
    final mate = await f.substance('Mate');

    // Nothing logged, no scene: both persons, no "Andere".
    expect(find.text(ProtocolStrings.whoAreYou), findsOneWidget);
    expect(find.byKey(_card(alex)), findsOneWidget);
    expect(find.byKey(_card(sam)), findsOneWidget);
    expect(find.byKey(_others), findsNothing);
    expect(find.text(Strings.protocolEmpty), findsOneWidget);

    // Nobody logged anything yet: no buttons, the "+" is the way.
    await f.tap(find.byKey(_card(alex)));
    expect(find.byKey(_button(water)), findsNothing);
    expect(find.byKey(_add), findsOneWidget);
    await f.tap(find.byKey(_back));

    // An earlier session: Alex took tea twice and water once, Sam mate.
    await f.entry(personId: alex.id, substanceId: tea.id);
    await f.entry(personId: alex.id, substanceId: water.id);
    await f.entry(personId: alex.id, substanceId: tea.id);
    await f.entry(personId: sam.id, substanceId: mate.id);
    await f.run(() => f.commands.stopTrack(f.track.id));
    await f.advance(const Duration(minutes: 5));
    await f.entry(personId: alex.id, substanceId: water.id);
    await f.settle();

    await f.tap(find.byKey(_card(alex)));
    expect(find.byKey(_button(tea)), findsOneWidget);
    expect(find.byKey(_button(water)), findsOneWidget);
    expect(find.byKey(_button(mate)), findsNothing);
    // 2 x tea, 2 x water over all sessions: the more recent one first.
    expect(
      _before(tester, find.byKey(_button(water)), find.byKey(_button(tea))),
      isTrue,
    );
    // The count is the one of the CURRENT session.
    expect(
      find.descendant(
        of: find.byKey(_button(water)),
        matching: find.text(ProtocolStrings.timesCount(1)),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(_button(tea)),
        matching: find.text(ProtocolStrings.timesCount(0)),
      ),
      findsOneWidget,
    );

    await f.tap(find.byKey(_button(tea)));
    final entries = await f.entries();
    expect(entries, hasLength(2));
    expect(entries.last.personId, alex.id);
    expect(entries.last.substanceId, tea.id);
    expect(entries.last.amount, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"+" opens the full sheet with only the person chosen', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final gbl = await f.substance('GBL');
    final tea = await f.substance('Tee');
    await f.scene(persons: [jacke, kim], substances: [gbl]);
    await f.entry(personId: jacke.id, substanceId: gbl.id, amount: '1 ml');
    await f.settle();

    await f.tap(find.byKey(_card(jacke)));
    await f.tap(find.byKey(_add));
    expect(find.text(Strings.protocolNewEntry), findsOneWidget);
    expect(
      tester
          .widget<ProtocolChoice>(find.byKey(ValueKey('person-${jacke.id}')))
          .selected,
      isTrue,
    );
    // Neither the last substance nor its amount is filled in.
    expect(
      tester
          .widget<ProtocolChoice>(find.byKey(ValueKey('substance-${gbl.id}')))
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('amount')))
          .controller!
          .text,
      isEmpty,
    );
    // Something that is not part of the scene.
    await f.tap(find.byKey(ValueKey('substance-${tea.id}')));
    await tester.enterText(find.byKey(const ValueKey('amount')), '1 Tasse');
    await f.tap(find.byKey(const ValueKey('save-entry')));

    final entries = await f.entries();
    expect(entries, hasLength(2));
    expect(entries.last.personId, jacke.id);
    expect(entries.last.substanceId, tea.id);
    expect(entries.last.amount, '1 Tasse');
    // Back at "Wer bist du?".
    expect(find.text(ProtocolStrings.whoAreYou), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a button shows a remaining time only for a lockout the user '
      'set, and a running lockout never blocks the tap', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    // The lockout is a value the user typed in; the app has none.
    final gbl = await f.substance('GBL', lockoutMs: 2 * hourMs);
    final water = await f.substance('Wasser');
    await f.scene(persons: [jacke, kim], substances: [gbl, water]);
    await f.entry(personId: jacke.id, substanceId: gbl.id);
    await f.entry(personId: jacke.id, substanceId: water.id);
    await f.settle();
    await f.advance(const Duration(minutes: 30));

    Finder inButton(Substance s, Finder what) =>
        find.descendant(of: find.byKey(_button(s)), matching: what);
    final clock = find.byIcon(Icons.schedule_rounded);

    await f.tap(find.byKey(_card(jacke)));
    // GBL: count and the rest of the user's own lockout.
    expect(inButton(gbl, find.text(ProtocolStrings.timesCount(1))),
        findsOneWidget);
    expect(inButton(gbl, find.text('1 h 30 min')), findsOneWidget);
    expect(inButton(gbl, clock), findsOneWidget);
    // Wasser has no lockout: just the count, no timer of any kind.
    expect(inButton(water, find.text(ProtocolStrings.timesCount(1))),
        findsOneWidget);
    expect(inButton(water, clock), findsNothing);
    expect(inButton(water, find.byType(Text)), findsNWidgets(2));

    // It keeps counting down on the button.
    await f.advance(const Duration(minutes: 20));
    expect(inButton(gbl, find.text('1 h 10 min')), findsOneWidget);

    // The lockout is shown, not enforced: the tap writes, nothing asks.
    await f.tap(find.byKey(_button(gbl)));
    expect(find.byType(AlertDialog), findsNothing);
    final entries = await f.entries();
    expect(entries, hasLength(3));
    expect(entries.last.substanceId, gbl.id);
    expect(entries.last.at, f.app.clock.nowMs());
    expect(find.text('Jacke · GBL eingetragen'), findsOneWidget);

    // The lockout is per person: Kim's button has none.
    await f.tap(find.byKey(_card(kim)));
    expect(inButton(gbl, find.text(ProtocolStrings.timesCount(0))),
        findsOneWidget);
    expect(inButton(gbl, clock), findsNothing);
    await f.tap(find.byKey(_back));

    // Once it is over the time disappears from Jacke's button as well.
    await f.advance(const Duration(hours: 2, minutes: 1));
    await f.tap(find.byKey(_card(jacke)));
    expect(inButton(gbl, find.text(ProtocolStrings.timesCount(2))),
        findsOneWidget);
    expect(inButton(gbl, clock), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Details" opens the sheet for the entry that was just '
      'written', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final gbl = await f.substance('GBL');
    await f.scene(persons: [jacke, kim], substances: [gbl]);

    await f.tap(find.byKey(_card(jacke)));
    await f.tap(find.byKey(_button(gbl)));
    await f.tap(find.text(ProtocolStrings.details));

    expect(find.text(Strings.protocolEditEntry), findsOneWidget);
    expect(
      tester
          .widget<ProtocolChoice>(find.byKey(ValueKey('substance-${gbl.id}')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('amount')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.enterText(find.byKey(const ValueKey('amount')), '1 ml');
    await tester.enterText(find.byKey(const ValueKey('note')), 'am Zelt');
    await f.tap(find.byKey(const ValueKey('save-entry')));

    final entries = await f.entries();
    expect(entries, hasLength(1));
    expect(entries.single.personId, jacke.id);
    expect(entries.single.substanceId, gbl.id);
    expect(entries.single.amount, '1 ml');
    expect(entries.single.note, 'am Zelt');
    expect(find.text(ProtocolStrings.entryUpdated), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a deleted person leaves the scene on the lane as well', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final gbl = await f.substance('GBL');
    final water = await f.substance('Wasser');
    await f.scene(persons: [jacke, kim], substances: [gbl, water]);
    expect(find.byKey(_card(kim)), findsOneWidget);

    await f.run(() => f.people.deletePerson(kim.id));
    await f.run(() => f.people.deleteSubstance(gbl.id));
    await f.settle();

    final set = await f.storedSet();
    expect(set.scenePersonIds, [jacke.id]);
    expect(set.sceneSubstanceIds, [water.id]);
    // One person left in the scene: straight to the buttons.
    expect(find.text(ProtocolStrings.whoAreYou), findsNothing);
    expect(find.byKey(_button(water)), findsOneWidget);
    expect(find.byKey(_button(gbl)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture targets are at least 56 px high, scaled with the '
      'button scale, and carry semantics labels', (tester) async {
    final handle = tester.ensureSemantics();
    const scale = 1.5;
    final f = await ProtocolFixture.pump(
      tester,
      prefs: UiPrefs.defaults.copyWith(buttonScale: scale),
    );
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final gbl = await f.substance('GBL', lockoutMs: hourMs);
    await f.scene(persons: [jacke, kim], substances: [gbl]);
    const min = 56 * scale;

    expect(tester.getSize(find.byKey(_card(jacke))).height,
        greaterThanOrEqualTo(min));
    expect(tester.getSize(find.byKey(_card(kim))).height,
        greaterThanOrEqualTo(min));
    expect(
      find.bySemanticsLabel(RegExp('^Jacke')),
      findsWidgets,
    );

    await f.tap(find.byKey(_card(jacke)));
    expect(tester.getSize(find.byKey(_button(gbl))).height,
        greaterThanOrEqualTo(min));
    expect(tester.getSize(find.byKey(_back)).height, greaterThanOrEqualTo(min));
    expect(tester.getSize(find.byKey(_add)).height, greaterThanOrEqualTo(min));
    expect(
      find.bySemanticsLabel(ProtocolStrings.captureLabel('GBL', 0, null)),
      findsOneWidget,
    );

    await f.tap(find.byKey(_button(gbl)));
    await f.tap(find.byKey(_card(jacke)));
    expect(
      find.bySemanticsLabel(ProtocolStrings.captureLabel('GBL', 1, '1 h')),
      findsOneWidget,
    );
    handle.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final (name, size, tile) in [
    ('a wide window', TestApp.desktopSize, null),
    ('a narrow tile', TestApp.phoneSize, const Size(132, 220)),
    ('a wide tile', TestApp.desktopSize, const Size(320, 150)),
  ]) {
    testWidgets('one-tap capture works in $name', (tester) async {
      final f = await ProtocolFixture.pump(
        tester,
        surfaceSize: size,
        tileSize: tile,
      );
      final persons = [
        for (final n in ['Jacke', 'Kim', 'Noa', 'Uli']) await f.person(n),
      ];
      final substances = [
        for (final n in ['GBL', 'Wasser', 'Tee', 'Mate', 'Saft', 'Cola'])
          await f.substance(n, lockoutMs: n == 'GBL' ? hourMs : null),
      ];
      await f.scene(persons: persons.sublist(0, 3), substances: substances);
      expect(find.byType(ProtocolLane), findsOneWidget);
      expect(tester.takeException(), isNull);

      await f.tap(find.byKey(_card(persons[1])));
      // Five buttons at most, also with six substances in the scene.
      expect(find.byKey(_button(substances[4])), findsOneWidget);
      expect(find.byKey(_button(substances[5])), findsNothing);
      expect(tester.takeException(), isNull);

      await f.tap(find.byKey(_button(substances[0])));
      final entries = await f.entries();
      expect(entries.single.personId, persons[1].id);
      expect(entries.single.substanceId, substances[0].id);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (name, size) in [
    ('phone', TestApp.phoneSize),
    ('wide', TestApp.desktopSize),
  ]) {
    testWidgets('on the tracks screen, rows and tiles ($name)', (tester) async {
      final h = await TracksHarness.start(tester, surfaceSize: size);
      final track = await h.addTrack(const ProtocolConfig(), name: 'Zelt');
      final people = h.container.read(peopleRepositoryProvider);
      final jacke = await h.run(() => people.createPerson(name: 'Jacke'));
      final kim = await h.run(() => people.createPerson(name: 'Kim'));
      final gbl = await h.run(
        () => people.createSubstance(name: 'GBL', lockoutMs: hourMs),
      );
      await h.run(
        () => h.container
            .read(setRepositoryProvider)
            .updateScene(
              h.activeSet.id,
              personIds: [jacke.id, kim.id],
              substanceIds: [gbl.id],
            ),
      );

      var expected = 0;
      for (final layout in LaneLayout.values) {
        await h.setPrefs(UiPrefs.defaults.copyWith(layout: layout));
        await h.settle();
        expect(tester.takeException(), isNull, reason: '$layout, step 1');

        // The lists are lazy: bring the lane into view first.
        await tester.scrollUntilVisible(
          find.byKey(_card(kim)),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await h.tap(find.byKey(_card(kim)));
        expect(tester.takeException(), isNull, reason: '$layout, step 2');
        await tester.scrollUntilVisible(
          find.byKey(_button(gbl)),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(_button(gbl)));
        await settleUi(tester, h.app);
        expect(tester.takeException(), isNull, reason: '$layout, written');

        final open = await h.run(
          () => h.container
              .read(trackCommandsProvider)
              .getOpenSession(track.id),
        );
        final entries = [
          for (final e in open!.events)
            if (e.type == EventType.entry) e,
        ];
        expect(entries, hasLength(++expected), reason: '$layout');
        expect(entries.last.personId, kim.id);
        expect(entries.last.substanceId, gbl.id);

        // Let the inline undo bar leave before the next round.
        await tester.pump(const Duration(seconds: 11));
        await h.settle();
        await h.settle();
        expect(find.text('Kim · GBL eingetragen'), findsNothing);
      }
    });
  }

  testWidgets('Cupertino platforms capture the same way', (tester) async {
    final f = await ProtocolFixture.pump(
      tester,
      platform: TargetPlatform.iOS,
    );
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final gbl = await f.substance('GBL');
    await f.scene(persons: [jacke, kim], substances: [gbl]);

    await f.tap(find.byKey(_card(kim)));
    await f.tap(find.byKey(_button(gbl)));
    expect((await f.entries()).single.personId, kim.id);
    expect(find.text('Kim · GBL eingetragen'), findsOneWidget);
    await f.tap(find.text(Strings.undo));
    expect(await f.entries(), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
