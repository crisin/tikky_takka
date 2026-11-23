import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/protocol/protocol_lane.dart';
import 'package:tikky_takka/features/protocol/protocol_strings.dart';
import 'package:tikky_takka/features/protocol/protocol_widgets.dart';
import 'package:tikky_takka/features/tracks/pad/tap_pad.dart';
import 'package:tikky_takka/features/tracks/tracks_strings.dart';
import 'package:tikky_takka/features/tracks/tracks_view.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../../support/test_app.dart';
import '../tracks/tracks_harness.dart';
import 'protocol_test_support.dart';

const _add = ValueKey('protocol-add');
const _others = ValueKey('capture-others');

Key _card(Person p) => ProtocolFixture.card(p);

/// Whether [a] comes before [b] in reading order.
bool _before(WidgetTester tester, Finder a, Finder b) {
  final pa = tester.getTopLeft(a);
  final pb = tester.getTopLeft(b);
  return pa.dy < pb.dy || (pa.dy == pb.dy && pa.dx < pb.dx);
}

/// What the lane asked the tap pad for, and whether the set shows it.
({PadPageRequest? request, TracksView view}) _asked(ProtocolFixture f) => (
  request: f.container.read(padPageRequestProvider),
  view: f.container.read(tracksViewProvider(f.track.setId)),
);

