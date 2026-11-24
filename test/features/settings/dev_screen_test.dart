import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/repo/settings_store.dart';
import 'package:tikky_takka/core/services/dev/app_reset.dart';
import 'package:tikky_takka/core/services/dev/dev_tools.dart';
import 'package:tikky_takka/core/services/dev/frame_stats.dart';
import 'package:tikky_takka/features/settings/dev_screen.dart';
import 'package:tikky_takka/features/settings/settings_strings.dart';

import 'settings_harness.dart';

class FakeDevTools implements DevTools {
  FakeDevTools({this.isWeb = true, this.online = true});

  @override
  final bool isWeb;
  @override
  bool online;

  final List<String> log = [];

  @override
  Future<PwaStatus?> pwaStatus() async => !isWeb
      ? null
      : const PwaStatus(
          workerSupported: true,
          workerState: 'activated',
          controlled: true,
          installed: false,
          online: true,
          persisted: false,
          usageBytes: 5 * 1024 * 1024,
          quotaBytes: 2 * 1024 * 1024 * 1024,
          caches: [
            CacheInfo(
              name: 'tikky-abc123',
              entries: [
                CacheEntryInfo(path: 'main.dart.js', bytes: 3 * 1024 * 1024),
                CacheEntryInfo(path: './', bytes: 2048),
              ],
            ),
            CacheInfo(name: 'tikky-canvaskit-ffff', entries: []),
          ],
        );

  @override
  Future<bool> checkForUpdate() async {
    log.add('update');
    return false;
  }

  @override
  Future<void> clearOfflineCache() async => log.add('clearCache');

  @override
  Future<void> clearPageStorage() async => log.add('clearStorage');

  @override
  void reload() => log.add('reload');

  @override
  int? memoryBytes() => 64 * 1024 * 1024;

  @override
  Future<int?> databaseBytes() async => null;

  @override
  double? pageClockMs() => null;
}

void main() {
  group('FrameStats', () {
    test('summarises the newest frames up to its capacity', () {
      final stats = FrameStats(capacity: 3);
      expect(stats.summary().frames, 0);
      stats
        ..add(const Duration(milliseconds: 90), Duration.zero)
        ..add(const Duration(milliseconds: 2), const Duration(milliseconds: 4))
        ..add(const Duration(milliseconds: 4), const Duration(milliseconds: 6))
        ..add(
          const Duration(milliseconds: 6),
          const Duration(milliseconds: 20),
        );
      final s = stats.summary(budgetMs: 16);
      expect(s.frames, 3);
      expect(s.avgBuildMs, 4);
      expect(s.avgRasterMs, 10);
      expect(s.worstMs, 26);
      expect(s.slow, 1);
      stats.clear();
      expect(stats.summary().frames, 0);
    });
  });

  test('DevFormat uses the German decimal comma', () {
    expect(DevFormat.bytes(812), '812 B');
    expect(DevFormat.bytes(14 * 1024), '14 KB');
    expect(DevFormat.bytes(3355443), '3,2 MB');
    expect(DevFormat.ms(4.24), '4,2 ms');
    expect(DevFormat.ms(1234), '1234 ms');
  });

  test('PwaStatus reads the build version from the app cache', () async {
    final status = await FakeDevTools().pwaStatus();
    expect(status!.cachedVersion, 'abc123');
  });

  group('developer screen', () {
    Future<(SettingsHarness, FakeDevTools)> open(
      WidgetTester tester, {
      FakeDevTools? tools,
    }) async {
      final fake = tools ?? FakeDevTools();
      final h = await SettingsHarness.create(
        tester,
        extraOverrides: [
          devToolsProvider.overrideWithValue(fake),
          frameStatsProvider.overrideWithValue(FrameStats()),
        ],
      );
      await h.createSet(tester, 'Abend');
      await h.pump(tester, const DevScreen());
      return (h, fake);
    }

    testWidgets('shows the caches and their files', (tester) async {
      final (h, _) = await open(tester);
      expect(find.text(SettingsStrings.devWorkerActive), findsOneWidget);
      expect(find.text('abc123'), findsOneWidget);

      final cache = find.byKey(DevKeys.cache('tikky-abc123'));
      await h.reveal(tester, cache);
      expect(find.text('2 Dateien · 3,0 MB'), findsOneWidget);
      await tester.tap(cache);
      await h.settle(tester);
      expect(find.text('main.dart.js'), findsOneWidget);
      expect(find.text('3,0 MB'), findsOneWidget);
    });

    testWidgets('reloads the offline cache only with a network', (
      tester,
    ) async {
      final (h, tools) = await open(tester);
      tools.online = false;
      await h.reveal(tester, find.byKey(DevKeys.clearCache));
      await tester.tap(find.byKey(DevKeys.clearCache));
      await h.settle(tester);
      expect(tools.log, isEmpty);
      expect(find.text(SettingsStrings.devNeedsNetwork), findsOneWidget);

      tools.online = true;
      await tester.tap(find.byKey(DevKeys.clearCache));
      await h.settle(tester);
      expect(tools.log, ['clearCache', 'reload']);
    });

    testWidgets('reset asks first, then wipes and reloads', (tester) async {
      final (h, tools) = await open(tester);
      await tester.runAsync(
        () => h.settings.setString(SettingsKeys.seedDone, 'true'),
      );
      final reset = h.container(tester).read(appResetProvider);

      await h.reveal(tester, find.byKey(DevKeys.reset));
      await tester.tap(find.byKey(DevKeys.reset));
      await h.settle(tester);
      expect(find.text(SettingsStrings.devResetTitle), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await h.settle(tester);
      expect((await tester.runAsync(reset.counts))!.sets, 1);
      expect(tools.log, isEmpty);

      await tester.tap(find.byKey(DevKeys.reset));
      await h.settle(tester);
      await tester.tap(find.text(SettingsStrings.devResetConfirm));
      await h.settle(tester);

      final counts = (await tester.runAsync(reset.counts))!;
      expect(counts.sets, 0);
      expect(counts.settings, 0);
      expect(h.settings.contains(SettingsKeys.seedDone), isFalse);
      expect(h.alarms.log, contains('cancelAll'));
      expect(tools.log, ['clearStorage', 'clearCache', 'reload']);
    });

    testWidgets('off the web: no PWA section, reset seeds again', (
      tester,
    ) async {
      final (h, tools) = await open(tester, tools: FakeDevTools(isWeb: false));
      expect(find.text(SettingsStrings.devPwa), findsNothing);

      await h.reveal(tester, find.byKey(DevKeys.reset));
      await tester.tap(find.byKey(DevKeys.reset));
      await h.settle(tester);
      await tester.tap(find.text(SettingsStrings.devResetConfirm));
      await h.settle(tester);

      expect(tools.log, isNot(contains('reload')));
      expect(find.text(SettingsStrings.devResetDone), findsOneWidget);
      final reset = h.container(tester).read(appResetProvider);
      // The first-launch set is back.
      expect((await tester.runAsync(reset.counts))!.sets, 1);
      expect(h.settings.getBool(SettingsKeys.seedDone), isTrue);
    });
  });
}
