import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/adaptive/adaptive.dart';
import 'package:tikky_takka/features/tracks/timeline/evening/evening_view.dart';
import 'package:tikky_takka/features/tracks/timeline/timeline_event_sheet.dart';
import 'package:tikky_takka/features/tracks/timeline/timeline_mode.dart';
import 'package:tikky_takka/features/tracks/timeline/timeline_view.dart';
import 'package:tikky_takka/features/tracks/tracks_screen.dart';
import 'package:tikky_takka/features/tracks/tracks_strings.dart';
import 'package:tikky_takka/features/tracks/tracks_view.dart';
import 'package:tikky_takka/l10n/formatters.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../../../support/test_app.dart';
import '../tracks_harness.dart';

extension on TracksHarness {
  /// Shows the evening as a list ("Kompakt"; the strip of "Jetzt" and
  /// the evening itself have their own tests).
  Future<void> showTimeline() => run(() async {
    final choices = container.read(timelineChoicesProvider.notifier);
    await choices.show(activeSet.id, TimelineLevel.evening);
    await choices.setCompact(activeSet.id, compact: true);
    await container
        .read(tracksViewsProvider.notifier)
        .show(activeSet.id, TracksView.timeline);
  });

  TrackCommands get commands => container.read(trackCommandsProvider);

  Future<TrackEvent> tick(Track track, {String? label}) async =>
      (await run<TrackEvent?>(() => commands.tick(track.id, label: label)))!;

  Finder row(TrackEvent event) => find.byKey(TimelineKeys.row(event.id));

  Finder inRow(TrackEvent event, String text) =>
      find.descendant(of: row(event), matching: find.text(text));

  Future<TrackEvent?> stored(TrackEvent event) async {
    final session = await tester.runAsync(
      () =>
          container.read(historyRepositoryProvider).getSession(event.sessionId),
    );
    for (final e in session?.events ?? const <TrackEvent>[]) {
      if (e.id == event.id) return e;
    }
    return null;
  }

  double top(Finder finder) => tester.getTopLeft(finder).dy;

  /// Taps a chip of the filter row (it scrolls horizontally).
  Future<void> tapChip(Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
    await tap(find.byKey(key));
  }
}

/// A counter with labels and three ticks: Reiher, a minute later Ente,
/// twelve minutes later Reiher again.
Future<(Track, List<TrackEvent>)> _birds(TracksHarness h) async {
  final birds = await h.addTrack(
    const CounterConfig(labels: ['Reiher', 'Ente']),
    name: 'Vögel',
  );
  final a = await h.tick(birds, label: 'Reiher');
  await h.advance(const Duration(minutes: 1));
  final b = await h.tick(birds, label: 'Ente');
  await h.advance(const Duration(minutes: 12));
  final c = await h.tick(birds, label: 'Reiher');
  await h.settle();
  return (birds, [a, b, c]);
}

