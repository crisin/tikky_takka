import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/app.dart';
import 'package:tikky_takka/core/clock.dart';
import 'package:tikky_takka/core/db/app_database.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/services/alarms/alarm_service.dart';
import 'package:tikky_takka/core/services/keep_awake.dart';
import 'package:tikky_takka/core/services/lock_service.dart';
import 'package:tikky_takka/theme/theme.dart';

/// Everything a widget test needs to drive the app without plugins: an
/// in-memory database, a fake clock, deterministic ids and no-op /
/// recording services.
class TestApp {
  TestApp._({
    required this.db,
    required this.settings,
    required this.clock,
    required this.alarms,
    required this.overrides,
  });

  /// A typical phone in portrait, in logical pixels.
  static const Size phoneSize = Size(400, 800);

  /// A desktop window (wide layout: navigation rail, track grid).
  static const Size desktopSize = Size(1100, 800);

  final AppDatabase db;
  final SettingsStore settings;
  final FakeClock clock;
  final RecordingAlarmService alarms;

  /// Pass to a [ProviderScope] (or `ProviderContainer`).
  final List<Override> overrides;

  /// Creates the environment. Call inside `testWidgets` BEFORE pumping.
  static Future<TestApp> create(
    WidgetTester tester, {
    int startMs = 1700000000000,
    List<Override> extraOverrides = const [],
    RecordingAlarmService? alarmService,
    LockService lockService = const NoopLockService(),
  }) async {
    final db = AppDatabase.inMemory();
    final clock = FakeClock(startMs);
    final settings = (await tester.runAsync(
      () => SettingsStore.load(db, clock: clock),
    ))!;
    final alarms = alarmService ?? RecordingAlarmService();
    var nextId = 0;
    addTearDown(db.close);
    return TestApp._(
      db: db,
      settings: settings,
      clock: clock,
      alarms: alarms,
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        settingsStoreProvider.overrideWithValue(settings),
        clockProvider.overrideWithValue(clock),
        idGeneratorProvider.overrideWithValue(
          () => 'id-${(++nextId).toString().padLeft(4, '0')}',
        ),
        alarmServiceProvider.overrideWithValue(alarms),
        lockServiceProvider.overrideWithValue(lockService),
        keepAwakeServiceProvider.overrideWithValue(const NoopKeepAwake()),
        dynamicPaletteProvider.overrideWith((ref) async => null),
        ...extraOverrides,
      ],
    );
  }

  /// Pumps the complete app ([TikkyApp]) and waits for the bootstrap (seed
  /// data, alarm init) and the first data to arrive.
  ///
  /// The surface defaults to a phone ([phoneSize]); the test framework's own
  /// default of 800 x 600 would already count as a wide layout.
  Future<void> pumpApp(
    WidgetTester tester, {
    Size surfaceSize = phoneSize,
  }) async {
    setSurface(tester, surfaceSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        // No automatic retries: a failing provider should fail the test.
        retry: (_, _) => null,
        child: const TikkyApp(),
      ),
    );
    await settle(tester);
  }

  /// Pumps any widget inside the app's theme and provider scope (for
  /// feature widget tests that do not need the whole shell). [child] is
  /// the `home` of a [MaterialApp]; give it its own `Scaffold` if needed.
  Future<void> pumpWidget(
    WidgetTester tester,
    Widget child, {
    TargetPlatform? platform,
    TikkyTheme theme = ThemePresets.light,
    UiPrefs prefs = UiPrefs.defaults,
    Size surfaceSize = phoneSize,
  }) async {
    setSurface(tester, surfaceSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        retry: (_, _) => null,
        child: MaterialApp(
          theme: buildMaterialTheme(theme, prefs, platform: platform),
          themeAnimationDuration: Duration.zero,
          home: child,
        ),
      ),
    );
    await settle(tester);
  }

  /// Sets the logical size of the test window (also what `MediaQuery`
  /// reports) and restores it after the test.
  static void setSurface(WidgetTester tester, Size logicalSize) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = logicalSize;
    addTearDown(tester.view.reset);
  }

  /// Lets pending database work and stream emissions reach the widgets.
  ///
  /// The in-memory database completes its futures on the real event loop,
  /// so a few rounds of "real async + frame" are needed instead of
  /// `pumpAndSettle` (which would also never finish while a lane ticks).
  Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }
}
