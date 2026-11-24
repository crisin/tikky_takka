import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/tracks/lane_view.dart';
import 'package:tikky_takka/features/tracks/ring_monitor.dart';
import 'package:tikky_takka/features/tracks/timeline/protocol_bridge.dart';
import 'package:tikky_takka/features/tracks/track_lane.dart';
import 'package:tikky_takka/features/tracks/tracks_screen.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../../support/test_app.dart';

/// Records in-app rings instead of playing sounds.
class RecordingRingFeedback implements RingFeedback {
  final List<String> rung = [];

  @override
  Future<void> ring(Track track) async => rung.add(track.id);
}

/// The whole app on the tracks destination, with shortcuts to the data
/// layer for arranging and asserting.
class TracksHarness {
  TracksHarness._(this.tester, this.app, this.rings);

  final WidgetTester tester;
  final TestApp app;
  final RecordingRingFeedback rings;

  static Future<TracksHarness> start(
    WidgetTester tester, {
    Size surfaceSize = TestApp.phoneSize,
  }) async {
    final rings = RecordingRingFeedback();
    final app = await TestApp.create(
      tester,
      extraOverrides: [ringFeedbackProvider.overrideWithValue(rings)],
    );
    await app.pumpApp(tester, surfaceSize: surfaceSize);
    return TracksHarness._(tester, app, rings);
  }

  ProviderContainer get container =>
      // The tracks destination stays alive (offstage) while another
      // destination is shown.
      ProviderScope.containerOf(
        tester.element(find.byType(TracksScreen, skipOffstage: false)),
      );

  /// Runs data-layer work on the real event loop and lets the UI catch up.
  Future<T> run<T>(Future<T> Function() body) async {
    final result = await tester.runAsync(body);
    await app.settle(tester);
    return result as T;
  }

  /// Lets database work, streams and short animations (sheets, snackbars)
  /// finish.
  Future<void> settle() async {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    await app.settle(tester);
  }

  Future<void> tap(Finder finder) async {
    await tester.tap(finder);
    await settle();
  }

  /// Moves the fake clock and lets the shared ticker fire.
  Future<void> advance(Duration duration) async {
    app.clock.advance(duration);
    await tester.pump(const Duration(milliseconds: 100));
    await app.settle(tester);
  }

  TrackSet get activeSet => container.read(activeSetProvider)!;

  List<Track> get tracks => container.read(activeTracksProvider);

  Track trackNamed(String name) => tracks.firstWhere((t) => t.name == name);

  Track get stopwatch => trackNamed(Strings.seedStopwatchName);
  Track get timer => trackNamed(Strings.seedTimerName);
  Track get counter => trackNamed(Strings.seedCounterName);

  /// Writes a protocol entry at the time of the clock and returns it as
  /// the event the timeline shows for it (same id).
  Future<TrackEvent?> entry({
    required String personId,
    required String substanceId,
    String? amount,
    String? note,
  }) async => entryAsEvent(
    await container
        .read(entryRepositoryProvider)
        .add(
          personId: personId,
          substanceId: substanceId,
          amount: amount,
          note: note,
        ),
  );

  /// The entries of the protocol, oldest first.
  Future<List<Entry>> entries() =>
      run(() => container.read(entryRepositoryProvider).getAll());

  Future<Track> addTrack(TrackConfig config, {required String name}) => run(
    () => container
        .read(trackRepositoryProvider)
        .createTrack(setId: activeSet.id, name: name, config: config),
  );

  Future<void> setPrefs(UiPrefs prefs) =>
      run(() => container.read(uiPrefsProvider.notifier).set(prefs));

  Future<TrackSnapshot?> snapshot(Track track) async {
    final open = await tester.runAsync(
      () => container.read(trackCommandsProvider).getOpenSession(track.id),
    );
    if (open == null) return null;
    return deriveSnapshot(
      config: open.session.config,
      events: open.events,
      nowMs: app.clock.nowMs(),
    );
  }

  Future<List<String>> storedOrder() async {
    final list = await tester.runAsync(
      () => container.read(trackRepositoryProvider).getTracks(activeSet.id),
    );
    return [for (final t in list!) t.name];
  }

  String digits(Track track) =>
      tester.widget<Text>(find.byKey(LaneKeys.digits(track.id))).data!;

  String subLine(Track track) =>
      tester.widget<Text>(find.byKey(LaneKeys.subLine(track.id))).data!;

  Finder primary(Track track) => find.byKey(LaneKeys.primary(track.id));

  Finder secondary(Track track, LaneSecondaryKind kind) =>
      find.byKey(LaneKeys.secondary(track.id, kind));

  Finder lane(Track track) => find.byKey(LaneKeys.lane(track.id));

  /// Tooltip (= visible action name) of a lane button.
  String tooltipOf(Finder button) => tester
      .widget<Tooltip>(
        find.descendant(of: button, matching: find.byType(Tooltip)),
      )
      .message!;
}
