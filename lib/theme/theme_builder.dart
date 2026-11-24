import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tikky_theme.dart';
import 'tokens.dart';
import 'ui_prefs.dart';

/// Derives the Material 3 [ThemeData] (with the [TikkyTokens] extension and
/// a matching Cupertino theme) from design tokens and UI preferences.
///
/// Flat by design: no elevation, no surface tint, hairline outlines.
ThemeData buildMaterialTheme(
  TikkyTheme theme,
  UiPrefs prefs, {
  TargetPlatform? platform,
}) {
  final target = platform ?? defaultTargetPlatform;
  final tokens = TikkyTokens(theme: theme, prefs: prefs, platform: target);
  final c = theme.colors;
  final onDanger = tokens.onColor(c.danger);

  final scheme =
      ColorScheme.fromSeed(
        seedColor: c.primary,
        brightness: theme.brightness,
      ).copyWith(
        primary: c.primary,
        onPrimary: c.onPrimary,
        primaryContainer: c.surfaceAlt,
        onPrimaryContainer: c.text,
        secondary: c.primary,
        onSecondary: c.onPrimary,
        secondaryContainer: c.surfaceAlt,
        onSecondaryContainer: c.text,
        tertiary: c.primary,
        onTertiary: c.onPrimary,
        tertiaryContainer: c.surfaceAlt,
        onTertiaryContainer: c.text,
        error: c.danger,
        onError: onDanger,
        errorContainer: c.danger,
        onErrorContainer: onDanger,
        surface: c.surface,
        onSurface: c.text,
        onSurfaceVariant: c.textMuted,
        surfaceDim: c.background,
        surfaceBright: c.surface,
        surfaceContainerLowest: c.background,
        surfaceContainerLow: c.surface,
        surfaceContainer: c.surface,
        surfaceContainerHigh: c.surfaceAlt,
        surfaceContainerHighest: c.surfaceAlt,
        outline: c.border,
        outlineVariant: c.border,
        inverseSurface: c.text,
        onInverseSurface: c.background,
        inversePrimary: c.onPrimary,
        surfaceTint: Colors.transparent,
        shadow: Colors.transparent,
        scrim: Colors.black54,
      );

  final typography = Typography.material2021(
    platform: target,
    colorScheme: scheme,
  );
  final baseText = theme.isDark ? typography.white : typography.black;
  final family = tokens.fontFamily;
  final fallback = tokens.fontFamilyFallback;
  final textTheme = baseText.apply(
    fontFamily: family,
    fontFamilyFallback: fallback.isEmpty ? null : fallback,
    bodyColor: c.text,
    displayColor: c.text,
  );

  final shape = RoundedRectangleBorder(borderRadius: tokens.radii.mdAll);
  final outlinedShape = RoundedRectangleBorder(
    borderRadius: tokens.radii.mdAll,
    side: tokens.hairline,
  );
  final overlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarBrightness: theme.brightness,
    statusBarIconBrightness: theme.isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarIconBrightness: theme.isDark
        ? Brightness.light
        : Brightness.dark,
  );
  final buttonPadding = EdgeInsets.symmetric(
    horizontal: tokens.space.lg,
    vertical: tokens.space.md,
  );
  OutlineInputBorder inputBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: tokens.radii.mdAll,
        borderSide: BorderSide(color: color, width: width),
      );
  final hairlineWidth = tokens.sizes.hairline <= 0
      ? 1.0
      : tokens.sizes.hairline;

  return ThemeData(
    useMaterial3: true,
    platform: target,
    brightness: theme.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.surface,
    dividerColor: c.border,
    disabledColor: c.textMuted.withValues(alpha: 0.5),
    hintColor: c.textMuted,
    fontFamily: family,
    fontFamilyFallback: fallback.isEmpty ? null : fallback,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    typography: typography,
    visualDensity: switch (prefs.density) {
      UiDensity.compact => VisualDensity.compact,
      UiDensity.normal => VisualDensity.standard,
      UiDensity.roomy => VisualDensity.standard,
    },
    materialTapTargetSize: MaterialTapTargetSize.padded,
    iconTheme: IconThemeData(color: c.text, size: tokens.sizes.iconMd),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        // Predictive back gesture on Android 14+.
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarThemeData(
      backgroundColor: c.background,
      foregroundColor: c.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: tokens.text.title,
      systemOverlayStyle: overlay,
      shape: Border(bottom: tokens.hairline),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: outlinedShape,
    ),
    dividerTheme: DividerThemeData(
      color: c.border,
      thickness: hairlineWidth,
      space: hairlineWidth,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: c.surfaceAlt,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? c.text : c.textMuted,
          size: tokens.sizes.iconMd,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => tokens.text.caption.copyWith(
          color: states.contains(WidgetState.selected) ? c.text : c.textMuted,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w400,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.surface,
      elevation: 0,
      indicatorColor: c.surfaceAlt,
      selectedIconTheme: IconThemeData(
        color: c.text,
        size: tokens.sizes.iconMd,
      ),
      unselectedIconTheme: IconThemeData(
        color: c.textMuted,
        size: tokens.sizes.iconMd,
      ),
      selectedLabelTextStyle: tokens.text.caption.copyWith(
        color: c.text,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: tokens.text.caption,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      modalBackgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      showDragHandle: true,
      dragHandleColor: c.border,
      shape: RoundedRectangleBorder(borderRadius: tokens.radii.sheetTop),
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(maxWidth: tokens.sizes.sheetMaxWidth),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: tokens.radii.lgAll,
        side: tokens.hairline,
      ),
      titleTextStyle: tokens.text.title,
      contentTextStyle: tokens.text.body,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.text,
      contentTextStyle: tokens.text.body.copyWith(color: c.background),
      actionTextColor: c.background,
      elevation: 0,
      shape: shape,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        textStyle: tokens.text.button,
        padding: buttonPadding,
        shape: shape,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        textStyle: tokens.text.button,
        padding: buttonPadding,
        shape: shape,
        side: tokens.hairline,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.text,
        textStyle: tokens.text.button,
        padding: buttonPadding,
        shape: shape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: c.text),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primary,
      foregroundColor: c.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: c.surface,
      isDense: prefs.density == UiDensity.compact,
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.space.md,
        vertical: tokens.space.md,
      ),
      labelStyle: tokens.text.bodyMuted,
      hintStyle: tokens.text.bodyMuted,
      border: inputBorder(c.border, hairlineWidth),
      enabledBorder: inputBorder(c.border, hairlineWidth),
      focusedBorder: inputBorder(c.primary, hairlineWidth + 1),
      errorBorder: inputBorder(c.danger, hairlineWidth),
      focusedErrorBorder: inputBorder(c.danger, hairlineWidth + 1),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.textMuted,
      textColor: c.text,
      titleTextStyle: tokens.text.body,
      subtitleTextStyle: tokens.text.caption,
      contentPadding: EdgeInsets.symmetric(horizontal: tokens.space.page),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surface,
      selectedColor: c.surfaceAlt,
      side: tokens.hairline,
      labelStyle: tokens.text.label,
      shape: RoundedRectangleBorder(borderRadius: tokens.radii.smAll),
      elevation: 0,
      pressElevation: 0,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: c.surface,
        foregroundColor: c.textMuted,
        selectedBackgroundColor: c.surfaceAlt,
        selectedForegroundColor: c.text,
        side: tokens.hairline,
        textStyle: tokens.text.label,
        shape: shape,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.surfaceAlt,
      circularTrackColor: c.surfaceAlt,
      linearMinHeight: tokens.sizes.progressBar,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.primary,
      inactiveTrackColor: c.surfaceAlt,
      thumbColor: c.primary,
      overlayColor: c.primary.withValues(alpha: 0.12),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: outlinedShape,
      textStyle: tokens.text.body,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        shape: WidgetStatePropertyAll(outlinedShape),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.text,
        borderRadius: tokens.radii.smAll,
      ),
      textStyle: tokens.text.caption.copyWith(color: c.background),
    ),
    cupertinoOverrideTheme: buildCupertinoTheme(theme, prefs, platform: target),
    extensions: [tokens],
  );
}

