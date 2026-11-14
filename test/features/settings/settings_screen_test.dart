import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/core/services/lock_service.dart';
import 'package:tikky_takka/features/settings/display_settings_screen.dart';
import 'package:tikky_takka/features/settings/settings_hooks.dart';
import 'package:tikky_takka/features/settings/settings_screen.dart';
import 'package:tikky_takka/features/settings/settings_strings.dart';
import 'package:tikky_takka/features/settings/theme_list_screen.dart';
import 'package:tikky_takka/features/settings/widgets/theme_preview.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import 'settings_harness.dart';

Finder _inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

class _SupportedLock implements LockService {
  _SupportedLock({this.allow = true});

  final bool allow;
  int prompts = 0;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<bool> authenticate({required String reason}) async {
    prompts++;
    return allow;
  }
}

void main() {
  group('behaviour switches', () {
    testWidgets('toggle, apply at once and persist', (tester) async {
      final h = await SettingsHarness.create(tester);
      await h.pump(tester, const SettingsScreen());
      final container = h.container(tester);

      expect(container.read(uiPrefsProvider), UiPrefs.defaults);

      await h.reveal(tester, find.text(Strings.prefHaptics));
      await tester.tap(find.text(Strings.prefHaptics));
      await h.settle(tester);
      expect(container.read(uiPrefsProvider).haptics, isFalse);

      await h.reveal(tester, find.text(Strings.prefKeepScreenOn));
      await tester.tap(find.text(Strings.prefKeepScreenOn));
      await h.settle(tester);
      expect(container.read(uiPrefsProvider).keepScreenOn, isTrue);

      await h.reveal(tester, find.text(Strings.prefUse24h));
      await tester.tap(find.text(Strings.prefUse24h));
      await h.settle(tester);
      expect(container.read(uiPrefsProvider).use24h, isFalse);

      // The widget tree sees the new preferences without a restart ...
      final tokens = tester.element(find.byType(SettingsScreen)).tikky;
      expect(tokens.prefs.haptics, isFalse);
      expect(tokens.prefs.keepScreenOn, isTrue);

      // ... and a fresh start reads them back.
      final stored = UiPrefs.fromJson(
        (await h.reloadedStore(tester)).getJson(SettingsKeys.uiPrefs)!,
      );
      expect(stored.haptics, isFalse);
      expect(stored.keepScreenOn, isTrue);
      expect(stored.use24h, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CSV separator is a segmented choice', (tester) async {
      final h = await SettingsHarness.create(tester);
      await h.pump(tester, const SettingsScreen());

      await h.reveal(tester, find.text(Strings.csvComma));
      await tester.tap(find.text(Strings.csvComma));
      await h.settle(tester);
      expect(
        h.container(tester).read(uiPrefsProvider).csvSeparator,
        CsvSeparator.comma,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('lane display settings', () {
    testWidgets('every lane preference has a control with a live preview', (
      tester,
    ) async {
      final h = await SettingsHarness.create(tester);
      await h.pump(tester, const DisplaySettingsScreen());
      final container = h.container(tester);
      UiPrefs prefs() => container.read(uiPrefsProvider);
      UiPrefs previewPrefs() =>
          tester.widget<ThemePreview>(find.byType(ThemePreview)).prefs;

      // Sample lanes in three states.
      expect(find.byType(SampleLane), findsNWidgets(3));
      expect(find.text('1:23:45'), findsOneWidget);

      await h.reveal(tester, find.text(Strings.prefShowTenths));
      await tester.tap(find.text(Strings.prefShowTenths));
      await h.settle(tester);
      expect(prefs().showTenths, isTrue);
      expect(find.text('1:23:45.6'), findsOneWidget);

      await h.reveal(tester, find.text(Strings.prefShowSubLine));
      expect(find.text(SettingsStrings.sampleStopwatchSub), findsOneWidget);
      await tester.tap(find.text(Strings.prefShowSubLine));
      await h.settle(tester);
      expect(prefs().showSubLine, isFalse);
      expect(find.text(SettingsStrings.sampleStopwatchSub), findsNothing);

      await h.reveal(tester, find.text(Strings.prefShowProgress));
      await tester.tap(find.text(Strings.prefShowProgress));
      await h.settle(tester);
      expect(prefs().showProgressBar, isFalse);

      await h.reveal(tester, find.text(Strings.prefLeftHanded));
      await tester.tap(find.text(Strings.prefLeftHanded));
      await h.settle(tester);
      expect(prefs().leftHanded, isTrue);

      await h.reveal(tester, find.text(Strings.prefDensityRoomy));
      await tester.tap(find.text(Strings.prefDensityRoomy));
      await h.settle(tester);
      expect(prefs().density, UiDensity.roomy);

      await h.reveal(tester, find.text(Strings.prefLayoutTiles));
      await tester.tap(find.text(Strings.prefLayoutTiles));
      await h.settle(tester);
      expect(prefs().layout, LaneLayout.tiles);
      expect(previewPrefs(), prefs());

      final digitSlider = find.descendant(
        of: find.byKey(const ValueKey('pref.${UiPrefsKeys.digitScale}')),
        matching: find.byType(Slider),
      );
      await h.reveal(tester, digitSlider);
      await tester.drag(digitSlider, const Offset(120, 0));
      await h.settle(tester);
      expect(prefs().digitScale, greaterThan(1));

      final buttonSlider = find.descendant(
        of: find.byKey(const ValueKey('pref.${UiPrefsKeys.buttonScale}')),
        matching: find.byType(Slider),
      );
      await h.reveal(tester, buttonSlider);
      await tester.drag(buttonSlider, const Offset(-120, 0));
      await h.settle(tester);
      expect(prefs().buttonScale, lessThan(1));
      // Stored in tidy 5 % steps.
      expect((prefs().buttonScale * 100).round() % 5, 0);

      expect(previewPrefs(), prefs());
      final stored = UiPrefs.fromJson(
        (await h.reloadedStore(tester)).getJson(SettingsKeys.uiPrefs)!,
      );
      expect(stored, prefs());
      expect(tester.takeException(), isNull);
    });

    testWidgets('the preview sits beside the list on wide layouts', (
      tester,
    ) async {
      final h = await SettingsHarness.create(tester);
      await h.pump(
        tester,
        const DisplaySettingsScreen(),
        surfaceSize: SettingsHarness.desktopSize,
      );
      expect(find.byType(PinnedPreview), findsNothing);
      expect(find.byType(ThemePreview), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('appearance', () {
    testWidgets('theme mode: system, presets and back', (tester) async {
      final h = await SettingsHarness.create(tester);
      await h.pump(tester, const SettingsScreen());
      final container = h.container(tester);

      // System mode by default: the light / dark pair is offered.
      expect(container.read(themeSettingsProvider).followSystem, isTrue);
      expect(find.text(Strings.themeLightForSystem), findsOneWidget);
      expect(find.text(Strings.themeDarkForSystem), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('settings.themeMode')));
      await h.settle(tester);
      expect(_inSheet(Strings.themeSystem), findsOneWidget);
      for (final preset in ThemePresets.all) {
        expect(_inSheet(preset.name), findsOneWidget);
      }
      await tester.tap(_inSheet(Strings.themeBlack));
      await h.settle(tester);

      final settings = container.read(themeSettingsProvider);
      expect(settings.followSystem, isFalse);
      expect(settings.themeId, ThemePresets.blackId);
      expect(find.text(Strings.themeLightForSystem), findsNothing);
      // Applied at once.
      expect(
        Theme.of(
          tester.element(find.byType(SettingsScreen)),
        ).scaffoldBackgroundColor,
        ThemePresets.black.colors.background,
      );

      await tester.tap(find.byKey(const ValueKey('settings.themeMode')));
      await h.settle(tester);
      await tester.tap(_inSheet(Strings.themeSystem));
      await h.settle(tester);
      expect(container.read(themeSettingsProvider).followSystem, isTrue);
      // The fixed choice is remembered for later.
      expect(container.read(themeSettingsProvider).themeId, ThemePresets.blackId);
      expect(tester.takeException(), isNull);
    });

    testWidgets('system mode: the dark theme can be changed', (tester) async {
      final h = await SettingsHarness.create(tester);
      await h.pump(tester, const SettingsScreen());

      await tester.tap(find.byKey(const ValueKey('settings.darkTheme')));
      await h.settle(tester);
      await tester.tap(_inSheet(Strings.themeBlack));
      await h.settle(tester);

      final settings = h.container(tester).read(themeSettingsProvider);
      expect(settings.followSystem, isTrue);
      expect(settings.darkThemeId, ThemePresets.blackId);
      expect(settings.lightThemeId, ThemePresets.lightId);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dynamic colour is offered only where available', (
      tester,
    ) async {
      final without = await SettingsHarness.create(tester);
      await without.pump(tester, const SettingsScreen());
      expect(find.text(Strings.dynamicColor), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      final h = await SettingsHarness.create(
        tester,
        dynamicPalette: const DynamicPalette(
          lightPrimary: Color(0xFF006A60),
          lightOnPrimary: Color(0xFFFFFFFF),
          darkPrimary: Color(0xFF53DBC9),
          darkOnPrimary: Color(0xFF003731),
        ),
      );
      await h.pump(tester, const SettingsScreen());
      expect(find.text(Strings.dynamicColor), findsOneWidget);

      await tester.tap(find.text(Strings.dynamicColor));
      await h.settle(tester);
      expect(
        h.container(tester).read(themeSettingsProvider).useDynamicColor,
        isTrue,
      );
      expect(
        tester.element(find.byType(SettingsScreen)).tikky.colors.primary,
        const Color(0xFF006A60),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens the theme list', (tester) async {
      final h = await SettingsHarness.create(tester);
      await h.pump(tester, const SettingsScreen());

      await tester.tap(find.byKey(const ValueKey('settings.themes')));
      await h.settle(tester);
      expect(find.byType(ThemeListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('hooks and fallbacks', () {
    testWidgets('wired hooks are called', (tester) async {
      final calls = <String>[];
      final h = await SettingsHarness.create(
        tester,
        extraOverrides: [
          settingsHooksProvider.overrideWithValue(
            SettingsHooks(
              openExport: (context, ref) async => calls.add('export'),
              openImport: (context, ref) async => calls.add('import'),
              openPersons: (context, ref) async => calls.add('persons'),
              openSubstances: (context, ref) async => calls.add('substances'),
              privacyTiles: (context) => const [
                ListTile(title: Text('lock tile from the privacy feature')),
              ],
              appVersion: '9.9.9',
            ),
          ),
        ],
      );
      await h.pump(tester, const SettingsScreen());

      for (final key in ['export', 'import', 'persons', 'substances']) {
        final tile = find.byKey(ValueKey('settings.$key'));
        await h.reveal(tester, tile);
        await tester.tap(tile);
        await h.settle(tester);
      }
      expect(calls, ['export', 'import', 'persons', 'substances']);
      expect(h.export.delivered, isEmpty);

      await h.reveal(tester, find.text('lock tile from the privacy feature'));
      expect(find.text(Strings.appLock), findsNothing);
      await h.reveal(tester, find.text('9.9.9'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('unwired export builds through the export service', (
      tester,
    ) async {
      final h = await SettingsHarness.create(tester);
      await h.pump(tester, const SettingsScreen());
      await tester.runAsync(
        () => h
            .container(tester)
            .read(uiPrefsProvider.notifier)
            .change((p) => p.copyWith(csvSeparator: CsvSeparator.comma)),
      );
      await h.settle(tester);

      final tile = find.byKey(const ValueKey('settings.export'));
      await h.reveal(tester, tile);
      await tester.tap(tile);
      await h.settle(tester);
      await tester.tap(_inSheet(Strings.exportSessionsCsv));
      await h.settle(tester);

      expect(h.export.delivered.single.fileName, 'sessions.csv');
      // Protocol tracks stay out unless the export sheet opts in.
      expect(h.export.lastOptions!.includeProtocol, isFalse);
      expect(h.export.lastOptions!.separator, CsvSeparator.comma);
      expect(find.text(Strings.exportDone), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unwired import merges the picked backup', (tester) async {
      final h = await SettingsHarness.create(tester);
      await h.pump(tester, const SettingsScreen());
      final tile = find.byKey(const ValueKey('settings.import'));
      await h.reveal(tester, tile);

      // Cancelled dialog: nothing happens.
      await tester.tap(tile);
      await h.settle(tester);
      expect(h.export.imported, isEmpty);

      // Not a backup: the user is told, nothing is imported.
      h.export.pickResult = 'hello';
      await tester.tap(tile);
      await h.settle(tester);
      expect(find.text(Strings.importInvalidFile), findsOneWidget);
      await tester.tap(find.text(Strings.ok));
      await h.settle(tester);
      expect(h.export.imported, isEmpty);

      h.export.pickResult = '{"schemaVersion": 1}';
      await tester.tap(tile);
      await h.settle(tester);
      expect(h.export.imported, hasLength(1));
      expect(find.textContaining(Strings.importDone), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('persons and substances say so while unwired', (tester) async {
      final h = await SettingsHarness.create(tester);
      await h.pump(tester, const SettingsScreen());
      final tile = find.byKey(const ValueKey('settings.persons'));
      await h.reveal(tester, tile);
      await tester.tap(tile);
      await h.settle(tester);
      expect(find.text(Strings.comingSoon), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fallback app lock: disabled where unsupported', (
      tester,
    ) async {
      final h = await SettingsHarness.create(tester);
      await h.pump(tester, const SettingsScreen());
      await h.reveal(tester, find.text(Strings.appLock));
      expect(find.text(Strings.appLockUnavailable), findsOneWidget);

      await tester.tap(find.text(Strings.appLock));
      await h.settle(tester);
      expect(h.container(tester).read(appLockEnabledProvider), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fallback app lock: asks for authentication before locking', (
      tester,
    ) async {
      final denied = _SupportedLock(allow: false);
      final h = await SettingsHarness.create(tester, lockService: denied);
      await h.pump(tester, const SettingsScreen());
      await h.reveal(tester, find.text(Strings.appLock));
      expect(find.text(Strings.appLockHint), findsOneWidget);

      await tester.tap(find.text(Strings.appLock));
      await h.settle(tester);
      expect(denied.prompts, 1);
      expect(h.container(tester).read(appLockEnabledProvider), isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      final allowed = _SupportedLock();
      final h2 = await SettingsHarness.create(tester, lockService: allowed);
      await h2.pump(tester, const SettingsScreen());
      await h2.reveal(tester, find.text(Strings.appLock));
      await tester.tap(find.text(Strings.appLock));
      await h2.settle(tester);
      expect(allowed.prompts, 1);
      expect(h2.container(tester).read(appLockEnabledProvider), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('notification permissions are shown', (tester) async {
      final h = await SettingsHarness.create(tester);
      await h.pump(tester, const SettingsScreen());
      await h.reveal(tester, find.text(Strings.exactAlarmsPermission));
      expect(find.text(Strings.notificationsPermission), findsOneWidget);
      expect(find.text(Strings.permissionGranted), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('renders with Cupertino controls on Apple platforms', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final h = await SettingsHarness.create(tester);
      await h.pump(tester, const SettingsScreen());
      expect(find.byType(CupertinoNavigationBar), findsOneWidget);

      await h.reveal(tester, find.text(Strings.prefHaptics));
      await tester.tap(find.text(Strings.prefHaptics));
      await h.settle(tester);
      expect(h.container(tester).read(uiPrefsProvider).haptics, isFalse);

      // The theme choice is a native action sheet.
      await h.reveal(
        tester,
        find.byKey(const ValueKey('settings.themeMode')),
        up: true,
      );
      await tester.tap(find.byKey(const ValueKey('settings.themeMode')));
      await h.settle(tester);
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(CupertinoActionSheet),
          matching: find.text(Strings.themeDark),
        ),
      );
      await h.settle(tester);
      expect(
        h.container(tester).read(themeSettingsProvider).themeId,
        ThemePresets.darkId,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
