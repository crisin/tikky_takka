import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/app.dart';
import 'package:tikky_takka/app_wiring.dart';
import 'package:tikky_takka/core/db/app_database.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/services/export_service.dart';
import 'package:tikky_takka/core/services/export_service_impl.dart';
import 'package:tikky_takka/features/history/history_screen.dart';
import 'package:tikky_takka/features/protocol/protocol_people_screen.dart';
import 'package:tikky_takka/features/settings/lock_gate.dart';
import 'package:tikky_takka/features/settings/settings_screen.dart';
import 'package:tikky_takka/features/settings/theme_editor_screen.dart';
import 'package:tikky_takka/features/settings/theme_list_screen.dart';
import 'package:tikky_takka/features/settings/widgets/setting_rows.dart';
import 'package:tikky_takka/features/tracks/track_editor_sheet.dart';
import 'package:tikky_takka/features/tracks/track_lane.dart';
import 'package:tikky_takka/features/tracks/tracks_screen.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/main.dart' show productionOverrides;

import 'support/test_app.dart';

/// Records what the export hands to the OS instead of opening a dialog.
class _RecordingDelivery implements ExportDelivery {
  final List<ExportFile> delivered = [];

  @override
  Future<bool> deliver(ExportFile file, {Rect? sharePositionOrigin}) async {
    delivered.add(file);
    return true;
  }

  @override
  Future<String?> pickJsonFile() async => null;
}

