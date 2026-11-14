import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tikky_takka/core/domain/domain.dart';
import 'package:tikky_takka/theme/theme.dart';

void main() {
  group('TikkyTheme JSON', () {
    test('every preset survives a JSON round trip', () {
      for (final preset in ThemePresets.all) {
        final json = jsonMap(jsonDecode(jsonEncode(preset.toJson())));
        // A deliberately different fallback proves every token is read.
        final fallback = preset.isDark ? ThemePresets.light : ThemePresets.dark;
        final decoded = TikkyTheme.fromJson(json, fallback: fallback);
        expect(decoded, preset, reason: preset.id);
        expect(decoded.hashCode, preset.hashCode);
      }
    });

    test('a fully customised theme survives a round trip', () {
      final custom = ThemePresets.dark.copyWith(
        id: 'custom-1',
        name: 'Neon',
        brightness: Brightness.light,
        colors: ThemePresets.dark.colors.copyWith(
          background: const Color(0x80112233),
          primary: const Color(0xFFFF00AA),
          warning: const Color(0xFF010203),
        ),
        trackPalette: const [Color(0xFF111111), Color(0x22222222)],
        fontFamily: TikkyFonts.mono,
        digitStyle: const DigitStyle(tabular: false, monospace: true, weight: 700),
        cornerRadius: 3.5,
        borderWidth: 2,
      );
      final decoded = TikkyTheme.fromJson(
        jsonMap(jsonDecode(jsonEncode(custom.toJson()))),
        fallback: ThemePresets.light,
      );
      expect(decoded, custom);
      expect(decoded.colors.background.toARGB32(), 0x80112233);
      expect(decoded.trackPalette.last.toARGB32(), 0x22222222);
      expect(decoded.digitStyle.weight, 700);
    });

    test('missing or malformed tokens fall back instead of throwing', () {
      final decoded = TikkyTheme.fromJson({
        'id': 'x',
        'colors': {'primary': '#12AB34', 'text': 'not a colour', 'border': 5.5},
        'trackPalette': 'nope',
        'fontFamily': 'Comic Sans',
        'digitStyle': {'weight': 1234},
        'cornerRadius': 999,
        'borderWidth': -3,
      }, fallback: ThemePresets.dark);
      expect(decoded.id, 'x');
      expect(decoded.name, ThemePresets.dark.name);
      expect(decoded.brightness, Brightness.dark);
      // #RRGGBB is read as opaque.
      expect(decoded.colors.primary.toARGB32(), 0xFF12AB34);
      expect(decoded.colors.text, ThemePresets.dark.colors.text);
      expect(decoded.colors.border, ThemePresets.dark.colors.border);
      expect(decoded.trackPalette, ThemePresets.dark.trackPalette);
      expect(decoded.fontFamily, TikkyFonts.system);
      expect(decoded.digitStyle.weight, 900);
      expect(decoded.cornerRadius, 40);
      expect(decoded.borderWidth, 0);
    });

    test('theme files: export, parse, reject foreign content', () {
      final file = ThemePresets.black.toFileContent();
      final parsed = TikkyTheme.tryParseFile(
        file,
        fallbackFor: ThemePresets.forBrightness,
      );
      expect(parsed, ThemePresets.black);

      TikkyTheme? parse(String s) =>
          TikkyTheme.tryParseFile(s, fallbackFor: ThemePresets.forBrightness);
      expect(parse('not json'), isNull);
      expect(parse('[1,2]'), isNull);
      expect(parse('{"type":"something_else","version":1}'), isNull);
      expect(parse('{"type":"tikky_theme","version":99}'), isNull);
      expect(parse('{"type":"tikky_theme","version":1}'), isNotNull);
    });

    test('track colours wrap around and honour custom colours', () {
      final theme = ThemePresets.light;
      final n = theme.trackPalette.length;
      expect(theme.paletteColor(0), theme.trackPalette.first);
      expect(theme.paletteColor(n), theme.trackPalette.first);
      expect(theme.paletteColor(n + 2), theme.trackPalette[2]);
      expect(theme.paletteColor(-1), theme.trackPalette.last);
      const base = Track(
        id: 't',
        setId: 's',
        name: 'n',
        config: StopwatchConfig(),
        colorIndex: 1,
      );
      expect(theme.trackColor(base), theme.trackPalette[1]);
      expect(
        theme.trackColor(base.copyWith(customColor: () => 0xFF123456)),
        const Color(0xFF123456),
      );
    });

    test('presets', () {
      expect(ThemePresets.all.map((t) => t.name), ['Hell', 'Dunkel', 'Schwarz']);
      expect(ThemePresets.all.map((t) => t.id).toSet().length, 3);
      expect(ThemePresets.light.brightness, Brightness.light);
      expect(ThemePresets.dark.brightness, Brightness.dark);
      expect(ThemePresets.black.colors.background, const Color(0xFF000000));
      expect(ThemePresets.isPresetId(ThemePresets.blackId), isTrue);
      expect(ThemePresets.isPresetId('custom'), isFalse);
      expect(ThemePresets.byId(ThemePresets.darkId), ThemePresets.dark);
      expect(ThemePresets.byId('nope'), isNull);
    });
  });

  group('UiPrefs JSON', () {
    test('defaults', () {
      const p = UiPrefs.defaults;
      expect(p.layout, LaneLayout.rows);
      expect(p.density, UiDensity.normal);
      expect(p.showTenths, isFalse);
      expect(p.showProgressBar, isTrue);
      expect(p.haptics, isTrue);
      expect(p.use24h, isTrue);
      expect(p.csvSeparator, CsvSeparator.semicolon);
      expect(p.csvSeparator.char, ';');
    });

    test('round trip of non-default values', () {
      const prefs = UiPrefs(
        layout: LaneLayout.tiles,
        density: UiDensity.roomy,
        digitScale: 1.3,
        buttonScale: 0.9,
        showTenths: true,
        showProgressBar: false,
        showSubLine: false,
        leftHanded: true,
        haptics: false,
        keepScreenOn: true,
        use24h: false,
        csvSeparator: CsvSeparator.comma,
      );
      final decoded = UiPrefs.fromJson(
        jsonMap(jsonDecode(jsonEncode(prefs.toJson()))),
      );
      expect(decoded, prefs);
      expect(decoded.hashCode, prefs.hashCode);
      expect(prefs.toJson().keys.toSet(), UiPrefsKeys.all.toSet());
    });

    test('lenient decoding and clamping', () {
      final decoded = UiPrefs.fromJson({
        'layout': 'spiral',
        'density': 7,
        'digitScale': 50,
        'buttonScale': 0.01,
        'showTenths': 'true',
      });
      expect(decoded.layout, LaneLayout.rows);
      expect(decoded.density, UiDensity.normal);
      expect(decoded.digitScale, UiPrefs.maxDigitScale);
      expect(decoded.buttonScale, UiPrefs.minButtonScale);
      expect(decoded.showTenths, isTrue);
      expect(UiPrefs.fromJson(const {}), UiPrefs.defaults);
    });

    test('partial overrides', () {
      const base = UiPrefs(leftHanded: true, digitScale: 1.2);
      final overridden = base.applyOverride({
        UiPrefsKeys.layout: 'tiles',
        UiPrefsKeys.showTenths: true,
        'unknown': 1,
      });
      expect(overridden.layout, LaneLayout.tiles);
      expect(overridden.showTenths, isTrue);
      // Everything else is inherited.
      expect(overridden.leftHanded, isTrue);
      expect(overridden.digitScale, 1.2);
      expect(base.applyOverride(null), same(base));
      expect(base.applyOverride(const {}), same(base));

      expect(overridden.overrideAgainst(base), {
        UiPrefsKeys.layout: 'tiles',
        UiPrefsKeys.showTenths: true,
      });
      expect(base.overrideAgainst(base), isNull);
      expect(base.applyOverride(overridden.overrideAgainst(base)), overridden);
    });
  });

  group('ThemeSettings and resolution', () {
    final custom = ThemePresets.dark.copyWith(id: 'custom', name: 'Custom');
    final themes = [...ThemePresets.all, custom];

    test('round trip', () {
      const settings = ThemeSettings(
        followSystem: false,
        themeId: 'custom',
        lightThemeId: 'a',
        darkThemeId: 'b',
        useDynamicColor: true,
      );
      expect(
        ThemeSettings.fromJson(
          jsonMap(jsonDecode(jsonEncode(settings.toJson()))),
        ),
        settings,
      );
      expect(ThemeSettings.fromJson(const {}), ThemeSettings.defaults);
      expect(ThemeSettings.defaults.followSystem, isTrue);
    });

    test('system mode follows the OS brightness', () {
      const settings = ThemeSettings(darkThemeId: ThemePresets.blackId);
      expect(
        resolveAppTheme(
          settings: settings,
          themes: themes,
          platformBrightness: Brightness.light,
        ),
        ThemePresets.light,
      );
      expect(
        resolveAppTheme(
          settings: settings,
          themes: themes,
          platformBrightness: Brightness.dark,
        ),
        ThemePresets.black,
      );
    });

    test('fixed theme ignores the OS; deleted themes fall back', () {
      expect(
        resolveAppTheme(
          settings: const ThemeSettings(followSystem: false, themeId: 'custom'),
          themes: themes,
          platformBrightness: Brightness.light,
        ),
        custom,
      );
      expect(
        resolveAppTheme(
          settings: const ThemeSettings(followSystem: false, themeId: 'gone'),
          themes: themes,
          platformBrightness: Brightness.dark,
        ),
        ThemePresets.light,
      );
      expect(
        resolveAppTheme(
          settings: const ThemeSettings(darkThemeId: 'gone'),
          themes: themes,
          platformBrightness: Brightness.dark,
        ),
        ThemePresets.dark,
      );
    });

    test('dynamic colour replaces the accent only when enabled', () {
      const palette = DynamicPalette(
        lightPrimary: Color(0xFF0000AA),
        lightOnPrimary: Color(0xFFFFFFFF),
        darkPrimary: Color(0xFFAAAAFF),
        darkOnPrimary: Color(0xFF000033),
      );
      final off = resolveAppTheme(
        settings: const ThemeSettings(),
        themes: themes,
        platformBrightness: Brightness.dark,
        dynamicPalette: palette,
      );
      expect(off, ThemePresets.dark);
      final on = resolveAppTheme(
        settings: const ThemeSettings(useDynamicColor: true),
        themes: themes,
        platformBrightness: Brightness.dark,
        dynamicPalette: palette,
      );
      expect(on.colors.primary, palette.darkPrimary);
      expect(on.colors.onPrimary, palette.darkOnPrimary);
      expect(on.colors.background, ThemePresets.dark.colors.background);
      final light = applyDynamicPalette(ThemePresets.light, palette);
      expect(light.colors.primary, palette.lightPrimary);
    });

    test('per-set overrides', () {
      const plain = TrackSet(id: 's1', name: 'Plain');
      const themed = TrackSet(
        id: 's2',
        name: 'Festival',
        themeId: ThemePresets.blackId,
        uiPrefsOverride: {'layout': 'tiles', 'keepScreenOn': true},
      );
      const stale = TrackSet(id: 's3', name: 'Stale', themeId: 'gone');
      TikkyTheme themeOf(TrackSet? set) => resolveSetTheme(
        set: set,
        themes: themes,
        appTheme: ThemePresets.light,
      );
      expect(themeOf(null), ThemePresets.light);
      expect(themeOf(plain), ThemePresets.light);
      expect(themeOf(themed), ThemePresets.black);
      expect(themeOf(stale), ThemePresets.light);

      const app = UiPrefs(haptics: false);
      expect(resolveSetPrefs(set: plain, appPrefs: app), app);
      final prefs = resolveSetPrefs(set: themed, appPrefs: app);
      expect(prefs.layout, LaneLayout.tiles);
      expect(prefs.keepScreenOn, isTrue);
      expect(prefs.haptics, isFalse);
    });
  });

  group('derived Flutter themes', () {
    test('Material 3 theme carries tokens, colours and a Cupertino theme', () {
      for (final preset in ThemePresets.all) {
        final data = buildMaterialTheme(
          preset,
          UiPrefs.defaults,
          platform: TargetPlatform.android,
        );
        expect(data.useMaterial3, isTrue);
        expect(data.brightness, preset.brightness);
        expect(data.scaffoldBackgroundColor, preset.colors.background);
        expect(data.colorScheme.primary, preset.colors.primary);
        expect(data.colorScheme.onPrimary, preset.colors.onPrimary);
        expect(data.colorScheme.surface, preset.colors.surface);
        expect(data.colorScheme.error, preset.colors.danger);
        final tokens = data.extension<TikkyTokens>()!;
        expect(tokens.theme, preset);
        expect(tokens.colors.textMuted, preset.colors.textMuted);
        expect(data.cupertinoOverrideTheme!.brightness, preset.brightness);
        expect(data.cupertinoOverrideTheme!.primaryColor, preset.colors.primary);
      }
    });

    test('Cupertino theme', () {
      final cupertino = buildCupertinoTheme(
        ThemePresets.dark,
        UiPrefs.defaults,
        platform: TargetPlatform.iOS,
      );
      expect(cupertino.brightness, Brightness.dark);
      expect(
        cupertino.scaffoldBackgroundColor,
        ThemePresets.dark.colors.background,
      );
      expect(cupertino.barBackgroundColor, ThemePresets.dark.colors.surface);
    });

    test('tokens react to UI preferences and digit style', () {
      final normal = TikkyTokens(
        theme: ThemePresets.light,
        prefs: UiPrefs.defaults,
        platform: TargetPlatform.android,
      );
      final big = TikkyTokens(
        theme: ThemePresets.light.copyWith(
          digitStyle: const DigitStyle(monospace: true, weight: 600),
          fontFamily: TikkyFonts.serif,
          cornerRadius: 20,
        ),
        prefs: const UiPrefs(
          density: UiDensity.roomy,
          digitScale: 1.5,
          buttonScale: 1.5,
        ),
        platform: TargetPlatform.android,
      );
      expect(big.sizes.digitsLarge, normal.sizes.digitsLarge * 1.5);
      expect(big.sizes.primaryButton, normal.sizes.primaryButton * 1.5);
      expect(big.space.md, greaterThan(normal.space.md));
      expect(big.sizes.laneMinHeight, greaterThan(normal.sizes.laneMinHeight));
      expect(big.radii.md, 20);

      expect(normal.text.digitsLarge.fontFeatures, const [
        FontFeature.tabularFigures(),
      ]);
      expect(normal.text.digitsLarge.fontWeight, FontWeight.w400);
      expect(normal.text.digitsLarge.fontFamily, isNull);
      expect(big.text.digitsLarge.fontFamily, 'monospace');
      expect(big.text.digitsLarge.fontWeight, FontWeight.w600);
      expect(big.text.body.fontFamily, 'serif');
      expect(normal.text.laneTitle.color, ThemePresets.light.colors.textMuted);

      final ios = TikkyTokens(
        theme: ThemePresets.light.copyWith(fontFamily: TikkyFonts.mono),
        prefs: UiPrefs.defaults,
        platform: TargetPlatform.iOS,
      );
      expect(ios.text.body.fontFamily, 'Menlo');

      expect(normal, normal.copyWith());
      expect(normal.lerp(big, 0.4), same(normal));
      expect(normal.lerp(big, 0.6), same(big));
      expect(normal.hairline.width, ThemePresets.light.borderWidth);
      expect(normal.onColor(const Color(0xFFFFFFFF)), const Color(0xFF000000));
      expect(normal.onColor(const Color(0xFF000000)), const Color(0xFFFFFFFF));
    });

    testWidgets('context.tikky reads the tokens of the surrounding theme', (
      tester,
    ) async {
      late TikkyTokens found;
      late TikkyTokens fallback;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMaterialTheme(ThemePresets.black, UiPrefs.defaults),
          home: Builder(
            builder: (context) {
              found = context.tikky;
              return Theme(
                data: ThemeData(),
                child: Builder(
                  builder: (context) {
                    fallback = context.tikky;
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );
      expect(found.theme, ThemePresets.black);
      expect(fallback, TikkyTokens.fallback);
    });
  });
}
