import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/protocol/protocol_strings.dart';
import 'package:tikky_takka/features/protocol/protocol_widgets.dart';
import 'package:tikky_takka/features/tracks/set_switcher.dart';
import 'package:tikky_takka/features/tracks/tracks_strings.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../tracks/tracks_harness.dart';
import 'protocol_test_support.dart';

const _edit = ValueKey('scene-edit');
const _clear = ValueKey('scene-clear');
const _done = ValueKey('scene-done');

Key _person(Person p) => ValueKey('scene-person-${p.id}');
Key _substance(Substance s) => ValueKey('scene-substance-${s.id}');

void main() {
  testWidgets('the scene editor stores every tap right away', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final uli = await f.person('Uli');
    final water = await f.substance('Wasser');
    final gbl = await f.substance('GBL');
    final tea = await f.substance('Tee');
    expect((await f.storedSet()).hasScene, isFalse);

    // From the lane.
    await f.tap(find.byKey(_edit));
    expect(find.text(ProtocolStrings.sceneOf('Festival')), findsOneWidget);
    expect(find.text(ProtocolStrings.sceneWho), findsOneWidget);
    expect(find.text(ProtocolStrings.sceneWhat), findsOneWidget);
    // Everybody and everything is offered, nothing is chosen.
    for (final key in [_person(jacke), _person(kim), _person(uli)]) {
      expect(tester.widget<ProtocolChoice>(find.byKey(key)).selected, isFalse);
    }
    for (final key in [_substance(water), _substance(gbl), _substance(tea)]) {
      expect(tester.widget<ProtocolChoice>(find.byKey(key)).selected, isFalse);
    }

    // Who is here: stored without a save button.
    await f.tap(find.byKey(_person(kim)));
    expect((await f.storedSet()).scenePersonIds, [kim.id]);
    await f.tap(find.byKey(_person(jacke)));
    expect((await f.storedSet()).scenePersonIds, [kim.id, jacke.id]);
    expect(
      tester.widget<ProtocolChoice>(find.byKey(_person(jacke))).selected,
      isTrue,
    );

    // What is on today: ordered by selection, the place is shown.
    await f.tap(find.byKey(_substance(tea)));
    await f.tap(find.byKey(_substance(water)));
    await f.tap(find.byKey(_substance(gbl)));
    expect((await f.storedSet()).sceneSubstanceIds, [tea.id, water.id, gbl.id]);
    expect(find.text(ProtocolStrings.sceneOrdered(1, 'Tee')), findsOneWidget);
    expect(find.text(ProtocolStrings.sceneOrdered(3, 'GBL')), findsOneWidget);

    // Tapping again takes it out; the others move up.
    await f.tap(find.byKey(_substance(tea)));
    expect((await f.storedSet()).sceneSubstanceIds, [water.id, gbl.id]);
    expect(find.text(ProtocolStrings.sceneOrdered(1, 'Wasser')), findsOneWidget);
    expect(find.text('Tee'), findsOneWidget);

    // Large toggles.
    final big = tester
        .element(find.byKey(_done))
        .tikky
        .sizes
        .bigTapTarget;
    expect(
      tester.getSize(find.byKey(_person(kim))).height,
      greaterThanOrEqualTo(big),
    );
    expect(
      tester.getSize(find.byKey(_substance(gbl))).height,
      greaterThanOrEqualTo(big),
    );

    // "Fertig": the lane follows the scene.
    await f.tap(find.byKey(_done));
    expect(find.text(ProtocolStrings.sceneWho), findsNothing);
    expect(find.byKey(ProtocolFixture.card(kim)), findsOneWidget);
    expect(find.byKey(ProtocolFixture.card(jacke)), findsOneWidget);
    expect(find.byKey(ProtocolFixture.card(uli)), findsNothing);
    await f.tap(find.byKey(ProtocolFixture.card(kim)));
    expect(find.byKey(ProtocolFixture.button(water)), findsOneWidget);
    expect(find.byKey(ProtocolFixture.button(gbl)), findsOneWidget);
    expect(find.byKey(ProtocolFixture.button(tea)), findsNothing);
    // Setting up a scene writes no entry.
    expect(await f.entries(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new persons and substances are added inline and join the '
      'scene; "Szene leeren" empties it', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    await f.scene(persons: [jacke]);

    // A single-person scene shows the buttons; the name leads to step 1.
    await f.tap(find.byKey(const ValueKey('capture-back')));
    await f.tap(find.byKey(_edit));
    expect(
      tester.widget<ProtocolChoice>(find.byKey(_person(jacke))).selected,
      isTrue,
    );

    await f.tap(find.byKey(const ValueKey('scene-add-person')));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('scene-new-person')),
        matching: find.byType(TextField),
      ),
      'Kim',
    );
    await f.tap(find.byTooltip(ProtocolStrings.confirmAdd));
    final persons = await f.run(() => f.people.getPersons());
    expect(persons.map((p) => p.name), ['Jacke', 'Kim']);
    final kim = persons.last;
    expect((await f.storedSet()).scenePersonIds, [jacke.id, kim.id]);
    expect(
      tester.widget<ProtocolChoice>(find.byKey(_person(kim))).selected,
      isTrue,
    );

    await f.tap(find.byKey(const ValueKey('scene-add-substance')));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('scene-new-substance')),
        matching: find.byType(TextField),
      ),
      'GBL',
    );
    await f.tap(find.byTooltip(ProtocolStrings.confirmAdd));
    final substances = await f.run(() => f.people.getSubstances());
    expect(substances.single.name, 'GBL');
    // A substance added here gets no lockout from the app.
    expect(substances.single.lockoutMs, isNull);
    expect((await f.storedSet()).sceneSubstanceIds, [substances.single.id]);

    // "Szene leeren": both lists are empty, persons and substances stay.
    await f.tap(find.byKey(_clear));
    expect(find.byType(AlertDialog), findsNothing);
    final cleared = await f.storedSet();
    expect(cleared.hasScene, isFalse);
    expect(await f.run(() => f.people.getPersons()), hasLength(2));
    expect(
      tester.widget<ProtocolChoice>(find.byKey(_person(kim))).selected,
      isFalse,
    );

    await f.tap(find.byKey(_done));
    // No scene: everybody is listed again.
    expect(find.byKey(ProtocolFixture.card(jacke)), findsOneWidget);
    expect(find.byKey(ProtocolFixture.card(kim)), findsOneWidget);
    expect(find.byKey(const ValueKey('capture-others')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the set sheet offers "Szene bearbeiten" for a set', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    final people = h.container.read(peopleRepositoryProvider);
    final alex = await h.run(() => people.createPerson(name: 'Alex'));

    await h.tap(find.byType(SetSwitcherButton));
    await h.tap(
      find.byTooltip('${TracksStrings.setOptions}: ${Strings.seedSetName}'),
    );
    await h.tap(find.text(ProtocolStrings.sceneEdit));
    expect(
      find.text(ProtocolStrings.sceneOf(Strings.seedSetName)),
      findsOneWidget,
    );

    await h.tap(find.byKey(_person(alex)));
    final stored = await h.run(
      () => h.container.read(setRepositoryProvider).getSet(h.activeSet.id),
    );
    expect(stored!.scenePersonIds, [alex.id]);
    // The provider the lanes read has it as well.
    expect(h.container.read(setProvider(h.activeSet.id))!.hasScene, isTrue);
    expect(tester.takeException(), isNull);
  });
}
