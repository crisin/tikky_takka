import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/tracks/set_switcher.dart';
import 'package:tikky_takka/features/tracks/track_editor_sheet.dart';
import 'package:tikky_takka/features/tracks/track_lane.dart';
import 'package:tikky_takka/features/tracks/tracks_screen.dart';
import 'package:tikky_takka/features/tracks/tracks_strings.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../../support/test_app.dart';
import 'tracks_harness.dart';

void main() {
  group('app bar', () {
    testWidgets('start all / pause all act on the active set', (tester) async {
      final h = await TracksHarness.start(tester);
      final toggle = find.byKey(TracksScreenKeys.toggleAll);

      expect(find.byTooltip(Strings.startAll), findsOneWidget);
      await h.tap(toggle);

      expect((await h.snapshot(h.stopwatch))!.isRunning, isTrue);
      expect((await h.snapshot(h.timer))!.isRunning, isTrue);
      // Counters are tap-driven and never started in bulk.
      expect(await h.snapshot(h.counter), isNull);
      expect(find.byTooltip(Strings.pauseAll), findsOneWidget);

      await h.advance(const Duration(seconds: 3));
      await h.tap(toggle);
      expect((await h.snapshot(h.stopwatch))!.isPaused, isTrue);
      expect((await h.snapshot(h.timer))!.isPaused, isTrue);
      expect(find.byTooltip(Strings.startAll), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a set without anything to start has no toggle', (
      tester,
    ) async {
      final h = await TracksHarness.start(tester);
      final repo = h.container.read(trackRepositoryProvider);
      await h.run(() async {
        await repo.deleteTrack(h.stopwatch.id);
        await repo.deleteTrack(h.timer.id);
      });
      expect(find.byKey(TracksScreenKeys.toggleAll), findsNothing);
      expect(find.byKey(TracksScreenKeys.addTrack), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('empty states', () {
    testWidgets('an empty set invites to add a track', (tester) async {
      final h = await TracksHarness.start(tester);
      final repo = h.container.read(trackRepositoryProvider);
      await h.run(() async {
        for (final track in h.tracks) {
          await repo.deleteTrack(track.id);
        }
      });

      expect(find.text(Strings.tracksEmptyTitle), findsOneWidget);
      await h.tap(find.byKey(TracksScreenKeys.emptyAddTrack));
      expect(find.text(Strings.newTrack), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no set at all offers to create one', (tester) async {
      final h = await TracksHarness.start(tester);
      final sets = h.container.read(setRepositoryProvider);
      final id = h.activeSet.id;
      await h.run(() => sets.deleteSet(id));

      expect(find.text(Strings.noSetsTitle), findsOneWidget);
      await h.tap(find.text(TracksStrings.createSet));
      await tester.enterText(find.byType(TextField), 'Küche');
      await h.tap(find.text(Strings.save));

      expect(h.activeSet.name, 'Küche');
      expect(find.text(Strings.tracksEmptyTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('set switcher', () {
    testWidgets('creates a set and switches between sets', (tester) async {
      final h = await TracksHarness.start(tester);

      await h.tap(find.byType(SetSwitcherButton));
      expect(find.text(TracksStrings.setsTitle), findsOneWidget);
      expect(find.text(TracksStrings.setTrackCount(3)), findsOneWidget);

      await h.tap(find.text(Strings.newSet));
      await tester.enterText(find.byType(TextField), 'Training');
      await h.tap(find.text(Strings.save));

      // The new set is active, the sheet is closed, the set is empty.
      expect(h.activeSet.name, 'Training');
      expect(find.text(TracksStrings.setsTitle), findsNothing);
      expect(find.text(Strings.tracksEmptyTitle), findsOneWidget);
      expect(find.byType(TrackLane), findsNothing);

      await h.tap(find.byType(SetSwitcherButton));
      await h.tap(find.text(Strings.seedSetName));
      expect(h.activeSet.name, Strings.seedSetName);
      expect(find.byType(TrackLane), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renames a set', (tester) async {
      final h = await TracksHarness.start(tester);

      await h.tap(find.byType(SetSwitcherButton));
      await h.tap(
        find.byTooltip('${TracksStrings.setOptions}: ${Strings.seedSetName}'),
      );
      await h.tap(find.text(Strings.rename));
      await tester.enterText(find.byType(TextField), 'Alltag');
      await h.tap(find.text(Strings.save));

      expect(h.activeSet.name, 'Alltag');
      expect(find.text('Alltag'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('deletes a set after confirmation, with undo', (tester) async {
      final h = await TracksHarness.start(tester);
      final sets = h.container.read(setRepositoryProvider);
      await h.run(() => sets.createSet(name: 'Festival'));
      await h.tap(h.primary(h.stopwatch));
      await h.advance(const Duration(seconds: 4));

      await h.tap(find.byType(SetSwitcherButton));
      await h.tap(
        find.byTooltip('${TracksStrings.setOptions}: ${Strings.seedSetName}'),
      );
      await h.tap(find.text(Strings.deleteSet));
      expect(
        find.text(TracksStrings.deleteSetQuestion(Strings.seedSetName)),
        findsOneWidget,
      );
      await h.tap(find.text(Strings.delete));

      // The other set took over; the deleted one is gone with its tracks.
      expect(h.activeSet.name, 'Festival');
      expect(find.byType(TrackLane), findsNothing);
      expect(find.text(Strings.setDeleted), findsOneWidget);

      await h.tap(find.text(Strings.undo));
      expect(h.activeSet.name, Strings.seedSetName);
      expect(find.byType(TrackLane), findsNWidgets(3));
      // The running session came back with the set.
      expect((await h.snapshot(h.stopwatch))!.isRunning, isTrue);
      expect(h.digits(h.stopwatch), '00:04');
      expect(tester.takeException(), isNull);
    });

    testWidgets('reorders sets by dragging the grip', (tester) async {
      final h = await TracksHarness.start(tester);
      final sets = h.container.read(setRepositoryProvider);
      await h.run(() => sets.createSet(name: 'Festival'));

      await h.tap(find.byType(SetSwitcherButton));
      final grip = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(LaneDragHandle),
      );
      expect(grip, findsNWidgets(2));
      final gesture = await tester.startGesture(tester.getCenter(grip.first));
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 15));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await h.settle();

      final stored = await tester.runAsync(sets.getSets);
      expect([for (final s in stored!) s.name], ['Festival', 'Allgemein']);
      expect(tester.takeException(), isNull);
    });
  });

  group('track editor', () {
    testWidgets('long-press opens the editor; renaming is saved', (
      tester,
    ) async {
      final h = await TracksHarness.start(tester);
      final track = h.stopwatch;

      await tester.longPress(find.byKey(LaneKeys.digits(track.id)));
      await h.settle();
      expect(find.text(Strings.editTrack), findsOneWidget);

      await tester.enterText(find.byKey(TrackEditorKeys.name), 'Arbeit');
      await h.tap(find.byKey(TrackEditorKeys.save));

      expect(find.text(Strings.editTrack), findsNothing);
      expect(h.tracks.first.name, 'Arbeit');
      expect(find.textContaining('Arbeit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('right-click opens the editor too', (tester) async {
      final h = await TracksHarness.start(tester);
      await tester.tap(
        find.byKey(LaneKeys.digits(h.timer.id)),
        buttons: kSecondaryButton,
      );
      await h.settle();
      expect(find.text(Strings.editTrack), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('adds a track with a chosen mode and colour', (tester) async {
      final h = await TracksHarness.start(tester);

      await h.tap(find.byKey(TracksScreenKeys.addTrack));
      expect(find.text(Strings.newTrack), findsOneWidget);

      await tester.enterText(find.byKey(TrackEditorKeys.name), 'Nudeln');
      await h.tap(find.byKey(TrackEditorKeys.mode));
      await h.tap(find.text(Strings.modeCountdown).last);
      expect(find.text(Strings.optAutoRestart), findsOneWidget);
      await h.tap(find.byKey(TrackEditorKeys.swatch(5)));
      await h.tap(find.text(Strings.optAutoRestart));
      await h.tap(find.byKey(TrackEditorKeys.save));

      final track = h.trackNamed('Nudeln');
      expect(track.mode, TrackMode.countdown);
      expect(track.colorIndex, 5);
      expect(track.customColor, isNull);
      expect((track.config as CountdownConfig).autoRestart, isTrue);
      expect(find.byType(TrackLane), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unnamed track is named after its mode', (tester) async {
      final h = await TracksHarness.start(tester);
      await h.tap(find.byKey(TracksScreenKeys.addTrack));
      await h.tap(find.byKey(TrackEditorKeys.mode));
      await h.tap(find.text(Strings.modeReminder));
      await h.tap(find.byKey(TrackEditorKeys.save));

      expect(h.tracks.last.name, Strings.modeReminder);
      expect(h.tracks.last.mode, TrackMode.reminder);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mode options: interval rounds and exclusive stopwatch', (
      tester,
    ) async {
      final h = await TracksHarness.start(tester);
      final interval = await h.addTrack(
        const IntervalConfig(rounds: 3),
        name: 'Training',
      );

      await tester.longPress(find.byKey(LaneKeys.digits(interval.id)));
      await h.settle();
      await h.tap(find.byTooltip(TracksStrings.roundsMore));
      await h.tap(find.byTooltip(TracksStrings.roundsMore));
      await h.tap(find.byTooltip(TracksStrings.roundsFewer));
      await h.tap(find.byKey(TrackEditorKeys.save));
      expect((h.trackNamed('Training').config as IntervalConfig).rounds, 4);

      await tester.longPress(find.byKey(LaneKeys.digits(h.stopwatch.id)));
      await h.settle();
      await h.tap(find.text(Strings.optExclusive));
      await h.tap(find.byKey(TrackEditorKeys.save));
      expect((h.stopwatch.config as StopwatchConfig).exclusive, isTrue);
      expect(h.subLine(h.stopwatch), contains(TracksStrings.exclusiveTag));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a duration is picked with the adaptive picker', (
      tester,
    ) async {
      final h = await TracksHarness.start(tester);
      await tester.longPress(find.byKey(LaneKeys.digits(h.timer.id)));
      await h.settle();

      expect(find.text('10:00'), findsWidgets);
      await h.tap(find.text(Strings.optDuration));
      // The picker is open (Material wheel dialog on this platform).
      expect(find.byType(Dialog), findsOneWidget);
      await h.tap(find.text(Strings.cancel).last);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text(Strings.editTrack), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('counter labels are edited as chips', (tester) async {
      final h = await TracksHarness.start(tester);
      final track = h.counter;

      await tester.longPress(find.byKey(LaneKeys.digits(track.id)));
      await h.settle();
      expect(find.text(TracksStrings.noLabels), findsOneWidget);

      for (final label in ['Hund', 'Reiher']) {
        await tester.ensureVisible(find.byKey(TrackEditorKeys.addLabel));
        await h.tap(find.byKey(TrackEditorKeys.addLabel));
        await tester.enterText(find.byType(TextField).last, label);
        await h.tap(find.text(Strings.save).last);
      }
      expect(find.byType(InputChip), findsNWidgets(2));

      await h.tap(find.byTooltip(TracksStrings.removeLabel('Reiher')));
      expect(find.byType(InputChip), findsOneWidget);
      await h.tap(find.byKey(TrackEditorKeys.save));

      expect((h.counter.config as CounterConfig).labels, ['Hund']);
      expect(find.byKey(LaneKeys.label(track.id, 'Hund')), findsOneWidget);
      expect(h.primary(track), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a custom colour is chosen with the colour sheet', (
      tester,
    ) async {
      final h = await TracksHarness.start(tester);
      await tester.longPress(find.byKey(LaneKeys.digits(h.stopwatch.id)));
      await h.settle();

      await h.tap(find.byKey(TrackEditorKeys.customColor));
      expect(find.text(Strings.pickColor), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '12AB34');
      await h.tap(find.text(Strings.done));
      await h.tap(find.byKey(TrackEditorKeys.save));

      expect(h.stopwatch.customColor, 0xFF12AB34);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing the mode ends the running session', (tester) async {
      final h = await TracksHarness.start(tester);
      final track = h.stopwatch;
      await h.tap(h.primary(track));
      await h.advance(const Duration(seconds: 5));

      await tester.longPress(find.byKey(LaneKeys.digits(track.id)));
      await h.settle();
      await h.tap(find.byKey(TrackEditorKeys.mode));
      await h.tap(find.text(Strings.modeCounter).last);
      expect(find.text(TracksStrings.modeChangeStopsSession), findsOneWidget);
      await h.tap(find.byKey(TrackEditorKeys.save));

      expect(h.tracks.first.mode, TrackMode.counter);
      expect(await h.snapshot(track), isNull);
      expect(h.digits(track), '0');
      expect(tester.takeException(), isNull);
    });

    testWidgets('delete removes the track without asking; undo restores it', (
      tester,
    ) async {
      final h = await TracksHarness.start(tester);
      final track = h.counter;
      await h.tap(h.primary(track));
      await h.tap(h.primary(track));

      await tester.longPress(find.byKey(LaneKeys.digits(track.id)));
      await h.settle();
      await tester.ensureVisible(find.byKey(TrackEditorKeys.delete));
      await h.tap(find.byKey(TrackEditorKeys.delete));

      expect(find.byType(AlertDialog), findsNothing);
      expect(h.tracks, hasLength(2));
      expect(find.text(Strings.trackDeleted), findsOneWidget);

      await h.tap(find.text(Strings.undo));
      expect(h.tracks, hasLength(3));
      // The open session and its ticks are back as well.
      expect(((await h.snapshot(track))! as CounterSnapshot).count, 2);
      expect(h.digits(track), '2');
      expect(tester.takeException(), isNull);
    });

    testWidgets('archive hides the track; undo and the set sheet restore it', (
      tester,
    ) async {
      final h = await TracksHarness.start(tester);
      final track = h.timer;

      await tester.longPress(find.byKey(LaneKeys.digits(track.id)));
      await h.settle();
      await tester.ensureVisible(find.byKey(TrackEditorKeys.archive));
      await h.tap(find.byKey(TrackEditorKeys.archive));
      expect(h.tracks, hasLength(2));
      expect(find.text(Strings.trackArchived), findsOneWidget);

      await h.tap(find.text(Strings.undo));
      expect(h.tracks, hasLength(3));

      // Archive again and bring it back from the set sheet.
      final repo = h.container.read(trackRepositoryProvider);
      await h.run(() => repo.setArchived(track.id, archived: true));
      expect(h.tracks, hasLength(2));
      await h.tap(find.byType(SetSwitcherButton));
      await h.tap(find.text(TracksStrings.archivedTracks(1)));
      await h.tap(find.text(Strings.seedTimerName).last);
      expect(h.tracks, hasLength(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('duplicate copies the configuration', (tester) async {
      final h = await TracksHarness.start(tester);
      await tester.longPress(find.byKey(LaneKeys.digits(h.timer.id)));
      await h.settle();
      await tester.ensureVisible(find.byKey(TrackEditorKeys.duplicate));
      await h.tap(find.byKey(TrackEditorKeys.duplicate));

      expect(h.tracks, hasLength(4));
      final copy = h.tracks.last;
      expect(copy.name, Strings.themeCopyName(Strings.seedTimerName));
      expect(copy.config, h.timer.config);
      expect(find.text(TracksStrings.trackDuplicated), findsOneWidget);

      await h.tap(find.text(Strings.undo));
      expect(h.tracks, hasLength(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('move to another set, with undo', (tester) async {
      final h = await TracksHarness.start(tester);
      final sets = h.container.read(setRepositoryProvider);
      final other = await h.run(() => sets.createSet(name: 'Küche'));
      final track = h.timer;

      await tester.longPress(find.byKey(LaneKeys.digits(track.id)));
      await h.settle();
      await tester.ensureVisible(find.byKey(TrackEditorKeys.move));
      await h.tap(find.byKey(TrackEditorKeys.move));
      await h.tap(find.text('Küche'));

      expect(h.tracks, hasLength(2));
      final moved = await tester.runAsync(
        () => h.container.read(trackRepositoryProvider).getTrack(track.id),
      );
      expect(moved!.setId, other.id);
      expect(find.text(TracksStrings.trackMovedTo('Küche')), findsOneWidget);

      await h.tap(find.text(Strings.undo));
      expect(await h.storedOrder(), [
        Strings.seedStopwatchName,
        Strings.seedTimerName,
        Strings.seedCounterName,
      ]);
      expect(tester.takeException(), isNull);
    });
  });

  group('reordering', () {
    testWidgets('dragging the grip reorders the list', (tester) async {
      final h = await TracksHarness.start(tester);
      expect(find.byKey(TracksScreenKeys.list), findsOneWidget);

      final grip = find.byKey(LaneKeys.handle(h.stopwatch.id));
      final gesture = await tester.startGesture(tester.getCenter(grip));
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await h.settle();

      expect(await h.storedOrder(), [
        Strings.seedTimerName,
        Strings.seedCounterName,
        Strings.seedStopwatchName,
      ]);
      expect(h.tracks.last.name, Strings.seedStopwatchName);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grid: dropping a grip on another lane moves the track', (
      tester,
    ) async {
      final h = await TracksHarness.start(
        tester,
        surfaceSize: TestApp.desktopSize,
      );
      expect(find.byKey(TracksScreenKeys.grid), findsOneWidget);

      final from = tester.getCenter(
        find.byKey(LaneKeys.handle(h.counter.id)),
      );
      final to = tester.getCenter(h.lane(h.stopwatch));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 50));
      const steps = 8;
      for (var i = 1; i <= steps; i++) {
        await gesture.moveTo(Offset.lerp(from, to, i / steps)!);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await gesture.up();
      await h.settle();

      expect(await h.storedOrder(), [
        Strings.seedCounterName,
        Strings.seedStopwatchName,
        Strings.seedTimerName,
      ]);
      expect(tester.takeException(), isNull);
    });
  });

  group('layout', () {
    testWidgets('wide screens show the lanes in columns', (tester) async {
      final h = await TracksHarness.start(
        tester,
        surfaceSize: TestApp.desktopSize,
      );
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byKey(TracksScreenKeys.grid), findsOneWidget);

      final first = tester.getTopLeft(h.lane(h.stopwatch));
      final second = tester.getTopLeft(h.lane(h.timer));
      final third = tester.getTopLeft(h.lane(h.counter));
      expect(second.dy, first.dy);
      expect(second.dx, greaterThan(first.dx));
      expect(third.dy, greaterThan(first.dy));
      expect(third.dx, first.dx);
      // Lanes in one row are equally high.
      expect(
        tester.getSize(h.lane(h.stopwatch)).height,
        tester.getSize(h.lane(h.timer)).height,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tiles layout uses two columns on a phone', (tester) async {
      final h = await TracksHarness.start(tester);
      await h.setPrefs(const UiPrefs(layout: LaneLayout.tiles));

      expect(find.byKey(TracksScreenKeys.grid), findsOneWidget);
      final first = tester.getTopLeft(h.lane(h.stopwatch));
      final second = tester.getTopLeft(h.lane(h.timer));
      expect(second.dy, first.dy);
      expect(second.dx, greaterThan(first.dx));
      // A tile stacks the buttons below the digits.
      expect(
        tester.getCenter(h.primary(h.stopwatch)).dy,
        greaterThan(
          tester.getCenter(find.byKey(LaneKeys.digits(h.stopwatch.id))).dy,
        ),
      );

      // Tiles work like rows.
      await h.tap(h.primary(h.stopwatch));
      await h.advance(const Duration(seconds: 2));
      expect(h.digits(h.stopwatch), '00:02');
      expect(tester.takeException(), isNull);
    });

    testWidgets('tiles with large text and buttons do not overflow', (
      tester,
    ) async {
      final h = await TracksHarness.start(tester);
      await h.addTrack(
        const CounterConfig(labels: ['Eichhörnchen', 'Reiher', 'Hund']),
        name: 'Tiere im Park beobachten',
      );
      await h.addTrack(const ReminderConfig(), name: 'Trinken');
      await h.setPrefs(
        const UiPrefs(
          layout: LaneLayout.tiles,
          density: UiDensity.roomy,
          digitScale: UiPrefs.maxDigitScale,
          buttonScale: UiPrefs.maxButtonScale,
          showTenths: true,
        ),
      );
      expect(tester.takeException(), isNull);

      await h.setPrefs(
        const UiPrefs(
          density: UiDensity.compact,
          digitScale: UiPrefs.maxDigitScale,
          buttonScale: UiPrefs.maxButtonScale,
          showTenths: true,
          leftHanded: true,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a set can override layout and theme', (tester) async {
      final h = await TracksHarness.start(tester);
      final sets = h.container.read(setRepositoryProvider);
      final set = h.activeSet;
      expect(find.byKey(TracksScreenKeys.list), findsOneWidget);

      await h.run(
        () => sets.updateSet(
          set.copyWith(
            themeId: () => ThemePresets.blackId,
            uiPrefsOverride: () => {
              UiPrefsKeys.layout: LaneLayout.tiles.name,
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byKey(TracksScreenKeys.grid), findsOneWidget);
      final context = tester.element(h.lane(h.stopwatch));
      expect(context.tikky.theme.id, ThemePresets.blackId);
      expect(context.tikky.prefs.layout, LaneLayout.tiles);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cupertino platforms render the same lanes', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final h = await TracksHarness.start(tester);
        expect(find.byType(CupertinoNavigationBar), findsOneWidget);
        expect(find.byType(TrackLane), findsNWidgets(3));

        await h.tap(h.primary(h.stopwatch));
        await h.advance(const Duration(seconds: 3));
        expect(h.digits(h.stopwatch), '00:03');

        await h.tap(find.byKey(TracksScreenKeys.addTrack));
        expect(find.text(Strings.newTrack), findsOneWidget);
        expect(find.byType(CupertinoTextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('keyboard shortcuts', () {
    testWidgets('1-9 toggles the n-th track', (tester) async {
      final h = await TracksHarness.start(
        tester,
        surfaceSize: TestApp.desktopSize,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await h.settle();
      expect((await h.snapshot(h.stopwatch))!.isRunning, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad3);
      await h.settle();
      expect(((await h.snapshot(h.counter))! as CounterSnapshot).count, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await h.settle();
      expect((await h.snapshot(h.stopwatch))!.isPaused, isTrue);

      // No ninth track: nothing happens.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9);
      await h.settle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Space starts and pauses all, N adds a track', (tester) async {
      final h = await TracksHarness.start(
        tester,
        surfaceSize: TestApp.desktopSize,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await h.settle();
      expect((await h.snapshot(h.stopwatch))!.isRunning, isTrue);
      expect((await h.snapshot(h.timer))!.isRunning, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await h.settle();
      expect((await h.snapshot(h.stopwatch))!.isPaused, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await h.settle();
      expect(find.text(Strings.newTrack), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shortcuts rest while a sheet is open or another '
        'destination is shown', (tester) async {
      final h = await TracksHarness.start(
        tester,
        surfaceSize: TestApp.desktopSize,
      );

      // Typing a name that contains shortcut characters.
      await h.tap(find.byKey(TracksScreenKeys.addTrack));
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await h.settle();
      expect(await h.snapshot(h.stopwatch), isNull);
      await h.tap(find.text(Strings.cancel));

      await h.tap(find.text(Strings.navHistory));
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await h.settle();
      expect(await h.snapshot(h.stopwatch), isNull);

      // The history filter bar has a "Spuren" chip of its own.
      await h.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(Strings.navTracks),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await h.settle();
      expect((await h.snapshot(h.stopwatch))!.isRunning, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
