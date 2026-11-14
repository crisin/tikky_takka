import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/features/protocol/protocol_lane.dart';
import 'package:tikky_takka/features/tracks/lane_undo.dart';
import 'package:tikky_takka/features/tracks/lane_view.dart';
import 'package:tikky_takka/features/tracks/track_lane.dart';
import 'package:tikky_takka/features/tracks/tracks_strings.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import 'tracks_harness.dart';

void main() {
  testWidgets('seed lanes render per mode', (tester) async {
    final h = await TracksHarness.start(tester);

    expect(find.byType(TrackLane), findsNWidgets(3));
    expect(h.digits(h.stopwatch), '00:00');
    expect(h.digits(h.timer), '10:00');
    expect(h.digits(h.counter), '0');
    // A ready lane names its mode in the line below the name.
    expect(
      h.subLine(h.stopwatch),
      '${Strings.modeStopwatch}${TracksStrings.separator}${Strings.statusIdle}',
    );
    expect(h.subLine(h.counter), endsWith(TracksStrings.tapToCount));

    // A ready lane has no fill; a running timer has one, a stopwatch never.
    expect(find.byKey(LaneKeys.progress(h.timer.id)), findsNothing);
    await h.tap(h.primary(h.timer));
    await h.tap(h.primary(h.stopwatch));
    expect(find.byKey(LaneKeys.progress(h.timer.id)), findsOneWidget);
    expect(find.byKey(LaneKeys.progress(h.stopwatch.id)), findsNothing);

    expect(h.tooltipOf(h.primary(h.stopwatch)), Strings.actionPause);
    expect(h.tooltipOf(h.primary(h.counter)), Strings.actionTick);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stopwatch: start, tick, lap, pause, resume', (tester) async {
    final h = await TracksHarness.start(tester);
    final track = h.stopwatch;

    await h.tap(h.primary(track));
    expect(h.tooltipOf(h.primary(track)), Strings.actionPause);
    expect(h.subLine(track), Strings.statusRunning);

    await h.advance(const Duration(seconds: 5));
    expect(h.digits(track), '00:05');

    await h.tap(h.secondary(track, LaneSecondaryKind.lap));
    await h.advance(const Duration(seconds: 2));
    expect(h.subLine(track), contains(Strings.lapNumber(2)));
    expect(h.subLine(track), contains(Strings.lastLap('00:05')));

    await h.tap(h.primary(track));
    expect(h.tooltipOf(h.primary(track)), Strings.actionResume);
    await h.advance(const Duration(seconds: 30));
    expect(h.digits(track), '00:07');

    await h.tap(h.primary(track));
    await h.advance(const Duration(seconds: 3));
    expect(h.digits(track), '00:10');
    expect((await h.snapshot(track))!.isRunning, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a paused lane stops with its secondary button, with undo', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    final track = h.stopwatch;

    await h.tap(h.primary(track));
    await h.advance(const Duration(seconds: 8));
    expect(h.secondary(track, LaneSecondaryKind.stop), findsNothing);
    await h.tap(h.primary(track));
    await h.tap(h.secondary(track, LaneSecondaryKind.stop));

    expect(await h.snapshot(track), isNull);
    expect(h.digits(track), '00:00');
    expect(find.text(TracksStrings.trackStopped(track.name)), findsOneWidget);
    expect(find.text(TracksStrings.timeKept('00:08')), findsOneWidget);

    await h.tap(find.text(Strings.undo));
    final snapshot = await h.snapshot(track);
    expect(snapshot, isNotNull);
    expect(snapshot!.isPaused, isTrue);
    expect(h.digits(track), '00:08');
    expect(find.byKey(LaneUndoKeys.bar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long press on the primary button stops a running lane', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    final track = h.stopwatch;

    await h.tap(h.primary(track));
    await h.advance(const Duration(seconds: 8));
    await tester.longPress(h.primary(track));
    await h.settle();

    expect(await h.snapshot(track), isNull);
    expect(h.digits(track), '00:00');
    expect(find.text(TracksStrings.trackStopped(track.name)), findsOneWidget);

    await h.tap(find.text(Strings.undo));
    final snapshot = await h.snapshot(track);
    expect(snapshot, isNotNull);
    expect(snapshot!.isRunning, isTrue);
    expect(h.digits(track), '00:08');
    expect(tester.takeException(), isNull);
  });

  testWidgets('countdown: runs down, rings, is dismissed on the lane', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    final track = h.timer;

    await h.tap(h.primary(track));
    expect(h.app.alarms.scheduled.containsKey(track.id), isTrue);
    await h.advance(const Duration(minutes: 4));
    expect(h.digits(track), '06:00');
    expect(h.rings.rung, isEmpty);

    await h.advance(const Duration(minutes: 6, seconds: 3));
    expect(h.digits(track), '+00:03');
    expect(h.subLine(track), startsWith(Strings.statusRinging));
    expect(h.tooltipOf(h.primary(track)), Strings.actionDismiss);
    // In-app ring feedback fired exactly once.
    expect(h.rings.rung, [track.id]);

    await h.advance(const Duration(seconds: 2));
    expect(h.rings.rung, [track.id]);

    await h.tap(h.primary(track));
    expect(await h.snapshot(track), isNull);
    expect(h.digits(track), '10:00');
    expect(h.tooltipOf(h.primary(track)), Strings.actionStart);
    expect(h.app.alarms.scheduled, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('countdown: restart begins a fresh run', (tester) async {
    final h = await TracksHarness.start(tester);
    final track = h.timer;

    await h.tap(h.primary(track));
    await h.advance(const Duration(minutes: 3));
    expect(h.digits(track), '07:00');

    await h.tap(h.secondary(track, LaneSecondaryKind.restart));
    expect(h.digits(track), '10:00');
    expect((await h.snapshot(track))!.isRunning, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('interval: round, phase and finish', (tester) async {
    final h = await TracksHarness.start(tester);
    final track = await h.addTrack(
      const IntervalConfig(workMs: 30000, restMs: 10000, rounds: 2),
      name: 'Training',
    );

    expect(h.digits(track), '00:30');
    expect(h.subLine(track), endsWith('2 × 00:30 / 00:10'));

    await h.tap(h.primary(track));
    await h.advance(const Duration(seconds: 10));
    expect(h.digits(track), '00:20');
    expect(h.subLine(track), contains(Strings.roundOf(1, 2)));
    expect(h.subLine(track), contains(Strings.phaseWork));

    await h.advance(const Duration(seconds: 25));
    expect(h.subLine(track), contains(Strings.phaseRest));
    expect(h.rings.rung, [track.id]);

    await h.advance(const Duration(seconds: 40));
    expect(h.subLine(track), Strings.phaseDone);
    expect(h.tooltipOf(h.primary(track)), Strings.actionDismiss);

    await h.tap(h.primary(track));
    expect(await h.snapshot(track), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('counter: taps count, undo removes the last one', (tester) async {
    final h = await TracksHarness.start(tester);
    final track = h.counter;

    await h.tap(h.primary(track));
    expect(h.digits(track), '1');
    await h.advance(const Duration(seconds: 20));
    await h.tap(h.primary(track));
    await h.advance(const Duration(seconds: 5));
    await h.tap(h.primary(track));
    expect(h.digits(track), '3');

    await h.advance(const Duration(seconds: 4));
    expect(h.subLine(track), Strings.totalTime('00:29'));
    // The current lap time is shown next to the count.
    expect(
      find.descendant(of: h.lane(track), matching: find.text('00:04')),
      findsOneWidget,
    );

    await h.tap(h.secondary(track, LaneSecondaryKind.undo));
    expect(h.digits(track), '2');
    final snapshot = (await h.snapshot(track))! as CounterSnapshot;
    expect(snapshot.count, 2);

    await tester.longPress(h.primary(track));
    await h.settle();
    expect(await h.snapshot(track), isNull);
    expect(h.digits(track), '0');
    expect(find.text(TracksStrings.ticksKept(2)), findsOneWidget);
    // The undo bar goes away by itself.
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    expect(find.byKey(LaneUndoKeys.bar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('counter with quick labels: one button per label', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    final track = await h.addTrack(
      const CounterConfig(labels: ['Eichhörnchen', 'Reiher', 'Hund']),
      name: 'Tiere',
    );

    // No single tap button; one button per label instead.
    expect(h.primary(track), findsNothing);
    for (final label in ['Eichhörnchen', 'Reiher', 'Hund']) {
      expect(find.byKey(LaneKeys.label(track.id, label)), findsOneWidget);
    }

    await h.tap(find.byKey(LaneKeys.label(track.id, 'Hund')));
    await h.tap(find.byKey(LaneKeys.label(track.id, 'Hund')));
    await h.tap(find.byKey(LaneKeys.label(track.id, 'Reiher')));

    expect(h.digits(track), '3');
    final snapshot = (await h.snapshot(track))! as CounterSnapshot;
    expect(snapshot.labelCounts, {'Eichhörnchen': 0, 'Reiher': 1, 'Hund': 2});
    expect(
      find.descendant(
        of: find.byKey(LaneKeys.label(track.id, 'Hund')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    await h.tap(h.secondary(track, LaneSecondaryKind.undo));
    expect(h.digits(track), '2');
    expect(
      find.descendant(
        of: find.byKey(LaneKeys.label(track.id, 'Reiher')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reminder: becomes due, nags, is acknowledged on the lane', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    final track = await h.addTrack(
      const ReminderConfig(intervalMs: 600000, nagEveryMs: 60000),
      name: 'Trinken',
    );

    expect(h.digits(track), '10:00');
    await h.tap(h.primary(track));
    await h.advance(const Duration(minutes: 9));
    expect(h.digits(track), '01:00');
    expect(h.tooltipOf(h.primary(track)), Strings.actionPause);

    await h.advance(const Duration(minutes: 1, seconds: 5));
    expect(h.digits(track), '+00:05');
    expect(h.tooltipOf(h.primary(track)), Strings.actionAck);
    expect(h.rings.rung, [track.id]);

    // Still not acknowledged a minute later: it nags again.
    await h.advance(const Duration(minutes: 1));
    expect(h.rings.rung, [track.id, track.id]);

    await h.tap(h.primary(track));
    final snapshot = (await h.snapshot(track))! as ReminderSnapshot;
    expect(snapshot.ackCount, 1);
    expect(snapshot.due, isFalse);
    expect(h.digits(track), '10:00');
    expect(h.subLine(track), contains(TracksStrings.ackCount(1)));
    expect(h.tooltipOf(h.primary(track)), Strings.actionPause);
    expect(h.rings.rung, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reminder: early ack restarts the interval', (tester) async {
    final h = await TracksHarness.start(tester);
    final track = await h.addTrack(
      const ReminderConfig(intervalMs: 600000),
      name: 'Trinken',
    );

    await h.tap(h.primary(track));
    await h.advance(const Duration(minutes: 4));
    expect(h.digits(track), '06:00');
    await h.tap(h.secondary(track, LaneSecondaryKind.ackEarly));
    expect(h.digits(track), '10:00');
    expect(((await h.snapshot(track))! as ReminderSnapshot).ackCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('protocol tracks use the protocol lane', (tester) async {
    final h = await TracksHarness.start(tester);
    final track = await h.addTrack(const ProtocolConfig(), name: 'Festival');

    expect(find.byType(ProtocolLane), findsOneWidget);
    expect(
      find.descendant(of: h.lane(track), matching: find.byType(TrackLane)),
      findsNothing,
    );
    // It still has the grip and an edit button.
    expect(find.byKey(LaneKeys.handle(track.id)), findsOneWidget);
    expect(
      find.bySemanticsLabel('Festival: ${Strings.editTrack}'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('lane buttons carry semantics labels', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await TracksHarness.start(tester);

    expect(
      find.bySemanticsLabel(
        '${Strings.seedStopwatchName}: ${Strings.actionStart}',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('${Strings.seedTimerName}: ${Strings.actionStart}'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        '${Strings.seedCounterName}: ${Strings.actionTick}',
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(Strings.dragHandle), findsNWidgets(3));

    // A running lane offers its secondary button and "stop" as an action.
    await h.tap(h.primary(h.stopwatch));
    expect(
      find.bySemanticsLabel(
        '${Strings.seedStopwatchName}: ${Strings.actionLap}',
      ),
      findsOneWidget,
    );
    final lane = tester.getSemantics(h.lane(h.stopwatch));
    expect(lane.getSemanticsData().customSemanticsActionIds, isNotEmpty);
    expect(h.tracks, hasLength(3));
    handle.dispose();
  });

  testWidgets('preferences: tenths, sub-line and progress bar', (tester) async {
    final h = await TracksHarness.start(tester);
    final track = h.timer;

    await h.setPrefs(
      const UiPrefs(
        showTenths: true,
        showSubLine: false,
        showProgressBar: false,
      ),
    );
    await h.tap(h.primary(track));
    expect(h.digits(h.stopwatch), '00:00.0');
    expect(find.byKey(LaneKeys.subLine(track.id)), findsNothing);
    expect(find.byKey(LaneKeys.progress(track.id)), findsNothing);

    await h.tap(h.primary(h.stopwatch));
    await h.advance(const Duration(milliseconds: 1300));
    expect(h.digits(h.stopwatch), '00:01.3');
    expect(tester.takeException(), isNull);
  });

  testWidgets('left-handed layout puts the primary button first', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    final track = h.stopwatch;

    double buttonX() => tester.getCenter(h.primary(track)).dx;
    double digitsX() =>
        tester.getCenter(find.byKey(LaneKeys.digits(track.id))).dx;

    expect(buttonX(), greaterThan(digitsX()));
    await h.setPrefs(const UiPrefs(leftHanded: true));
    expect(buttonX(), lessThan(digitsX()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('button and digit scale change the sizes', (tester) async {
    final h = await TracksHarness.start(tester);
    final track = h.stopwatch;

    final buttonBefore = tester.getSize(h.primary(track));
    final digitsBefore = tester
        .widget<Text>(find.byKey(LaneKeys.digits(track.id)))
        .style!
        .fontSize!;

    await h.setPrefs(const UiPrefs(buttonScale: 1.5, digitScale: 1.5));
    final buttonAfter = tester.getSize(h.primary(track));
    final digitsAfter = tester
        .widget<Text>(find.byKey(LaneKeys.digits(track.id)))
        .style!
        .fontSize!;

    expect(buttonAfter.width, closeTo(buttonBefore.width * 1.5, 0.01));
    expect(digitsAfter, closeTo(digitsBefore * 1.5, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a running lane only rebuilds its time text on a tick', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    final track = h.stopwatch;
    await h.tap(h.primary(track));

    final buttonBefore = tester.widget(h.primary(track));
    final laneBefore = tester.widget(h.lane(track));
    await h.advance(const Duration(seconds: 1));
    await h.advance(const Duration(seconds: 1));
    expect(h.digits(track), '00:02');
    // Same widget instances: neither the lane nor its buttons were rebuilt
    // by the ticker.
    expect(identical(tester.widget(h.lane(track)), laneBefore), isTrue);
    expect(identical(tester.widget(h.primary(track)), buttonBefore), isTrue);
    expect(tester.takeException(), isNull);
  });
}
