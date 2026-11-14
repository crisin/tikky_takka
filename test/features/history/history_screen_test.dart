import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/history/history_screen.dart';
import 'package:tikky_takka/features/history/history_session_list.dart';
import 'package:tikky_takka/features/history/history_strings.dart';
import 'package:tikky_takka/features/history/session_detail_page.dart';
import 'package:tikky_takka/l10n/strings.dart';

import '../../support/test_app.dart';
import 'history_fixture.dart';

void main() {
  late TestApp app;
  late HistoryFixture fx;

  Future<void> setUpApp(WidgetTester tester) async {
    app = await TestApp.create(tester, startMs: wednesdayMorning);
    fx = HistoryFixture(app);
  }

  Future<void> pumpHistory(
    WidgetTester tester, {
    Size surfaceSize = TestApp.phoneSize,
  }) async {
    await app.pumpWidget(
      tester,
      const HistoryScreen(),
      surfaceSize: surfaceSize,
    );
    await settleUi(tester, app);
  }

  HistoryFilter currentFilter(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HistoryScreen)))
          .read(historyFilterProvider);

  testWidgets('empty history shows the friendly empty state', (tester) async {
    await setUpApp(tester);
    await pumpHistory(tester);

    expect(find.text(Strings.historyEmptyTitle), findsOneWidget);
    expect(find.text(Strings.historyEmptyBody), findsOneWidget);
    expect(find.byType(SessionTile), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sessions are grouped by day with day totals', (tester) async {
    await setUpApp(tester);
    await fx.run(tester, fx.seedTwoDays);
    await pumpHistory(tester);

    expect(find.text(Strings.today), findsOneWidget);
    expect(find.text(Strings.yesterday), findsOneWidget);
    expect(find.text('Tagessumme 35 min'), findsOneWidget);
    expect(find.text('Tagessumme 1 h'), findsOneWidget);
    expect(find.text('2 Sitzungen'), findsOneWidget);
    expect(find.text('1 Sitzung'), findsOneWidget);

    expect(find.byType(SessionTile), findsNWidgets(3));
    // Newest first: today's tea, today's work, yesterday's work.
    final names = [
      for (final tile in tester.widgetList<SessionTile>(
        find.byType(SessionTile),
      ))
        tile.item.track!.name,
    ];
    expect(names, ['Tee', 'Arbeit', 'Arbeit']);
    expect(find.text('09:30 – 09:35 · Timer'), findsOneWidget);
    expect(find.text('09:00 – 09:30 · Stoppuhr'), findsOneWidget);
    expect(find.text('09:00 – 10:00 · Stoppuhr'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('30:00'), findsOneWidget);
    expect(find.text('1:00:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout keeps the content readable', (tester) async {
    await setUpApp(tester);
    await fx.run(tester, fx.seedTwoDays);
    await pumpHistory(tester, surfaceSize: TestApp.desktopSize);

    expect(find.byType(SessionTile), findsNWidgets(3));
    final width = tester.getSize(find.byType(SessionTile).first).width;
    expect(width, lessThanOrEqualTo(720));
    expect(tester.takeException(), isNull);
  });

  group('filter bar', () {
    testWidgets('set filter narrows the list and can be reset', (tester) async {
      await setUpApp(tester);
      final data = await fx.run(tester, fx.seedTwoDays);
      await pumpHistory(tester);

      await tester.tap(find.text(Strings.filterSet));
      await settleUi(tester, app);
      expect(find.text(HistoryStrings.filterSetTitle), findsOneWidget);
      await tester.tap(find.text('Küche'));
      await settleUi(tester, app);

      expect(currentFilter(tester).setId, data.kitchen.id);
      expect(find.byType(SessionTile), findsOneWidget);
      expect(find.text('Tee'), findsOneWidget);
      expect(find.text('Tagessumme 5 min'), findsOneWidget);
      // The chip now names the set.
      expect(find.text('Küche'), findsOneWidget);
      expect(find.text(Strings.filterSet), findsNothing);

      await tester.tap(find.byTooltip(Strings.filterReset));
      await settleUi(tester, app);
      expect(currentFilter(tester), HistoryFilter.all);
      expect(find.byType(SessionTile), findsNWidgets(3));
      expect(find.byTooltip(Strings.filterReset), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('track filter is a multi selection', (tester) async {
      await setUpApp(tester);
      final data = await fx.run(tester, fx.seedTwoDays);
      await pumpHistory(tester);

      await tester.tap(find.text(Strings.filterTracks));
      await settleUi(tester, app);
      expect(find.text(HistoryStrings.filterTracksTitle), findsOneWidget);
      // Set names tell the tracks apart.
      expect(find.text('Stoppuhr · Büro'), findsOneWidget);
      expect(find.text('Timer · Küche'), findsOneWidget);

      await tester.tap(withText<CheckboxListTile>('Arbeit'));
      await settleUi(tester, app);
      await tester.tap(find.text(Strings.done));
      await settleUi(tester, app);

      expect(currentFilter(tester).trackIds, {data.work.id});
      expect(find.byType(SessionTile), findsNWidgets(2));
      expect(find.text('Tee'), findsNothing);

      // Add the second track: the chip then counts.
      await tester.tap(find.byTooltip(Strings.filterTracks));
      await settleUi(tester, app);
      await tester.tap(withText<CheckboxListTile>('Tee'));
      await settleUi(tester, app);
      await tester.tap(find.text(Strings.done));
      await settleUi(tester, app);

      expect(currentFilter(tester).trackIds, {data.work.id, data.tea.id});
      expect(find.text('2 Spuren'), findsOneWidget);
      expect(find.byType(SessionTile), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('date presets filter by day; no match offers a reset', (
      tester,
    ) async {
      await setUpApp(tester);
      await fx.run(tester, fx.seedTwoDays);
      await pumpHistory(tester);

      await tester.tap(find.text(Strings.filterDateRange));
      await settleUi(tester, app);
      for (final label in [
        Strings.today,
        Strings.yesterday,
        HistoryStrings.presetThisWeek,
        HistoryStrings.presetLast7Days,
        HistoryStrings.presetThisMonth,
        HistoryStrings.presetLastMonth,
        HistoryStrings.presetCustom,
      ]) {
        expect(withText<ListTile>(label), findsOneWidget, reason: label);
      }
      await tester.tap(withText<ListTile>(Strings.yesterday));
      await settleUi(tester, app);

      final filter = currentFilter(tester);
      expect(filter.fromMs, DateTime(2026, 11, 10).millisecondsSinceEpoch);
      expect(filter.toMs, DateTime(2026, 11, 11).millisecondsSinceEpoch);
      expect(find.byType(SessionTile), findsOneWidget);
      expect(find.text('Tagessumme 1 h'), findsOneWidget);

      // The chip shows the preset; pick one without any session.
      await tester.tap(find.byTooltip(Strings.filterDateRange));
      await settleUi(tester, app);
      await tester.tap(withText<ListTile>(HistoryStrings.presetLastMonth));
      await settleUi(tester, app);

      expect(find.byType(SessionTile), findsNothing);
      expect(find.text(Strings.historyNoMatchTitle), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, Strings.filterReset));
      await settleUi(tester, app);
      expect(find.byType(SessionTile), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });

  group('sums', () {
    testWidgets('per day and per week, per track', (tester) async {
      await setUpApp(tester);
      await fx.run(tester, fx.seedTwoDays);
      await pumpHistory(tester);

      await tester.tap(find.text(Strings.sumsDaily));
      await settleUi(tester, app);
      expect(find.byType(SessionTile), findsNothing);
      expect(find.text(Strings.today), findsOneWidget);
      expect(find.text(Strings.yesterday), findsOneWidget);
      expect(find.text('Tagessumme 35 min'), findsOneWidget);
      expect(find.text('Tagessumme 1 h'), findsOneWidget);
      expect(find.text('0:30:00'), findsOneWidget);
      expect(find.text('0:05:00'), findsOneWidget);
      expect(find.text('1:00:00'), findsOneWidget);

      await tester.tap(find.text(Strings.sumsWeekly));
      await settleUi(tester, app);
      expect(find.text('KW 46 · 09.11.2026 – 15.11.2026'), findsOneWidget);
      expect(find.text('Wochensumme 1 h 35 min'), findsOneWidget);
      expect(find.text('3 Sitzungen'), findsOneWidget);
      // Work: two sessions, 1 h 30 min in that week.
      expect(find.text('1:30:00'), findsOneWidget);
      expect(find.text('Stoppuhr · 2 Sitzungen'), findsOneWidget);
      expect(find.text('0:05:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sums honour the filter', (tester) async {
      await setUpApp(tester);
      await fx.run(tester, fx.seedTwoDays);
      await pumpHistory(tester);

      await tester.tap(find.text(Strings.sumsWeekly));
      await settleUi(tester, app);
      await tester.tap(find.text(Strings.filterSet));
      await settleUi(tester, app);
      await tester.tap(find.text('Küche'));
      await settleUi(tester, app);

      expect(find.text('Wochensumme 5 min'), findsOneWidget);
      expect(find.text('1:30:00'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('session list actions', () {
    testWidgets('swiping a session away deletes it, with undo', (tester) async {
      await setUpApp(tester);
      await fx.run(tester, fx.seedTwoDays);
      await pumpHistory(tester);

      await tester.drag(find.text('Tee'), const Offset(-380, 0));
      await settleUi(tester, app);

      expect(find.text('Tee'), findsNothing);
      expect(find.byType(SessionTile), findsNWidgets(2));
      expect(find.text(Strings.sessionDeleted), findsOneWidget);
      expect(find.text('Tagessumme 30 min'), findsOneWidget);
      expect(
        await fx.run(tester, () => fx.history.getSessions(HistoryFilter.all)),
        hasLength(2),
      );

      await tester.tap(find.text(Strings.undo));
      await settleUi(tester, app);
      expect(find.text('Tee'), findsOneWidget);
      expect(find.byType(SessionTile), findsNWidgets(3));
      expect(find.text('Tagessumme 35 min'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long-press offers note and delete', (tester) async {
      await setUpApp(tester);
      final data = await fx.run(tester, fx.seedTwoDays);
      await pumpHistory(tester);

      await tester.longPress(find.text('Tee'));
      await settleUi(tester, app);
      expect(find.text(HistoryStrings.addNote), findsOneWidget);
      expect(find.text(Strings.deleteSession), findsOneWidget);

      await tester.tap(find.text(HistoryStrings.addNote));
      await settleUi(tester, app);
      await tester.enterText(find.byType(TextField), 'Grüner Tee; lecker');
      await tester.tap(find.text(Strings.save));
      await settleUi(tester, app);

      expect(find.text('Grüner Tee; lecker'), findsOneWidget);
      final session = await fx.run(
        tester,
        () => fx.history.getSession(data.sessionIds[2]),
      );
      expect(session!.session.note, 'Grüner Tee; lecker');

      await tester.longPress(find.text('Tee'));
      await settleUi(tester, app);
      // With a note the action reads "edit".
      expect(find.text(Strings.editNote), findsOneWidget);
      await tester.tap(find.text(Strings.deleteSession));
      await settleUi(tester, app);
      expect(find.text('Tee'), findsNothing);
      expect(find.text(Strings.sessionDeleted), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('session detail', () {
    testWidgets('counter: ticks with labels, delete an event with undo', (
      tester,
    ) async {
      await setUpApp(tester);
      await fx.run(tester, () async {
        final set = await fx.sets.createSet(name: 'Garten');
        final track = await fx.tracks.createTrack(
          setId: set.id,
          name: 'Tiere',
          config: const CounterConfig(labels: ['Reiher', 'Hund']),
        );
        await fx.commands.tick(track.id, label: 'Reiher');
        app.clock.advance(const Duration(seconds: 30));
        await fx.commands.tick(track.id, label: 'Hund');
        app.clock.advance(const Duration(seconds: 65));
        await fx.commands.tick(track.id, label: 'Reiher');
        app.clock.advance(const Duration(seconds: 5));
        await fx.commands.stopTrack(track.id);
      });
      await pumpHistory(tester);

      expect(find.text('09:00 – 09:01 · Zähler · 3 Tipps'), findsOneWidget);
      await tester.tap(find.text('Tiere'));
      await settleUi(tester, app);

      expect(find.byType(SessionDetailPage), findsOneWidget);
      expect(find.text('Zähler · Garten'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('Tipp 1 · Reiher'), findsOneWidget);
      expect(find.text('Tipp 2 · Hund'), findsOneWidget);
      expect(find.text('Tipp 3 · Reiher'), findsOneWidget);
      expect(find.text('Stopp'), findsOneWidget);
      // Time since the previous tick, and the per-label counts.
      expect(find.text('00:30.0'), findsOneWidget);
      expect(find.text('01:05.0'), findsOneWidget);
      expect(find.text('Reiher 2 · Hund 1'), findsOneWidget);
      expect(find.text('09:00:30'), findsOneWidget);

      // Start and stop are fixed: three events offer actions.
      final more = find.byTooltip(HistoryStrings.eventActions);
      expect(more, findsNWidgets(3));
      await tester.ensureVisible(more.at(1));
      await tester.tap(more.at(1));
      await settleUi(tester, app);
      await tester.tap(find.text(Strings.deleteEvent));
      await settleUi(tester, app);

      expect(find.text('Tipp 2 · Hund'), findsNothing);
      expect(find.text('Tipp 2 · Reiher'), findsOneWidget);
      expect(find.text(Strings.eventDeleted), findsOneWidget);
      expect(find.text('Reiher 2'), findsOneWidget);

      await tester.tap(find.text(Strings.undo));
      await settleUi(tester, app);
      expect(find.text('Tipp 2 · Hund'), findsOneWidget);
      expect(find.text('Tipp 3 · Reiher'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stopwatch: laps, pause, figures and the session note', (
      tester,
    ) async {
      await setUpApp(tester);
      await fx.run(tester, () async {
        final set = await fx.sets.createSet(name: 'Büro');
        final track = await fx.tracks.createTrack(
          setId: set.id,
          name: 'Arbeit',
          config: const StopwatchConfig(),
        );
        await fx.commands.startTrack(track.id);
        app.clock.advance(const Duration(minutes: 10));
        await fx.commands.lap(track.id);
        app.clock.advance(const Duration(minutes: 5));
        await fx.commands.pauseTrack(track.id);
        app.clock.advance(const Duration(minutes: 2));
        await fx.commands.resumeTrack(track.id);
        app.clock.advance(const Duration(minutes: 3, seconds: 5));
        await fx.commands.stopTrack(track.id);
      });
      await pumpHistory(tester);

      expect(find.text('09:00 – 09:20 · Stoppuhr · 1 Runde'), findsOneWidget);
      await tester.tap(find.text('Arbeit'));
      await settleUi(tester, app);

      expect(find.text('18:05'), findsOneWidget);
      expect(find.text('11.11.2026, 09:00'), findsOneWidget);
      expect(find.text('11.11.2026, 09:20'), findsOneWidget);
      expect(find.text('00:18:05'), findsOneWidget);
      expect(find.text('00:02:00'), findsOneWidget);
      expect(find.text('Runde 1'), findsOneWidget);
      expect(find.text('10:00.0'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Weiter'), findsOneWidget);

      // Note via the app bar action.
      await tester.tap(find.byTooltip(Strings.editNote));
      await settleUi(tester, app);
      await tester.enterText(find.byType(TextField), 'Projekt A');
      await tester.tap(find.text(Strings.save));
      await settleUi(tester, app);
      expect(find.text('Projekt A'), findsOneWidget);
      expect(find.text(HistoryStrings.addNote), findsNothing);

      // A note on a single event.
      final more = find.byTooltip(HistoryStrings.eventActions);
      await tester.ensureVisible(more.first);
      await tester.tap(more.first);
      await settleUi(tester, app);
      await tester.tap(find.text(HistoryStrings.addNote));
      await settleUi(tester, app);
      await tester.enterText(find.byType(TextField), 'erste Etappe');
      await tester.tap(find.text(Strings.save));
      await settleUi(tester, app);
      expect(find.text('erste Etappe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reminder: acknowledgements show their delay', (tester) async {
      await setUpApp(tester);
      await fx.run(tester, () async {
        final set = await fx.sets.createSet(name: 'Alltag');
        final track = await fx.tracks.createTrack(
          setId: set.id,
          name: 'Trinken',
          config: const ReminderConfig(intervalMs: 10 * 60 * 1000),
        );
        await fx.commands.startTrack(track.id);
        // Due after 10 minutes, acknowledged 3 minutes late.
        app.clock.advance(const Duration(minutes: 13));
        await fx.commands.ack(track.id);
        // The next one is acknowledged right when it becomes due.
        app.clock.advance(const Duration(minutes: 10));
        await fx.commands.ack(track.id);
        app.clock.advance(const Duration(minutes: 1));
        await fx.commands.stopTrack(track.id);
      });
      await pumpHistory(tester);

      await tester.tap(find.text('Trinken'));
      await settleUi(tester, app);
      expect(find.text('Bestätigt'), findsNWidgets(2));
      expect(find.text('3 min nach Fälligkeit bestätigt'), findsOneWidget);
      expect(find.text(HistoryStrings.ackOnTime), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('protocol: entries show who, what and how much', (
      tester,
    ) async {
      await setUpApp(tester);
      await fx.run(tester, () async {
        final set = await fx.sets.createSet(name: 'Festival');
        final track = await fx.tracks.createTrack(
          setId: set.id,
          name: 'Protokoll',
          config: const ProtocolConfig(),
        );
        final alex = await fx.people.createPerson(name: 'Alex');
        final water = await fx.people.createSubstance(name: 'Wasser');
        await fx.commands.addEntry(
          track.id,
          personId: alex.id,
          substanceId: water.id,
          amount: '0,5 l',
          note: 'nach dem Tanzen',
        );
        app.clock.advance(const Duration(minutes: 1));
        await fx.commands.addEntry(track.id, amount: '1 Stück');
        app.clock.advance(const Duration(minutes: 1));
        await fx.commands.stopTrack(track.id);
      });
      await pumpHistory(tester);

      expect(find.textContaining('2 Einträge'), findsOneWidget);
      await tester.tap(find.text('Protokoll'));
      await settleUi(tester, app);
      expect(find.text('Alex · Wasser'), findsOneWidget);
      expect(find.text('0,5 l'), findsOneWidget);
      expect(find.text('nach dem Tanzen'), findsOneWidget);
      expect(
        find.text(
          '${Strings.protocolNoPerson} · ${Strings.protocolNoSubstance}',
        ),
        findsOneWidget,
      );
      expect(find.text('1 Stück'), findsOneWidget);

      // Entries are edited in the protocol sheet, not with a plain note.
      final more = find.byTooltip(HistoryStrings.eventActions);
      await tester.ensureVisible(more.first);
      await tester.tap(more.first);
      await settleUi(tester, app);
      expect(find.text(HistoryStrings.editEntry), findsOneWidget);
      expect(find.text(Strings.deleteEvent), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('deleting from the detail page returns to the list, with '
        'undo', (tester) async {
      await setUpApp(tester);
      await fx.run(tester, fx.seedTwoDays);
      await pumpHistory(tester);

      await tester.tap(find.text('Tee'));
      await settleUi(tester, app);
      expect(find.byType(SessionDetailPage), findsOneWidget);

      await tester.tap(find.byTooltip(Strings.deleteSession));
      await settleUi(tester, app);
      expect(find.byType(SessionDetailPage), findsNothing);
      expect(find.text('Tee'), findsNothing);
      expect(find.text(Strings.sessionDeleted), findsOneWidget);

      await tester.tap(find.text(Strings.undo));
      await settleUi(tester, app);
      expect(find.text('Tee'), findsOneWidget);
      expect(find.byType(SessionTile), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });
}
