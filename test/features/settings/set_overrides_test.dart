import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/features/settings/set_overrides_screen.dart';
import 'package:tikky_takka/features/settings/settings_screen.dart';
import 'package:tikky_takka/features/settings/settings_strings.dart';
import 'package:tikky_takka/features/settings/widgets/theme_preview.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import 'settings_harness.dart';

Finder _inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

void main() {
  testWidgets('a set gets its own theme and single preferences', (
    tester,
  ) async {
    final h = await SettingsHarness.create(tester);
    final set = await h.createSet(tester, 'Festival');
    await h.pump(tester, const SettingsScreen());
    final container = h.container(tester);
    // The tracks screen keeps these alive in the real app.
    container.listen(uiPrefsForSetProvider(set.id), (_, _) {});
    container.listen(themeForSetProvider(set.id), (_, _) {});
    await h.settle(tester);

    final tile = find.byKey(ValueKey('settings.set.${set.id}'));
    await h.reveal(tester, tile);
    expect(
      find.descendant(
        of: tile,
        matching: find.text(SettingsStrings.overrideInherited),
      ),
      findsOneWidget,
    );
    await tester.tap(tile);
    await h.settle(tester);
    expect(find.byType(SetOverridesScreen), findsOneWidget);

    ThemePreview preview() =>
        tester.widget<ThemePreview>(find.byType(ThemePreview));
    expect(preview().theme.id, ThemePresets.lightId);
    expect(find.text(SettingsStrings.overrideActive), findsNothing);
    expect(find.text(SettingsStrings.overrideResetAll), findsNothing);

    // --- one preference
    await h.reveal(tester, find.text(Strings.prefShowTenths));
    await tester.tap(find.text(Strings.prefShowTenths));
    await h.settle(tester);
    expect((await h.storedSet(tester, set.id))!.uiPrefsOverride, {
      UiPrefsKeys.showTenths: true,
    });
    expect(preview().prefs.showTenths, isTrue);
    expect(find.text(SettingsStrings.overrideActive), findsOneWidget);
    // The app-wide preference is untouched ...
    expect(container.read(uiPrefsProvider).showTenths, isFalse);
    // ... and the foundation resolves the override for this set only.
    expect(container.read(uiPrefsForSetProvider(set.id)).showTenths, isTrue);
    expect(container.read(uiPrefsForSetProvider(null)).showTenths, isFalse);

    // --- a second one, then reset the first
    await h.reveal(tester, find.text(Strings.prefLayoutTiles));
    await tester.tap(find.text(Strings.prefLayoutTiles));
    await h.settle(tester);
    expect((await h.storedSet(tester, set.id))!.uiPrefsOverride, {
      UiPrefsKeys.showTenths: true,
      UiPrefsKeys.layout: LaneLayout.tiles.name,
    });

    final reset = find.byTooltip(
      SettingsStrings.overrideReset(Strings.prefShowTenths),
    );
    await h.reveal(tester, reset);
    await tester.tap(reset);
    await h.settle(tester);
    expect((await h.storedSet(tester, set.id))!.uiPrefsOverride, {
      UiPrefsKeys.layout: LaneLayout.tiles.name,
    });
    expect(preview().prefs.showTenths, isFalse);
    expect(preview().prefs.layout, LaneLayout.tiles);

    // --- own theme
    await h.reveal(tester, find.text(Strings.setOverrideTheme), up: true);
    await tester.tap(find.text(Strings.setOverrideTheme));
    await h.settle(tester);
    expect(_inSheet(Strings.useAppDefault), findsOneWidget);
    await tester.tap(_inSheet(Strings.themeBlack));
    await h.settle(tester);
    expect((await h.storedSet(tester, set.id))!.themeId, ThemePresets.blackId);
    expect(preview().theme.id, ThemePresets.blackId);
    expect(container.read(themeForSetProvider(set.id)).id, ThemePresets.blackId);
    // The app itself keeps its theme.
    expect(container.read(appThemeProvider).id, ThemePresets.lightId);

    // --- back on the settings screen the set is marked
    await tester.pageBack();
    await h.settle(tester);
    expect(
      find.descendant(
        of: tile,
        matching: find.text(SettingsStrings.overrideActive),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all overrides can be removed, with undo', (tester) async {
    final h = await SettingsHarness.create(tester);
    final set = await h.createSet(tester, 'Training');
    final customised = set.copyWith(
      themeId: () => ThemePresets.darkId,
      uiPrefsOverride: () => {
        UiPrefsKeys.density: UiDensity.roomy.name,
        UiPrefsKeys.keepScreenOn: true,
      },
    );
    await h.pump(tester, SetOverridesScreen(initialSet: customised));

    expect(find.text(SettingsStrings.overrideActive), findsNWidgets(2));
    await h.reveal(tester, find.text(SettingsStrings.overrideResetAll));
    await tester.tap(find.text(SettingsStrings.overrideResetAll));
    await h.settle(tester);

    var stored = (await h.storedSet(tester, set.id))!;
    expect(stored.themeId, isNull);
    expect(stored.uiPrefsOverride, isNull);
    expect(stored.name, 'Training');
    expect(find.text(SettingsStrings.overrideActive), findsNothing);

    await tester.tap(find.text(Strings.undo));
    await h.settle(tester);
    stored = (await h.storedSet(tester, set.id))!;
    expect(stored.themeId, ThemePresets.darkId);
    expect(stored.uiPrefsOverride, {
      UiPrefsKeys.density: UiDensity.roomy.name,
      UiPrefsKeys.keepScreenOn: true,
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('a deleted custom theme falls back to the app theme', (
    tester,
  ) async {
    final h = await SettingsHarness.create(tester);
    final set = await h.createSet(tester, 'Küche');
    await h.pump(
      tester,
      SetOverridesScreen(
        initialSet: set.copyWith(themeId: () => 'gone'),
      ),
    );
    expect(
      tester.widget<ThemePreview>(find.byType(ThemePreview)).theme.id,
      ThemePresets.lightId,
    );
    expect(find.text(SettingsStrings.overrideInherited), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
