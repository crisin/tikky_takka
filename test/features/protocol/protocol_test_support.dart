import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/protocol/protocol_lane.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../../support/test_app.dart';

const int minuteMs = 60 * 1000;
const int hourMs = 60 * minuteMs;

/// Lets database work arrive and animations (sheets, snackbars, page
/// transitions) finish. Never `pumpAndSettle`: the lane ticks.
///
/// Database work completes on the real event loop and may start an
/// animation only afterwards, so "real async" and "animation time"
/// alternate a few times.
///
/// A save runs a long chain of database calls (inline person, inline
/// substance, the entry, the session). When the whole suite runs in
/// parallel the machine is busy and that chain occasionally needed more
/// than the turns of the event loop granted here, so one short real wait
/// and an extra round are part of every settle.
Future<void> settleUi(WidgetTester tester, TestApp app) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 5)),
  );
  for (var i = 0; i < 4; i++) {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 350));
  }
  await app.settle(tester);
}

/// Shows the lane of every protocol track, like the tracks screen does.
class ProtocolHost extends ConsumerWidget {
  const ProtocolHost({this.tileSize, super.key});

  /// Shows the lanes in boxes of this fixed size (like grid tiles)
  /// instead of list rows.
  final Size? tileSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(allTracksProvider).value ?? const <Track>[];
    return Scaffold(
      body: ListView(
        children: [
          for (final track in tracks)
            if (track.mode == TrackMode.protocol)
              if (tileSize case final size?)
                Align(
                  child: SizedBox.fromSize(
                    size: size,
                    child: ProtocolLane(key: ValueKey(track.id), track: track),
                  ),
                )
              else
                ProtocolLane(key: ValueKey(track.id), track: track),
        ],
      ),
    );
  }
}

/// A pumped [ProtocolHost] with one protocol track.
class ProtocolFixture {
  ProtocolFixture(this.tester, this.app, this.container, this.track);

  final WidgetTester tester;
  final TestApp app;
  final ProviderContainer container;
  final Track track;

  static Future<ProtocolFixture> pump(
    WidgetTester tester, {
    Size surfaceSize = TestApp.phoneSize,
    TargetPlatform? platform,
    UiPrefs prefs = UiPrefs.defaults,
    Size? tileSize,
  }) async {
    final app = await TestApp.create(tester);
    await app.pumpWidget(
      tester,
      ProtocolHost(tileSize: tileSize),
      surfaceSize: surfaceSize,
      platform: platform,
      prefs: prefs,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ProtocolHost)),
    );
    final track = (await tester.runAsync(() async {
      final set = await container
          .read(setRepositoryProvider)
          .createSet(name: 'Festival');
      return container
          .read(trackRepositoryProvider)
          .createTrack(
            setId: set.id,
            name: 'Zelt',
            config: const ProtocolConfig(),
          );
    }))!;
    final fixture = ProtocolFixture(tester, app, container, track);
    await fixture.settle();
    return fixture;
  }

  /// Runs real async work (database) and returns its result.
  ///
  /// Followed by one frame: a write wakes the streams that watch the
  /// table, and their reload starts in the test's fake-async zone. Until
  /// that zone runs again the reload sits on the database's operation
  /// queue, and the next `runAsync` write would wait behind it for ever.
  /// (The idle lane watches the substances for their lockouts, so this
  /// also matters before the first entry.)
  Future<T> run<T>(Future<T> Function() body) async {
    final result = (await tester.runAsync(body)) as T;
    await tester.pump();
    return result;
  }

  /// See [settleUi].
  Future<void> settle() => settleUi(tester, app);

  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settle();
  }

  PeopleRepository get people => container.read(peopleRepositoryProvider);
  TrackCommands get commands => container.read(trackCommandsProvider);

  Future<Person> person(String name) =>
      run(() => people.createPerson(name: name));

  Future<Substance> substance(String name, {int? lockoutMs}) =>
      run(() => people.createSubstance(name: name, lockoutMs: lockoutMs));

  /// Sets the scene of the track's set.
  Future<void> scene({
    List<Person> persons = const [],
    List<Substance> substances = const [],
  }) async {
    await run(
      () => container
          .read(setRepositoryProvider)
          .updateScene(
            track.setId,
            personIds: [for (final p in persons) p.id],
            substanceIds: [for (final s in substances) s.id],
          ),
    );
    await settle();
  }

  /// The stored set of the track.
  Future<TrackSet> storedSet() async {
    final set = await run<TrackSet?>(
      () => container.read(setRepositoryProvider).getSet(track.setId),
    );
    return set!;
  }

  /// The key of a person card (step 1).
  static Key card(Person person) => ValueKey('person-card-${person.id}');

  /// The key of a one-tap substance button (step 2).
  static Key button(Substance substance) => ValueKey('capture-${substance.id}');

  Future<TrackEvent?> entry({
    String? personId,
    String? substanceId,
    String? amount,
    String? note,
  }) => run(
    () => commands.addEntry(
      track.id,
      personId: personId,
      substanceId: substanceId,
      amount: amount,
      note: note,
    ),
  );

  /// The entries of the open session, oldest first.
  Future<List<TrackEvent>> entries() async {
    final open = await run(() => commands.getOpenSession(track.id));
    return [
      for (final e in open?.events ?? const <TrackEvent>[])
        if (e.type == EventType.entry) e,
    ];
  }

  /// Moves the fake clock and lets the shared ticker notice.
  Future<void> advance(Duration duration) async {
    app.clock.advance(duration);
    await tester.pump(const Duration(milliseconds: 300));
  }
}
