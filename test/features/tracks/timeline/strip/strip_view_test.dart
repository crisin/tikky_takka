import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/adaptive/adaptive.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/tracks/timeline/evening/evening_view.dart';
import 'package:tikky_takka/features/tracks/timeline/person_cards.dart';
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

  Future<void> mode(String label) => tap(
    find.descendant(
      of: find.byKey(TimelineKeys.level),
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
  testWidgets('"Jetzt" is the default level; "Abend" shows the evening, '
      '"Kompakt" its list', (tester) async {
    final h = await TracksHarness.start(tester);
    await _birds(h);
    await h.showTimeline();

    expect(find.byKey(StripKeys.view), findsOneWidget);
    expect(find.byKey(StripKeys.lanes), findsOneWidget);
    expect(find.byKey(TimelineKeys.list), findsNothing);
    // The day and "Kompakt" belong to the evening.
    expect(find.byKey(TimelineKeys.compact), findsNothing);
    // Without a protocol there are no person cards above.
    expect(find.byKey(PersonCardKeys.row), findsNothing);

    Finder segment(String label) => find.descendant(
      of: find.byKey(TimelineKeys.level),
      matching: find.text(label),
    );
    expect(
      tester.getCenter(segment(TracksStrings.levelNow)).dx,
      lessThan(tester.getCenter(segment(TracksStrings.levelEvening)).dx),
    );

    await h.mode(TracksStrings.levelEvening);
    expect(find.byKey(EveningKeys.view), findsOneWidget);
    expect(find.byKey(StripKeys.view), findsNothing);
    await h.tap(find.byKey(TimelineKeys.compact));
    expect(find.byKey(TimelineKeys.list), findsOneWidget);
    expect(find.byKey(TimelineKeys.order), findsOneWidget);
    await h.mode(TracksStrings.levelNow);
    expect(find.byKey(StripKeys.view), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the level is remembered per set; a stored mode of before is '
      'taken over', (tester) async {
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
    String? level(String setId) =>
        h.app.settings.getString('${SettingsKeys.timelineLevelPrefix}$setId');
    expect(level(first.id), isNull);

    await h.mode(TracksStrings.levelEvening);
    expect(level(first.id), 'evening');

    // Another set starts with "Jetzt" ...
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
    await h.run(
      () => h.container.read(activeSetIdProvider.notifier).select(first.id),
    );
    await h.settle();
    expect(find.byKey(EveningKeys.view), findsOneWidget);

    // The mode of before: the list is the evening as a list, the summary
    // the evening, the strip "Jetzt".
    await h.run(() async {
      final store = h.app.settings;
      await store.setString('${SettingsKeys.timelineModePrefix}a', 'list');
      await store.setString('${SettingsKeys.timelineModePrefix}b', 'summary');
      await store.setString('${SettingsKeys.timelineModePrefix}c', 'strip');
      // Once there is a level, it wins.
      await store.setString('${SettingsKeys.timelineModePrefix}d', 'list');
      await store.setString('${SettingsKeys.timelineLevelPrefix}d', 'now');
    });
    final restarted = ProviderContainer(overrides: h.app.overrides);
    addTearDown(restarted.dispose);
    TimelineChoice choice(String setId) =>
        restarted.read(timelineChoiceProvider(setId));
    expect(
      choice('a'),
      const TimelineChoice(TimelineLevel.evening, compact: true),
    );
    expect(choice('b'), const TimelineChoice(TimelineLevel.evening));
    expect(choice('c'), TimelineChoice.initial);
    expect(choice('d').level, TimelineLevel.now);
    expect(choice(first.id).level, TimelineLevel.evening);
    expect(choice('unknown'), TimelineChoice.initial);
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

  testWidgets('"Alles" and "Jetzt"; following stops when the user '
      'pans', (tester) async {
    final h = await TracksHarness.start(tester);
    await _birds(h);
    await h.run(() => h.commands.startTrack(h.stopwatch.id));
    await h.advance(const Duration(minutes: 2));
    await h.showTimeline();
    final v = h.viewport;
    final step = TikkyTokens.fallback.strip.zoomStep;
    bool canJump() =>
        tester.widget<PillButton>(find.byKey(StripKeys.now)).onPressed != null;
    expect(find.text(TracksStrings.stripAll), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(StripKeys.now),
        matching: find.text(TracksStrings.stripNow),
      ),
      findsOneWidget,
    );
    Future<void> zoom(double factor) async {
      v.zoomBy(factor);
      await tester.pump();
    }

    // The first view shows everything, with a little air.
    final now = h.app.clock.nowMs();
    final fitStart = v.startMs;
    final fitScale = v.msPerPx;
    expect(v.following, isFalse);
    expect(v.xOf(v.extentStart), greaterThan(0));
    expect(v.xOf(now), lessThan(v.width));
    expect(v.xOf(now), greaterThan(v.width * 0.9));

    await zoom(step);
    expect(v.msPerPx, closeTo(fitScale / step, 1e-6));
    await zoom(step);
    expect(v.msPerPx, closeTo(fitScale / step / step, 1e-6));
    await zoom(1 / step);
    expect(v.msPerPx, closeTo(fitScale / step, 1e-6));
    // The middle stayed where it was.
    expect(
      v.timeAt(v.width / 2),
      closeTo(fitStart + fitScale * v.width / 2, 1),
    );
    // Not further out than everything.
    await zoom(1 / step);
    await zoom(1 / step);
    expect(v.msPerPx, closeTo(fitScale, 1e-6));

    await zoom(step);
    await zoom(step);
    await tester.drag(find.byKey(StripKeys.lanes), const Offset(120, 0));
    await tester.pump();
    await h.tap(find.byKey(StripKeys.fit));
    expect(v.msPerPx, closeTo(fitScale, 1e-6));
    expect(v.startMs, closeTo(fitStart, 1e-6));

    // "Jetzt" jumps to the now line and follows it.
    await zoom(step);
    await zoom(step);
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
    await zoom(step);
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

  testWidgets('"Jetzt" shows the open sessions; the filters apply to the '
      'strip', (tester) async {
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
    // The level switch is still there.
    expect(find.byKey(TimelineKeys.level), findsOneWidget);

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
      h.lanesOrigin + const Offset(40, 20),
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

      // The lanes take the whole width; long names are cut off.
      expect(tester.getRect(find.byKey(StripKeys.lanes)).right, size.width);
      expect(
        tester.getRect(find.byKey(StripKeys.lanes)).left,
        tester.getRect(find.byKey(StripKeys.view)).left,
      );

      h.viewport.zoomBy(2);
      await tester.pump();
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
      for (final label in [TracksStrings.stripFit, TracksStrings.stripToNow]) {
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
      h.viewport.zoomBy(TikkyTokens.fallback.strip.zoomStep);
      await tester.pump();
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
