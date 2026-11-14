import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/adaptive/adaptive.dart';
import 'package:tikky_takka/features/protocol/protocol_lane.dart';
import 'package:tikky_takka/features/protocol/protocol_strings.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import 'protocol_test_support.dart';

const _bar = ValueKey('capture-undo-bar');

Finder get _inLane =>
    find.descendant(of: find.byType(ProtocolLane), matching: find.byKey(_bar));

void main() {
  testWidgets('a one-tap entry shows an undo bar INSIDE the lane - no '
      'snackbar - with "Rückgängig" and "Details"', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final gbl = await f.substance('GBL');
    await f.scene(persons: [jacke, kim], substances: [gbl]);
    expect(_inLane, findsNothing);

    await f.tap(find.byKey(ProtocolFixture.card(jacke)));
    await f.tap(find.byKey(ProtocolFixture.button(gbl)));
    expect(await f.entries(), hasLength(1));

    expect(find.byType(SnackBar), findsNothing);
    expect(_inLane, findsOneWidget);
    final bar = tester.widget<InlineUndoBar>(find.byKey(_bar));
    expect(bar.message, ProtocolStrings.captured('Jacke', 'GBL'));
    expect(bar.secondaryLabel, ProtocolStrings.details);
    expect(
      find.descendant(of: find.byKey(_bar), matching: find.text(Strings.undo)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(_bar),
        matching: find.text(ProtocolStrings.details),
      ),
      findsOneWidget,
    );

    // Below the person cards: it covers none of them, and none moved.
    final barRect = tester.getRect(find.byKey(_bar));
    for (final person in [jacke, kim]) {
      final card = tester.getRect(find.byKey(ProtocolFixture.card(person)));
      expect(card.bottom, lessThanOrEqualTo(barRect.top));
    }
    final laneRect = tester.getRect(find.byType(ProtocolLane));
    expect(barRect.bottom, lessThanOrEqualTo(laneRect.bottom));
    expect(barRect.left, greaterThanOrEqualTo(laneRect.left));

    // "Rückgängig" removes the entry and the bar.
    await f.tap(find.byKey(InlineUndoBar.undoKey));
    expect(await f.entries(), isEmpty);
    expect(await f.run(() => f.commands.getOpenSession(f.track.id)), isNull);
    expect(_inLane, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bar does not move the cards, is replaced by the next '
      'entry and leaves after about ten seconds', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final gbl = await f.substance('GBL');
    final water = await f.substance('Wasser');
    await f.scene(persons: [jacke, kim], substances: [gbl, water]);
    // An earlier entry, so the lane is past its "Noch kein Eintrag" line.
    await f.entry(personId: kim.id, substanceId: water.id);
    await f.settle();
    final cardTop = tester.getTopLeft(find.byKey(ProtocolFixture.card(kim)));

    await f.tap(find.byKey(ProtocolFixture.card(jacke)));
    await f.tap(find.byKey(ProtocolFixture.button(gbl)));
    expect(
      tester.widget<InlineUndoBar>(find.byKey(_bar)).message,
      ProtocolStrings.captured('Jacke', 'GBL'),
    );
    // Back at "Wer bist du?": the cards are where they were.
    expect(tester.getTopLeft(find.byKey(ProtocolFixture.card(kim))), cardTop);

    await tester.pump(const Duration(seconds: 5));
    await f.tap(find.byKey(ProtocolFixture.card(kim)));
    await f.tap(find.byKey(ProtocolFixture.button(water)));
    expect(
      tester.widget<InlineUndoBar>(find.byKey(_bar)).message,
      ProtocolStrings.captured('Kim', 'Wasser'),
    );
    expect(await f.entries(), hasLength(3));

    // The first entry's ten seconds are over; the bar is about the second.
    await tester.pump(const Duration(seconds: 6));
    await f.settle();
    expect(_inLane, findsOneWidget);

    // Undo takes back exactly the second entry.
    await f.tap(find.byKey(InlineUndoBar.undoKey));
    final left = await f.entries();
    expect(left, hasLength(2));
    expect(left.last.personId, jacke.id);
    expect(left.last.substanceId, gbl.id);
    expect(_inLane, findsNothing);

    // Without undo it leaves by itself.
    await f.tap(find.byKey(ProtocolFixture.card(kim)));
    await f.tap(find.byKey(ProtocolFixture.button(gbl)));
    expect(_inLane, findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    await f.settle();
    expect(_inLane, findsNothing);
    expect(await f.entries(), hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hasty tap on the bar right after the entry does not take it '
      'back', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final kim = await f.person('Kim');
    final gbl = await f.substance('GBL');
    await f.scene(persons: [jacke, kim], substances: [gbl]);

    await f.tap(find.byKey(ProtocolFixture.card(jacke)));
    await tester.tap(find.byKey(ProtocolFixture.button(gbl)));
    // The entry is written and the bar is there - no time has passed.
    await f.app.settle(tester);
    expect(_inLane, findsOneWidget);
    await tester.tap(find.byKey(InlineUndoBar.undoKey));
    await tester.tap(find.byKey(InlineUndoBar.secondaryKey));
    await f.app.settle(tester);
    expect(await f.entries(), hasLength(1));
    expect(find.text(Strings.protocolEditEntry), findsNothing);
    expect(_inLane, findsOneWidget);

    // A moment later it works.
    await f.settle();
    await f.tap(find.byKey(InlineUndoBar.undoKey));
    expect(await f.entries(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Details" opens the sheet for that entry and closes the bar', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    final jacke = await f.person('Jacke');
    final gbl = await f.substance('GBL');
    await f.scene(persons: [jacke], substances: [gbl]);

    await f.tap(find.byKey(ProtocolFixture.button(gbl)));
    await f.tap(find.byKey(InlineUndoBar.secondaryKey));
    expect(find.text(Strings.protocolEditEntry), findsOneWidget);
    expect(find.byKey(_bar), findsNothing);
    expect(await f.entries(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('left-handed: the undo button leads; narrow tiles stack the '
      'bar without overflow', (tester) async {
    final f = await ProtocolFixture.pump(
      tester,
      prefs: const UiPrefs(leftHanded: true, buttonScale: 1.5),
      tileSize: const Size(220, 420),
    );
    final jacke = await f.person('Jacke mit einem ziemlich langen Namen');
    final gbl = await f.substance('GBL');
    await f.scene(persons: [jacke], substances: [gbl]);

    await f.tap(find.byKey(ProtocolFixture.button(gbl)));
    expect(tester.takeException(), isNull);
    expect(find.byKey(_bar), findsOneWidget);
    final bar = tester.getRect(find.byKey(_bar));
    final undo = tester.getRect(find.byKey(InlineUndoBar.undoKey));
    final details = tester.getRect(find.byKey(InlineUndoBar.secondaryKey));
    // In reading order (the buttons wrap in a tile this narrow).
    expect(
      undo.top < details.top ||
          (undo.top == details.top && undo.left < details.left),
      isTrue,
    );
    expect(undo.left, greaterThanOrEqualTo(bar.left));
    expect(details.right, lessThanOrEqualTo(bar.right));
    // The bar was scrolled into view inside the tile.
    final lane = tester.getRect(find.byType(ProtocolLane));
    expect(bar.bottom, lessThanOrEqualTo(lane.bottom));
    expect(tester.takeException(), isNull);
  });
}
