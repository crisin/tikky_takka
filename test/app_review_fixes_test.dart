import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/app_wiring.dart';
import 'package:tikky_takka/core/clock.dart';
import 'package:tikky_takka/core/db/app_database.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/engine/engine.dart';
import 'package:tikky_takka/core/services/export_service.dart';
import 'package:tikky_takka/core/services/export_service_impl.dart';
import 'package:tikky_takka/core/services/lock_service.dart';
import 'package:tikky_takka/features/history/history_screen.dart';
import 'package:tikky_takka/features/settings/settings_screen.dart';
import 'package:tikky_takka/features/settings/widgets/setting_rows.dart';
import 'package:tikky_takka/features/tracks/track_lane.dart';
import 'package:tikky_takka/features/tracks/tracks_screen.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import 'support/shell_nav.dart';
import 'support/test_app.dart';

/// Counts how often the history is read from the database.
class _CountingHistory extends HistoryRepository {
  _CountingHistory(super.db, super.clock, super.alarmSync);

  int loads = 0;

  @override
  Future<List<HistorySession>> getSessions(HistoryFilter filter) {
    loads++;
    return super.getSessions(filter);
  }
}

/// Hands a prepared backup file to the import.
class _PickedFile implements ExportDelivery {
  _PickedFile(this.json);

  final String json;

  @override
  Future<bool> deliver(ExportFile file, {Rect? sharePositionOrigin}) async =>
      true;

  @override
  Future<String?> pickJsonFile() async => json;
}

