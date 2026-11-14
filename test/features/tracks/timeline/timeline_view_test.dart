import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/app.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/repo.dart';
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
  /// Shows the timeline in its list mode (the strip is the default and
  /// has its own tests).
  Future<void> showTimeline() => run(() async {
    await container
        .read(timelineModesProvider.notifier)
        .show(activeSet.id, TimelineMode.list);
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

  /// Switches between "Zeitleiste" and "Zusammenfassung".
  Future<void> mode(String label) => tap(
    find.descendant(
      of: find.byKey(TimelineKeys.mode),
      matching: find.text(label),
    ),
  );

  /// Chooses a range from the scope chip's sheet.
  Future<void> pickScope(String label) async {
    await tap(find.byKey(TimelineKeys.scope));
    await tap(find.text(label).last);
  }

  Finder scopeShows(String label) => find.descendant(
    of: find.byKey(TimelineKeys.scope),
    matching: find.text(label),
  );
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

  testWidgets('running timers stay pinned at the top with their live '
      'time', (tester) async {
    final h = await TracksHarness.start(tester);
    final (_, ticks) = await _birds(h);
    await h.showTimeline();
    Finder chip(Track track) => find.byKey(TimelineKeys.stripChip(track.id));

    expect(find.text(TracksStrings.stripNothingRunning), findsOneWidget);
    final strip = tester.getRect(find.byKey(TimelineKeys.strip));

    await h.run(() => h.commands.startTrack(h.stopwatch.id));
    await h.advance(const Duration(seconds: 7));
    expect(find.text(TracksStrings.stripNothingRunning), findsNothing);
    expect(chip(h.stopwatch), findsOneWidget);
    expect(
      find.descendant(of: chip(h.stopwatch), matching: find.text('00:07')),
      findsOneWidget,
    );
    await h.advance(const Duration(seconds: 3));
    expect(
      find.descendant(of: chip(h.stopwatch), matching: find.text('00:10')),
      findsOneWidget,
    );
    // Above the list, and it does not push anything around.
    expect(tester.getRect(find.byKey(TimelineKeys.strip)), strip);
    expect(strip.bottom, lessThanOrEqualTo(h.top(h.row(ticks[2]))));
    // Counters are not timers.
    expect(find.byKey(TimelineKeys.strip), findsOneWidget);
    expect(chip(h.counter), findsNothing);

    // Paused: no longer running.
    await h.run(() => h.commands.pauseTrack(h.stopwatch.id));
    await h.settle();
    expect(chip(h.stopwatch), findsNothing);
    expect(find.text(TracksStrings.stripNothingRunning), findsOneWidget);
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

  testWidgets('a protocol entry reads "Person · Substanz · Menge" and '
      'opens the protocol entry sheet', (tester) async {
    final h = await TracksHarness.start(tester);
    final people = h.container.read(peopleRepositoryProvider);
    final jacke = await h.run(() => people.createPerson(name: 'Jacke'));
    final gbl = await h.run(() => people.createSubstance(name: 'GBL'));
    final tent = await h.addTrack(const ProtocolConfig(), name: 'Zelt');
    final entry = (await h.run(
      () => h.commands.addEntry(
        tent.id,
        personId: jacke.id,
        substanceId: gbl.id,
        amount: '1 ml',
      ),
    ))!;
    final bare = (await h.run(() => h.commands.addEntry(tent.id)))!;
    await h.showTimeline();

    expect(h.inRow(entry, 'Jacke · GBL · 1 ml'), findsOneWidget);
    expect(
      h.inRow(
        bare,
        '${Strings.protocolNoPerson} · ${Strings.protocolNoSubstance}',
      ),
      findsOneWidget,
    );

    await h.tap(h.row(entry));
    expect(find.text(Strings.protocolEditEntry), findsOneWidget);
    expect(find.text(TracksStrings.eventEditTitle), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('amount')))
          .controller!
          .text,
      '1 ml',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('scope: open sessions by default, today and the last 24 hours '
      'also show what has ended', (tester) async {
    final h = await TracksHarness.start(tester);
    // A closed session ...
    final old = await h.tick(h.counter);
    await h.run(() => h.commands.stopTrack(h.counter.id));
    await h.advance(const Duration(minutes: 2));
    // ... and an open one.
    final (_, ticks) = await _birds(h);
    await h.showTimeline();

    expect(h.scopeShows(TracksStrings.scopeOpen), findsOneWidget);
    expect(h.row(ticks[0]), findsOneWidget);
    expect(h.row(old), findsNothing);

    // The chip offers the three ranges.
    await h.tap(find.byKey(TimelineKeys.scope));
    expect(find.text(TracksStrings.scopeToday), findsOneWidget);
    expect(find.text(TracksStrings.scopeLast24h), findsOneWidget);
    await h.tap(find.text(TracksStrings.scopeLast24h));
    expect(h.scopeShows(TracksStrings.scopeLast24h), findsOneWidget);
    expect(h.row(old), findsOneWidget);
    expect(h.row(ticks[0]), findsOneWidget);

    await h.pickScope(TracksStrings.scopeToday);
    expect(h.scopeShows(TracksStrings.scopeToday), findsOneWidget);
    expect(h.row(ticks[2]), findsOneWidget);

    // Two days later nothing of this is in "the last 24 hours" - but the
    // session that is still open stays in "Laufende Sitzungen".
    await h.advance(const Duration(days: 2));
    await h.pickScope(TracksStrings.scopeOpen);
    expect(h.row(ticks[0]), findsOneWidget);
    await h.pickScope(TracksStrings.scopeLast24h);
    await h.settle();
    expect(h.row(ticks[0]), findsNothing);
    expect(h.row(old), findsNothing);
    expect(find.text(TracksStrings.timelineEmptyRange), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty set of open sessions says so', (tester) async {
    final h = await TracksHarness.start(tester);
    await h.showTimeline();
    expect(find.text(TracksStrings.timelineEmptyTitle), findsOneWidget);
    expect(find.text(TracksStrings.timelineEmptyOpen), findsOneWidget);
    await h.mode(TracksStrings.modeSummary);
    expect(find.text(TracksStrings.summaryEmptyTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('summary', () {
    testWidgets('counts per label with first, last and average gap; sorted '
        'by count, or by last time', (tester) async {
      final h = await TracksHarness.start(tester);
      final birds = await h.addTrack(
        const CounterConfig(labels: ['Reiher', 'Ente', 'Specht']),
        name: 'Vögel',
      );
      final first = await h.tick(birds, label: 'Reiher');
      await h.advance(const Duration(minutes: 4));
      await h.tick(birds, label: 'Reiher');
      await h.advance(const Duration(minutes: 4));
      final lastReiher = await h.tick(birds, label: 'Reiher');
      await h.advance(const Duration(minutes: 1));
      final ente = await h.tick(birds, label: 'Ente');
      await h.run(() => h.commands.startTrack(h.stopwatch.id));
      await h.advance(const Duration(seconds: 75));
      await h.run(() => h.commands.lap(h.stopwatch.id));
      await h.run(() => h.commands.pauseTrack(h.stopwatch.id));
      await h.showTimeline();

      await h.mode(TracksStrings.modeSummary);
      expect(find.byKey(TimelineKeys.list), findsNothing);
      expect(find.byKey(TimelineKeys.summary), findsOneWidget);
      final group = find.byKey(TimelineKeys.group('Vögel'));
      Finder inGroup(String text) =>
          find.descendant(of: group, matching: find.text(text));

      expect(inGroup('Reiher'), findsOneWidget);
      expect(inGroup('Ente'), findsOneWidget);
      // Never tapped: not listed.
      expect(inGroup('Specht'), findsNothing);
      expect(inGroup(TracksStrings.summaryCount(3)), findsOneWidget);
      expect(inGroup(TracksStrings.summaryCount(1)), findsOneWidget);
      expect(inGroup(TracksStrings.summaryTotal(4)), findsOneWidget);
      expect(
        inGroup(
          '${Fmt.time(first.at)} – ${Fmt.time(lastReiher.at)} · '
          '${TracksStrings.summaryAvgGap('4 min')}',
        ),
        findsOneWidget,
      );
      expect(inGroup(Fmt.time(ente.at)), findsOneWidget);
      // Most frequent first.
      expect(h.top(inGroup('Reiher')), lessThan(h.top(inGroup('Ente'))));

      // The stopwatch: net time and laps.
      final watch = find.byKey(TimelineKeys.group(Strings.seedStopwatchName));
      expect(
        find.descendant(of: watch, matching: find.text('01:15')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: watch,
          matching: find.text(
            '${TracksStrings.summaryNetTime} · ${TracksStrings.summaryLaps(1)}',
          ),
        ),
        findsOneWidget,
      );

      // By last time: the duck was seen last.
      Finder sortShows(String label) => find.descendant(
        of: find.byKey(TimelineKeys.sort),
        matching: find.text(label),
      );
      expect(sortShows(TracksStrings.sortByCount), findsOneWidget);
      await h.tapChip(TimelineKeys.sort);
      expect(sortShows(TracksStrings.sortByLast), findsOneWidget);
      expect(h.top(inGroup('Ente')), lessThan(h.top(inGroup('Reiher'))));

      // The running timers stay in view here too.
      expect(find.byKey(TimelineKeys.strip), findsOneWidget);

      // Back to the timeline.
      await h.mode(TracksStrings.modeTimeline);
      expect(find.byKey(TimelineKeys.list), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('protocol: per person per substance, counts and times - no '
        'amounts, no judgement', (tester) async {
      final h = await TracksHarness.start(tester);
      final people = h.container.read(peopleRepositoryProvider);
      final jacke = await h.run(() => people.createPerson(name: 'Jacke'));
      final kim = await h.run(() => people.createPerson(name: 'Kim'));
      final gbl = await h.run(
        () => people.createSubstance(name: 'GBL', lockoutMs: 2 * 3600 * 1000),
      );
      final water = await h.run(() => people.createSubstance(name: 'Wasser'));
      final tent = await h.addTrack(const ProtocolConfig(), name: 'Zelt');
      Future<void> entry(Person p, Substance s, {String? amount}) => h.run(
        () => h.commands.addEntry(
          tent.id,
          personId: p.id,
          substanceId: s.id,
          amount: amount,
        ),
      );
      await entry(jacke, gbl, amount: '1 ml');
      await h.advance(const Duration(minutes: 10));
      await entry(jacke, gbl, amount: '2 ml');
      await entry(jacke, water, amount: '0,5 l');
      await entry(kim, water);
      await h.showTimeline();
      await h.mode(TracksStrings.modeSummary);

      final jackeGroup = find.byKey(TimelineKeys.group('Zelt · Jacke'));
      final kimGroup = find.byKey(TimelineKeys.group('Zelt · Kim'));
      expect(jackeGroup, findsOneWidget);
      expect(kimGroup, findsOneWidget);
      Finder inJacke(String text) =>
          find.descendant(of: jackeGroup, matching: find.text(text));
      expect(inJacke('GBL'), findsOneWidget);
      expect(inJacke('Wasser'), findsOneWidget);
      expect(inJacke(TracksStrings.summaryCount(2)), findsOneWidget);
      expect(inJacke(TracksStrings.summaryTotal(3)), findsOneWidget);
      expect(h.top(inJacke('GBL')), lessThan(h.top(inJacke('Wasser'))));
      // The person with more entries comes first.
      expect(h.top(jackeGroup), lessThan(h.top(kimGroup)));

      // Nothing but counts and times: no amounts, no sums, no intervals,
      // no lockout, no warning.
      final texts = [
        for (final text in tester.widgetList<Text>(
          find.descendant(
            of: find.byKey(TimelineKeys.summary),
            matching: find.byType(Text),
          ),
        ))
          text.data ?? '',
      ];
      for (final text in texts) {
        expect(text.contains('ml'), isFalse, reason: text);
        expect(text.contains('0,5'), isFalse, reason: text);
        expect(text.contains('Schnitt'), isFalse, reason: text);
        expect(text.contains('frühestens'), isFalse, reason: text);
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the stream rests while another destination is shown and '
      'catches up afterwards', (tester) async {
    final h = await TracksHarness.start(tester);
    final (birds, ticks) = await _birds(h);
    await h.showTimeline();
    bool tickerMode() => tester
        .widget<TickerMode>(
          find
              .descendant(
                of: find.byKey(TimelineKeys.view, skipOffstage: false),
                matching: find.byType(TickerMode, skipOffstage: false),
              )
              .first,
        )
        .enabled;
    expect(tickerMode(), isTrue);

    await h.run(
      () async => h.container
          .read(shellDestinationProvider.notifier)
          .go(ShellDestination.settings),
    );
    await h.settle();
    expect(tickerMode(), isFalse);
    final later = await h.tick(birds, label: 'Ente');
    await h.settle();
    expect(
      find.byKey(TimelineKeys.row(later.id), skipOffstage: false),
      findsNothing,
    );

    await h.run(
      () async => h.container
          .read(shellDestinationProvider.notifier)
          .go(ShellDestination.tracks),
    );
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
      await h.mode(TracksStrings.modeSummary);
      expect(tester.takeException(), isNull);
    });
  }
}
