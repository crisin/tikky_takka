import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/repo/repo.dart';
import 'package:tikky_takka/features/settings/settings_strings.dart';
import 'package:tikky_takka/features/settings/theme_editor_screen.dart';
import 'package:tikky_takka/features/settings/theme_list_screen.dart';
import 'package:tikky_takka/features/settings/widgets/color_picker.dart';
import 'package:tikky_takka/features/settings/widgets/setting_rows.dart';
import 'package:tikky_takka/features/settings/widgets/theme_preview.dart';
import 'package:tikky_takka/l10n/strings.dart';
import 'package:tikky_takka/theme/theme.dart';

import 'settings_harness.dart';

Finder _inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

Finder _sliderOf(String title) => find.descendant(
  of: find.widgetWithText(SliderSettingTile, title),
  matching: find.byType(Slider),
);

Finder get _hexField => find.descendant(
  of: find.byType(ColorPickerPanel),
  matching: find.byType(TextField),
);

final TikkyTheme _custom = ThemePresets.light.copyWith(
  id: 'custom-1',
  name: 'Mein Blau',
  colors: ThemePresets.light.colors.copyWith(primary: const Color(0xFF2F6FED)),
  cornerRadius: 20,
);

void main() {
  testWidgets('duplicate a preset, edit every kind of token, read it back', (
    tester,
  ) async {
    final h = await SettingsHarness.create(tester);
    await h.pump(tester, const ThemeListScreen());
    final container = h.container(tester);
    TikkyTheme theme() => container.read(customThemesProvider).single;
    TikkyTheme preview() =>
        tester.widget<ThemePreview>(find.byType(ThemePreview)).theme;

    // The three presets are listed, nothing custom yet.
    expect(find.byType(ThemeChip), findsNWidgets(3));
    expect(find.text(SettingsStrings.themeCustomEmpty), findsOneWidget);

    // Presets are read-only: tapping one offers to duplicate it.
    await tester.tap(find.text(Strings.themeLight));
    await h.settle(tester);
    expect(_inSheet(Strings.edit), findsNothing);
    expect(_inSheet(Strings.delete), findsNothing);
    await tester.tap(_inSheet(Strings.themeDuplicate));
    await h.settle(tester);

    expect(find.byType(ThemeEditorScreen), findsOneWidget);
    expect(theme().name, Strings.themeCopyName(Strings.themeLight));
    expect(ThemePresets.isPresetId(theme().id), isFalse);
    expect(theme().colors, ThemePresets.light.colors);
    expect(find.byType(SampleLane), findsNWidgets(3));

    // --- name
    await tester.tap(find.text(Strings.name));
    await h.settle(tester);
    await tester.enterText(find.byType(TextField), 'Mein Blau');
    await tester.tap(find.text(Strings.save));
    await h.settle(tester);
    expect(theme().name, 'Mein Blau');

    // --- brightness
    await tester.tap(find.text(SettingsStrings.themeDim));
    await h.settle(tester);
    expect(theme().brightness, Brightness.dark);

    // --- a colour: swatch, sliders, hex field
    await h.reveal(tester, find.text(Strings.tokenPrimary));
    await tester.tap(find.text(Strings.tokenPrimary));
    await h.settle(tester);
    expect(find.byType(ColorPickerPanel), findsOneWidget);

    final swatches = find.descendant(
      of: find.byType(ColorPickerPanel),
      matching: find.byType(ColorSwatchDot),
    );
    // Index 0 shows the current colour; quick choices follow.
    await h.reveal(tester, swatches.at(1));
    await tester.tap(swatches.at(1));
    await h.settle(tester);
    expect(theme().colors.primary, ThemePresets.light.colors.background);

    final hue = find
        .descendant(
          of: find.byType(ColorPickerPanel),
          matching: find.byType(Slider),
        )
        .first;
    await h.reveal(tester, hue);
    final beforeDrag = theme().colors.primary;
    await tester.drag(hue, const Offset(80, 0));
    await h.settle(tester);
    expect(theme().colors.primary, isNot(beforeDrag));

    await h.reveal(tester, _hexField);
    await tester.enterText(_hexField, '#FF0000');
    await h.settle(tester);
    expect(theme().colors.primary.toARGB32(), 0xFFFF0000);
    // The preview follows.
    expect(preview().colors.primary.toARGB32(), 0xFFFF0000);

    // Incomplete or wrong input changes nothing.
    await tester.enterText(_hexField, '#12');
    await h.settle(tester);
    expect(theme().colors.primary.toARGB32(), 0xFFFF0000);

    await h.reveal(tester, find.text(Strings.tokenPrimary));
    await tester.tap(find.text(Strings.tokenPrimary));
    await h.settle(tester);
    expect(find.byType(ColorPickerPanel), findsNothing);

    // --- track palette: add, recolour, move, remove, undo
    final baseLength = ThemePresets.light.trackPalette.length;
    await h.reveal(tester, find.byTooltip(SettingsStrings.paletteAdd));
    await tester.tap(find.byTooltip(SettingsStrings.paletteAdd));
    await h.settle(tester);
    expect(theme().trackPalette, hasLength(baseLength + 1));

    await h.reveal(tester, _hexField);
    await tester.enterText(_hexField, '123456');
    await h.settle(tester);
    expect(theme().trackPalette.last.toARGB32(), 0xFF123456);

    await h.reveal(tester, find.byTooltip(SettingsStrings.paletteMoveEarlier));
    await tester.tap(find.byTooltip(SettingsStrings.paletteMoveEarlier));
    await h.settle(tester);
    expect(theme().trackPalette[baseLength - 1].toARGB32(), 0xFF123456);

    await tester.tap(find.byTooltip(SettingsStrings.paletteRemove));
    await h.settle(tester);
    expect(theme().trackPalette, hasLength(baseLength));
    expect(
      theme().trackPalette.map((c) => c.toARGB32()),
      isNot(contains(0xFF123456)),
    );
    await tester.tap(find.text(Strings.undo));
    await h.settle(tester);
    expect(theme().trackPalette, hasLength(baseLength + 1));
    expect(theme().trackPalette[baseLength - 1].toARGB32(), 0xFF123456);

    // --- font and digits
    await h.reveal(tester, find.text(Strings.tokenFontFamily));
    await tester.tap(find.text(Strings.tokenFontFamily));
    await h.settle(tester);
    await tester.tap(_inSheet(Strings.fontSerif));
    await h.settle(tester);
    expect(theme().fontFamily, TikkyFonts.serif);

    await h.reveal(tester, find.text(Strings.tokenDigitMonospace));
    await tester.tap(find.text(Strings.tokenDigitMonospace));
    await h.settle(tester);
    await h.reveal(tester, find.text(Strings.tokenDigitTabular));
    await tester.tap(find.text(Strings.tokenDigitTabular));
    await h.settle(tester);
    expect(theme().digitStyle.monospace, isTrue);
    expect(theme().digitStyle.tabular, isFalse);

    await h.reveal(tester, _sliderOf(Strings.tokenDigitWeight));
    await tester.drag(
      _sliderOf(Strings.tokenDigitWeight),
      const Offset(100, 0),
    );
    await h.settle(tester);
    expect(theme().digitStyle.weight, greaterThan(400));
    expect(theme().digitStyle.weight % 100, 0);

    // --- shape
    await h.reveal(tester, _sliderOf(Strings.tokenCornerRadius));
    await tester.drag(
      _sliderOf(Strings.tokenCornerRadius),
      const Offset(100, 0),
    );
    await h.settle(tester);
    expect(theme().cornerRadius, greaterThan(ThemePresets.light.cornerRadius));

    await h.reveal(tester, _sliderOf(Strings.tokenBorderWidth));
    await tester.drag(
      _sliderOf(Strings.tokenBorderWidth),
      const Offset(100, 0),
    );
    await h.settle(tester);
    expect(theme().borderWidth, greaterThan(ThemePresets.light.borderWidth));

    expect(preview(), theme());

    // --- round trip 1: a fresh start reads exactly this theme
    final store = await h.reloadedStore(tester);
    final storedList =
        store.getJson(SettingsKeys.customThemes)!['themes']! as List<Object?>;
    final stored = TikkyTheme.fromJson(
      (storedList.single! as Map).cast<String, Object?>(),
      fallback: ThemePresets.light,
    );
    expect(stored, theme());

    // --- round trip 2: the exported file parses back to the same tokens
    final parsed = TikkyTheme.tryParseFile(
      theme().toFileContent(),
      fallbackFor: ThemePresets.forBrightness,
    );
    expect(parsed, theme());
    expect(tester.takeException(), isNull);
  });

  testWidgets('warns about low contrast and can discard all changes', (
    tester,
  ) async {
    final h = await SettingsHarness.create(tester);
    await h.seedCustomThemes(tester, [_custom]);
    await h.pump(tester, const ThemeEditorScreen(themeId: 'custom-1'));
    final container = h.container(tester);
    TikkyTheme theme() => container.read(customThemesProvider).single;

    expect(find.text('Mein Blau'), findsWidgets);
    expect(find.text(SettingsStrings.contrastTitle), findsNothing);
    // Nothing changed yet: nothing to discard.
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(
              IconButton,
              Icons.settings_backup_restore_rounded,
            ),
          )
          .onPressed,
      isNull,
    );

    await h.reveal(tester, find.text(Strings.tokenText));
    await tester.tap(find.text(Strings.tokenText));
    await h.settle(tester);
    await h.reveal(tester, _hexField);
    await tester.enterText(_hexField, '#FFFFFF');
    await h.settle(tester);

    expect(theme().colors.text.toARGB32(), 0xFFFFFFFF);
    expect(find.text(SettingsStrings.contrastTitle), findsOneWidget);
    expect(
      find.textContaining(SettingsStrings.contrastTextOnSurface),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip(SettingsStrings.themeResetChanges));
    await h.settle(tester);
    expect(theme(), _custom);
    expect(find.text(SettingsStrings.contrastTitle), findsNothing);
    expect(find.byType(ColorPickerPanel), findsNothing);

    // "Rückgängig" brings the edit back.
    await tester.tap(find.text(Strings.undo));
    await h.settle(tester);
    expect(theme().colors.text.toARGB32(), 0xFFFFFFFF);
    expect(find.text(SettingsStrings.contrastTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export and import as a JSON file', (tester) async {
    final h = await SettingsHarness.create(tester);
    await h.seedCustomThemes(tester, [_custom]);
    await h.pump(tester, const ThemeListScreen());
    final container = h.container(tester);

    await tester.tap(
      find.byTooltip(SettingsStrings.themeActionsFor('Mein Blau')),
    );
    await h.settle(tester);
    await tester.tap(_inSheet(Strings.themeExport));
    await h.settle(tester);

    final file = h.export.delivered.single;
    expect(file.fileName, 'tikky-takka_design_mein-blau.json');
    expect(file.mimeType, 'application/json');
    final content = utf8.decode(file.bytes);
    expect((jsonDecode(content) as Map)['type'], TikkyTheme.fileType);
    expect(find.text(SettingsStrings.themeExported), findsOneWidget);

    // Importing the same file adds a NEW theme and overwrites nothing.
    h.export.pickResult = content;
    await tester.tap(find.byTooltip(Strings.themeImport));
    await h.settle(tester);
    final themes = container.read(customThemesProvider);
    expect(themes, hasLength(2));
    expect(themes.first, _custom);
    expect(themes.last.id, isNot(_custom.id));
    expect(themes.last.copyWith(id: _custom.id), _custom);
    expect(find.text('Mein Blau'), findsNWidgets(2));

    // Not a theme file: the user is told, nothing is added.
    h.export.pickResult = '{"type": "something else"}';
    await tester.tap(find.byTooltip(Strings.themeImport));
    await h.settle(tester);
    expect(find.text(Strings.themeImportFailed), findsOneWidget);
    await tester.tap(find.text(Strings.ok));
    await h.settle(tester);
    expect(container.read(customThemesProvider), hasLength(2));

    // Cancelled file dialog.
    h.export.pickResult = null;
    await tester.tap(find.byTooltip(Strings.themeImport));
    await h.settle(tester);
    expect(container.read(customThemesProvider), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('presets can be exported too', (tester) async {
    final h = await SettingsHarness.create(tester);
    await h.pump(tester, const ThemeListScreen());

    await tester.tap(
      find.byTooltip(SettingsStrings.themeActionsFor(Strings.themeBlack)),
    );
    await h.settle(tester);
    await tester.tap(_inSheet(Strings.themeExport));
    await h.settle(tester);

    final parsed = TikkyTheme.tryParseFile(
      utf8.decode(h.export.delivered.single.bytes),
      fallbackFor: ThemePresets.forBrightness,
    );
    expect(parsed, ThemePresets.black);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rename, use and delete (with undo) from the list', (
    tester,
  ) async {
    final h = await SettingsHarness.create(tester);
    await h.seedCustomThemes(tester, [_custom]);
    await h.pump(tester, const ThemeListScreen());
    final container = h.container(tester);

    Future<void> action(String name, String label) async {
      await tester.tap(find.byTooltip(SettingsStrings.themeActionsFor(name)));
      await h.settle(tester);
      await tester.tap(_inSheet(label));
      await h.settle(tester);
    }

    await action('Mein Blau', Strings.rename);
    await tester.enterText(find.byType(TextField), 'Nachtblau');
    await tester.tap(find.text(Strings.save));
    await h.settle(tester);
    expect(container.read(customThemesProvider).single.name, 'Nachtblau');

    await action('Nachtblau', SettingsStrings.themeUse);
    final settings = container.read(themeSettingsProvider);
    expect(settings.followSystem, isFalse);
    expect(settings.themeId, 'custom-1');
    expect(container.read(appThemeProvider).id, 'custom-1');
    expect(find.textContaining(SettingsStrings.themeInUse), findsOneWidget);
    // Applied to the running app.
    expect(
      tester.element(find.byType(ThemeListScreen)).tikky.colors.primary,
      _custom.colors.primary,
    );

    await action('Nachtblau', Strings.delete);
    expect(container.read(customThemesProvider), isEmpty);
    // The app falls back to a preset instead of breaking.
    expect(
      ThemePresets.isPresetId(container.read(appThemeProvider).id),
      isTrue,
    );

    await tester.tap(find.text(Strings.undo));
    await h.settle(tester);
    expect(container.read(customThemesProvider).single.name, 'Nachtblau');
    expect(container.read(appThemeProvider).id, 'custom-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('"new" duplicates the theme in use and opens the editor', (
    tester,
  ) async {
    final h = await SettingsHarness.create(tester);
    await h.pump(tester, const ThemeListScreen());

    await tester.tap(find.byTooltip(Strings.themeNew));
    await h.settle(tester);
    expect(find.byType(ThemeEditorScreen), findsOneWidget);
    final copy = h.container(tester).read(customThemesProvider).single;
    expect(copy.colors, ThemePresets.light.colors);

    // Deleting from the editor returns to the list.
    await tester.tap(find.byTooltip(SettingsStrings.themeActions));
    await h.settle(tester);
    await tester.tap(_inSheet(Strings.delete));
    await h.settle(tester);
    expect(find.byType(ThemeEditorScreen), findsNothing);
    expect(h.container(tester).read(customThemesProvider), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the editor refuses presets and unknown ids', (tester) async {
    final h = await SettingsHarness.create(tester);
    await h.pump(
      tester,
      const ThemeEditorScreen(themeId: ThemePresets.lightId),
    );
    expect(find.text(SettingsStrings.themeNotFound), findsOneWidget);
    expect(find.byType(ThemePreview), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stays usable on a small phone with the keyboard open', (
    tester,
  ) async {
    final h = await SettingsHarness.create(tester);
    await h.seedCustomThemes(tester, [_custom]);
    await h.pump(
      tester,
      const ThemeEditorScreen(themeId: 'custom-1'),
      surfaceSize: const Size(320, 568),
    );

    await h.reveal(tester, find.text(Strings.tokenBackground));
    await tester.tap(find.text(Strings.tokenBackground));
    await h.settle(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await h.settle(tester);
    await h.reveal(tester, _hexField);
    await tester.enterText(_hexField, '#101010');
    await h.settle(tester);

    expect(
      h.container(tester).read(customThemesProvider).single.colors.background,
      const Color(0xFF101010),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout and Cupertino controls', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final h = await SettingsHarness.create(tester);
      await h.seedCustomThemes(tester, [_custom]);
      await h.pump(
        tester,
        const ThemeEditorScreen(themeId: 'custom-1'),
        surfaceSize: SettingsHarness.desktopSize,
      );
      expect(find.byType(PinnedPreview), findsNothing);
      expect(find.byType(SampleLane), findsNWidgets(3));

      await h.reveal(tester, find.text(Strings.tokenDanger));
      await tester.tap(find.text(Strings.tokenDanger));
      await h.settle(tester);
      final field = find.descendant(
        of: find.byType(ColorPickerPanel),
        matching: find.byType(CupertinoTextField),
      );
      await h.reveal(tester, field);
      await tester.enterText(field, '#AA0000');
      await h.settle(tester);
      expect(
        h.container(tester).read(customThemesProvider).single.colors.danger,
        const Color(0xFFAA0000),
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