/// Derives the [CupertinoThemeData] used by Cupertino widgets on iOS / macOS
/// (navigation bars, tab bar, pickers, action sheets).
CupertinoThemeData buildCupertinoTheme(
  TikkyTheme theme,
  UiPrefs prefs, {
  TargetPlatform? platform,
}) {
  final target = platform ?? defaultTargetPlatform;
  final c = theme.colors;
  final apple = target == TargetPlatform.iOS || target == TargetPlatform.macOS;
  final family =
      TikkyFonts.family(theme.fontFamily, target) ??
      (apple ? 'CupertinoSystemText' : null);
  TextStyle style(double size, FontWeight weight, Color color) => TextStyle(
    inherit: false,
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    color: color,
    decoration: TextDecoration.none,
  );
  return CupertinoThemeData(
    brightness: theme.brightness,
    primaryColor: c.primary,
    primaryContrastingColor: c.onPrimary,
    scaffoldBackgroundColor: c.background,
    barBackgroundColor: c.surface,
    applyThemeToAll: true,
    textTheme: CupertinoTextThemeData(
      primaryColor: c.primary,
      textStyle: style(17, FontWeight.w400, c.text),
      actionTextStyle: style(17, FontWeight.w400, c.primary),
      navTitleTextStyle: style(17, FontWeight.w600, c.text),
      navLargeTitleTextStyle: style(34, FontWeight.w700, c.text),
      navActionTextStyle: style(17, FontWeight.w400, c.primary),
      tabLabelTextStyle: style(10, FontWeight.w500, c.textMuted),
      pickerTextStyle: style(21, FontWeight.w400, c.text),
      dateTimePickerTextStyle: style(21, FontWeight.w400, c.text),
    ),
  );
}
