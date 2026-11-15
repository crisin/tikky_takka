import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/adaptive/adaptive.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/tracks/timeline/evening/evening_view.dart';
import 'package:tikky_takka/features/tracks/timeline/period/month_view.dart';
import 'package:tikky_takka/features/tracks/timeline/period/week_view.dart';
import 'package:tikky_takka/features/tracks/timeline/timeline_mode.dart';
import 'package:tikky_takka/features/tracks/timeline/timeline_view.dart';
import 'package:tikky_takka/features/tracks/tracks_strings.dart';
import 'package:tikky_takka/features/tracks/tracks_view.dart';
import 'package:tikky_takka/l10n/formatters.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../tracks_harness.dart';

/// "Woche" and "Monat" (Pult 3.3, 3.4). The test clock starts on Tuesday,
/// 14 November 2023, in the late evening.
void main() {
  Future<({TracksHarness h, Track tent, LocalDay tuesday, LocalDay today})>
  setUp(WidgetTester tester) async {
    final h = await TracksHarness.start(
      tester,
      surfaceSize: const Size(390, 900),
    );
    final people = h.container.read(peopleRepositoryProvider);
    final jacke = await h.run(() => people.createPerson(name: 'Jacke'));
    final beer = await h.run(
      () => people.createSubstance(name: 'Bier', color: 0xFFC8A060),
    );
    final mate = await h.run(
      () => people.createSubstance(name: 'Mate', color: 0xFF40C080),
    );
    final tent = await h.addTrack(const ProtocolConfig(), name: 'Zelt');
    final commands = h.container.read(trackCommandsProvider);
    Future<void> add(Substance s) => h.run(
      () => commands.addEntry(tent.id, personId: jacke.id, substanceId: s.id),
    );
    final dayStart = h.container.read(uiPrefsProvider).dayStartMinutes;
    final tuesday = logicalDayOf(h.app.clock.nowMs(), dayStart);
    await add(beer);
    // After midnight: still Tuesday's evening.
    await h.advance(const Duration(hours: 2));
    await add(mate);
    await h.advance(const Duration(days: 1));
    await add(beer);
    await h.settle();
    return (
      h: h,
      tent: tent,
      tuesday: tuesday,
      today: logicalDayOf(h.app.clock.nowMs(), dayStart),
    );
  }

  Future<void> show(TracksHarness h, TimelineLevel level) => h.run(() async {
    await h.container
        .read(timelineChoicesProvider.notifier)
        .show(h.activeSet.id, level);
    await h.container
        .read(tracksViewsProvider.notifier)
        .show(h.activeSet.id, TracksView.timeline);
  });

  String? Function(LocalDay) countIn(WidgetTester tester) =>
      (day) => tester.widget<Text>(find.byKey(WeekKeys.count(day))).data;

  Finder text(Key key, String value) =>
      find.descendant(of: find.byKey(key), matching: find.text(value));

  testWidgets('the week: a row per day with its count, totals per thing; a '
      'tap on a day opens its evening', (tester) async {
    final (:h, :tent, :tuesday, :today) = await setUp(tester);
    await show(h, TimelineLevel.week);
    final count = countIn(tester);
    expect(find.byKey(WeekKeys.view), findsOneWidget);
    final monday = tuesday.weekStart;
    expect(text(TimelineKeys.day, Fmt.weekRange(monday)), findsOneWidget);
    expect(
      text(TimelineKeys.day, TracksStrings.weekNumber(isoWeekNumber(monday))),
      findsOneWidget,
    );
    expect(count(monday), TracksStrings.noCount);
    expect(count(tuesday), '2');
    expect(count(today), '1');
    // Days still to come have no count.
    final later = logicalDayShift(today, 1);
    expect(count(later), '');
    expect(find.text(TracksStrings.weekTotal(3)), findsOneWidget);
    expect(find.byKey(WeekKeys.total('s:')), findsNothing);
    // The week going on: no next one.
    expect(
      tester.widget<HeaderRoundButton>(find.byKey(TimelineKeys.next)).onPressed,
      isNull,
    );

    await h.tap(find.byKey(WeekKeys.day(tuesday)));
    expect(find.byKey(EveningKeys.view), findsOneWidget);
    expect(
      text(TimelineKeys.day, Fmt.dayShort(logicalDayStartMs(tuesday, 360))),
      findsOneWidget,
    );
    expect(
      h.container.read(timelineChoiceProvider(h.activeSet.id)).level,
      TimelineLevel.evening,
    );
    expect(tent.id, isNotEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the month: a calendar in four steps, what it counts, three '
      'figures', (tester) async {
    final (:h, tent: _, :tuesday, :today) = await setUp(tester);
    await show(h, TimelineLevel.month);
    expect(find.byKey(MonthKeys.view), findsOneWidget);
    final first = LocalDay(tuesday.year, tuesday.month, 1);
    expect(text(TimelineKeys.day, Fmt.monthYear(first)), findsOneWidget);
    expect(
      text(
        TimelineKeys.day,
        TracksStrings.monthCaption(TracksStrings.monthAll, current: true),
      ),
      findsOneWidget,
    );
    expect(text(MonthKeys.count, '3'), findsOneWidget);
    expect(text(MonthKeys.days, '2'), findsOneWidget);
    // From the 1st up to the day before Tuesday.
    expect(
      text(MonthKeys.pause, TracksStrings.days(tuesday.day - 1)),
      findsOneWidget,
    );
    Color fill(LocalDay day) =>
        tester.widget<Material>(find.byKey(MonthKeys.day(day))).color!;
    final t = tester.element(find.byKey(MonthKeys.view)).tikky;
    final roles = t.roles(t.colors.primary);
    // Two on Tuesday is the most: full; one is the first step.
    expect(fill(tuesday), roles.solid);
    expect(fill(today), roles.tint);
    expect(fill(first), t.colors.surface);

    // Counting only beer.
    final beerChip = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('month-thing-s:'),
    );
    expect(beerChip, findsNWidgets(2));
    await h.tap(find.text('Bier').first);
    expect(text(MonthKeys.count, '2'), findsOneWidget);
    expect(find.text(TracksStrings.monthCountLabel('Bier')), findsOneWidget);
    expect(text(MonthKeys.days, '2'), findsOneWidget);
    expect(
      text(TimelineKeys.day, TracksStrings.monthCaption('Bier', current: true)),
      findsOneWidget,
    );

    // The month before: nothing; then back.
    await h.tap(find.byKey(TimelineKeys.previous));
    expect(text(MonthKeys.count, '0'), findsOneWidget);
    await h.tap(find.byKey(TimelineKeys.next));
    expect(text(TimelineKeys.day, Fmt.monthYear(first)), findsOneWidget);

    // A tap on a day opens its evening.
    await h.tap(find.byKey(MonthKeys.day(tuesday)));
    expect(find.byKey(EveningKeys.view), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (size, scale) in const [
    (Size(320, 640), 1.6),
    (Size(640, 360), 1.3),
  ]) {
    testWidgets('no overflow in the week and the month at '
        '${size.width.toInt()} x ${size.height.toInt()}, text $scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (:h, tent: _, tuesday: _, today: _) = await setUp(tester);
      await tester.binding.setSurfaceSize(size);
      await h.settle();
      for (final level in TimelineLevel.values) {
        await show(h, level);
        await h.settle();
        expect(tester.takeException(), isNull, reason: level.name);
      }
    });
  }
}
