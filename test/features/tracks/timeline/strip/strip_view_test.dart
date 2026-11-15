import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/adaptive/adaptive.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/tracks/timeline/strip/strip_detail.dart';
import 'package:tikky_takka/features/tracks/timeline/strip/strip_model.dart';
import 'package:tikky_takka/features/tracks/timeline/strip/strip_view.dart';
import 'package:tikky_takka/features/tracks/timeline/strip/strip_viewport.dart';
import 'package:tikky_takka/features/tracks/timeline/timeline_event_sheet.dart';
import 'package:tikky_takka/features/tracks/timeline/timeline_mode.dart';
import 'package:tikky_takka/features/tracks/timeline/timeline_view.dart';
import 'package:tikky_takka/features/tracks/tracks_strings.dart';
import 'package:tikky_takka/features/tracks/tracks_view.dart';
import 'package:tikky_takka/l10n/formatters.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../../tracks_harness.dart';

extension on TracksHarness {
  /// Shows the timeline view; the strip is its default mode.
  Future<void> showTimeline() => run(
    () => container
        .read(tracksViewsProvider.notifier)
        .show(activeSet.id, TracksView.timeline),
  );

  TrackCommands get commands => container.read(trackCommandsProvider);

  Future<TrackEvent> tick(Track track, {String? label}) async =>
      (await run<TrackEvent?>(() => commands.tick(track.id, label: label)))!;

  StripViewState get strip =>
      tester.state<StripViewState>(find.byType(StripView));

  StripViewport get viewport => strip.viewport;

  Offset get lanesOrigin => tester.getTopLeft(find.byKey(StripKeys.lanes));

  StripMarker? markerOf(TrackEvent event) {
    for (final m in strip.layout.markers) {
      if (m.event?.row.event.id == event.id) return m;
    }
    return null;
  }

  Future<void> tapMarker(TrackEvent event) async {
    await tester.tapAt(lanesOrigin + markerOf(event)!.center);
    await settle();
  }

  Finder stripLane(String rowId) => find.byKey(StripKeys.lane(rowId));

  Finder inStripLane(String rowId, String text) =>
      find.descendant(of: stripLane(rowId), matching: find.text(text));

  Future<void> mode(String label) => tap(
    find.descendant(
      of: find.byKey(TimelineKeys.mode),
      matching: find.text(label),
    ),
  );

