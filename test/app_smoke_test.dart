import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/adaptive/adaptive.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/services/alarms/alarm_service.dart';
import 'package:tikky_takka/features/history/history_screen.dart';
import 'package:tikky_takka/features/settings/lock_gate.dart';
import 'package:tikky_takka/features/settings/settings_screen.dart';
import 'package:tikky_takka/features/tracks/pad/tap_pad.dart';
import 'package:tikky_takka/features/tracks/tracks_screen.dart';
import 'package:tikky_takka/features/tracks/tracks_strings.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import 'support/shell_nav.dart';
import 'support/test_app.dart';

void main() {
  testWidgets('app starts with seed data on the tracks destination', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    await app.pumpApp(tester);

    expect(find.byType(LockGate), findsOneWidget);
    expect(find.byType(TracksScreen), findsOneWidget);
    expect(find.byType(NavPill), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    // Seed: set "Allgemein" with a stopwatch, a timer and a counter.
    expect(find.text(Strings.seedSetName), findsOneWidget);
    expect(find.text(Strings.seedStopwatchName), findsWidgets);
    expect(find.text(Strings.seedTimerName), findsWidgets);
    expect(find.text(Strings.seedCounterName), findsWidgets);

    // Bootstrap initialised the alarm service and rebuilt the alarms.
    expect(app.alarms.log, containsAllInOrder(['init', 'cancelAll']));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pill switches the views, "···" opens settings and history', (
    tester,
  ) async {
    final app = await TestApp.create(tester);
    await app.pumpApp(tester);

    expect(find.byType(HistoryScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsNothing);

    await tester.tap(find.text(TracksStrings.viewPad));
    await app.settle(tester);
    expect(find.byType(TapPad), findsOneWidget);
    await tester.tap(find.text(TracksStrings.viewLanes));
    await app.settle(tester);
    expect(find.byType(TapPad), findsNothing);

    await openHistoryPage(tester);
    await app.settle(tester);
    expect(find.byType(HistoryScreen), findsOneWidget);
    await closePage(tester);

    await openSettingsPage(tester);
    await app.settle(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await closePage(tester);
    await app.settle(tester);
    expect(find.byType(TracksScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layouts use a navigation rail', (tester) async {
    final app = await TestApp.create(tester);
    await app.pumpApp(tester, surfaceSize: TestApp.desktopSize);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavPill), findsNothing);
    expect(find.byType(TracksScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Apple platforms get the same navigation', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final app = await TestApp.create(tester);
      await app.pumpApp(tester);

      expect(find.byType(NavPill), findsOneWidget);
      expect(find.byType(CupertinoTabBar), findsNothing);
      expect(find.text(Strings.seedSetName), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the selected theme is applied and persisted', (tester) async {
    final app = await TestApp.create(tester);
    await app.pumpApp(tester);

    final context = tester.element(find.byType(TracksScreen));
    // Tests run with a light platform brightness: system mode -> "Hell".
    expect(context.tikky.theme.id, ThemePresets.lightId);

    final container = ProviderScope.containerOf(context);
    await tester.runAsync(
      () => container
          .read(themeSettingsProvider.notifier)
          .selectTheme(ThemePresets.blackId),
    );
    await app.settle(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(
      Theme.of(tester.element(find.byType(TracksScreen)))
          .scaffoldBackgroundColor,
      ThemePresets.black.colors.background,
    );
    expect(app.settings.getJson('theme.settings')!['themeId'], 'preset.black');
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification actions reach the track commands', (tester) async {
    final app = await TestApp.create(tester);
    await app.pumpApp(tester);
    final context = tester.element(find.byType(TracksScreen));
    final container = ProviderScope.containerOf(context);

    final timer = container
        .read(activeTracksProvider)
        .firstWhere((t) => t.name == Strings.seedTimerName);
    await tester.runAsync(
      () => container.read(trackCommandsProvider).startTrack(timer.id),
    );
    await app.settle(tester);
    expect(app.alarms.scheduled.containsKey(timer.id), isTrue);

    app.alarms.emit(
      AlarmAction(trackId: timer.id, type: AlarmActionType.dismiss),
    );
    await app.settle(tester);
    expect(app.alarms.scheduled, isEmpty);
    expect(
      await tester.runAsync(
        () => container.read(trackCommandsProvider).getOpenSession(timer.id),
      ),
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