void main() {
  testWidgets('scene with several persons: a card opens "Was?" of that '
      'person on the tap pad and writes nothing', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final uli = await f.person('Uli');
    final gbl = await f.substance('GBL');
    // Scene order differs from the order of the lists.
    await f.scene(persons: [kim, jacke], substances: [gbl]);

    // Only the scene's persons, in the scene's order.
    expect(find.text(ProtocolStrings.whoAreYou), findsOneWidget);
    expect(find.byKey(_card(jacke)), findsOneWidget);
    expect(find.byKey(_card(kim)), findsOneWidget);
    expect(find.byKey(_card(uli)), findsNothing);
    expect(find.byKey(_others), findsOneWidget);
    expect(
      _before(tester, find.byKey(_card(kim)), find.byKey(_card(jacke))),
      isTrue,
    );
    expect(_asked(f).view, TracksView.lanes);

    await f.tap(find.byKey(_card(jacke)));
    final asked = _asked(f);
    expect(asked.view, TracksView.pad);
    expect(asked.request?.trackId, f.track.id);
    expect(asked.request?.personId, jacke.id);
    // Nothing written by choosing, no sheet, no dialog.
    expect(await f.entries(), isEmpty);
    expect(find.text(Strings.protocolNewEntry), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(await f.run(() => f.commands.getOpenSession(f.track.id)), isNull);
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
    expect(
      _before(tester, find.byKey(_card(kim)), find.byKey(_card(uli))),
      isTrue,
    );

    await f.tap(find.byKey(_card(uli)));
    expect(_asked(f).request?.personId, uli.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a scene with exactly one person still shows its card', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    await f.person('Kim');
    final gbl = await f.substance('GBL');
    await f.scene(persons: [jacke], substances: [gbl]);

    expect(find.byKey(_card(jacke)), findsOneWidget);
    expect(find.byKey(_others), findsOneWidget);
    await f.tap(find.byKey(_card(jacke)));
    expect(_asked(f).request?.personId, jacke.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without a scene everybody is listed, most recent first', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final sam = await f.person('Sam');
    final water = await f.substance('Wasser');

    // Nothing logged, no scene: both persons, no "Andere".
    expect(find.text(ProtocolStrings.whoAreYou), findsOneWidget);
    expect(find.byKey(_card(alex)), findsOneWidget);
    expect(find.byKey(_card(sam)), findsOneWidget);
    expect(find.byKey(_others), findsNothing);
    expect(find.text(Strings.protocolEmpty), findsOneWidget);

    await f.entry(personId: sam.id, substanceId: water.id);
    await f.settle();
    expect(
      _before(tester, find.byKey(_card(sam)), find.byKey(_card(alex))),
      isTrue,
    );
    expect(find.text('Sam · gerade eben'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"+" opens the full sheet without a person', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final gbl = await f.substance('GBL');
    final tea = await f.substance('Tee');
    await f.scene(persons: [jacke, kim], substances: [gbl]);

    await f.tap(find.byKey(_add));
    expect(find.text(Strings.protocolNewEntry), findsOneWidget);
    expect(
      tester
          .widget<ProtocolChoice>(find.byKey(ValueKey('person-${jacke.id}')))
          .selected,
      isFalse,
    );
    await f.tap(find.byKey(ValueKey('person-${jacke.id}')));
    await f.tap(find.byKey(ValueKey('substance-${tea.id}')));
    await tester.enterText(find.byKey(const ValueKey('amount')), '1 Tasse');
    await f.tap(find.byKey(const ValueKey('save-entry')));

    final entries = await f.entries();
    expect(entries.single.personId, jacke.id);
    expect(entries.single.substanceId, tea.id);
    expect(entries.single.amount, '1 Tasse');
    expect(find.text(Strings.protocolSaved), findsOneWidget);
    // The lane does not switch to the tap pad for this.
    expect(_asked(f).view, TracksView.lanes);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a card shows the lockout the user set; entries without a '
      'person open the sheet', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    // The lockout is a value the user typed in; the app has none.
    final gbl = await f.substance('GBL', lockoutMs: 2 * hourMs);
    await f.entry(personId: jacke.id, substanceId: gbl.id);
    await f.entry(substanceId: gbl.id);
    await f.settle();
    await f.advance(const Duration(minutes: 30));

    // Per person: Jacke's card and the one of entries without a person.
    expect(
      find.text(ProtocolStrings.lockoutFor('GBL', '1 h 30 min')),
      findsNWidgets(2),
    );
    const nobody = ValueKey('person-card-none');
    expect(find.byKey(nobody), findsOneWidget);
    await f.tap(find.byKey(nobody));
    expect(find.text(Strings.protocolNewEntry), findsOneWidget);
    expect(_asked(f).request, isNull);
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
    expect(find.byKey(_card(kim)), findsNothing);
    expect(find.byKey(_card(jacke)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cards are at least 56 px high, scaled with the button scale, '
      'and carry semantics labels', (tester) async {
    final handle = tester.ensureSemantics();
    const scale = 1.5;
    final f = await ProtocolFixture.pump(
      tester,
      prefs: UiPrefs.defaults.copyWith(buttonScale: scale),
    );
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final gbl = await f.substance('GBL');
    await f.scene(persons: [jacke, kim], substances: [gbl]);
    const min = 56 * scale;

    for (final p in [jacke, kim]) {
      expect(
        tester.getSize(find.byKey(_card(p))).height,
        greaterThanOrEqualTo(min),
      );
    }
    expect(tester.getSize(find.byKey(_add)).height, greaterThanOrEqualTo(min));
    expect(find.bySemanticsLabel(RegExp('^Jacke')), findsWidgets);
    handle.dispose();
    expect(tester.takeException(), isNull);
  });

  for (final (name, size, tile) in [
    ('a wide window', TestApp.desktopSize, null),
    ('a narrow tile', TestApp.phoneSize, const Size(132, 220)),
    ('a wide tile', TestApp.desktopSize, const Size(320, 150)),
  ]) {
    testWidgets('the cards work in $name', (tester) async {
      final f = await ProtocolFixture.pump(
        tester,
        surfaceSize: size,
        tileSize: tile,
      );
      final persons = [
        for (final n in ['Jacke', 'Kim', 'Noa', 'Uli']) await f.person(n),
      ];
      final gbl = await f.substance('GBL', lockoutMs: hourMs);
      await f.scene(persons: persons.sublist(0, 3), substances: [gbl]);
      expect(find.byType(ProtocolLane), findsOneWidget);
      expect(tester.takeException(), isNull);

      await f.tap(find.byKey(_card(persons[1])));
      expect(_asked(f).request?.personId, persons[1].id);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (name, size) in [
    ('phone', TestApp.phoneSize),
    ('wide', TestApp.desktopSize),
  ]) {
    testWidgets('on the tracks screen a card leads to "Was?" on the tap pad, '
        'where one tap writes ($name)', (tester) async {
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
      final views = h.container.read(tracksViewsProvider.notifier);

      var expected = 0;
      for (final layout in LaneLayout.values) {
        await h.setPrefs(UiPrefs.defaults.copyWith(layout: layout));
        await h.settle();
        expect(tester.takeException(), isNull, reason: '$layout, lanes');

        // The lists are lazy: bring the lane into view first.
        await tester.scrollUntilVisible(
          find.byKey(_card(kim)),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await h.tap(find.byKey(_card(kim)));
        expect(tester.takeException(), isNull, reason: '$layout, pad');
        expect(find.byType(TapPad), findsOneWidget);
        expect(find.text(TracksStrings.padWhatTitle), findsOneWidget);
        expect(find.byKey(PadKeys.back), findsOneWidget);
        expect(h.container.read(padPageRequestProvider), isNull);

        final field = find.byKey(
          PadKeys.button('x:${track.id}:${kim.id}:${gbl.id}'),
        );
        expect(field, findsOneWidget, reason: '$layout');
        await tester.tap(field);
        // The pad writes on the real event loop.
        for (var i = 0; i < 3; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await h.settle();
        }
        expect(tester.takeException(), isNull, reason: '$layout, written');

        final open = await h.run(
          () =>
              h.container.read(trackCommandsProvider).getOpenSession(track.id),
        );
        final entries = [
          for (final e in open!.events)
            if (e.type == EventType.entry) e,
        ];
        expect(entries, hasLength(++expected), reason: '$layout');
        expect(entries.last.personId, kim.id);
        expect(entries.last.substanceId, gbl.id);

        // Back to the lanes for the next round.
        await h.run(() => views.show(h.activeSet.id, TracksView.lanes));
        await h.settle();
      }
    });
  }

  testWidgets('Cupertino platforms choose the same way', (tester) async {
    final f = await ProtocolFixture.pump(tester, platform: TargetPlatform.iOS);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final gbl = await f.substance('GBL');
    await f.scene(persons: [jacke, kim], substances: [gbl]);

    await f.tap(find.byKey(_card(kim)));
    expect(_asked(f).request?.personId, kim.id);
    expect(_asked(f).view, TracksView.pad);
    expect(tester.takeException(), isNull);
  });
}