  Future<void> tapChip(Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
    await tap(find.byKey(key));
  }

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
  testWidgets('the strip is the default mode; the order of the modes is '
      'Streifen, Liste, Zusammenfassung', (tester) async {
    final h = await TracksHarness.start(tester);
    await _birds(h);
    await h.showTimeline();

    expect(find.byKey(StripKeys.view), findsOneWidget);
    expect(find.byKey(StripKeys.lanes), findsOneWidget);
    expect(find.byKey(TimelineKeys.list), findsNothing);
    // The order toggle belongs to the list.
    expect(find.byKey(TimelineKeys.order), findsNothing);
    // The running timers stay pinned above.
    expect(find.byKey(TimelineKeys.strip), findsOneWidget);
    expect(
      tester.getBottomLeft(find.byKey(TimelineKeys.strip)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byKey(StripKeys.view)).dy),
    );

    Finder segment(String label) => find.descendant(
      of: find.byKey(TimelineKeys.mode),
      matching: find.text(label),
    );
    expect(TracksStrings.modeTimeline, 'Liste');
    final xs = [
      for (final label in [
        TracksStrings.modeStrip,
        TracksStrings.modeTimeline,
        TracksStrings.modeSummary,
      ])
        tester.getCenter(segment(label)).dx,
    ];
    expect(xs[0], lessThan(xs[1]));
    expect(xs[1], lessThan(xs[2]));

    await h.mode(TracksStrings.modeTimeline);
    expect(find.byKey(TimelineKeys.list), findsOneWidget);
    expect(find.byKey(TimelineKeys.order), findsOneWidget);
    expect(find.byKey(StripKeys.view), findsNothing);
    await h.mode(TracksStrings.modeSummary);
    expect(find.byKey(TimelineKeys.summary), findsOneWidget);
    await h.mode(TracksStrings.modeStrip);
    expect(find.byKey(StripKeys.view), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the mode is remembered per set', (tester) async {
    final h = await TracksHarness.start(tester);
    final first = h.activeSet;
    await _birds(h);
    final kitchen = await h.run(
      () => h.container.read(setRepositoryProvider).createSet(name: 'Küche'),
    );
    final noodles = await h.run(
      () => h.container
          .read(trackRepositoryProvider)
          .createTrack(
            setId: kitchen.id,
            name: 'Nudeln',
            config: const CounterConfig(),
          ),
    );
    await h.showTimeline();
    expect(find.byKey(StripKeys.view), findsOneWidget);
    expect(
      h.app.settings.getString('${SettingsKeys.timelineModePrefix}${first.id}'),
      isNull,
    );

    await h.mode(TracksStrings.modeSummary);
    expect(
      h.app.settings.getString('${SettingsKeys.timelineModePrefix}${first.id}'),
      'summary',
    );

    // Another set starts with the strip ...
    await h.run(
      () => h.container.read(activeSetIdProvider.notifier).select(kitchen.id),
    );
    await h.run(
      () => h.container
          .read(tracksViewsProvider.notifier)
          .show(kitchen.id, TracksView.timeline),
    );
    await h.tick(noodles);
    await h.settle();
    expect(find.byKey(StripKeys.view), findsOneWidget);
    // ... and remembers its own choice.
    await h.mode(TracksStrings.modeTimeline);
    expect(find.byKey(TimelineKeys.list), findsOneWidget);
    expect(
      h.app.settings.getString(
        '${SettingsKeys.timelineModePrefix}${kitchen.id}',
      ),
      'list',
    );

    await h.run(
      () => h.container.read(activeSetIdProvider.notifier).select(first.id),
    );
    await h.settle();
    expect(find.byKey(TimelineKeys.summary), findsOneWidget);
    expect(find.byKey(TimelineKeys.list), findsNothing);

    // A fresh start of the app reads the same choices from the store.
    final restarted = ProviderContainer(overrides: h.app.overrides);
    addTearDown(restarted.dispose);
    expect(
      restarted.read(timelineModeProvider(first.id)),
      TimelineMode.summary,
    );
    expect(restarted.read(timelineModeProvider(kitchen.id)), TimelineMode.list);
    expect(restarted.read(timelineModeProvider('unknown')), TimelineMode.strip);
    expect(TimelineMode.fromName('nonsense'), TimelineMode.strip);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lanes and a fixed gutter for mixed track types', (tester) async {
    final h = await TracksHarness.start(
      tester,
      surfaceSize: const Size(1270, 800),
    );
    final people = h.container.read(peopleRepositoryProvider);
    final jacke = await h.run(() => people.createPerson(name: 'Jacke'));
    final mo = await h.run(() => people.createPerson(name: 'Mo'));
    final gbl = await h.run(
      () => people.createSubstance(
        name: 'GBL',
        lockoutMs: 2 * 60 * 60 * 1000,
        color: 0xFF112233,
      ),
    );
    final water = await h.run(() => people.createSubstance(name: 'Wasser'));
    final tent = await h.addTrack(const ProtocolConfig(), name: 'Zelt');
    final (birds, ticks) = await _birds(h);
    await h.run(() => h.commands.startTrack(h.stopwatch.id));
    await h.advance(const Duration(minutes: 2));
    await h.run(() => h.commands.lap(h.stopwatch.id));
    await h.run(() => h.commands.pauseTrack(h.stopwatch.id));
    await h.advance(const Duration(minutes: 1));
    await h.run(() => h.commands.startTrack(h.timer.id));
    final withLockout = (await h.run(
      () => h.commands.addEntry(
        tent.id,
        personId: jacke.id,
        substanceId: gbl.id,
        amount: '1 ml',
      ),
    ))!;
    await h.advance(const Duration(minutes: 3));
    final plain = (await h.run(
      () =>
          h.commands.addEntry(tent.id, personId: mo.id, substanceId: water.id),
    ))!;
    await h.advance(const Duration(minutes: 1));
    await h.showTimeline();

    // Track order of the set: the seeded tracks, then the new ones. The
    // seeded counter has no activity and gets no lane.
    final ids = [
      h.stopwatch.id,
      h.timer.id,
      tent.id,
      '${tent.id}/p/${jacke.id}',
      '${tent.id}/p/${jacke.id}/s/${gbl.id}',
      '${tent.id}/p/${mo.id}',
      '${tent.id}/p/${mo.id}/s/${water.id}',
      birds.id,
      '${birds.id}/l/Reiher',
      '${birds.id}/l/Ente',
    ];
    for (final id in ids) {
      expect(h.stripLane(id), findsOneWidget, reason: id);
    }
    expect(h.stripLane(h.counter.id), findsNothing);
    for (var i = 1; i < ids.length; i++) {
      expect(
        tester.getTopLeft(h.stripLane(ids[i])).dy,
        greaterThan(tester.getTopLeft(h.stripLane(ids[i - 1])).dy),
        reason: ids[i],
      );
    }
    expect(
      h.inStripLane(h.stopwatch.id, Strings.seedStopwatchName),
      findsOneWidget,
    );
    expect(h.inStripLane(tent.id, 'Zelt'), findsOneWidget);
    expect(h.inStripLane('${tent.id}/p/${jacke.id}', 'Jacke'), findsOneWidget);
    expect(h.inStripLane('${birds.id}/l/Reiher', 'Reiher'), findsOneWidget);
    // Sub-lanes are indented, a person's substances further.
    final gblLane = '${tent.id}/p/${jacke.id}/s/${gbl.id}';
    expect(
      tester.getTopLeft(h.inStripLane('${tent.id}/p/${jacke.id}', 'Jacke')).dx,
      greaterThan(tester.getTopLeft(h.inStripLane(tent.id, 'Zelt')).dx),
    );
    expect(
      tester.getTopLeft(h.inStripLane(gblLane, 'GBL')).dx,
      greaterThan(
        tester
            .getTopLeft(h.inStripLane('${tent.id}/p/${jacke.id}', 'Jacke'))
            .dx,
      ),
    );
    // Every substance lane has its timer: time since its last entry, in
    // the warning colour while the lockout the user set is running.
    final gblTimer = find.byKey(StripKeys.timer(gblLane));
    expect(
      find.descendant(of: gblTimer, matching: find.text('04:00')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(of: gblTimer, matching: find.byType(Text)),
          )
          .style!
          .color,
      TikkyTokens.fallback.colors.warning,
    );
    expect(
      find.descendant(
        of: find.byKey(StripKeys.timer('${tent.id}/p/${mo.id}/s/${water.id}')),
        matching: find.text('01:00'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(StripKeys.timer(tent.id)), findsNothing);
    // Wide: the buttons say what they do.
    expect(find.text(TracksStrings.stripFit), findsOneWidget);
    expect(find.text(TracksStrings.stripNow), findsOneWidget);
    // The wide gutter, to the left of the lanes.
    final gutter = tester.getRect(find.byKey(StripKeys.gutter));
    final lanes = tester.getRect(find.byKey(StripKeys.lanes));
    expect(gutter.width, TikkyTokens.fallback.strip.gutter);
    expect(lanes.left, gutter.right);
    // The strip uses the whole width and the height that is left.
    final view = tester.getRect(find.byKey(StripKeys.view));
    expect(lanes.right, view.right);
    expect(view.right, 1270);
    expect(view.bottom, greaterThan(700));

    // What is drawn: bars for every lane, the pause, the lap, the ticks,
    // the entries - and a lockout band only for the substance with one.
    final layout = h.strip.layout;
    expect(layout.rowTops, hasLength(ids.length));
    expect(
      {for (final b in layout.bars) b.rowIndex},
      {for (var i = 0; i < ids.length; i++) i},
    );
    expect(
      layout.bars.where((b) => b.rowIndex == 0).map((b) => b.kind),
      containsAll([StripBarKind.active, StripBarKind.paused]),
    );
    expect(layout.bars.where((b) => b.rowIndex == 1).single.touchesNow, isTrue);
    expect(
      layout.markers.where((m) => m.rowIndex == 0).single.kind,
      StripMarkerKind.lap,
    );
    expect(h.markerOf(ticks[0])!.rowIndex, 8);
    expect(h.markerOf(ticks[1])!.rowIndex, 9);
    expect(h.markerOf(withLockout)!.rowIndex, 4);
    expect(h.markerOf(plain)!.rowIndex, 6);
    expect(h.markerOf(withLockout)!.event!.colorArgb, 0xFF112233);
    expect(layout.bands, hasLength(1));
    expect(layout.bands.single.rowIndex, 4);
    expect(layout.bands.single.colorArgb, 0xFF112233);
    expect(
      layout.bands.single.rect.left,
      closeTo(h.markerOf(withLockout)!.center.dx, 0.01),
    );
    // Everything of the scope is in view, now included.
    expect(layout.nowX, inInclusiveRange(0, lanes.width));
    for (final m in layout.markers) {
      expect(m.center.dx, inInclusiveRange(0, lanes.width));
    }

    // Panning moves the content, not the names.
    final before = tester.getTopLeft(h.stripLane(tent.id));
    final x = h.markerOf(ticks[2])!.center.dx;
    await h.tap(find.byKey(StripKeys.zoomIn));
    await tester.drag(find.byKey(StripKeys.lanes), const Offset(-160, 0));
    await tester.pump();
    expect(tester.getTopLeft(h.stripLane(tent.id)), before);
    expect(h.markerOf(ticks[2])?.center.dx, isNot(x));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap on a marker says what happened; "Bearbeiten" opens '
      'the event editor', (tester) async {
    final h = await TracksHarness.start(tester);
    final (birds, ticks) = await _birds(h);
    await h.showTimeline();
    final ente = ticks[1];

    await h.tapMarker(ente);
    final detail = find.byKey(StripDetailKeys.event);
    expect(detail, findsOneWidget);
    Finder inDetail(String text) =>
        find.descendant(of: detail, matching: find.text(text));
    // The wording of the list row, the track and the time with seconds.
    expect(inDetail('Ente · 1'), findsOneWidget);
    expect(inDetail(birds.name), findsOneWidget);
    expect(
      inDetail('${Fmt.date(ente.at)}, ${Fmt.time(ente.at, seconds: true)}'),
      findsOneWidget,
    );

    await h.tap(find.byKey(StripDetailKeys.edit));
    expect(find.byKey(StripDetailKeys.event), findsNothing);
    expect(find.text(TracksStrings.eventEditTitle), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(EventSheetKeys.label('Ente')))
          .selected,
      isTrue,
    );
    // Editing works from here like from the list.
    await h.tap(find.byKey(EventSheetKeys.label('Reiher')));
    await tester.ensureVisible(find.byKey(EventSheetKeys.save));
    await h.tap(find.byKey(EventSheetKeys.save));
    await h.settle();
    expect((await h.stored(ente))!.label, 'Reiher');
    expect(h.markerOf(ente)!.event!.row.text, 'Reiher · 2');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a protocol entry opens the entry sheet; the lockout the '
      'user set reads "frühestens wieder"', (tester) async {
    final h = await TracksHarness.start(tester);
    final people = h.container.read(peopleRepositoryProvider);
    final jacke = await h.run(() => people.createPerson(name: 'Jacke'));
    final gbl = await h.run(
      () => people.createSubstance(name: 'GBL', lockoutMs: 2 * 60 * 60 * 1000),
    );
    final water = await h.run(() => people.createSubstance(name: 'Wasser'));
    final tent = await h.addTrack(const ProtocolConfig(), name: 'Zelt');
    final entry = (await h.run(
      () => h.commands.addEntry(
        tent.id,
        personId: jacke.id,
        substanceId: gbl.id,
        amount: '1 ml',
      ),
    ))!;
    await h.advance(const Duration(minutes: 20));
    final drink = (await h.run(
      () => h.commands.addEntry(
        tent.id,
        personId: jacke.id,
        substanceId: water.id,
      ),
    ))!;
    await h.advance(const Duration(minutes: 10));
    await h.showTimeline();

    await h.tapMarker(drink);
    expect(find.text('Jacke · Wasser'), findsOneWidget);
    // No lockout on water: no such line, and no judgement of any kind.
    expect(find.textContaining('frühestens'), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await h.settle();

    await h.tapMarker(entry);
    expect(find.text('Jacke · GBL · 1 ml'), findsOneWidget);
    expect(find.text(Strings.lockoutRemaining('1 h 30 min')), findsOneWidget);
    await h.tap(find.byKey(StripDetailKeys.edit));
    // The sheet "Ändern" of the entry.
    expect(find.text('GBL · Jacke'), findsOneWidget);
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

  testWidgets('an entry of a substance lane tells the time since the one '
      'before it', (tester) async {
    final h = await TracksHarness.start(tester);
    final people = h.container.read(peopleRepositoryProvider);
    final jacke = await h.run(() => people.createPerson(name: 'Jacke'));
    final water = await h.run(() => people.createSubstance(name: 'Wasser'));
    final tent = await h.addTrack(const ProtocolConfig(), name: 'Zelt');
    Future<TrackEvent> drink() async => (await h.run<TrackEvent?>(
      () => h.commands.addEntry(
        tent.id,
        personId: jacke.id,
        substanceId: water.id,
      ),
    ))!;
    final first = await drink();
    await h.advance(const Duration(minutes: 25));
    final second = await drink();
    await h.advance(const Duration(minutes: 5));
    await h.showTimeline();

    await h.tapMarker(second);
    expect(
      find.text(TracksStrings.stripSincePrevious('25 min')),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(10, 10));
    await h.settle();
    await h.tapMarker(first);
    expect(find.byKey(StripDetailKeys.sincePrevious), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Löschen" deletes without asking and offers "Rückgängig"', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    final (_, ticks) = await _birds(h);
    await h.showTimeline();

    await h.tapMarker(ticks[2]);
    await h.tap(find.byKey(StripDetailKeys.delete));
    await h.settle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(StripDetailKeys.event), findsNothing);
    expect(await h.stored(ticks[2]), isNull);
    expect(h.markerOf(ticks[2]), isNull);
    expect(h.markerOf(ticks[0]), isNotNull);
    expect(find.text(Strings.eventDeleted), findsOneWidget);

    await h.tap(find.text(Strings.undo));
    expect(await h.stored(ticks[2]), ticks[2]);
    expect(h.markerOf(ticks[2])!.event!.row.text, 'Reiher · 2');

    // A start can be looked at and moved in time, but not removed.
    await tester.pump(const Duration(seconds: 6));
    await h.settle();
    await h.tapChip(TimelineKeys.lifecycle);
    final start = h.strip.layout.markers.firstWhere(
      (m) => m.kind == StripMarkerKind.lifecycle,
    );
    expect(start.event!.row.text, TracksStrings.timelineStarted);
    // It sits on the first tick; the nearest marker wins either way.
    await tester.tapAt(h.lanesOrigin + start.center - const Offset(6, 0));
    await h.settle();
    if (find.text(TracksStrings.timelineStarted).evaluate().isNotEmpty) {
      expect(find.byKey(StripDetailKeys.delete), findsNothing);
      expect(find.byKey(StripDetailKeys.edit), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap on a bar shows the figures of the session', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    await h.run(() => h.commands.startTrack(h.stopwatch.id));
    final startedAt = h.app.clock.nowMs();
    await h.advance(const Duration(minutes: 10));
    await h.run(() => h.commands.pauseTrack(h.stopwatch.id));
    await h.advance(const Duration(minutes: 5));
    await h.showTimeline();

    final bar = h.strip.layout.bars.firstWhere(
      (b) => b.kind == StripBarKind.active,
    );
    await tester.tapAt(h.lanesOrigin + bar.rect.center);
    await h.settle();
    final sheet = find.byKey(StripDetailKeys.session);
    expect(sheet, findsOneWidget);
    Finder inSheet(String text) =>
        find.descendant(of: sheet, matching: find.text(text));
    expect(inSheet(Strings.seedStopwatchName), findsOneWidget);
    expect(inSheet(Strings.started), findsOneWidget);
    expect(
      inSheet('${Fmt.date(startedAt)}, ${Fmt.time(startedAt, seconds: true)}'),
      findsOneWidget,
    );
    expect(inSheet(Strings.ended), findsOneWidget);
    expect(inSheet(Strings.netDuration), findsOneWidget);
    expect(inSheet('10:00'), findsOneWidget);
    // "Pausiert" names the open end and the sum of the pauses.
    expect(inSheet(Strings.pausedDuration), findsNWidgets(2));
    expect(inSheet('05:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zoom buttons, "Alles zeigen" and "Jetzt"; following stops '
      'when the user pans', (tester) async {
    final h = await TracksHarness.start(tester);
    await _birds(h);
    await h.run(() => h.commands.startTrack(h.stopwatch.id));
    await h.advance(const Duration(minutes: 2));
    await h.showTimeline();
    final v = h.viewport;
    final step = TikkyTokens.fallback.strip.zoomStep;
    // On a phone all four are icons; their names are the tooltips.
    bool canJump() =>
        tester
            .widget<AdaptiveIconButton>(
              find.descendant(
                of: find.byKey(StripKeys.now),
                matching: find.byType(AdaptiveIconButton),
              ),
            )
            .onPressed !=
        null;
    expect(find.byTooltip(TracksStrings.stripFit), findsOneWidget);
    expect(find.byTooltip(TracksStrings.stripNow), findsOneWidget);
    expect(find.byTooltip(TracksStrings.stripZoomIn), findsOneWidget);
    expect(find.byTooltip(TracksStrings.stripZoomOut), findsOneWidget);

    // The first view shows everything, with a little air.
    final now = h.app.clock.nowMs();
    final fitStart = v.startMs;
    final fitScale = v.msPerPx;
    expect(v.following, isFalse);
    expect(v.xOf(v.extentStart), greaterThan(0));
    expect(v.xOf(now), lessThan(v.width));
    expect(v.xOf(now), greaterThan(v.width * 0.9));

    await h.tap(find.byKey(StripKeys.zoomIn));
    expect(v.msPerPx, closeTo(fitScale / step, 1e-6));
    await h.tap(find.byKey(StripKeys.zoomIn));
    expect(v.msPerPx, closeTo(fitScale / step / step, 1e-6));
    await h.tap(find.byKey(StripKeys.zoomOut));
    expect(v.msPerPx, closeTo(fitScale / step, 1e-6));
    // The middle stayed where it was.
    expect(
      v.timeAt(v.width / 2),
      closeTo(fitStart + fitScale * v.width / 2, 1),
    );
    // Not further out than everything.
    await h.tap(find.byKey(StripKeys.zoomOut));
    await h.tap(find.byKey(StripKeys.zoomOut));
    expect(v.msPerPx, closeTo(fitScale, 1e-6));

    await h.tap(find.byKey(StripKeys.zoomIn));
    await h.tap(find.byKey(StripKeys.zoomIn));
    await tester.drag(find.byKey(StripKeys.lanes), const Offset(120, 0));
    await tester.pump();
    await h.tap(find.byKey(StripKeys.fit));
    expect(v.msPerPx, closeTo(fitScale, 1e-6));
    expect(v.startMs, closeTo(fitStart, 1e-6));

    // "Jetzt" jumps to the now line and follows it.
    await h.tap(find.byKey(StripKeys.zoomIn));
    await h.tap(find.byKey(StripKeys.zoomIn));
    expect(canJump(), isTrue);
    await h.tap(find.byKey(StripKeys.now));
    expect(v.following, isTrue);
    expect(canJump(), isFalse);
    final anchor = v.width * TikkyTokens.fallback.strip.followAnchor;
    expect(v.xOf(h.app.clock.nowMs()), closeTo(anchor, 1e-6));
    final followedFrom = v.startMs;
    await h.advance(const Duration(seconds: 30));
    expect(v.startMs, closeTo(followedFrom + 30000, 1e-6));
    expect(v.xOf(h.app.clock.nowMs()), closeTo(anchor, 1e-6));
    expect(h.strip.layout.nowX, closeTo(anchor, 1e-6));
    // Zooming keeps following.
    await h.tap(find.byKey(StripKeys.zoomIn));
    expect(v.following, isTrue);
    expect(v.xOf(h.app.clock.nowMs()), closeTo(anchor, 1e-6));

    // A pan ends it: time passes, the view stays.
    await tester.drag(find.byKey(StripKeys.lanes), const Offset(150, 0));
    await tester.pump();
    expect(v.following, isFalse);
    expect(canJump(), isTrue);
    final parked = v.startMs;
    await h.advance(const Duration(seconds: 30));
    expect(v.startMs, parked);
    // The running bar still grows to the now line.
    expect(h.strip.layout.nowX, closeTo(v.xOf(h.app.clock.nowMs()), 1e-6));

    // "Jetzt" takes it up again.
    await h.tap(find.byKey(StripKeys.now));
    expect(v.following, isTrue);
    expect(v.xOf(h.app.clock.nowMs()), closeTo(anchor, 1e-6));
    expect(tester.takeException(), isNull);
  });

  testWidgets('markers that are too close show as a cluster; a tap zooms '
      'into it', (tester) async {
    final h = await TracksHarness.start(tester);
    final first = await h.tick(h.counter);
    await h.advance(const Duration(seconds: 20));
    final second = await h.tick(h.counter);
    await h.advance(const Duration(seconds: 20));
    final third = await h.tick(h.counter);
    await h.advance(const Duration(hours: 3));
    final late = await h.tick(h.counter);
    await h.showTimeline();
    final v = h.viewport;

    var layout = h.strip.layout;
    final cluster = layout.clusters.single;
    expect(cluster.count, 3);
    expect(h.markerOf(first), isNull);
    expect(h.markerOf(late), isNotNull);

    final scale = v.msPerPx;
    await tester.tapAt(h.lanesOrigin + cluster.rect.center);
    await h.settle();
    expect(v.msPerPx, lessThan(scale));
    layout = h.strip.layout;
    expect(layout.clusters, isEmpty);
    for (final e in [first, second, third]) {
      final m = h.markerOf(e)!;
      expect(m.center.dx, inInclusiveRange(0, v.width));
    }
    // No sheet opened: the tap only zoomed.
    expect(find.byKey(StripDetailKeys.event), findsNothing);

    // Zooming out again clusters them again.
    await h.tap(find.byKey(StripKeys.fit));
    expect(h.strip.layout.clusters.single.count, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop: Ctrl + wheel zooms around the pointer, the wheel '
      'scrolls along the time, a hover names the marker', (tester) async {
    final h = await TracksHarness.start(
      tester,
      surfaceSize: const Size(1270, 720),
    );
    final (_, ticks) = await _birds(h);
    await h.showTimeline();
    final v = h.viewport;
    final wheel = TikkyTokens.fallback.strip.wheelZoomDistance;

    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    final local = h.markerOf(ticks[1])!.center;
    final position = h.lanesOrigin + local;
    await tester.sendEventToBinding(mouse.hover(position));
    await tester.pump();
    // Time and the wording of the list.
    expect(
      find.descendant(
        of: find.byKey(StripKeys.tooltip),
        matching: find.text(
          TracksStrings.stripMarkerTip(
            Fmt.time(ticks[1].at, seconds: true),
            'Ente · 1',
          ),
        ),
      ),
      findsOneWidget,
    );

    // Ctrl + wheel: closer, and the instant under the pointer stays.
    final fitScale = v.msPerPx;
    final under = v.timeAt(local.dx);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendEventToBinding(mouse.scroll(Offset(0, -2 * wheel)));
    await tester.pump();
    expect(v.msPerPx, closeTo(fitScale / 4, 1e-6));
    expect(v.timeAt(local.dx), closeTo(under, 1e-3));
    expect(h.markerOf(ticks[1])!.center.dx, closeTo(local.dx, 1e-3));
    await tester.sendEventToBinding(mouse.scroll(Offset(0, wheel)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(v.msPerPx, closeTo(fitScale / 2, 1e-6));
    expect(v.timeAt(local.dx), closeTo(under, 1e-3));
    // The view moved: the hover text is gone until the pointer moves.
    expect(find.byKey(StripKeys.tooltip), findsNothing);

    // Plain wheel: along the time, the zoom stays.
    final scale = v.msPerPx;
    var start = v.startMs;
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, 50)));
    await tester.pump();
    expect(v.msPerPx, scale);
    expect(v.startMs, closeTo(start + 50 * scale, 1e-6));
    // Shift + wheel as well.
    start = v.startMs;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -50)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(v.startMs, closeTo(start - 50 * scale, 1e-6));

    // Dragging with the mouse pans - on the axis too.
    start = v.startMs;
    await tester.sendEventToBinding(mouse.removePointer());
    await tester.drag(
      find.byKey(StripKeys.axis),
      const Offset(-100, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(v.startMs, greaterThan(start));
    expect(v.msPerPx, scale);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard: arrows pan, + and - zoom, Home fits, End goes to '
      'now', (tester) async {
    final h = await TracksHarness.start(
      tester,
      surfaceSize: const Size(1270, 720),
    );
    await _birds(h);
    await h.showTimeline();
    final v = h.viewport;
    final t = TikkyTokens.fallback.strip;
    final fitScale = v.msPerPx;
    final fitStart = v.startMs;

    // "+" where the layout has it (here: the key right of "ü").
    await tester.sendKeyEvent(LogicalKeyboardKey.bracketRight, character: '+');
    await tester.pump();
    expect(v.msPerPx, closeTo(fitScale / t.zoomStep, 1e-6));
    await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd);
    await tester.pump();
    expect(v.msPerPx, closeTo(fitScale / t.zoomStep / t.zoomStep, 1e-6));
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.pump();
    expect(v.msPerPx, closeTo(fitScale / t.zoomStep, 1e-6));

    var start = v.startMs;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(v.startMs, closeTo(start + v.spanMs * t.keyPanShare, 1e-6));
    start = v.startMs;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(v.startMs, closeTo(start - 2 * v.spanMs * t.keyPanShare, 1e-6));

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();
    expect(v.following, isTrue);
    expect(v.xOf(h.app.clock.nowMs()), closeTo(v.width * t.followAnchor, 1e-6));

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pump();
    expect(v.following, isFalse);
    expect(v.msPerPx, closeTo(fitScale, 1e-6));
    expect(v.startMs, closeTo(fitStart, 1e-6));

    // The keys of the tracks screen still work: N adds a track.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await h.settle();
    expect(find.text(Strings.newTrack), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the scope and the filters apply to the strip', (tester) async {
    final h = await TracksHarness.start(tester);
    // A closed session ...
    final old = await h.tick(h.counter);
    await h.run(() => h.commands.stopTrack(h.counter.id));
    await h.advance(const Duration(minutes: 30));
    // ... and open ones.
    final (birds, ticks) = await _birds(h);
    await h.run(() => h.commands.startTrack(h.stopwatch.id));
    await h.advance(const Duration(minutes: 1));
    await h.showTimeline();

    expect(h.stripLane(birds.id), findsOneWidget);
    expect(h.stripLane(h.stopwatch.id), findsOneWidget);
    expect(h.stripLane(h.counter.id), findsNothing);
    expect(h.markerOf(old), isNull);
    final openStart = h.viewport.extentStart;

    // "Letzte 24 h" also shows what has ended - and fits the view again.
    await h.tap(find.byKey(TimelineKeys.scope));
    await h.tap(find.text(TracksStrings.scopeLast24h).last);
    expect(h.stripLane(h.counter.id), findsOneWidget);
    expect(h.viewport.extentStart, lessThan(openStart));
    expect(h.viewport.xOf(old.at), inInclusiveRange(0, h.viewport.width));
    expect(
      h.strip.layout.markers.any((m) => m.event?.row.event.id == old.id) ||
          h.strip.layout.clusters.any(
            (c) => c.events.any((e) => e.row.event.id == old.id),
          ),
      isTrue,
    );

    // Start and stop become markers only with the chip.
    bool lifecycle() =>
        h.strip.layout.markers.any(
          (m) => m.kind == StripMarkerKind.lifecycle,
        ) ||
        h.strip.layout.clusters.any(
          (c) => c.events.any((e) => e.kind == StripMarkerKind.lifecycle),
        );
    expect(lifecycle(), isFalse);
    await h.tapChip(TimelineKeys.lifecycle);
    expect(lifecycle(), isTrue);
    await h.tapChip(TimelineKeys.lifecycle);
    expect(lifecycle(), isFalse);

    // Hiding a track removes its lane.
    await h.tapChip(TimelineKeys.trackChip(birds.id));
    expect(h.stripLane(birds.id), findsNothing);
    expect(h.stripLane('${birds.id}/l/Reiher'), findsNothing);
    expect(h.markerOf(ticks[0]), isNull);
    expect(h.stripLane(h.stopwatch.id), findsOneWidget);
    await h.tapChip(TimelineKeys.trackChip(h.stopwatch.id));
    await h.tapChip(TimelineKeys.trackChip(h.counter.id));
    expect(find.text(TracksStrings.timelineAllHidden), findsOneWidget);
    expect(find.byKey(StripKeys.lanes), findsNothing);
    await h.tapChip(TimelineKeys.trackChip(birds.id));
    expect(h.stripLane(birds.id), findsOneWidget);
    expect(h.markerOf(ticks[0]), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing happened yet: a friendly empty state', (tester) async {
    final h = await TracksHarness.start(tester);
    await h.showTimeline();
    expect(find.byKey(StripKeys.lanes), findsNothing);
    expect(find.text(TracksStrings.timelineEmptyTitle), findsOneWidget);
    expect(find.text(TracksStrings.timelineEmptyOpen), findsOneWidget);
    // The mode switch and the scope are still there.
    expect(find.byKey(TimelineKeys.mode), findsOneWidget);
    await h.tap(find.byKey(TimelineKeys.scope));
    await h.tap(find.text(TracksStrings.scopeToday).last);
    expect(find.text(TracksStrings.timelineEmptyRange), findsOneWidget);

    // The first event brings the strip, fitted to it.
    final tick = await h.tick(h.counter);
    await h.settle();
    expect(find.text(TracksStrings.timelineEmptyTitle), findsNothing);
    expect(find.byKey(StripKeys.lanes), findsOneWidget);
    expect(h.markerOf(tick)!.center.dx, inInclusiveRange(0, h.viewport.width));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a counter keeps one lane when the lanes would not fit', (
    tester,
  ) async {
    final h = await TracksHarness.start(
      tester,
      surfaceSize: const Size(640, 360),
    );
    final (birds, ticks) = await _birds(h);
    await h.tick(h.counter);
    await h.run(() => h.commands.startTrack(h.stopwatch.id));
    await h.run(() => h.commands.startTrack(h.timer.id));
    await h.advance(const Duration(minutes: 1));
    await h.showTimeline();
    expect(tester.takeException(), isNull);

    // Landscape phone: little height, so no lane per label.
    expect(h.stripLane(birds.id), findsOneWidget);
    expect(h.stripLane('${birds.id}/l/Reiher'), findsNothing);
    expect(h.markerOf(ticks[0])!.event!.label, 'Reiher');
    // What does not fit scrolls vertically; the axis stays.
    final axisTop = tester.getTopLeft(find.byKey(StripKeys.axis)).dy;
    final last = h.stripLane(birds.id);
    final before = tester.getTopLeft(last).dy;
    await tester.dragFrom(
      tester.getTopLeft(find.byKey(StripKeys.gutter)) + const Offset(40, 20),
      const Offset(0, -60),
    );
    await tester.pump();
    expect(tester.getTopLeft(last).dy, lessThan(before));
    expect(tester.getTopLeft(find.byKey(StripKeys.axis)).dy, axisTop);
    expect(tester.takeException(), isNull);
  });

  for (final (size, scale) in const [
    (Size(360, 640), 1.6),
    (Size(640, 360), 1.3),
    (Size(1270, 720), 1.5),
  ]) {
    testWidgets('no overflow at ${size.width.toInt()} x '
        '${size.height.toInt()} with text scale $scale, roomy density, '
        '12-hour times and long names', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = await TracksHarness.start(tester, surfaceSize: size);
      final people = h.container.read(peopleRepositoryProvider);
      final person = await h.run(
        () => people.createPerson(name: 'Jemand mit einem sehr langen Namen'),
      );
      final substance = await h.run(
        () => people.createSubstance(
          name: 'Etwas mit langem Namen',
          lockoutMs: 45 * 60 * 1000,
        ),
      );
      final tent = await h.addTrack(
        const ProtocolConfig(),
        name: 'Zelt hinten links am Waldrand',
      );
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
      await h.run(
        () => h.commands.addEntry(
          tent.id,
          personId: person.id,
          substanceId: substance.id,
          amount: 'eine ganze Menge Text',
        ),
      );
      await h.advance(const Duration(minutes: 20));
      await h.tick(birds, label: 'Eichhörnchen mit sehr langem Namen');
      await h.showTimeline();
      expect(tester.takeException(), isNull);
      expect(find.byKey(StripKeys.lanes), findsOneWidget);

      // The narrow gutter on a phone: colour dot and the cut-off name.
      final gutter = tester.getSize(find.byKey(StripKeys.gutter)).width;
      final strip = TikkyTokens.fallback.strip;
      expect(
        gutter,
        size.width < strip.narrowBreakpoint ? strip.gutterNarrow : strip.gutter,
      );
      expect(tester.getRect(find.byKey(StripKeys.lanes)).right, size.width);

      await h.tap(find.byKey(StripKeys.zoomIn));
      await h.tap(find.byKey(StripKeys.zoomOut));
      await h.tap(find.byKey(StripKeys.now));
      await h.tap(find.byKey(StripKeys.fit));
      await h.tapChip(TimelineKeys.lifecycle);
      expect(tester.takeException(), isNull);
      await tester.dragFrom(
        h.lanesOrigin + const Offset(120, 12),
        const Offset(-90, 0),
      );
      await tester.pump();
      await h.tap(find.byKey(StripKeys.fit));
      expect(tester.takeException(), isNull);

      // The detail of a marker fits as well.
      final marker = h.markerOf(tick);
      if (marker != null) {
        await tester.ensureVisible(find.byKey(StripKeys.lane(birds.id)));
        await tester.pump();
        final at = h.lanesOrigin + h.markerOf(tick)!.center;
        if (tester.getRect(find.byKey(StripKeys.view)).contains(at)) {
          await tester.tapAt(at);
          await h.settle();
          expect(tester.takeException(), isNull);
        }
      }
    });
  }

  testWidgets('screen readers: a summary of the strip, the names of the '
      'lanes and a node per visible marker', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      final h = await TracksHarness.start(tester);
      final (birds, ticks) = await _birds(h);
      await h.showTimeline();

      // Three lanes (the counter and its two labels), three events - and
      // where to find the same as text.
      final summary = TracksStrings.stripSemantics(3, 3);
      expect(summary, contains('„Liste“'));
      expect(find.semantics.byLabel(summary), findsOne);
      expect(find.semantics.byLabel(birds.name), findsAtLeast(1));
      expect(
        find.semantics.byLabel(
          TracksStrings.stripSubLane(birds.name, 'Reiher'),
        ),
        findsOne,
      );
      for (final label in [
        TracksStrings.stripZoomIn,
        TracksStrings.stripZoomOut,
        TracksStrings.stripFit,
        TracksStrings.stripNow,
      ]) {
        expect(find.semantics.byLabel(label), findsAtLeast(1), reason: label);
      }

      // The markers read like the rows of the list.
      String label(TrackEvent e, String text) =>
          TracksStrings.timelineRowSemantics(
            Fmt.time(e.at, seconds: true),
            birds.name,
            text,
          );
      expect(find.semantics.byLabel(label(ticks[0], 'Reiher · 1')), findsOne);
      expect(find.semantics.byLabel(label(ticks[1], 'Ente · 1')), findsOne);
      expect(find.semantics.byLabel(label(ticks[2], 'Reiher · 2')), findsOne);

      // After a pan the nodes sit where the markers are now.
      final node = find.semantics.byLabel(label(ticks[2], 'Reiher · 2'));
      final before = node.evaluate().single.rect;
      expect(before.center.dx, closeTo(h.markerOf(ticks[2])!.center.dx, 0.5));
      await tester.dragFrom(
        h.lanesOrigin + const Offset(150, 12),
        const Offset(-80, 0),
      );
      await tester.pump();
      await tester.pump();
      final after = node.evaluate().single.rect;
      expect(after.center.dx, lessThan(before.center.dx - 20));
      expect(after.center.dx, closeTo(h.markerOf(ticks[2])!.center.dx, 0.5));
      // What left the view has no node any more.
      await h.tap(find.byKey(StripKeys.zoomIn));
      await tester.pump();
      expect(h.markerOf(ticks[0]), isNull);
      expect(
        find.semantics.byLabel(label(ticks[0], 'Reiher · 1')),
        findsNothing,
      );
      await h.tap(find.byKey(StripKeys.fit));
      await tester.pump();

      // Activating a node opens what a tap opens.
      tester.semantics.tap(node);
      await h.settle();
      expect(find.byKey(StripDetailKeys.event), findsOneWidget);
      expect(find.text('Reiher · 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('the set theme and preference overrides apply to the strip', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    await _birds(h);
    await h.run(
      () => h.container
          .read(setRepositoryProvider)
          .updateSet(
            h.activeSet.copyWith(
              themeId: () => ThemePresets.blackId,
              uiPrefsOverride: () => {
                UiPrefsKeys.density: UiDensity.roomy.name,
              },
            ),
          ),
    );
    await tester.pump(const Duration(seconds: 1));
    await h.showTimeline();
    final context = tester.element(find.byKey(StripKeys.lanes));
    expect(context.tikky.theme.id, ThemePresets.blackId);
    // The lanes follow the density of the set.
    final roomy = TikkyTokens(
      theme: ThemePresets.light,
      prefs: const UiPrefs(density: UiDensity.roomy),
    ).strip;
    expect(roomy.lane, greaterThan(TikkyTokens.fallback.strip.lane));
    expect(h.strip.layout.rowHeights.first, roomy.lane);
    expect(h.strip.layout.rowHeights[1], roomy.subLane);
    expect(tester.takeException(), isNull);
  });
}