/// The complete app as production wires it (`featureWiringOverrides`:
/// settings hooks and the real export service), on an in-memory database
/// with the fake plugin services of [TestApp].
void main() {
  late _RecordingDelivery delivery;

  Future<TestApp> start(WidgetTester tester, {Size? size}) async {
    delivery = _RecordingDelivery();
    final app = await TestApp.create(
      tester,
      extraOverrides: featureWiringOverrides(exportDelivery: delivery),
    );
    await app.pumpApp(tester, surfaceSize: size ?? TestApp.phoneSize);
    return app;
  }

  Future<void> settle(WidgetTester tester, TestApp app) async {
    await app.settle(tester);
    // Route and sheet transitions.
    await tester.pump(const Duration(milliseconds: 600));
    await app.settle(tester, rounds: 3);
  }

  /// Closes the sheet or page on top.
  Future<void> pop(WidgetTester tester, TestApp app) async {
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await settle(tester, app);
  }

  /// Scrolls the settings list until [finder] can be tapped.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find
          .descendant(
            of: find.byType(SettingsBody).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
  }

  Finder inNavigation(String label) => find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );

  testWidgets('tracks: the track editor opens for new and existing tracks', (
    tester,
  ) async {
    final app = await start(tester);
    expect(find.byType(TracksScreen), findsOneWidget);

    await tester.tap(find.byKey(TracksScreenKeys.addTrack));
    await settle(tester, app);
    expect(find.text(Strings.newTrack), findsOneWidget);
    expect(find.byKey(TrackEditorKeys.save), findsOneWidget);
    await pop(tester, app);
    expect(find.byKey(TrackEditorKeys.save), findsNothing);

    await tester.longPress(find.text(Strings.seedStopwatchName).first);
    await settle(tester, app);
    expect(find.text(Strings.editTrack), findsOneWidget);
    await pop(tester, app);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history: the export sheet builds and delivers a real CSV', (
    tester,
  ) async {
    final app = await start(tester);

    await tester.tap(inNavigation(Strings.navHistory));
    await settle(tester, app);
    expect(find.byType(HistoryScreen), findsOneWidget);

    await tester.tap(find.byTooltip(Strings.export));
    await settle(tester, app);
    expect(find.text(Strings.exportTitle), findsOneWidget);
    expect(find.text(Strings.exportIncludeProtocol), findsOneWidget);

    await tester.tap(find.text(Strings.exportSessionsCsv));
    await settle(tester, app);
    expect(delivery.delivered, hasLength(1));
    final file = delivery.delivered.single;
    expect(file.fileName, endsWith('.csv'));
    // UTF-8 byte order mark.
    expect(file.bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    // Delivered: the sheet closed and reports success.
    expect(find.text(Strings.exportIncludeProtocol), findsNothing);
    expect(find.text(Strings.exportDone), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings: export sheet, people, app lock and theme editor '
      'are reachable', (tester) async {
    final app = await start(tester);

    await tester.tap(inNavigation(Strings.navSettings));
    await settle(tester, app);
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Appearance -> theme list -> theme editor.
    await tester.tap(find.byKey(const ValueKey('settings.themes')));
    await settle(tester, app);
    expect(find.byType(ThemeListScreen), findsOneWidget);
    await tester.tap(find.byTooltip(Strings.themeNew));
    await settle(tester, app);
    expect(find.byType(ThemeEditorScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await pop(tester, app);
    await pop(tester, app);
    expect(find.byType(ThemeListScreen), findsNothing);

    // Data -> the real export sheet (not the fallback action sheet).
    final export = find.byKey(const ValueKey('settings.export'));
    await reveal(tester, export);
    await tester.tap(export);
    await settle(tester, app);
    expect(find.text(Strings.exportIncludeProtocol), findsOneWidget);
    await pop(tester, app);

    // Data -> persons / substances open the protocol feature's screen.
    final persons = find.byKey(const ValueKey('settings.persons'));
    await reveal(tester, persons);
    await tester.tap(persons);
    await settle(tester, app);
    expect(find.byType(ProtocolPeopleScreen), findsOneWidget);
    expect(find.text(Strings.comingSoon), findsNothing);
    await pop(tester, app);

    final substances = find.byKey(const ValueKey('settings.substances'));
    await reveal(tester, substances);
    await tester.tap(substances);
    await settle(tester, app);
    expect(
      tester
          .widget<ProtocolPeopleScreen>(find.byType(ProtocolPeopleScreen))
          .initialTab,
      ProtocolPeopleTab.substances,
    );
    await pop(tester, app);

    // Privacy -> the lock feature's own tile (disabled: no lock in tests).
    await reveal(tester, find.byType(AppLockTile));
    expect(find.text(Strings.appLockUnavailable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout: all three destinations through the rail', (
    tester,
  ) async {
    final app = await start(tester, size: TestApp.desktopSize);
    Finder inRail(String label) => find.descendant(
      of: find.byType(NavigationRail),
      matching: find.text(label),
    );

    await tester.tap(inRail(Strings.navHistory));
    await settle(tester, app);
    expect(find.byType(HistoryScreen), findsOneWidget);
    await tester.tap(inRail(Strings.navSettings));
    await settle(tester, app);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.tap(inRail(Strings.navTracks));
    await settle(tester, app);
    expect(find.byType(TracksScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the production services degrade gracefully without plugins', (
    tester,
  ) async {
    // Exactly what main() registers, on an in-memory database. No plugin
    // exists in a widget test, which is the worst case a device can offer:
    // notifications, authentication and the wake lock all fail to
    // initialise. The app must start and work regardless.
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    final settings = (await tester.runAsync(() => SettingsStore.load(db)))!;
    TestApp.setSurface(tester, TestApp.phoneSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          settingsStoreProvider.overrideWithValue(settings),
          ...productionOverrides(),
        ],
        retry: (_, _) => null,
        child: const TikkyApp(),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 600));
    }

    await settle();
    expect(find.byType(TracksScreen), findsOneWidget);
    expect(find.text(Strings.seedTimerName), findsWidgets);

    // Starting a countdown schedules an alarm: a no-op here, never an error.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TracksScreen)),
    );
    final timer = container
        .read(activeTracksProvider)
        .firstWhere((t) => t.name == Strings.seedTimerName);
    // Through the lane button, not `runAsync`: the service chains futures
    // that were created in the test's fake-async zone.
    await tester.tap(find.byKey(LaneKeys.primary(timer.id)));
    await settle();
    expect(container.read(openSessionProvider(timer.id)), isNotNull);
    await tester.tap(find.byKey(LaneKeys.primary(timer.id)));
    await settle();
    expect(tester.takeException(), isNull);

    // Settings: notifications unsupported. The app lock check FAILS here
    // (missing plugin), which is "unknown" and deliberately not reported
    // as "not available on this device": a failed check must never be
    // mistaken for a definite no (it would open a locked app).
    await tester.tap(inNavigation(Strings.navSettings));
    await settle();
    await reveal(tester, find.byType(AppLockTile));
    await settle();
    expect(find.text(Strings.notificationsUnsupported), findsOneWidget);
    expect(find.text(Strings.appLockUnavailable), findsNothing);
    expect(find.text(LockStrings.checkFailedTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
