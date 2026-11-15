import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/adaptive/adaptive.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/tracks/pad/pad_model.dart';
import 'package:tikky_takka/features/tracks/pad/tap_pad.dart';
import 'package:tikky_takka/features/tracks/tracks_screen.dart';
import 'package:tikky_takka/features/tracks/tracks_strings.dart';
import 'package:tikky_takka/features/tracks/tracks_view.dart';
import 'package:tikky_takka/l10n/formatters.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../../../support/test_app.dart';
import '../tracks_harness.dart';

const _birdLabels = ['Reiher', 'Ente', 'Specht'];

extension on TracksHarness {
  Future<void> showPad() => run(
    () => container
        .read(tracksViewsProvider.notifier)
        .show(activeSet.id, TracksView.pad),
  );

  Finder button(String id) => find.byKey(PadKeys.button(id));

  String value(String id) =>
      tester.widget<Text>(find.byKey(PadKeys.value(id))).data!;

  String sub(String id) =>
      tester.widget<Text>(find.byKey(PadKeys.sub(id))).data!;

  TrackCommands get commands => container.read(trackCommandsProvider);

  Future<List<TrackEvent>> events(Track track) async {
    final open = await tester.runAsync(() => commands.getOpenSession(track.id));
    return open?.events ?? const [];
  }

  Future<List<TrackEvent>> ofType(Track track, EventType type) async => [
    for (final e in await events(track))
      if (e.type == type) e,
  ];

  /// Lets time pass (also past the same-button guard).
  Future<void> wait([Duration d = const Duration(milliseconds: 200)]) =>
      advance(d);

  String get barMessage =>
      tester.widget<InlineUndoBar>(find.byKey(PadKeys.undoBar)).message;

  String? get barDetail =>
      tester.widget<InlineUndoBar>(find.byKey(PadKeys.undoBar)).detail;

  bool get barHasUndo =>
      tester.widget<InlineUndoBar>(find.byKey(PadKeys.undoBar)).onUndo != null;

  /// Lets the pad write everything that is queued: its taps run one
  /// after the other, each with several round trips to the database on
  /// the real event loop - more than one [settle] grants when the whole
  /// suite runs in parallel.
  Future<void> drain() async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await settle();
    }
  }

  /// Taps and waits until the pad has written it.
  Future<void> press(Finder finder) async {
    await tester.tap(finder);
    await drain();
  }

  Future<void> tapUndo() => press(find.byKey(InlineUndoBar.undoKey));
}

String _stamp(TracksHarness h) =>
    TracksStrings.padWhen(Fmt.time(h.app.clock.nowMs()), TracksStrings.padNow);

/// People, substances and a scene for a protocol track.
class _Protocol {
  _Protocol(this.track, this.jacke, this.kim, this.gbl, this.water);

  final Track track;
  final Person jacke;
  final Person kim;
  final Substance gbl;
  final Substance water;

  static Future<_Protocol> create(
    TracksHarness h, {
    required List<String> scenePersons,
  }) async {
    final people = h.container.read(peopleRepositoryProvider);
    final jacke = await h.run(() => people.createPerson(name: 'Jacke'));
    final kim = await h.run(() => people.createPerson(name: 'Kim'));
    final gbl = await h.run(() => people.createSubstance(name: 'GBL'));
    final water = await h.run(() => people.createSubstance(name: 'Wasser'));
    final track = await h.addTrack(const ProtocolConfig(), name: 'Zelt');
    final ids = {'Jacke': jacke.id, 'Kim': kim.id};
    await h.run(
      () => h.container
          .read(setRepositoryProvider)
          .updateScene(
            h.activeSet.id,
            personIds: [for (final name in scenePersons) ids[name]!],
            substanceIds: [gbl.id, water.id],
          ),
    );
    await h.settle();
    return _Protocol(track, jacke, kim, gbl, water);
  }

  String person(Person p) => 'p:${track.id}:${p.id}';
  String substance(Person p, Substance s) => 'x:${track.id}:${p.id}:${s.id}';
  String more([Person? p]) => 'm:${track.id}:${p?.id ?? '-'}';
  String other(Person p) => 'o:${track.id}:${p.id}';

  Future<List<TrackEvent>> entries(TracksHarness h) =>
      h.ofType(track, EventType.entry);
}

