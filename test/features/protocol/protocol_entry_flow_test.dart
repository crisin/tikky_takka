import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/protocol/entry_edit_sheet.dart';
import 'package:tikky_takka/features/protocol/protocol_people_screen.dart';
import 'package:tikky_takka/features/protocol/protocol_strings.dart';
import 'package:tikky_takka/features/protocol/protocol_widgets.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../../support/test_app.dart';
import 'protocol_test_support.dart';

const _add = ValueKey('protocol-add');
const _save = ValueKey('save-entry');

void main() {
  testWidgets('quick entry: add person and substance inline, save, undo', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);

    await f.tap(find.byKey(_add));
    expect(find.text(Strings.protocolNewEntry), findsOneWidget);
    expect(find.text(Strings.protocolWho), findsOneWidget);
    expect(find.text(Strings.protocolWhat), findsOneWidget);
    // Both lists start empty: the app ships no persons or substances.
    expect(find.byType(ProtocolChoice), findsNWidgets(5));

    // New person, typed inline.
    await f.tap(find.byKey(const ValueKey('add-person')));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('new-person')),
        matching: find.byType(TextField),
      ),
      'Alex',
    );
    await f.tap(find.byTooltip(ProtocolStrings.confirmAdd));
    final persons = await f.run(() => f.people.getPersons());
    expect(persons.single.name, 'Alex');
    expect(
      tester
          .widget<ProtocolChoice>(
            find.byKey(ValueKey('person-${persons.single.id}')),
          )
          .selected,
      isTrue,
    );

    // New substance, typed inline; it gets no lockout from the app.
    await f.tap(find.byKey(const ValueKey('add-substance')));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('new-substance')),
        matching: find.byType(TextField),
      ),
      'Wasser',
    );
    await f.tap(find.byTooltip(ProtocolStrings.confirmAdd));
    final substances = await f.run(() => f.people.getSubstances());
    expect(substances.single.name, 'Wasser');
    expect(substances.single.lockoutMs, isNull);

    await tester.enterText(find.byKey(const ValueKey('amount')), '0,5 l');
    await tester.enterText(find.byKey(const ValueKey('note')), 'am Zelt');
    await f.tap(find.byKey(_save));

    // Saved without any confirmation dialog; the sheet is gone.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(Strings.protocolNewEntry), findsNothing);
    expect(find.text(Strings.protocolSaved), findsOneWidget);
    expect(find.text('Alex · gerade eben'), findsOneWidget);
    expect(find.text('Wasser · 0,5 l'), findsOneWidget);

    final entries = await f.entries();
    expect(entries, hasLength(1));
    expect(entries.single.personId, persons.single.id);
    expect(entries.single.substanceId, substances.single.id);
    expect(entries.single.amount, '0,5 l');
    expect(entries.single.note, 'am Zelt');
    expect(entries.single.at, f.app.clock.nowMs());

    // "Rückgängig" takes the entry back, and with it the session it opened.
    await f.tap(find.text(Strings.undo));
    expect(find.text(Strings.protocolEmpty), findsOneWidget);
    expect(await f.run(() => f.commands.getOpenSession(f.track.id)), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('earlier amounts of the chosen substance are offered', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final water = await f.substance('Wasser');
    final tea = await f.substance('Tee');
    await f.entry(personId: alex.id, substanceId: water.id, amount: '0,5 l');
    await f.entry(personId: alex.id, substanceId: tea.id, amount: '1 Tasse');
    await f.settle();

    await f.tap(find.byKey(_add));
    // Nothing chosen yet: every amount typed before is offered.
    expect(find.byKey(const ValueKey('amount-0,5 l')), findsOneWidget);
    expect(find.byKey(const ValueKey('amount-1 Tasse')), findsOneWidget);

    await f.tap(find.byKey(ValueKey('substance-${water.id}')));
    expect(find.byKey(const ValueKey('amount-0,5 l')), findsOneWidget);
    // An amount typed for another substance is not carried over.
    expect(find.byKey(const ValueKey('amount-1 Tasse')), findsNothing);

    await f.tap(find.byKey(const ValueKey('amount-0,5 l')));
    await f.tap(find.byKey(_save));

    final entries = await f.entries();
    expect(entries, hasLength(3));
    expect(entries.last.personId, isNull);
    expect(entries.last.substanceId, water.id);
    expect(entries.last.amount, '0,5 l');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the time of a new entry can be moved back', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');

    await f.tap(find.byKey(_add));
    await f.tap(find.byKey(ValueKey('person-${alex.id}')));
    await f.tap(find.byKey(const ValueKey('time-earlier')));
    await f.tap(find.byKey(const ValueKey('time-earlier')));
    expect(find.byKey(const ValueKey('entry-time')), findsOneWidget);
    expect(find.textContaining('vor 10 min'), findsOneWidget);
    await f.tap(find.byKey(_save));

    final entries = await f.entries();
    expect(entries.single.at, f.app.clock.nowMs() - 10 * minuteMs);
    expect(find.text('Alex · vor 10 min'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sheet shows the user-set lockout but never blocks saving', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final water = await f.substance('Wasser', lockoutMs: 2 * hourMs);
    await f.entry(personId: alex.id, substanceId: water.id, amount: '0,5 l');
    await f.settle();
    await f.advance(const Duration(minutes: 30));

    // "+": nothing is chosen until the user taps it.
    await f.tap(find.byKey(_add));
    await f.tap(find.byKey(ValueKey('person-${alex.id}')));
    expect(
      tester
          .widget<ProtocolChoice>(find.byKey(ValueKey('person-${alex.id}')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ProtocolChoice>(find.byKey(ValueKey('substance-${water.id}')))
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
    await f.tap(find.byKey(ValueKey('substance-${water.id}')));
    expect(
      find.text('Alex · ${Strings.lockoutRemaining('1 h 30 min')}'),
      findsOneWidget,
    );
    await f.tap(find.byKey(_save));

    expect(await f.entries(), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an entry can be edited, including its time, and deleted', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final sam = await f.person('Sam');
    final water = await f.substance('Wasser');
    final original = (await f.entry(
      personId: alex.id,
      substanceId: water.id,
      amount: '0,5 l',
    ))!;
    await f.settle();
    await f.advance(const Duration(minutes: 20));

    await f.tap(find.byTooltip(ProtocolStrings.showEntries));
    await f.tap(find.text('Alex · Wasser · 0,5 l'));
    // The sheet "Ändern" of an older entry.
    expect(find.text('Wasser · Alex'), findsOneWidget);
    expect(find.byKey(EntrySheetKeys.again), findsOneWidget);

    // Every change is written right away; "Fertig" only closes.
    await f.tap(find.byKey(EntrySheetKeys.rowPerson));
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
    await f.tap(find.byKey(_save));

    expect(find.text(ProtocolStrings.entryUpdated), findsOneWidget);
    expect(find.text('Sam · Wasser · 1 l'), findsOneWidget);
    var entries = await f.entries();
    expect(entries.single.id, original.id);
    expect(entries.single.personId, sam.id);
    expect(entries.single.amount, '1 l');
    expect(entries.single.at, original.at - 5 * minuteMs);

    // Undo restores the entry as it was.
    await f.tap(find.text(Strings.undo));
    entries = await f.entries();
    expect(entries.single.personId, alex.id);
    expect(entries.single.amount, '0,5 l');
    expect(entries.single.at, original.at);

    // Delete from the sheet: no dialog, undo snackbar.
    await f.tap(find.text('Alex · Wasser · 0,5 l'));
    await f.tap(find.byKey(EntrySheetKeys.delete));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(Strings.protocolDeleted), findsOneWidget);
    expect(await f.entries(), isEmpty);
    await f.tap(find.text(Strings.undo));
    expect((await f.entries()).single, isA<TrackEvent>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Ändern": earlier amounts as chips, one row open at a '
      'time, "Nochmal jetzt" logs the entry again', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final water = await f.substance('Wasser');
    await f.entry(personId: alex.id, substanceId: water.id, amount: '1 l');
    await f.advance(const Duration(minutes: 10));
    final original = (await f.entry(personId: alex.id, substanceId: water.id))!;
    await f.settle();
    await f.advance(const Duration(minutes: 26));

    await f.tap(find.byTooltip(ProtocolStrings.showEntries));
    await f.tap(find.text('Alex · Wasser'));
    // The gap to the person's previous entry of that substance.
    expect(
      find.textContaining(ProtocolStrings.afterPrevious('10 min')),
      findsOneWidget,
    );

    // The amount typed before is offered; tapping it again takes it off.
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
    expect(entries, hasLength(3));
    expect(entries.last.id, isNot(original.id));
    expect(entries.last.at, f.app.clock.nowMs());
    expect(entries.last.personId, alex.id);
    expect(entries.last.substanceId, water.id);
    expect(entries.last.note, 'am Zelt');
    expect(find.text(Strings.protocolSaved), findsOneWidget);
    await f.tap(find.text(Strings.undo));
    expect(await f.entries(), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('choices in the sheet are large tap targets', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    await f.settle();
    await f.tap(find.byKey(_add));

    final context = tester.element(find.byKey(_save));
    final big = context.tikky.sizes.bigTapTarget;
    expect(
      tester.getSize(find.byKey(ValueKey('person-${alex.id}'))).height,
      greaterThanOrEqualTo(big),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('add-substance'))).height,
      greaterThanOrEqualTo(big),
    );
    expect(tester.getSize(find.byKey(_save)).height, greaterThanOrEqualTo(big));
    expect(tester.takeException(), isNull);
  });

  testWidgets('persons and substances are managed by the user only', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    await app.pumpWidget(tester, const ProtocolPeopleScreen());
    final people = ProviderScope.containerOf(
      tester.element(find.byType(ProtocolPeopleScreen)),
    ).read(peopleRepositoryProvider);
    Future<void> tap(Finder finder) async {
      await tester.tap(finder);
      await settleUi(tester, app);
    }

    Future<List<Substance>> substances() async => (await tester.runAsync(
      () => people.getSubstances(includeArchived: true),
    ))!;

    // Empty lists and the neutral note.
    expect(find.text(ProtocolStrings.personsEmptyTitle), findsOneWidget);
    expect(find.text(ProtocolStrings.neutralNote), findsOneWidget);

    // Add a substance; the lockout field starts without any value.
    await tap(find.text(Strings.substances));
    expect(find.text(ProtocolStrings.substancesEmptyTitle), findsOneWidget);
    await tap(find.byTooltip(ProtocolStrings.newSubstance));
    expect(find.text(Strings.lockoutNone), findsOneWidget);
    expect(find.text(Strings.lockoutHint), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('editor-name')), 'Wasser');
    await tester.pump();
    await tap(find.byKey(const ValueKey('editor-save')));

    expect((await substances()).single.name, 'Wasser');
    expect((await substances()).single.lockoutMs, isNull);
    expect(find.text('Wasser'), findsOneWidget);

    // Remove it from the list: no dialog, undo snackbar.
    await tap(find.text('Wasser'));
    await tap(find.text(ProtocolStrings.remove));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(ProtocolStrings.substanceRemoved), findsOneWidget);
    expect((await substances()).single.archived, isTrue);
    expect(find.text(ProtocolStrings.removedSection), findsOneWidget);

    await tap(find.text(Strings.undo));
    expect((await substances()).single.archived, isFalse);
    expect(find.text(ProtocolStrings.removedSection), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
