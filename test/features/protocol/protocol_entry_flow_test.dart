import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/features/protocol/entry_edit_sheet.dart';
import 'package:tikky_takka/features/protocol/protocol_strings.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import 'protocol_test_support.dart';

void main() {
  testWidgets('a fresh entry is moved back in time with one tap', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final water = await f.substance('Wasser');
    final written = await f.entry(person: alex, substance: water);

    await f.openEdit(written, fresh: true);
    expect(find.text('Wasser · Alex'), findsOneWidget);
    expect(
      tester.widget<SheetChip>(find.byKey(EntrySheetKeys.timeNow)).selected,
      isTrue,
    );
    // "Nochmal jetzt" makes no sense for what was just written.
    expect(find.byKey(EntrySheetKeys.again), findsNothing);

    await f.tap(find.byKey(EntrySheetKeys.timeBack(10)));
    expect((await f.entries()).single.at, written.at - 10 * minuteMs);
    // Measured from when it was written, not added up.
    await f.tap(find.byKey(EntrySheetKeys.timeBack(5)));
    expect((await f.entries()).single.at, written.at - 5 * minuteMs);
    await f.tap(find.byKey(EntrySheetKeys.timeNow));
    expect((await f.entries()).single.at, written.at);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an entry can be edited, including its time, and deleted', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final sam = await f.person('Sam');
    final water = await f.substance('Wasser');
    final original = await f.entry(
      person: alex,
      substance: water,
      amount: '0,5 l',
    );
    await f.advance(const Duration(minutes: 20));

    await f.openEdit(original);
    // The sheet "Ändern" of an older entry.
    expect(find.text('Wasser · Alex'), findsOneWidget);
    expect(find.byKey(EntrySheetKeys.again), findsOneWidget);

    // Every change is written right away; "Fertig" only closes.
    await f.tap(find.byKey(EntrySheetKeys.rowPerson));
    await f.tap(find.byKey(ValueKey('person-${sam.id}')));
    expect((await f.entries()).single.personId, sam.id);
    // An entry always has a person: tapping it again changes nothing.
    await f.tap(find.byKey(ValueKey('person-${sam.id}')));
    expect((await f.entries()).single.personId, sam.id);
    await f.tap(find.byKey(EntrySheetKeys.amountOther));
    await tester.enterText(find.byKey(EntrySheetKeys.amountField), '1 l');
    // 20 minutes ago -> 25 minutes ago.
    await f.tap(find.byKey(EntrySheetKeys.timeStep(-5)));
    // Never into the future.
    for (var i = 0; i < 6; i++) {
      await f.tap(find.byKey(EntrySheetKeys.timeStep(5)));
    }
    expect((await f.entries()).single.at, f.app.clock.nowMs());
    for (var i = 0; i < 5; i++) {
      await f.tap(find.byKey(EntrySheetKeys.timeStep(-5)));
    }
    await f.tap(find.byKey(EntrySheetKeys.done));

    expect(find.text(ProtocolStrings.entryUpdated), findsOneWidget);
    var entries = await f.entries();
    expect(entries.single.id, original.id);
    expect(entries.single.personId, sam.id);
    expect(entries.single.amount, '1 l');
    expect(entries.single.at, original.at - 5 * minuteMs);

    // Undo restores the entry as it was.
    await f.tap(find.text(Strings.undo));
    entries = await f.entries();
    expect(entries.single, original);

    // Delete from the sheet: no dialog, undo snackbar.
    await f.openEdit(original);
    await f.tap(find.byKey(EntrySheetKeys.delete));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(Strings.protocolDeleted), findsOneWidget);
    expect(await f.entries(), isEmpty);
    await f.tap(find.text(Strings.undo));
    expect((await f.entries()).single, original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Ändern": earlier amounts as chips, one row open at a '
      'time, "Nochmal jetzt" logs the entry again', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final sam = await f.person('Sam');
    final water = await f.substance('Wasser');
    final tea = await f.substance('Tee');
    await f.entry(person: alex, substance: water, amount: '1 l');
    // Typed for something else: never carried over.
    await f.entry(person: sam, substance: tea, amount: '2 Tassen');
    await f.advance(const Duration(minutes: 10));
    final original = await f.entry(person: alex, substance: water);
    await f.advance(const Duration(minutes: 26));

    await f.openEdit(original);
    // The gap to the person's previous entry of that thing.
    expect(
      find.textContaining(ProtocolStrings.afterPrevious('10 min')),
      findsOneWidget,
    );

    // The amount typed before is offered; tapping it again takes it off.
    expect(find.byKey(EntrySheetKeys.amount('2 Tassen')), findsNothing);
    await f.tap(find.byKey(EntrySheetKeys.amount('1 l')));
    expect((await f.entries()).last.amount, '1 l');
    await f.tap(find.byKey(EntrySheetKeys.amount('1 l')));
    expect((await f.entries()).last.amount, isNull);

    // One row at a time.
    await f.tap(find.byKey(EntrySheetKeys.rowPerson));
    expect(find.byKey(ValueKey('person-${alex.id}')), findsOneWidget);
    await f.tap(find.byKey(EntrySheetKeys.rowNote));
    expect(find.byKey(ValueKey('person-${alex.id}')), findsNothing);
    await tester.enterText(find.byKey(EntrySheetKeys.note), 'am Zelt');
    await f.settle();
    expect((await f.entries()).last.note, 'am Zelt');

    await f.tap(find.byKey(EntrySheetKeys.again));
    final entries = await f.entries();
    expect(entries, hasLength(4));
    expect(entries.last.id, isNot(original.id));
    expect(entries.last.at, f.app.clock.nowMs());
    expect(entries.last.personId, alex.id);
    expect(entries.last.substanceId, water.id);
    expect(entries.last.note, 'am Zelt');
    expect(find.text(Strings.protocolSaved), findsOneWidget);
    await f.tap(find.text(Strings.undo));
    expect(await f.entries(), hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new thing is added inline and chosen', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final water = await f.substance('Wasser');
    final written = await f.entry(person: alex, substance: water);

    await f.openEdit(written);
    await f.tap(find.byKey(EntrySheetKeys.rowSubstance));
    final minTarget = tester
        .element(find.byKey(EntrySheetKeys.done))
        .tikky
        .sizes
        .minTapTarget;
    expect(
      tester.getSize(find.byKey(ValueKey('substance-${water.id}'))).height,
      greaterThanOrEqualTo(minTarget),
    );
    await f.tap(find.byKey(const ValueKey('add-substance')));
    await tester.enterText(find.byKey(const ValueKey('new-substance')), 'Mate');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await f.settle();

    final mate = (await f.run(f.people.getSubstances))
        .singleWhere((s) => s.name == 'Mate');
    expect((await f.entries()).single.substanceId, mate.id);
    expect(tester.takeException(), isNull);
  });
}