void main() {
  testWidgets('one chronological list across tracks, newest first, with a '
      'toggle for oldest first', (tester) async {
    final h = await TracksHarness.start(tester);
    final (birds, ticks) = await _birds(h);
    await h.advance(const Duration(minutes: 1));
    final other = await h.tick(h.counter);
    await h.showTimeline();

    expect(find.byKey(TracksScreenKeys.list), findsNothing);
    expect(find.byKey(TimelineKeys.list), findsOneWidget);
    // What happened, in plain words, with the running count per label.
    expect(h.inRow(ticks[0], 'Reiher · 1'), findsOneWidget);
    expect(h.inRow(ticks[1], 'Ente · 1'), findsOneWidget);
    expect(h.inRow(ticks[2], 'Reiher · 2'), findsOneWidget);
    expect(h.inRow(other, 'Tipp 1'), findsOneWidget);
    // Time with seconds, track name next to its colour dot.
    expect(
      h.inRow(ticks[2], Fmt.time(ticks[2].at, seconds: true)),
      findsOneWidget,
    );
    expect(h.inRow(ticks[2], birds.name), findsOneWidget);
    expect(h.inRow(other, Strings.seedCounterName), findsOneWidget);

    final newestFirst = [other, ticks[2], ticks[1], ticks[0]];
    for (var i = 1; i < newestFirst.length; i++) {
      expect(
        h.top(h.row(newestFirst[i - 1])),
        lessThan(h.top(h.row(newestFirst[i]))),
        reason: 'row $i',
      );
    }

    expect(find.byTooltip(TracksStrings.timelineNewestFirst), findsOneWidget);
    await h.tap(find.byKey(TimelineKeys.order));
    expect(find.byTooltip(TracksStrings.timelineOldestFirst), findsOneWidget);
    for (var i = 1; i < newestFirst.length; i++) {
      expect(
        h.top(h.row(newestFirst[i - 1])),
        greaterThan(h.top(h.row(newestFirst[i]))),
        reason: 'row $i',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a gap marker where more than the threshold passed', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    final (_, ticks) = await _birds(h);
    await h.showTimeline();

    // One minute between the first two: no marker. Twelve minutes: one.
    expect(find.text(TracksStrings.gapEarlier('12 min')), findsOneWidget);
    expect(find.textContaining('früher'), findsOneWidget);
    final marker = h.top(find.text(TracksStrings.gapEarlier('12 min')));
    expect(marker, greaterThan(h.top(h.row(ticks[2]))));
    expect(marker, lessThan(h.top(h.row(ticks[1]))));

    await h.tap(find.byKey(TimelineKeys.order));
    expect(find.text(TracksStrings.gapLater('12 min')), findsOneWidget);
    expect(find.textContaining('früher'), findsNothing);
    final later = h.top(find.text(TracksStrings.gapLater('12 min')));
    expect(later, greaterThan(h.top(h.row(ticks[1]))));
    expect(later, lessThan(h.top(h.row(ticks[2]))));
    expect(tester.takeException(), isNull);
  });

  testWidgets('lifecycle events are hidden by default; tracks can be '
      'filtered', (tester) async {
    final h = await TracksHarness.start(tester);
    final (birds, ticks) = await _birds(h);
    await h.run(() => h.commands.startTrack(h.stopwatch.id));
    await h.advance(const Duration(seconds: 30));
    final lap = (await h.run(() => h.commands.lap(h.stopwatch.id)))!;
    await h.run(() => h.commands.pauseTrack(h.stopwatch.id));
    await h.showTimeline();

    expect(find.text(TracksStrings.timelineStarted), findsNothing);
    expect(find.text(TracksStrings.timelinePaused), findsNothing);
    expect(h.inRow(lap, 'Runde 1 · 00:30.0'), findsOneWidget);

    await h.tapChip(TimelineKeys.lifecycle);
    // The counter's start and the stopwatch's.
    expect(find.text(TracksStrings.timelineStarted), findsNWidgets(2));
    expect(find.text(TracksStrings.timelinePaused), findsOneWidget);

    await h.tapChip(TimelineKeys.lifecycle);
    expect(find.text(TracksStrings.timelineStarted), findsNothing);

    // Hide the counter track: only the stopwatch's lap is left.
    await h.tapChip(TimelineKeys.trackChip(birds.id));
    expect(h.row(ticks[0]), findsNothing);
    expect(h.row(ticks[2]), findsNothing);
    expect(h.row(lap), findsOneWidget);
    await h.tapChip(TimelineKeys.trackChip(h.stopwatch.id));
    expect(find.text(TracksStrings.timelineAllHidden), findsOneWidget);
    await h.tapChip(TimelineKeys.trackChip(birds.id));
    expect(h.row(ticks[0]), findsOneWidget);
    expect(h.row(lap), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a row edits time, label and note', (tester) async {
    final h = await TracksHarness.start(tester);
    final (_, ticks) = await _birds(h);
    await h.showTimeline();
    final ente = ticks[1];

    await h.tap(h.row(ente));
    expect(find.text(TracksStrings.eventEditTitle), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(EventSheetKeys.time)).data,
      '${Fmt.date(ente.at)}, ${Fmt.time(ente.at, seconds: true)}',
    );
    // The track's labels to choose from.
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(EventSheetKeys.label('Ente')))
          .selected,
      isTrue,
    );
    expect(find.byKey(EventSheetKeys.label('Reiher')), findsOneWidget);
    expect(find.byKey(EventSheetKeys.noLabel), findsOneWidget);

    await h.tap(find.byKey(EventSheetKeys.earlier));
    await h.tap(find.byKey(EventSheetKeys.earlier));
    await h.tap(find.byKey(EventSheetKeys.earlier));
    await h.tap(find.byKey(EventSheetKeys.later));
    await h.tap(find.byKey(EventSheetKeys.later));
    expect(
      tester.widget<Text>(find.byKey(EventSheetKeys.time)).data,
      '${Fmt.date(ente.at - 60000)}, '
      '${Fmt.time(ente.at - 60000, seconds: true)}',
    );
    await h.tap(find.byKey(EventSheetKeys.label('Reiher')));
    await tester.enterText(find.byKey(EventSheetKeys.note), 'am Teich');
    await tester.ensureVisible(find.byKey(EventSheetKeys.save));
    await h.tap(find.byKey(EventSheetKeys.save));
    await h.settle();

    final edited = (await h.stored(ente))!;
    expect(edited.at, ente.at - 60000);
    expect(edited.label, 'Reiher');
    expect(edited.note, 'am Teich');
    expect(edited.type, EventType.tick);
    expect(find.text(TracksStrings.eventEditTitle), findsNothing);
    // Same instant as the first tick now, logged after it: the running
    // counts follow.
    expect(h.inRow(ticks[0], 'Reiher · 1'), findsOneWidget);
    expect(h.inRow(ente, 'Reiher · 2'), findsOneWidget);
    expect(h.inRow(ticks[2], 'Reiher · 3'), findsOneWidget);
    expect(h.inRow(ente, 'am Teich'), findsOneWidget);
    expect(find.text(TracksStrings.eventUpdated), findsOneWidget);

    // Undo puts the old values back.
    await h.tap(find.text(Strings.undo));
    final restored = (await h.stored(ente))!;
    expect(restored.at, ente.at);
    expect(restored.label, 'Ente');
    expect(restored.note, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete with undo; start and stop cannot be deleted', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    final (birds, ticks) = await _birds(h);
    await h.showTimeline();

    await h.tap(h.row(ticks[2]));
    await tester.ensureVisible(find.byKey(EventSheetKeys.delete));
    await h.tap(find.byKey(EventSheetKeys.delete));
    await h.settle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(await h.stored(ticks[2]), isNull);
    expect(h.row(ticks[2]), findsNothing);
    expect(((await h.snapshot(birds))! as CounterSnapshot).count, 2);
    expect(find.text(Strings.eventDeleted), findsOneWidget);

    await h.tap(find.text(Strings.undo));
    expect(await h.stored(ticks[2]), ticks[2]);
    expect(h.inRow(ticks[2], 'Reiher · 2'), findsOneWidget);

    // A start can be moved in time but not removed.
    await tester.pump(const Duration(seconds: 6));
    await h.settle();
    await h.tapChip(TimelineKeys.lifecycle);
    await h.tap(find.text(TracksStrings.timelineStarted));
    expect(find.text(TracksStrings.eventEditTitle), findsOneWidget);
    expect(find.byKey(EventSheetKeys.delete), findsNothing);
    expect(find.byKey(EventSheetKeys.save), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a lap takes a free label', (tester) async {
    final h = await TracksHarness.start(tester);
    await h.run(() => h.commands.startTrack(h.stopwatch.id));
    await h.advance(const Duration(seconds: 90));
    final lap = (await h.run(() => h.commands.lap(h.stopwatch.id)))!;
    await h.showTimeline();

    await h.tap(h.row(lap));
    expect(find.byKey(EventSheetKeys.noLabel), findsNothing);
    await tester.enterText(find.byKey(EventSheetKeys.lapLabel), 'Bergauf');
    await tester.ensureVisible(find.byKey(EventSheetKeys.save));
    await h.tap(find.byKey(EventSheetKeys.save));
    await h.settle();
    expect((await h.stored(lap))!.label, 'Bergauf');
    expect(h.inRow(lap, 'Runde 1 · 01:30.0 · Bergauf'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the evening: one logical day, back and forth; the next '
      'one only up to the evening going on', (tester) async {
    final h = await TracksHarness.start(tester);
    final (_, ticks) = await _birds(h);
    await h.showTimeline();
    expect(h.row(ticks[0]), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(TimelineKeys.day),
        matching: find.text(Fmt.dayShort(ticks[0].at)),
      ),
      findsOneWidget,
    );
    bool canGoOn() =>
        tester
            .widget<HeaderRoundButton>(find.byKey(TimelineKeys.next))
            .onPressed !=
        null;
    expect(canGoOn(), isFalse);

    await h.tap(find.byKey(TimelineKeys.previous));
    expect(h.row(ticks[0]), findsNothing);
    expect(find.text(TracksStrings.eveningEmpty), findsOneWidget);
    expect(canGoOn(), isTrue);
    await h.tap(find.byKey(TimelineKeys.next));
    expect(h.row(ticks[0]), findsOneWidget);

    // Two days later the evening going on is another one.
    await h.advance(const Duration(days: 2));
    await h.settle();
    await h.tap(find.byKey(TimelineKeys.previous));
    await h.tap(find.byKey(TimelineKeys.next));
    expect(h.row(ticks[0]), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Kompakt" switches between the evening and its list; the '
      'choice is remembered per set', (tester) async {
    final h = await TracksHarness.start(tester);
    await _birds(h);
    await h.showTimeline();
    expect(find.byKey(TimelineKeys.list), findsOneWidget);
    await h.tap(find.byKey(TimelineKeys.compact));
    expect(find.byKey(TimelineKeys.list), findsNothing);
    expect(find.byKey(EveningKeys.view), findsOneWidget);
    final id = h.activeSet.id;
    expect(
      h.app.settings.getString('${SettingsKeys.timelineCompactPrefix}$id'),
      'false',
    );
    expect(
      h.app.settings.getString('${SettingsKeys.timelineLevelPrefix}$id'),
      'evening',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty evening says so', (tester) async {
    final h = await TracksHarness.start(tester);
    await h.showTimeline();
    expect(find.text(TracksStrings.timelineEmptyTitle), findsOneWidget);
    expect(find.text(TracksStrings.eveningEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the stream rests while a page covers the tracks screen and '
      'catches up afterwards', (tester) async {
    final h = await TracksHarness.start(tester);
    final (birds, ticks) = await _birds(h);
    await h.showTimeline();
    // The ticker mode in effect inside the timeline (the page on top turns
    // it off for everything below).
    bool tickerMode() => TickerMode.valuesOf(
      tester.element(
        find
            .descendant(
              of: find.byKey(TimelineKeys.view, skipOffstage: false),
              matching: find.byType(TickerMode, skipOffstage: false),
            )
            .first,
      ),
    ).enabled;
    expect(tickerMode(), isTrue);

    unawaited(openSettings(tester.element(find.byType(TracksScreen))));
    await h.settle();
    expect(tickerMode(), isFalse);
    final later = await h.tick(birds, label: 'Ente');
    await h.settle();
    expect(
      find.byKey(TimelineKeys.row(later.id), skipOffstage: false),
      findsNothing,
    );

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await h.settle();
    expect(tickerMode(), isTrue);
    expect(h.inRow(later, 'Ente · 2'), findsOneWidget);
    expect(h.row(ticks[0]), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(360, 640), TestApp.desktopSize]) {
    testWidgets('no overflow at ${size.width.toInt()} px with large text, '
        '12-hour times and long names', (tester) async {
      final h = await TracksHarness.start(tester, surfaceSize: size);
      final birds = await h.addTrack(
        const CounterConfig(labels: ['Eichhörnchen mit sehr langem Namen']),
        name: 'Vögel im Stadtpark am Sonntagmorgen',
      );
      await h.setPrefs(
        const UiPrefs(
          buttonScale: UiPrefs.maxButtonScale,
          digitScale: UiPrefs.maxDigitScale,
          density: UiDensity.roomy,
          use24h: false,
        ),
      );
      final tick = await h.tick(
        birds,
        label: 'Eichhörnchen mit sehr langem Namen',
      );
      await h.run(() => h.commands.startTrack(h.stopwatch.id));
      await h.run(() => h.commands.startTrack(h.timer.id));
      await h.advance(const Duration(minutes: 20));
      await h.tick(birds, label: 'Eichhörnchen mit sehr langem Namen');
      await h.showTimeline();
      expect(tester.takeException(), isNull);
      expect(
        h.inRow(tick, Fmt.time(tick.at, use24h: false, seconds: true)),
        findsOneWidget,
      );
      await h.tapChip(TimelineKeys.lifecycle);
      expect(tester.takeException(), isNull);
      await h.tap(h.row(tick));
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(EventSheetKeys.save));
      await h.tap(find.byKey(EventSheetKeys.save));
      // The evening itself fits as well.
      await h.tap(find.byKey(TimelineKeys.compact));
      expect(find.byKey(EveningKeys.view), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