/// The complete app: lifecycle, clock jumps, history loading and the two
/// import entry points.
void main() {
  Future<void> settle(WidgetTester tester, TestApp app) async {
    await app.settle(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await app.settle(tester, rounds: 4);
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(
        tester.element(find.byType(TracksScreen, skipOffstage: false)),
      );

  Future<void> lifecycle(
    WidgetTester tester,
    TestApp app,
    AppLifecycleState state,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(state);
    await settle(tester, app);
  }

  void restoreLifecycle(WidgetTester tester) => addTearDown(
    () => tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    ),
  );

  testWidgets('going to the background rebuilds the alarm plans once, so '
      'the notification slots start from that moment', (tester) async {
    final app = await TestApp.create(tester);
    await app.pumpApp(tester);
    restoreLifecycle(tester);
    final container = containerOf(tester);
    final set = container.read(activeSetProvider)!;
    final reminder = (await tester.runAsync(
      () => container
          .read(trackRepositoryProvider)
          .createTrack(
            setId: set.id,
            name: 'Trinken',
            config: const ReminderConfig(intervalMs: 60000, nagEveryMs: 60000),
          ),
    ))!;
    await settle(tester, app);
    await tester.runAsync(
      () => container.read(trackCommandsProvider).startTrack(reminder.id),
    );
    await settle(tester, app);
    final planned = app.alarms.scheduled[reminder.id]!;
    expect(planned, hasLength(AlarmSync.maxAlarmsPerTrack));

    // Half an hour in the foreground: every planned slot is in the past.
    app.clock.advance(const Duration(minutes: 30));
    await tester.pump(const Duration(milliseconds: 100));
    await settle(tester, app);
    expect(planned.last.at, lessThan(app.clock.nowMs()));
    expect(app.alarms.scheduled[reminder.id], same(planned));

    app.alarms.log.clear();
    await lifecycle(tester, app, AppLifecycleState.inactive);
    expect(app.alarms.log, isEmpty);
    await lifecycle(tester, app, AppLifecycleState.hidden);
    final fresh = app.alarms.scheduled[reminder.id]!;
    expect(fresh, hasLength(AlarmSync.maxAlarmsPerTrack));
    expect(fresh.first.at, greaterThan(app.clock.nowMs()));
    expect(fresh.last.planEndsHere, isTrue);
    expect(app.alarms.log.where((e) => e == 'cancelAll'), hasLength(1));

    // Android reports hidden and then paused: still one rebuild.
    await lifecycle(tester, app, AppLifecycleState.paused);
    expect(app.alarms.log.where((e) => e == 'cancelAll'), hasLength(1));

    // Resuming syncs again (alarms may have fired meanwhile) ...
    await lifecycle(tester, app, AppLifecycleState.resumed);
    expect(app.alarms.log.where((e) => e == 'cancelAll'), hasLength(2));
    // ... and the next trip to the background plans again.
    await lifecycle(tester, app, AppLifecycleState.hidden);
    expect(app.alarms.log.where((e) => e == 'cancelAll'), hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a jump of the system time resyncs the alarms and tells the '
      'user once; the log is not rewritten', (tester) async {
    final app = await TestApp.create(tester);
    await app.pumpApp(tester);
    final container = containerOf(tester);
    final timer = container
        .read(activeTracksProvider)
        .firstWhere((t) => t.name == Strings.seedTimerName);
    await tester.tap(find.byKey(LaneKeys.primary(timer.id)));
    await settle(tester, app);
    final startedAt = (await tester.runAsync(
      () => container.read(trackCommandsProvider).getOpenSession(timer.id),
    ))!.session.startedAt;
    final dueBefore = app.alarms.scheduled[timer.id]!.single.at;

    // Time that simply passes is no jump.
    app.clock.advance(const Duration(minutes: 2));
    await tester.pump(const Duration(milliseconds: 100));
    await settle(tester, app);
    expect(find.text(Strings.clockChanged), findsNothing);

    // The user sets the clock back by one minute.
    app.alarms.log.clear();
    app.clock.setMs(app.clock.nowMs() - 60000);
    await tester.pump(const Duration(milliseconds: 100));
    await app.settle(tester);
    expect(find.text(Strings.clockChanged), findsOneWidget);
    expect(app.alarms.log, contains('cancelAll'));
    expect(app.alarms.log, contains('schedule:${timer.id}:1'));
    // Nothing was rewritten: same start, hence the same due time.
    expect(app.alarms.scheduled[timer.id]!.single.at, dueBefore);
    expect(
      (await tester.runAsync(
        () => container.read(trackCommandsProvider).getOpenSession(timer.id),
      ))!.session.startedAt,
      startedAt,
    );

    // The notice goes away and is not repeated for a jump right after it,
    // but the alarms are resynced every time.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await settle(tester, app);
    expect(find.text(Strings.clockChanged), findsNothing);
    app.alarms.log.clear();
    app.clock.setMs(app.clock.nowMs() + 60000);
    await tester.pump(const Duration(milliseconds: 100));
    await settle(tester, app);
    expect(find.text(Strings.clockChanged), findsNothing);
    expect(app.alarms.log, contains('cancelAll'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the history is only read while its destination is shown, '
      'and catches up with one reload when it is shown again', (tester) async {
    late _CountingHistory history;
    final app = await TestApp.create(
      tester,
      extraOverrides: [
        historyRepositoryProvider.overrideWith(
          (ref) => history = _CountingHistory(
            ref.watch(appDatabaseProvider),
            ref.watch(clockProvider),
            ref.watch(alarmSyncProvider),
          ),
        ),
      ],
    );
    await app.pumpApp(tester);
    final container = containerOf(tester);
    final counter = container
        .read(activeTracksProvider)
        .firstWhere((t) => t.name == Strings.seedCounterName);

    await openHistoryPage(tester);
    await settle(tester, app);
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(history.loads, greaterThan(0));

    // Back on the tracks: the history page is gone ...
    await closePage(tester);
    await settle(tester, app);
    expect(find.byType(HistoryScreen, skipOffstage: false), findsNothing);
    final before = history.loads;

    // ... and event writes do not make anything re-read the history.
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(LaneKeys.primary(counter.id)));
      await settle(tester, app);
    }
    await tester.runAsync(
      () => container.read(trackCommandsProvider).stopTrack(counter.id),
    );
    await settle(tester, app);
    expect(history.loads, before);

    // Opened again: it reads once, and the new session is there.
    await openHistoryPage(tester);
    await settle(tester, app);
    expect(history.loads, greaterThan(before));
    expect(find.text(Strings.seedCounterName), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  group('backup import', () {
    // A backup from a device with the app lock ON and haptics off.
    final backup = ExportFormat.encodeBackup(
      BackupData(
        settings: {
          SettingsKeys.appLock: 'true',
          SettingsKeys.uiPrefs: jsonEncode(
            UiPrefs.defaults.copyWith(haptics: false).toJson(),
          ),
        },
      ),
    );

    Future<TestApp> start(WidgetTester tester) async {
      final app = await TestApp.create(
        tester,
        extraOverrides: featureWiringOverrides(
          exportDelivery: _PickedFile(backup),
        ),
      );
      await app.pumpApp(tester);
      return app;
    }

    void expectImported(WidgetTester tester, TestApp app) {
      final container = containerOf(tester);
      // The preference providers were refreshed from the merged settings.
      expect(container.read(uiPrefsProvider).haptics, isFalse);
      // The app lock never comes from a file.
      expect(app.settings.contains(SettingsKeys.appLock), isFalse);
      expect(container.read(appLockEnabledProvider), isFalse);
    }

    testWidgets('from the settings screen: providers refreshed, app lock '
        'untouched', (tester) async {
      final app = await start(tester);
      expect(containerOf(tester).read(uiPrefsProvider).haptics, isTrue);

      await openSettingsPage(tester);
      await settle(tester, app);
      final import = find.byKey(const ValueKey('settings.import'));
      await tester.scrollUntilVisible(
        import,
        120,
        scrollable: find
            .descendant(
              of: find.byType(SettingsBody).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump();
      await tester.tap(import);
      await settle(tester, app);

      expect(find.byType(SettingsScreen), findsOneWidget);
      expectImported(tester, app);
      expect(tester.takeException(), isNull);
    });

    testWidgets('from the export sheet of the history: providers refreshed, '
        'app lock untouched', (tester) async {
      final app = await start(tester);

      await openHistoryPage(tester);
      await settle(tester, app);
      await tester.tap(find.byTooltip(Strings.export));
      await settle(tester, app);
      await tester.tap(find.text(Strings.importBackupJson));
      await settle(tester, app);

      expect(find.text(Strings.importDone), findsOneWidget);
      expectImported(tester, app);
      expect(tester.takeException(), isNull);
    });
  });
}
