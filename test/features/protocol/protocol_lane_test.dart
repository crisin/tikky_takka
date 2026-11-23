import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/protocol/protocol_lane.dart';
import 'package:tikky_takka/features/protocol/protocol_session_screen.dart';
import 'package:tikky_takka/features/protocol/protocol_strings.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../../support/test_app.dart';
import 'protocol_test_support.dart';

void main() {
  testWidgets('an idle protocol lane invites the first entry', (tester) async {
    final f = await ProtocolFixture.pump(tester);

    expect(find.text('Zelt'), findsOneWidget);
    expect(find.text(Strings.modeProtocol), findsOneWidget);
    expect(find.text(Strings.protocolEmpty), findsOneWidget);
    expect(find.text(ProtocolStrings.tapToAdd), findsOneWidget);
    expect(find.byKey(const ValueKey('protocol-add')), findsOneWidget);
    // No session yet: nothing to list or to finish.
    expect(find.byTooltip(ProtocolStrings.showEntries), findsNothing);
    expect(find.byTooltip(ProtocolStrings.finishSession), findsNothing);
    expect(await f.entries(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the primary button is a large tap target', (tester) async {
    await ProtocolFixture.pump(tester);
    final context = tester.element(find.byType(ProtocolLane));
    final size = tester.getSize(find.byKey(const ValueKey('protocol-add')));
    expect(size.width, greaterThanOrEqualTo(context.tikky.sizes.bigTapTarget));
    expect(size.height, greaterThanOrEqualTo(context.tikky.sizes.bigTapTarget));
  });

  testWidgets('shows last entry, time since and the remaining lockout per '
      'person', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final sam = await f.person('Sam');
    // The lockout is a value the user typed in; the app has none.
    final water = await f.substance('Wasser', lockoutMs: 4 * hourMs);
    final tea = await f.substance('Tee');

    await f.entry(personId: alex.id, substanceId: water.id, amount: '0,5 l');
    await f.settle();
    expect(find.text('Alex · gerade eben'), findsOneWidget);

    await f.advance(const Duration(hours: 1, minutes: 12));
    await f.entry(personId: sam.id, substanceId: tea.id, amount: '1 Tasse');
    await f.settle();
    await f.advance(const Duration(minutes: 30));

    expect(find.text('Alex · vor 1 h 42 min'), findsOneWidget);
    expect(find.text('Wasser · 0,5 l'), findsOneWidget);
    expect(
      find.text('Wasser: frühestens wieder in 2 h 18 min'),
      findsOneWidget,
    );
    expect(find.text('Sam · vor 30 min'), findsOneWidget);
    expect(find.text('Tee · 1 Tasse'), findsOneWidget);
    // Tee has no lockout: exactly one lockout line in total.
    expect(find.textContaining('frühestens wieder in'), findsOneWidget);
    expect(find.text(ProtocolStrings.entryCount(2)), findsOneWidget);

    // The most recent person comes first (left of or above the other).
    final samAt = tester.getTopLeft(
      find.byKey(ValueKey('person-card-${sam.id}')),
    );
    final alexAt = tester.getTopLeft(
      find.byKey(ValueKey('person-card-${alex.id}')),
    );
    expect(
      samAt.dy < alexAt.dy || (samAt.dy == alexAt.dy && samAt.dx < alexAt.dx),
      isTrue,
    );

    // Once the lockout is over its line disappears.
    await f.advance(const Duration(hours: 2, minutes: 18));
    expect(find.text('Alex · vor 4 h'), findsOneWidget);
    expect(find.textContaining('frühestens wieder in'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entries without person or substance are shown neutrally', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    await f.entry();
    await f.settle();

    expect(
      find.text(ProtocolStrings.personJustNow(Strings.protocolNoPerson)),
      findsOneWidget,
    );
    expect(find.text(Strings.protocolNoSubstance), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finishing a session needs no confirmation and can be undone', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    await f.entry(personId: alex.id);
    await f.settle();

    await f.tap(find.byTooltip(ProtocolStrings.finishSession));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(ProtocolStrings.sessionFinished), findsOneWidget);
    expect(find.text(Strings.protocolEmpty), findsOneWidget);
    expect(await f.run(() => f.commands.getOpenSession(f.track.id)), isNull);

    await f.tap(find.text(Strings.undo));
    expect(find.text('Alex · gerade eben'), findsOneWidget);
    expect(await f.entries(), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the entry list deletes with undo and closes the session', (
    tester,
  ) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final water = await f.substance('Wasser');
    await f.entry(personId: alex.id, substanceId: water.id, amount: '0,5 l');
    await f.advance(const Duration(minutes: 5));
    await f.entry(personId: alex.id, substanceId: water.id, amount: '1 l');
    await f.settle();

    await f.tap(find.byTooltip(ProtocolStrings.showEntries));
    expect(find.byType(ProtocolSessionScreen), findsOneWidget);
    expect(find.text('Alex · Wasser · 0,5 l'), findsOneWidget);
    expect(find.text('Alex · Wasser · 1 l'), findsOneWidget);
    expect(find.text(ProtocolStrings.neutralNote), findsOneWidget);

    // Delete the newest entry: no dialog, an undo snackbar instead.
    await f.tap(find.byTooltip(ProtocolStrings.deleteEntry).first);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Alex · Wasser · 1 l'), findsNothing);
    expect(find.text(Strings.protocolDeleted), findsOneWidget);
    expect(await f.entries(), hasLength(1));

    await f.tap(find.text(Strings.undo));
    expect(find.text('Alex · Wasser · 1 l'), findsOneWidget);
    expect(await f.entries(), hasLength(2));

    // "Sitzung beenden" leaves the screen and closes the session.
    await f.tap(find.byKey(const ValueKey('session-finish')));
    expect(find.byType(ProtocolSessionScreen), findsNothing);
    expect(await f.run(() => f.commands.getOpenSession(f.track.id)), isNull);
    final history = await f.run(
      () => f.container
          .read(historyRepositoryProvider)
          .getSessions(HistoryFilter.all),
    );
    expect(history, hasLength(1));
    expect(
      history.single.events.where((e) => e.type == EventType.entry),
      hasLength(2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the entry list shows the time between entries and deletes '
      'with a swipe, with undo', (tester) async {
    final f = await ProtocolFixture.pump(tester);
    final alex = await f.person('Alex');
    final water = await f.substance('Wasser');
    await f.entry(personId: alex.id, substanceId: water.id, amount: '0,5 l');
    await f.advance(const Duration(minutes: 25));
    await f.entry(personId: alex.id, substanceId: water.id, amount: '1 l');
    await f.settle();
    await f.tap(find.byTooltip(ProtocolStrings.showEntries));

    // Newest first, the gap between them.
    final gap = find.text(ProtocolStrings.gapEarlier('25 min'));
    expect(gap, findsOneWidget);
    final newer = find.text('Alex · Wasser · 1 l');
    final older = find.text('Alex · Wasser · 0,5 l');
    expect(tester.getTopLeft(newer).dy, lessThan(tester.getTopLeft(gap).dy));
    expect(tester.getTopLeft(gap).dy, lessThan(tester.getTopLeft(older).dy));

    // Swipe to the leading edge: gone at once, "Rückgängig" brings it back.
    await tester.drag(newer, const Offset(-500, 0));
    await f.settle();
    expect(newer, findsNothing);
    expect(gap, findsNothing);
    expect(find.text(Strings.protocolDeleted), findsOneWidget);
    expect(await f.entries(), hasLength(1));
    await f.tap(find.text(Strings.undo));
    expect(newer, findsOneWidget);
    expect(await f.entries(), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('left-handed layout puts the primary button on the left', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    await app.pumpWidget(
      tester,
      const ProtocolHost(),
      prefs: UiPrefs.defaults.copyWith(leftHanded: true),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProtocolHost)),
    );
    await tester.runAsync(() async {
      final set = await container
          .read(setRepositoryProvider)
          .createSet(name: 'Festival');
      await container
          .read(trackRepositoryProvider)
          .createTrack(
            setId: set.id,
            name: 'Zelt',
            config: const ProtocolConfig(),
          );
    });
    await app.settle(tester);

    final button = tester.getCenter(find.byKey(const ValueKey('protocol-add')));
    final text = tester.getCenter(find.text(Strings.protocolEmpty));
    expect(button.dx, lessThan(text.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lane in a tile of fixed height does not overflow', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    await app.pumpWidget(
      tester,
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) {
            final tracks =
                ref.watch(allTracksProvider).value ?? const <Track>[];
            if (tracks.isEmpty) return const SizedBox.shrink();
            return Center(
              child: SizedBox(
                width: 300,
                height: 150,
                child: ProtocolLane(track: tracks.first),
              ),
            );
          },
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Consumer)),
    );
    await tester.runAsync(() async {
      final set = await container
          .read(setRepositoryProvider)
          .createSet(name: 'Festival');
      final track = await container
          .read(trackRepositoryProvider)
          .createTrack(
            setId: set.id,
            name: 'Zelt',
            config: const ProtocolConfig(),
          );
      final people = container.read(peopleRepositoryProvider);
      final substance = await people.createSubstance(
        name: 'Wasser',
        lockoutMs: 2 * hourMs,
      );
      for (final name in ['Alex', 'Sam', 'Kim', 'Noa', 'Uli']) {
        final person = await people.createPerson(name: name);
        await container
            .read(trackCommandsProvider)
            .addEntry(
              track.id,
              personId: person.id,
              substanceId: substance.id,
              amount: '0,5 l',
            );
      }
    });
    await app.settle(tester);

    expect(find.byType(ProtocolLane), findsOneWidget);
    expect(find.textContaining('Alex'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
