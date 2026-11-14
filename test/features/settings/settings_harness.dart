import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/clock.dart';
import 'package:tikky_takka/core/db/app_database.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/repo/session_store.dart';
import 'package:tikky_takka/core/services/alarms/alarm_service.dart';
import 'package:tikky_takka/core/services/export_service.dart';
import 'package:tikky_takka/core/services/keep_awake.dart';
import 'package:tikky_takka/core/services/lock_service.dart';
import 'package:tikky_takka/features/settings/widgets/setting_rows.dart';
import 'package:tikky_takka/theme/theme.dart';

/// Test environment for the settings feature.
///
/// Deliberately independent of `app.dart` (and therefore of the other
/// feature screens): an in-memory database, a fake clock, deterministic
/// ids and a small app whose theme follows the providers, so "immediate
/// effect" can be asserted on the widget tree.
class SettingsHarness {
  SettingsHarness._({
    required this.db,
    required this.settings,
    required this.clock,
    required this.alarms,
    required this.export,
    required this.overrides,
  });

  static const Size phoneSize = Size(400, 800);
  static const Size desktopSize = Size(1100, 800);

  final AppDatabase db;
  final SettingsStore settings;
  final FakeClock clock;
  final RecordingAlarmService alarms;
  final FakeExportService export;
  final List<Override> overrides;

  static Future<SettingsHarness> create(
    WidgetTester tester, {
    DynamicPalette? dynamicPalette,
    LockService lockService = const NoopLockService(),
    List<Override> extraOverrides = const [],
  }) async {
    // Every in-memory database is independent; several per test are fine.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase.inMemory();
    final clock = FakeClock(1700000000000);
    final settings = (await tester.runAsync(
      () => SettingsStore.load(db, clock: clock),
    ))!;
    final alarms = RecordingAlarmService();
    final export = FakeExportService();
    var nextId = 0;
    addTearDown(db.close);
    return SettingsHarness._(
      db: db,
      settings: settings,
      clock: clock,
      alarms: alarms,
      export: export,
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
        exportServiceProvider.overrideWithValue(export),
        dynamicPaletteProvider.overrideWith((ref) async => dynamicPalette),
        ...extraOverrides,
      ],
    );
  }

  /// Stores [themes] as the user's custom themes. Call BEFORE [pump].
  Future<void> seedCustomThemes(
    WidgetTester tester,
    List<TikkyTheme> themes,
  ) async {
    await tester.runAsync(
      () => settings.setJson(SettingsKeys.customThemes, {
        'themes': [for (final t in themes) t.toJson()],
      }),
    );
  }

  SetRepository get _sets => SetRepository(
    db,
    clock,
    () => 'set-${++_setIds}',
    AlarmSync(SessionStore(db), clock, alarms),
  );
  int _setIds = 0;

  /// Creates a set directly in the database.
  Future<TrackSet> createSet(WidgetTester tester, String name) async =>
      (await tester.runAsync(() => _sets.createSet(name: name)))!;

  /// Reads a set back from the database.
  Future<TrackSet?> storedSet(WidgetTester tester, String id) =>
      tester.runAsync<TrackSet?>(() => _sets.getSet(id));

  /// Pumps [home] inside a `MaterialApp` whose theme is the app theme from
  /// the providers (so theme and preference changes show at once).
  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    Size surfaceSize = phoneSize,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = surfaceSize;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        retry: (_, _) => null,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: ref.watch(appThemeDataProvider),
            themeAnimationDuration: Duration.zero,
            home: home,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  /// Lets database work, stream emissions and route / sheet animations
  /// finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  /// The provider container of the pumped app.
  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  /// Reads the settings table again, as a fresh app start would.
  Future<SettingsStore> reloadedStore(WidgetTester tester) async =>
      (await tester.runAsync(() => SettingsStore.load(db, clock: clock)))!;

  /// The settings list of the page on top.
  Finder get list => find
      .descendant(
        of: find.byType(SettingsBody).last,
        matching: find.byType(Scrollable),
      )
      .first;

  /// Scrolls the settings list until [finder] is built and visible
  /// (downwards, or back [up]).
  Future<void> reveal(
    WidgetTester tester,
    Finder finder, {
    bool up = false,
  }) async {
    await tester.scrollUntilVisible(finder, up ? -120 : 120, scrollable: list);
    // Into the middle: on iOS the list scrolls on under the collapsed
    // large-title bar, so an item at the very top would sit beneath it.
    await tester.runAsync(
      () => Scrollable.ensureVisible(tester.element(finder), alignment: 0.5),
    );
    await tester.pump();
  }
}

/// Records delivered files and serves a prepared file to "open" dialogs.
class FakeExportService implements ExportService {
  /// Files handed to [deliver], oldest first.
  final List<ExportFile> delivered = [];

  /// What [pickJsonFile] returns (`null` = the user cancelled).
  String? pickResult;

  /// Backups passed to [importJsonBackup].
  final List<String> imported = [];

  /// Options of the last build call.
  ExportOptions? lastOptions;

  ExportFile _file(String name, ExportOptions options) {
    lastOptions = options;
    return ExportFile(
      fileName: name,
      mimeType: 'text/plain',
      bytes: Uint8List(0),
    );
  }

  @override
  Future<ExportFile> buildSessionsCsv(ExportOptions options) async =>
      _file('sessions.csv', options);

  @override
  Future<ExportFile> buildEventsCsv(ExportOptions options) async =>
      _file('events.csv', options);

  @override
  Future<ExportFile> buildJsonBackup(ExportOptions options) async =>
      _file('backup.json', options);

  @override
  Future<ImportReport> importJsonBackup(String json) async {
    if (!json.trimLeft().startsWith('{')) {
      throw const FormatException('not a backup');
    }
    imported.add(json);
    return const ImportReport(inserted: {'tracks': 2});
  }

  @override
  Future<bool> deliver(ExportFile file, {Rect? sharePositionOrigin}) async {
    delivered.add(file);
    return true;
  }

  @override
  Future<String?> pickJsonFile() async => pickResult;
}