void main() {
  group('tap behaviour', () {
    testWidgets('counter labels: the first tap starts the session, every tap '
        'counts with its label; no dialog, no snackbar', (tester) async {
      final h = await TracksHarness.start(tester);
      final birds = await h.addTrack(
        const CounterConfig(labels: _birdLabels),
        name: 'Vögel',
      );
      await h.showPad();
      String id(String label) => 'c:${birds.id}:$label';

      expect(find.byKey(TracksScreenKeys.list), findsNothing);
      for (final label in _birdLabels) {
        expect(h.button(id(label)), findsOneWidget);
        expect(h.value(id(label)), TracksStrings.padCount(0));
        expect(h.sub(id(label)), '');
      }
      expect(await h.snapshot(birds), isNull);
      expect(h.barMessage, TracksStrings.padReady);
      expect(h.barHasUndo, isFalse);

      await h.press(h.button(id('Reiher')));
      final first = (await h.snapshot(birds))! as CounterSnapshot;
      expect(first.count, 1);
      expect(first.labelCounts['Reiher'], 1);
      expect(h.value(id('Reiher')), TracksStrings.padCount(1));
      expect(h.value(id('Ente')), TracksStrings.padCount(0));
      expect(h.barMessage, 'Reiher');
      expect(h.barDetail, _stamp(h));
      expect(h.barHasUndo, isTrue);

      await h.wait(const Duration(seconds: 12));
      expect(h.sub(id('Reiher')), 'vor 12 s');
      await h.press(h.button(id('Ente')));
      await h.press(h.button(id('Reiher')));
      final ticks = await h.ofType(birds, EventType.tick);
      expect([for (final e in ticks) e.label], ['Reiher', 'Ente', 'Reiher']);
      expect(ticks.last.at, h.app.clock.nowMs());
      expect(h.value(id('Reiher')), TracksStrings.padCount(2));
      expect(h.value(id('Ente')), TracksStrings.padCount(1));
      expect(h.value(id('Specht')), TracksStrings.padCount(0));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a counter without labels is one button', (tester) async {
      final h = await TracksHarness.start(tester);
      await h.showPad();
      final id = 'c:${h.counter.id}';

      await h.press(h.button(id));
      await h.wait();
      await h.press(h.button(id));
      expect(((await h.snapshot(h.counter))! as CounterSnapshot).count, 2);
      expect(h.value(id), TracksStrings.padCount(2));
      expect(h.barMessage, Strings.seedCounterName);
      expect(h.barDetail, _stamp(h));
      expect(tester.takeException(), isNull);
    });

    testWidgets('stopwatch: start when idle, lap when running, resume when '
        'paused - never pause', (tester) async {
      final h = await TracksHarness.start(tester);
      await h.showPad();
      final watch = h.stopwatch;
      final id = 's:${watch.id}';
      expect(h.sub(id), TracksStrings.padTapToStart);

      await h.press(h.button(id));
      expect((await h.snapshot(watch))!.isRunning, isTrue);
      expect(h.barMessage, startsWith(TracksStrings.padStarted(watch.name)));

      await h.wait(const Duration(seconds: 5));
      expect(h.value(id), '00:05');
      await h.press(h.button(id));
      var snapshot = (await h.snapshot(watch))! as StopwatchSnapshot;
      expect(snapshot.isRunning, isTrue);
      expect(snapshot.lapCount, 1);
      expect(snapshot.laps.single.durationMs, 5000);
      expect(h.barMessage, startsWith(TracksStrings.padLap(watch.name, 1)));
      expect(await h.ofType(watch, EventType.pause), isEmpty);

      await h.run(() => h.commands.pauseTrack(watch.id));
      await h.wait(const Duration(seconds: 2));
      expect(h.sub(id), TracksStrings.padTapToResume);
      await h.press(h.button(id));
      snapshot = (await h.snapshot(watch))! as StopwatchSnapshot;
      expect(snapshot.isRunning, isTrue);
      expect(snapshot.lapCount, 1);
      expect(h.barMessage, startsWith(TracksStrings.padResumed(watch.name)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('countdown: start when idle, no change while running, '
        'dismiss when ringing', (tester) async {
      final h = await TracksHarness.start(tester);
      final egg = await h.addTrack(
        const CountdownConfig(durationMs: 60000),
        name: 'Ei',
      );
      await h.showPad();
      final id = 't:${egg.id}';

      await h.press(h.button(id));
      expect((await h.snapshot(egg))!.isRunning, isTrue);
      expect(h.value(id), '01:00');

      // Running: a tap changes nothing (pausing is done in the lanes).
      await h.wait(const Duration(seconds: 10));
      final before = h.barMessage;
      await h.press(h.button(id));
      expect((await h.snapshot(egg))!.isRunning, isTrue);
      expect([for (final e in await h.events(egg)) e.type], [EventType.start]);
      expect(h.barMessage, before);
      expect(h.value(id), '00:50');
      expect(h.sub(id), Strings.statusRunning);

      // Paused: still nothing.
      await h.run(() => h.commands.pauseTrack(egg.id));
      await h.wait();
      await h.press(h.button(id));
      expect((await h.snapshot(egg))!.isPaused, isTrue);
      await h.run(() => h.commands.resumeTrack(egg.id));

      await h.wait(const Duration(seconds: 60));
      expect((await h.snapshot(egg))!.isRinging, isTrue);
      expect(h.sub(id), TracksStrings.padTapToDismiss);
      await h.press(h.button(id));
      expect(await h.snapshot(egg), isNull);
      expect(h.barMessage, startsWith(TracksStrings.padDismissed('Ei')));

      // Undo brings the ringing timer back.
      await h.tapUndo();
      expect((await h.snapshot(egg))!.isRinging, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reminder: start, then acknowledge when due', (tester) async {
      final h = await TracksHarness.start(tester);
      final pill = await h.addTrack(
        const ReminderConfig(intervalMs: 60000),
        name: 'Pille',
      );
      await h.showPad();
      final id = 't:${pill.id}';

      await h.press(h.button(id));
      expect((await h.snapshot(pill))!.isRunning, isTrue);
      await h.wait(const Duration(seconds: 30));
      await h.press(h.button(id));
      expect(((await h.snapshot(pill))! as ReminderSnapshot).ackCount, 0);

      await h.wait(const Duration(seconds: 40));
      expect(h.sub(id), TracksStrings.padTapToAck);
      await h.press(h.button(id));
      final snapshot = (await h.snapshot(pill))! as ReminderSnapshot;
      expect(snapshot.ackCount, 1);
      expect(snapshot.due, isFalse);
      expect(h.barMessage, startsWith(TracksStrings.padAcked('Pille')));

      await h.tapUndo();
      final undone = (await h.snapshot(pill))! as ReminderSnapshot;
      expect(undone.ackCount, 0);
      expect(undone.due, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('rapid taps', () {
    testWidgets('taps on different buttons all register, in order', (
      tester,
    ) async {
      final h = await TracksHarness.start(tester);
      final birds = await h.addTrack(
        const CounterConfig(labels: _birdLabels),
        name: 'Vögel',
      );
      await h.showPad();
      String id(String label) => 'c:${birds.id}:$label';

      // No frame, no settling in between - as fast as fingers can be.
      await tester.tap(h.button(id('Reiher')));
      await tester.tap(h.button(id('Ente')));
      await tester.tap(h.button(id('Specht')));
      await tester.tap(h.button('c:${h.counter.id}'));
      await tester.tap(h.button(id('Reiher')));
      await tester.tap(h.button(id('Ente')));
      // Six transactions, one after the other.
      await h.drain();
      await h.drain();

      final ticks = await h.ofType(birds, EventType.tick);
      expect(
        [for (final e in ticks) e.label],
        ['Reiher', 'Ente', 'Specht', 'Reiher', 'Ente'],
      );
      expect(await h.ofType(h.counter, EventType.tick), hasLength(1));
      // One session, one start.
      expect(await h.ofType(birds, EventType.start), hasLength(1));
      expect(h.value(id('Reiher')), TracksStrings.padCount(2));
      expect(h.value(id('Ente')), TracksStrings.padCount(2));
      expect(h.value(id('Specht')), TracksStrings.padCount(1));
      // The bar is about the last tap.
      expect(h.barMessage, 'Ente');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a bounce on the SAME button within $padSameButtonGuardMs ms '
        'is one tap; later it counts again', (tester) async {
      final h = await TracksHarness.start(tester);
      await h.showPad();
      final id = 'c:${h.counter.id}';

      await tester.tap(h.button(id));
      await tester.tap(h.button(id));
      await h.drain();
      expect(await h.ofType(h.counter, EventType.tick), hasLength(1));

      await h.wait(const Duration(milliseconds: padSameButtonGuardMs - 50));
      await h.press(h.button(id));
      expect(await h.ofType(h.counter, EventType.tick), hasLength(1));

      await h.wait(const Duration(milliseconds: padSameButtonGuardMs));
      await h.press(h.button(id));
      expect(await h.ofType(h.counter, EventType.tick), hasLength(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('undo bar', () {
    testWidgets('undoes exactly the last tick - and the session it had '
        'started', (tester) async {
      final h = await TracksHarness.start(tester);
      final birds = await h.addTrack(
        const CounterConfig(labels: _birdLabels),
        name: 'Vögel',
      );
      await h.showPad();
      String id(String label) => 'c:${birds.id}:$label';

      await h.press(h.button(id('Reiher')));
      await h.press(h.button(id('Ente')));
      await h.wait();
      await h.press(h.button(id('Reiher')));
      expect(await h.ofType(birds, EventType.tick), hasLength(3));

      await h.tapUndo();
      final ticks = await h.ofType(birds, EventType.tick);
      expect([for (final e in ticks) e.label], ['Reiher', 'Ente']);
      expect(h.value(id('Reiher')), TracksStrings.padCount(1));
      expect(h.barMessage, startsWith(TracksStrings.padUndone));
      // Nothing more to take back.
      expect(h.barHasUndo, isFalse);

      // A first tap that is taken back leaves no session behind.
      final plain = 'c:${h.counter.id}';
      await h.press(h.button(plain));
      expect(await h.snapshot(h.counter), isNotNull);
      await h.tapUndo();
      expect(await h.snapshot(h.counter), isNull);
      expect(h.value(plain), TracksStrings.padCount(0));
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lap and start can be taken back', (tester) async {
      final h = await TracksHarness.start(tester);
      await h.showPad();
      final watch = h.stopwatch;
      final id = 's:${watch.id}';

      await h.press(h.button(id));
      await h.wait(const Duration(seconds: 3));
      await h.press(h.button(id));
      expect(await h.ofType(watch, EventType.lap), hasLength(1));
      await h.tapUndo();
      expect(await h.ofType(watch, EventType.lap), isEmpty);
      expect((await h.snapshot(watch))!.isRunning, isTrue);

      // The start itself: the timer is idle again, nothing is logged.
      final timer = h.timer;
      await h.press(h.button('t:${timer.id}'));
      expect((await h.snapshot(timer))!.isRunning, isTrue);
      await h.tapUndo();
      expect(await h.snapshot(timer), isNull);
      final history = await tester.runAsync(
        () => h.container
            .read(historyRepositoryProvider)
            .getSessions(HistoryFilter(trackIds: {timer.id})),
      );
      expect(history, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('starting an exclusive stopwatch offers no undo', (
      tester,
    ) async {
      final h = await TracksHarness.start(tester);
      final a = await h.addTrack(
        const StopwatchConfig(exclusive: true),
        name: 'Arbeit',
      );
      await h.showPad();

      await h.press(h.button('s:${a.id}'));
      expect((await h.snapshot(a))!.isRunning, isTrue);
      expect(h.barMessage, startsWith(TracksStrings.padStarted('Arbeit')));
      expect(h.barHasUndo, isFalse);
      expect(find.byKey(InlineUndoBar.undoKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stays in place, is replaced by the next action and leaves '
        'after about ten seconds', (tester) async {
      final h = await TracksHarness.start(tester);
      await h.showPad();
      final counter = 'c:${h.counter.id}';
      final barRect = tester.getRect(find.byKey(PadKeys.undoBar));
      final buttonRect = tester.getRect(h.button(counter));

      await h.press(h.button(counter));
      expect(h.barMessage, startsWith(Strings.seedCounterName));
      // The bar was there before: nothing moved, nothing is covered.
      expect(tester.getRect(find.byKey(PadKeys.undoBar)), barRect);
      expect(tester.getRect(h.button(counter)), buttonRect);
      expect(barRect.bottom, lessThanOrEqualTo(buttonRect.top));

      // (The bar's clock is real time, not the app clock.)
      await tester.pump(const Duration(seconds: 6));
      await h.press(h.button('s:${h.stopwatch.id}'));
      expect(h.barMessage, startsWith(TracksStrings.padStarted('Stoppuhr')));

      // Six more seconds: the first action's ten seconds are long over,
      // the bar is still about the second one.
      await tester.pump(const Duration(seconds: 6));
      await h.settle();
      expect(h.barHasUndo, isTrue);

      await tester.pump(const Duration(seconds: 5));
      await h.settle();
      expect(h.barMessage, TracksStrings.padReady);
      expect(h.barHasUndo, isFalse);
      expect(tester.getRect(find.byKey(PadKeys.undoBar)), barRect);
      expect(tester.takeException(), isNull);
    });
  });

  group('layout', () {
    testWidgets('the buttons fill the pad without scrolling; they never move '
        'or reorder while it is open', (tester) async {
      final h = await TracksHarness.start(tester);
      final birds = await h.addTrack(
        const CounterConfig(labels: _birdLabels),
        name: 'Vögel',
      );
      await h.showPad();
      final ids = [
        's:${h.stopwatch.id}',
        't:${h.timer.id}',
        'c:${h.counter.id}',
        for (final label in _birdLabels) 'c:${birds.id}:$label',
      ];
      Map<String, Rect> rects() => {
        for (final id in ids) id: tester.getRect(h.button(id)),
      };

      final before = rects();
      expect(find.byKey(PadKeys.scroll), findsNothing);
      final pad = tester.getRect(find.byKey(PadKeys.pad));
      final bar = tester.getRect(find.byKey(PadKeys.undoBar));
      final tokens = TikkyTokens.fallback;
      // Reading order = track order.
      for (var i = 1; i < ids.length; i++) {
        final a = before[ids[i - 1]]!;
        final b = before[ids[i]]!;
        expect(
          b.top > a.top || (b.top == a.top && b.left > a.left),
          isTrue,
          reason: ids[i],
        );
      }
      // Filled: from just below the bar down to the bottom edge.
      final top = before.values
          .map((r) => r.top)
          .reduce((a, b) => a < b ? a : b);
      final bottom = before.values
          .map((r) => r.bottom)
          .reduce((a, b) => a > b ? a : b);
      expect(top, closeTo(bar.bottom + tokens.space.sm, 0.5));
      expect(bottom, closeTo(pad.bottom - tokens.space.sm, 0.5));
      for (final rect in before.values) {
        expect(
          rect.height,
          greaterThanOrEqualTo(tokens.sizes.padButtonMinHeight),
        );
        expect(
          rect.width,
          greaterThanOrEqualTo(tokens.sizes.padButtonMinWidth),
        );
      }

      // Use them: counts change, places do not.
      await h.press(h.button(ids[5]));
      await h.press(h.button(ids[5 - 1]));
      await h.press(h.button(ids[0]));
      await h.press(h.button(ids[2]));
      expect(rects(), before);

      // Reordering the tracks elsewhere does not shuffle an open pad.
      await h.run(
        () => h.container.read(trackRepositoryProvider).reorderTracks(
          h.activeSet.id,
          [birds.id, h.counter.id, h.timer.id, h.stopwatch.id],
        ),
      );
      await h.settle();
      expect(rects(), before);

      // A pad that is opened anew follows the new order.
      await h.run(
        () => h.container
            .read(tracksViewsProvider.notifier)
            .show(h.activeSet.id, TracksView.lanes),
      );
      await h.showPad();
      expect(rects()[ids[3]], before[ids[0]]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('too many buttons: rows of the minimum height that scroll; '
        'the height follows the button scale', (tester) async {
      final h = await TracksHarness.start(tester);
      final many = await h.addTrack(
        CounterConfig(labels: [for (var i = 1; i <= 40; i++) 'Art $i']),
        name: 'Arten',
      );
      await h.showPad();

      expect(find.byKey(PadKeys.scroll), findsOneWidget);
      final first = 's:${h.stopwatch.id}';
      expect(tester.getSize(h.button(first)).height, 72);
      await tester.scrollUntilVisible(
        h.button('c:${many.id}:Art 40'),
        200,
        scrollable: find.descendant(
          of: find.byKey(PadKeys.scroll),
          matching: find.byType(Scrollable),
        ),
      );
      await h.press(h.button('c:${many.id}:Art 40'));
      final ticks = await h.ofType(many, EventType.tick);
      expect(ticks.single.label, 'Art 40');

      await h.setPrefs(const UiPrefs(buttonScale: 1.5));
      await h.settle();
      await tester.scrollUntilVisible(
        h.button('c:${many.id}:Art 40'),
        200,
        scrollable: find.descendant(
          of: find.byKey(PadKeys.scroll),
          matching: find.byType(Scrollable),
        ),
      );
      expect(tester.getSize(h.button('c:${many.id}:Art 40')).height, 72 * 1.5);
      expect(tester.takeException(), isNull);
    });

    for (final size in const [Size(360, 640), TestApp.desktopSize]) {
      testWidgets('no overflow at ${size.width.toInt()} px, with the largest '
          'buttons and digits', (tester) async {
        final h = await TracksHarness.start(tester, surfaceSize: size);
        await h.addTrack(
          const CounterConfig(
            labels: ['Eichhörnchen', 'Graureiher', 'Buntspecht', 'Stockente'],
          ),
          name: 'Vögel im Stadtpark am Sonntagmorgen',
        );
        await _Protocol.create(h, scenePersons: ['Jacke', 'Kim']);
        await h.setPrefs(
          const UiPrefs(
            buttonScale: UiPrefs.maxButtonScale,
            digitScale: UiPrefs.maxDigitScale,
            density: UiDensity.roomy,
            leftHanded: true,
            use24h: false,
          ),
        );
        await h.showPad();
        await h.press(find.byKey(PadKeys.button('c:${h.counter.id}')));
        await h.press(find.byKey(PadKeys.button('s:${h.stopwatch.id}')));
        await h.wait(const Duration(hours: 1, minutes: 2));
        expect(tester.takeException(), isNull);
        // Left-handed: the undo button leads.
        final bar = tester.getRect(find.byKey(PadKeys.undoBar));
        final undo = tester.getRect(find.byKey(InlineUndoBar.undoKey));
        expect(undo.center.dx, lessThan(bar.center.dx));
      });
    }

    testWidgets('every button carries a semantics label', (tester) async {
      final h = await TracksHarness.start(tester);
      final birds = await h.addTrack(
        const CounterConfig(labels: _birdLabels),
        name: 'Vögel',
      );
      final p = await _Protocol.create(h, scenePersons: ['Jacke', 'Kim']);
      await h.showPad();
      final handle = tester.ensureSemantics();

      await h.press(h.button('c:${birds.id}:Reiher'));
      expect(
        find.bySemanticsLabel(
          TracksStrings.padButtonSemantics('Vögel', 'Reiher', '1'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          TracksStrings.padButtonSemantics('Stoppuhr', 'Stoppuhr', '00:00'),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(TracksStrings.padPersonSemantics('Zelt', 'Kim')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(TracksStrings.padMoreSemantics('Zelt')),
        findsOneWidget,
      );
      await h.press(h.button(p.person(p.kim)));
      expect(find.bySemanticsLabel(TracksStrings.padBackToPad), findsOneWidget);
      expect(
        find.bySemanticsLabel(TracksStrings.padSubstanceSemantics('GBL')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(TracksStrings.padOtherSemantics),
        findsOneWidget,
      );
      handle.dispose();
      expect(tester.takeException(), isNull);
    });
  });

  group('protocol', () {
    testWidgets('two steps: person, then one tap on a substance writes the '
        'entry and returns to the main pad', (tester) async {
      final h = await TracksHarness.start(tester);
      final p = await _Protocol.create(h, scenePersons: ['Kim', 'Jacke']);
      await h.showPad();

      // Main pad: one button per scene person (scene order) and "+".
      expect(h.button(p.person(p.kim)), findsOneWidget);
      expect(h.button(p.person(p.jacke)), findsOneWidget);
      expect(h.button(p.more()), findsOneWidget);
      expect(h.button(p.substance(p.jacke, p.gbl)), findsNothing);
      expect(find.byKey(PadKeys.back), findsNothing);
      final kimAt = tester.getTopLeft(h.button(p.person(p.kim)));
      final jackeAt = tester.getTopLeft(h.button(p.person(p.jacke)));
      expect(
        kimAt.dy < jackeAt.dy ||
            (kimAt.dy == jackeAt.dy && kimAt.dx < jackeAt.dx),
        isTrue,
      );

      // Step 1 writes nothing.
      await h.press(h.button(p.person(p.jacke)));
      expect(await h.snapshot(p.track), isNull);
      expect(find.byKey(PadKeys.back), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(PadKeys.pad),
          matching: find.text('Jacke'),
        ),
        findsOneWidget,
      );
      expect(h.barMessage, TracksStrings.padWhatTitle);
      expect(h.button(p.substance(p.jacke, p.gbl)), findsOneWidget);
      expect(h.button(p.substance(p.jacke, p.water)), findsOneWidget);
      expect(h.button(p.other(p.jacke)), findsOneWidget);
      // Only this person's buttons.
      expect(h.button(p.person(p.kim)), findsNothing);
      expect(h.button('s:${h.stopwatch.id}'), findsNothing);

      // Step 2: one tap, the entry is there.
      await h.wait(const Duration(minutes: 1));
      await h.press(h.button(p.substance(p.jacke, p.gbl)));
      final entry = (await p.entries(h)).single;
      expect(entry.personId, p.jacke.id);
      expect(entry.substanceId, p.gbl.id);
      expect(entry.at, h.app.clock.nowMs());
      // The app fills in nothing the user did not choose.
      expect(entry.amount, isNull);
      expect(entry.note, isNull);
      expect(entry.label, isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text(Strings.protocolNewEntry), findsNothing);
      expect(h.barMessage, 'Jacke · GBL');
      expect(h.barDetail, _stamp(h));

      // Back on the main pad after a moment, the entry in the undo bar.
      await h.wait(TikkyTokens.fallback.motion.captureConfirm);
      expect(find.byKey(PadKeys.back), findsNothing);
      expect(h.button(p.person(p.kim)), findsOneWidget);
      expect(
        h.sub(p.person(p.jacke)),
        TracksStrings.padPersonLast('GBL', padSince(entry.at, entry.at)),
      );
      expect(h.sub(p.person(p.kim)), '');
      expect(h.barMessage, 'Jacke · GBL');

      // Undo deletes the entry - and the session it had opened.
      await h.tapUndo();
      expect(await h.snapshot(p.track), isNull);
      expect(h.sub(p.person(p.jacke)), '');

      // The back button leaves a person without writing.
      await h.press(h.button(p.person(p.kim)));
      await h.press(find.byKey(PadKeys.back));
      expect(find.byKey(PadKeys.back), findsNothing);
      expect(await h.snapshot(p.track), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"eingetragen" on the field, nothing moves; "Ändern" opens '
        'the entry that was just written', (tester) async {
      final h = await TracksHarness.start(tester);
      final p = await _Protocol.create(h, scenePersons: ['Kim', 'Jacke']);
      await h.showPad();
      await h.press(h.button(p.person(p.jacke)));
      final ids = [
        p.substance(p.jacke, p.gbl),
        p.substance(p.jacke, p.water),
        p.other(p.jacke),
      ];
      Map<String, Rect> rects() => {
        for (final id in ids) id: tester.getRect(h.button(id)),
        'bar': tester.getRect(find.byKey(PadKeys.undoBar)),
      };
      final before = rects();
      Finder captured(String id) => find.descendant(
        of: h.button(id),
        matching: find.text(TracksStrings.padCaptured),
      );

      // Within the moment the pad stays: write without letting time pass.
      await tester.tap(h.button(ids[1]));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(captured(ids[1]), findsOneWidget);
      expect(captured(ids[0]), findsNothing);
      expect(rects(), before);
      expect(
        tester
            .widget<InlineUndoBar>(find.byKey(PadKeys.undoBar))
            .secondaryLabel,
        TracksStrings.padEdit,
      );

      await h.press(find.byKey(InlineUndoBar.secondaryKey));
      expect(find.text(Strings.protocolEditEntry), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('amount')), '0,5 l');
      await tester.ensureVisible(find.byKey(const ValueKey('save-entry')));
      await h.press(find.byKey(const ValueKey('save-entry')));
      await h.settle();
      final entry = (await p.entries(h)).single;
      expect(entry.substanceId, p.water.id);
      expect(entry.amount, '0,5 l');
      expect(h.barMessage, 'Jacke · Wasser · 0,5 l');
      // Undo still takes the (changed) entry back.
      await h.tapUndo();
      expect(await h.snapshot(p.track), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Anderes": the remaining substances, one tap writes; a new '
        'name is created and written', (tester) async {
      final h = await TracksHarness.start(tester);
      final p = await _Protocol.create(h, scenePersons: ['Kim', 'Jacke']);
      final tea = await h.run(
        () => h.container
            .read(peopleRepositoryProvider)
            .createSubstance(name: 'Tee'),
      );
      await h.showPad();
      await h.press(h.button(p.person(p.kim)));
      await h.press(h.button(p.other(p.kim)));
      expect(find.byKey(PadKeys.other), findsOneWidget);
      expect(h.barMessage, TracksStrings.padOtherTitle);
      // Only what is not on "Was?" already.
      expect(h.button(p.substance(p.kim, tea)), findsOneWidget);
      expect(h.button(p.substance(p.kim, p.gbl)), findsNothing);

      // Back goes to "Was?", not to the pad.
      await h.press(find.byKey(PadKeys.back));
      expect(find.byKey(PadKeys.other), findsNothing);
      expect(h.button(p.substance(p.kim, p.gbl)), findsOneWidget);
      await h.wait();
      await h.press(h.button(p.other(p.kim)));

      await h.press(h.button(p.substance(p.kim, tea)));
      expect((await p.entries(h)).single.substanceId, tea.id);
      expect(h.barMessage, 'Kim · Tee');
      await h.wait(TikkyTokens.fallback.motion.captureConfirm);
      expect(find.byKey(PadKeys.back), findsNothing);

      // A new one: typed, "Eintragen", in the list and in the entry.
      await h.press(h.button(p.person(p.kim)));
      await h.press(h.button(p.other(p.kim)));
      await tester.enterText(find.byKey(PadKeys.newName), 'Mate');
      await h.press(find.byKey(PadKeys.newSave));
      await h.drain();
      final substances = await h.run(
        () => h.container.read(peopleRepositoryProvider).getSubstances(),
      );
      final mate = substances.singleWhere((s) => s.name == 'Mate');
      final entries = await p.entries(h);
      expect(entries.last.substanceId, mate.id);
      expect(entries.last.personId, p.kim.id);
      expect(h.barMessage, 'Kim · Mate');
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a single-person scene shows the substance buttons on the '
        'main pad: one tap writes', (tester) async {
      final h = await TracksHarness.start(tester);
      final p = await _Protocol.create(h, scenePersons: ['Kim']);
      await h.showPad();

      expect(h.button(p.person(p.kim)), findsNothing);
      expect(h.button(p.person(p.jacke)), findsNothing);
      expect(h.button(p.substance(p.kim, p.gbl)), findsOneWidget);
      expect(h.button(p.substance(p.kim, p.water)), findsOneWidget);
      expect(h.button(p.other(p.kim)), findsOneWidget);
      // Next to the other tracks.
      expect(h.button('s:${h.stopwatch.id}'), findsOneWidget);
      final places = {
        for (final s in [p.gbl, p.water])
          s.id: tester.getRect(h.button(p.substance(p.kim, s))),
      };

      await h.press(h.button(p.substance(p.kim, p.water)));
      await h.wait();
      await h.press(h.button(p.substance(p.kim, p.water)));
      await h.press(h.button(p.substance(p.kim, p.gbl)));
      final entries = await p.entries(h);
      expect(
        [for (final e in entries) e.substanceId],
        [p.water.id, p.water.id, p.gbl.id],
      );
      expect(entries.every((e) => e.personId == p.kim.id), isTrue);
      expect(entries.every((e) => e.amount == null), isTrue);
      expect(find.byKey(PadKeys.back), findsNothing);
      // O5: the count only with the setting.
      expect(
        find.byKey(PadKeys.value(p.substance(p.kim, p.water))),
        findsNothing,
      );
      await h.setPrefs(const UiPrefs(showEntryCounts: true));
      await h.settle();
      expect(h.value(p.substance(p.kim, p.water)), TracksStrings.padCount(2));
      expect(h.value(p.substance(p.kim, p.gbl)), TracksStrings.padCount(1));
      expect(h.barMessage, startsWith('Kim · GBL'));
      // Water is the most used now - the buttons stay where they were.
      for (final s in [p.gbl, p.water]) {
        expect(tester.getRect(h.button(p.substance(p.kim, s))), places[s.id]);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a scene every person has a button; "+" opens the '
        'full sheet, quietly', (tester) async {
      final h = await TracksHarness.start(tester);
      final p = await _Protocol.create(h, scenePersons: const []);
      await h.showPad();

      expect(h.button(p.person(p.jacke)), findsOneWidget);
      expect(h.button(p.person(p.kim)), findsOneWidget);

      await h.press(h.button(p.more()));
      expect(find.text(Strings.protocolNewEntry), findsOneWidget);
      await h.press(find.byKey(ValueKey('person-${p.kim.id}')));
      await h.press(find.byKey(ValueKey('substance-${p.water.id}')));
      await tester.ensureVisible(find.byKey(const ValueKey('save-entry')));
      await h.press(find.byKey(const ValueKey('save-entry')));
      await h.settle();

      final entry = (await p.entries(h)).single;
      expect(entry.personId, p.kim.id);
      expect(entry.substanceId, p.water.id);
      // No snackbar over the pad: the entry is in the undo bar.
      expect(find.byType(SnackBar), findsNothing);
      expect(h.barMessage, startsWith('Kim · Wasser'));
      expect(find.byKey(PadKeys.back), findsNothing);
      await h.tapUndo();
      expect(await h.snapshot(p.track), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a lockout the user set is shown on the button and never '
        'blocks the tap', (tester) async {
      final h = await TracksHarness.start(tester);
      final p = await _Protocol.create(h, scenePersons: ['Kim']);
      await h.run(
        () => h.container
            .read(peopleRepositoryProvider)
            .updateSubstance(p.gbl.copyWith(lockoutMs: () => 2 * 3600 * 1000)),
      );
      await h.showPad();
      final gbl = p.substance(p.kim, p.gbl);
      final water = p.substance(p.kim, p.water);
      Finder lockout(String id) => find.descendant(
        of: h.button(id),
        matching: find.textContaining(TracksStrings.padLockout('')),
      );
      expect(lockout(gbl), findsNothing);

      await h.press(h.button(gbl));
      await h.press(h.button(water));
      expect(lockout(gbl), findsOneWidget);
      expect(
        find.descendant(
          of: h.button(gbl),
          matching: find.text(TracksStrings.padLockout('2 h')),
        ),
        findsOneWidget,
      );
      // No lockout set for water: no time of any kind beyond "since".
      expect(lockout(water), findsNothing);

      await h.wait(const Duration(minutes: 30));
      await h.press(h.button(gbl));
      expect(await p.entries(h), hasLength(3));
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('keyboard', () {
    testWidgets('1-9 and 0 press the first ten buttons, Backspace undoes, '
        'Escape leaves a person; the lane shortcuts rest', (tester) async {
      final h = await TracksHarness.start(
        tester,
        surfaceSize: TestApp.desktopSize,
      );
      final birds = await h.addTrack(
        CounterConfig(labels: [for (var i = 1; i <= 7; i++) 'Art $i']),
        name: 'Arten',
      );
      final p = await _Protocol.create(h, scenePersons: ['Jacke', 'Kim']);
      await h.showPad();

      // 1 = stopwatch: start, then LAP (the lane shortcut would pause).
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await h.drain();
      expect((await h.snapshot(h.stopwatch))!.isRunning, isTrue);
      await h.wait(const Duration(seconds: 2));
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad1);
      await h.drain();
      final watch = (await h.snapshot(h.stopwatch))! as StopwatchSnapshot;
      expect(watch.isRunning, isTrue);
      expect(watch.lapCount, 1);

      // Backspace takes the lap back.
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await h.drain();
      expect(await h.ofType(h.stopwatch, EventType.lap), isEmpty);
      // Nothing left to undo: Backspace does nothing.
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await h.drain();
      expect((await h.snapshot(h.stopwatch))!.isRunning, isTrue);

      // 3 = counter, 4 = first label, 0 = tenth button (seventh label).
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpad0);
      await h.drain();
      expect(await h.ofType(h.counter, EventType.tick), hasLength(1));
      expect(
        [for (final e in await h.ofType(birds, EventType.tick)) e.label],
        ['Art 1', 'Art 7'],
      );

      // Space does not start everything from the pad.
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await h.drain();
      expect(await h.snapshot(h.timer), isNull);

      // A person's buttons: Escape goes back, digits press what is shown.
      await h.press(h.button(p.person(p.kim)));
      expect(find.byKey(PadKeys.back), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await h.drain();
      expect(find.byKey(PadKeys.back), findsNothing);
      await h.wait();
      await h.press(h.button(p.person(p.kim)));
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await h.drain();
      final entry = (await p.entries(h)).single;
      expect(entry.personId, p.kim.id);
      expect(entry.substanceId, p.water.id);
      expect(find.byKey(PadKeys.back), findsNothing);

      // N still adds a track.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await h.drain();
      expect(find.text(Strings.newTrack), findsOneWidget);
      // While the sheet is open the pad keys rest.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await h.drain();
      expect(await h.ofType(h.counter, EventType.tick), hasLength(1));
      expect(tester.takeException(), isNull);
    });
  });
}
