import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/adaptive/adaptive.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/tracks/pad/tap_pad.dart';
import 'package:tikky_takka/features/tracks/set_switcher.dart';
import 'package:tikky_takka/features/tracks/timeline/timeline_view.dart';
import 'package:tikky_takka/features/tracks/tracks_screen.dart';
import 'package:tikky_takka/features/tracks/tracks_strings.dart';
import 'package:tikky_takka/features/tracks/tracks_view.dart';
import 'package:tikky_takka/l10n/formatters.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import '../../support/test_app.dart';
import 'tracks_harness.dart';

/// A view in the navigation: the pill on a phone, the rail when wide.
Finder _segment(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is NavPill || w is NavigationRail),
  matching: find.text(label),
);

/// A segment of the mode switch of the timeline ("Streifen", "Liste",
/// "Zusammenfassung").
Finder _timelineMode(String label) => find.descendant(
  of: find.byKey(TimelineKeys.mode),
  matching: find.text(label),
);

void main() {
  test('TracksView.fromName falls back to the lanes', () {
    expect(TracksView.fromName('pad'), TracksView.pad);
    expect(TracksView.fromName('timeline'), TracksView.timeline);
    expect(TracksView.fromName('lanes'), TracksView.lanes);
    expect(TracksView.fromName('something-newer'), TracksView.lanes);
    expect(TracksView.fromName(null), TracksView.lanes);
  });

  testWidgets('the pill shows lanes, tap pad and timeline; the head and '
      'the plus stay', (tester) async {
    final h = await TracksHarness.start(tester);

    // Default: the lanes. On a phone the views are words in the pill.
    expect(find.byType(NavPill), findsOneWidget);
    expect(find.byKey(TracksScreenKeys.list), findsOneWidget);
    expect(find.byKey(PadKeys.pad), findsNothing);
    expect(_segment(TracksStrings.viewLanes), findsOneWidget);
    expect(_segment(TracksStrings.viewPad), findsOneWidget);
    expect(_segment(TracksStrings.viewTimeline), findsOneWidget);

    await h.tap(_segment(TracksStrings.viewPad));
    expect(find.byKey(PadKeys.pad), findsOneWidget);
    expect(find.byKey(TracksScreenKeys.list), findsNothing);
    expect(
      h.container.read(tracksViewProvider(h.activeSet.id)),
      TracksView.pad,
    );

    await h.tap(_segment(TracksStrings.viewTimeline));
    expect(find.byKey(TimelineKeys.view), findsOneWidget);
    expect(find.byKey(PadKeys.pad), findsNothing);

    // Set switcher, start / pause all and add track are still there.
    expect(find.byType(SetSwitcherButton), findsOneWidget);
    expect(find.byKey(TracksScreenKeys.toggleAll), findsOneWidget);
    expect(find.byKey(TracksScreenKeys.addTrack), findsOneWidget);
    await h.tap(find.byKey(TracksScreenKeys.toggleAll));
    expect((await h.snapshot(h.stopwatch))!.isRunning, isTrue);
    await h.tap(find.byKey(TracksScreenKeys.addTrack));
    expect(find.text(Strings.newTrack), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await h.settle();

    await h.tap(_segment(TracksStrings.viewLanes));
    expect(find.byKey(TracksScreenKeys.list), findsOneWidget);
    expect(find.byKey(TimelineKeys.view), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layouts show the views on the rail', (tester) async {
    final h = await TracksHarness.start(
      tester,
      surfaceSize: TestApp.desktopSize,
    );
    expect(find.byType(NavPill), findsNothing);
    final rail = find.byType(NavigationRail);
    for (final label in [
      TracksStrings.viewLanes,
      TracksStrings.viewPad,
      TracksStrings.viewTimeline,
    ]) {
      expect(
        find.descendant(of: rail, matching: find.text(label)),
        findsOneWidget,
      );
    }
    // "Neue Spur" leads the rail, the settings close it.
    expect(
      find.descendant(
        of: rail,
        matching: find.byKey(TracksScreenKeys.addTrack),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: rail,
        matching: find.byKey(TracksScreenKeys.settings),
      ),
      findsOneWidget,
    );
    await h.tap(_segment(TracksStrings.viewPad));
    expect(find.byKey(PadKeys.pad), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the view is remembered per set, in the settings store', (
    tester,
  ) async {
    final h = await TracksHarness.start(tester);
    final first = h.activeSet;
    final sets = h.container.read(setRepositoryProvider);
    final kitchen = await h.run(() => sets.createSet(name: 'Küche'));
    await h.run(
      () => h.container
          .read(trackRepositoryProvider)
          .createTrack(
            setId: kitchen.id,
            name: 'Nudeln',
            config: const CounterConfig(),
          ),
    );

    await h.tap(_segment(TracksStrings.viewPad));
    expect(find.byKey(PadKeys.pad), findsOneWidget);
    expect(
      h.app.settings.getString('${SettingsKeys.tracksViewPrefix}${first.id}'),
      'pad',
    );

    // Another set starts with the lanes ...
    await h.run(
      () => h.container.read(activeSetIdProvider.notifier).select(kitchen.id),
    );
    await h.settle();
    expect(find.byKey(TracksScreenKeys.list), findsOneWidget);
    expect(find.byKey(PadKeys.pad), findsNothing);
    // ... and remembers its own choice.
    await h.tap(_segment(TracksStrings.viewTimeline));
    expect(find.byKey(TimelineKeys.view), findsOneWidget);
    expect(
      h.app.settings.getString('${SettingsKeys.tracksViewPrefix}${kitchen.id}'),
      'timeline',
    );

    await h.run(
      () => h.container.read(activeSetIdProvider.notifier).select(first.id),
    );
    await h.settle();
    expect(find.byKey(PadKeys.pad), findsOneWidget);
    expect(find.byKey(TimelineKeys.view), findsNothing);

    // A fresh start of the app reads the same choices from the store.
    final restarted = ProviderContainer(overrides: h.app.overrides);
    addTearDown(restarted.dispose);
    expect(restarted.read(tracksViewProvider(first.id)), TracksView.pad);
    expect(restarted.read(tracksViewProvider(kitchen.id)), TracksView.timeline);
    expect(restarted.read(tracksViewProvider('unknown')), TracksView.lanes);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the lane shortcuts work in the lanes view and rest in the '
      'timeline; N works everywhere', (tester) async {
    final h = await TracksHarness.start(
      tester,
      surfaceSize: TestApp.desktopSize,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await h.settle();
    expect(((await h.snapshot(h.counter))! as CounterSnapshot).count, 1);

    await h.run(
      () => h.container
          .read(tracksViewsProvider.notifier)
          .show(h.activeSet.id, TracksView.timeline),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await h.settle();
    expect(((await h.snapshot(h.counter))! as CounterSnapshot).count, 1);
    expect(await h.snapshot(h.stopwatch), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await h.settle();
    expect(find.text(Strings.newTrack), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await h.settle();

    // Back in the lanes they work again.
    await h.run(
      () => h.container
          .read(tracksViewsProvider.notifier)
          .show(h.activeSet.id, TracksView.lanes),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await h.settle();
    expect((await h.snapshot(h.stopwatch))!.isRunning, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the set theme and preference overrides apply to the pad and '
      'the timeline', (tester) async {
    final h = await TracksHarness.start(tester);
    final sets = h.container.read(setRepositoryProvider);
    await h.run(
      () => sets.updateSet(
        h.activeSet.copyWith(
          themeId: () => ThemePresets.blackId,
          uiPrefsOverride: () => {
            UiPrefsKeys.buttonScale: 1.5,
            UiPrefsKeys.use24h: false,
          },
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    await h.tap(_segment(TracksStrings.viewPad));
    final pad = tester.element(find.byKey(PadKeys.undoBar));
    expect(pad.tikky.theme.id, ThemePresets.blackId);
    expect(pad.tikky.prefs.buttonScale, 1.5);
    final counter = find.byKey(PadKeys.button('c:${h.counter.id}'));
    expect(tester.getSize(counter).height, greaterThanOrEqualTo(72 * 1.5));
    await h.tap(counter);
    // The set's 12-hour clock, in the undo bar ...
    final stamp = Fmt.time(h.app.clock.nowMs(), use24h: false);
    final bar = tester.widget<InlineUndoBar>(find.byKey(PadKeys.undoBar));
    expect(bar.message, Strings.seedCounterName);
    expect(bar.detail, TracksStrings.padWhen(stamp, TracksStrings.padNow));

    // ... and in the timeline.
    await h.tap(_segment(TracksStrings.viewTimeline));
    final timeline = tester.element(find.byKey(TimelineKeys.view));
    expect(timeline.tikky.theme.id, ThemePresets.blackId);
    // The strip is the default mode; the times as text are in the list.
    await h.tap(_timelineMode(TracksStrings.modeTimeline));
    expect(
      find.text(Fmt.time(h.app.clock.nowMs(), use24h: false, seconds: true)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cupertino platforms: the pill, the pad and the timeline', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final h = await TracksHarness.start(tester);
      expect(find.byType(NavPill), findsOneWidget);

      await h.tap(_segment(TracksStrings.viewPad));
      expect(find.byKey(PadKeys.pad), findsOneWidget);
      await h.tap(find.byKey(PadKeys.button('c:${h.counter.id}')));
      await h.tap(find.byKey(PadKeys.button('s:${h.stopwatch.id}')));
      expect(((await h.snapshot(h.counter))! as CounterSnapshot).count, 1);
      expect((await h.snapshot(h.stopwatch))!.isRunning, isTrue);
      expect(find.byKey(InlineUndoBar.undoKey), findsOneWidget);
      await h.tap(find.byKey(InlineUndoBar.undoKey));
      expect(await h.snapshot(h.stopwatch), isNull);

      await h.tap(_segment(TracksStrings.viewTimeline));
      // The strip is the default mode; this walks through the list.
      await h.tap(_timelineMode(TracksStrings.modeTimeline));
      expect(find.byKey(TimelineKeys.list), findsOneWidget);
      expect(find.text('Tipp 1'), findsOneWidget);
      await h.tap(find.text('Tipp 1'));
      expect(find.text(TracksStrings.eventEditTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
