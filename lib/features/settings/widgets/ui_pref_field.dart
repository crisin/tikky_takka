import 'package:flutter/material.dart';

import '../../../adaptive/adaptive.dart';
import '../../../l10n/strings.dart';
import '../../../theme/theme.dart';
import '../settings_strings.dart';
import 'setting_rows.dart';
import 'settings_icons.dart';

/// The editor row for ONE field of [UiPrefs], chosen by its JSON key (see
/// [UiPrefsKeys]).
///
/// Used twice:
/// * app-wide preferences: [prefs] is the stored value and every change is
///   saved at once ([overridden] stays `null`);
/// * per-set overrides: [prefs] is the effective value for the set,
///   [overridden] tells whether the set overrides this field and [onReset]
///   removes the override again.
class UiPrefField extends StatelessWidget {
  const UiPrefField({
    required this.fieldKey,
    required this.prefs,
    required this.onChanged,
    this.overridden,
    this.onReset,
    super.key,
  });

  /// One of [UiPrefsKeys.all].
  final String fieldKey;
  final UiPrefs prefs;

  /// Called with the changed preferences; only [fieldKey] differs.
  final ValueChanged<UiPrefs> onChanged;

  /// `null`: plain mode. Otherwise whether the set overrides this field.
  final bool? overridden;
  final VoidCallback? onReset;

  /// Display name of a field.
  static String title(String key) => switch (key) {
    UiPrefsKeys.layout => Strings.prefLayout,
    UiPrefsKeys.density => Strings.prefDensity,
    UiPrefsKeys.digitScale => Strings.prefDigitScale,
    UiPrefsKeys.buttonScale => Strings.prefButtonScale,
    UiPrefsKeys.showTenths => Strings.prefShowTenths,
    UiPrefsKeys.showProgressBar => Strings.prefShowProgress,
    UiPrefsKeys.showSubLine => Strings.prefShowSubLine,
    UiPrefsKeys.leftHanded => Strings.prefLeftHanded,
    UiPrefsKeys.haptics => Strings.prefHaptics,
    UiPrefsKeys.keepScreenOn => Strings.prefKeepScreenOn,
    UiPrefsKeys.use24h => Strings.prefUse24h,
    UiPrefsKeys.csvSeparator => Strings.csvSeparator,
    _ => key,
  };

  static String? _hint(String key) => switch (key) {
    UiPrefsKeys.leftHanded => Strings.prefLeftHandedHint,
    UiPrefsKeys.haptics => SettingsStrings.prefHapticsHint,
    UiPrefsKeys.keepScreenOn => SettingsStrings.prefKeepScreenOnHint,
    UiPrefsKeys.use24h => SettingsStrings.prefUse24hHint,
    _ => null,
  };

  /// Steps of 5 % between the minimum and maximum of a scale.
  static int _divisions(double min, double max) => ((max - min) / 0.05).round();

  @override
  Widget build(BuildContext context) {
    final label = title(fieldKey);
    final overrideMode = overridden != null;
    final isOverridden = overridden ?? false;

    // In override mode the caption tells where the value comes from.
    final String? caption = overrideMode
        ? (isOverridden
              ? SettingsStrings.overrideActive
              : SettingsStrings.overrideInherited)
        : _hint(fieldKey);
    final Widget? reset = isOverridden && onReset != null
        ? AdaptiveIconButton(
            icon: SettingsIcons.restore(context),
            semanticLabel: SettingsStrings.overrideReset(label),
            onPressed: onReset,
          )
        : null;

    Widget toggle(bool value, UiPrefs Function(bool v) apply) {
      final tile = AdaptiveSwitchTile(
        title: label,
        subtitle: caption,
        value: value,
        onChanged: (v) => onChanged(apply(v)),
      );
      if (reset == null) return tile;
      return Row(
        children: [
          Expanded(child: tile),
          reset,
          SizedBox(width: context.tikky.space.xs),
        ],
      );
    }

    return switch (fieldKey) {
      UiPrefsKeys.layout => SegmentedSettingTile<LaneLayout>(
        title: label,
        caption: caption,
        trailing: reset,
        segments: const {
          LaneLayout.rows: Strings.prefLayoutRows,
          LaneLayout.tiles: Strings.prefLayoutTiles,
        },
        selected: prefs.layout,
        onChanged: (v) => onChanged(prefs.copyWith(layout: v)),
      ),
      UiPrefsKeys.density => SegmentedSettingTile<UiDensity>(
        title: label,
        caption: caption,
        trailing: reset,
        segments: const {
          UiDensity.compact: Strings.prefDensityCompact,
          UiDensity.normal: Strings.prefDensityNormal,
          UiDensity.roomy: Strings.prefDensityRoomy,
        },
        selected: prefs.density,
        onChanged: (v) => onChanged(prefs.copyWith(density: v)),
      ),
      UiPrefsKeys.csvSeparator => SegmentedSettingTile<CsvSeparator>(
        title: label,
        caption: caption,
        trailing: reset,
        segments: const {
          CsvSeparator.semicolon: Strings.csvSemicolon,
          CsvSeparator.comma: Strings.csvComma,
        },
        selected: prefs.csvSeparator,
        onChanged: (v) => onChanged(prefs.copyWith(csvSeparator: v)),
      ),
      UiPrefsKeys.digitScale => SliderSettingTile(
        title: label,
        caption: caption,
        trailing: reset,
        valueLabel: SettingsStrings.percent(prefs.digitScale),
        value: prefs.digitScale,
        min: UiPrefs.minDigitScale,
        max: UiPrefs.maxDigitScale,
        divisions: _divisions(UiPrefs.minDigitScale, UiPrefs.maxDigitScale),
        onChanged: (v) => onChanged(prefs.copyWith(digitScale: _snap(v))),
      ),
      UiPrefsKeys.buttonScale => SliderSettingTile(
        title: label,
        caption: caption,
        trailing: reset,
        valueLabel: SettingsStrings.percent(prefs.buttonScale),
        value: prefs.buttonScale,
        min: UiPrefs.minButtonScale,
        max: UiPrefs.maxButtonScale,
        divisions: _divisions(UiPrefs.minButtonScale, UiPrefs.maxButtonScale),
        onChanged: (v) => onChanged(prefs.copyWith(buttonScale: _snap(v))),
      ),
      UiPrefsKeys.showTenths => toggle(
        prefs.showTenths,
        (v) => prefs.copyWith(showTenths: v),
      ),
      UiPrefsKeys.showProgressBar => toggle(
        prefs.showProgressBar,
        (v) => prefs.copyWith(showProgressBar: v),
      ),
      UiPrefsKeys.showSubLine => toggle(
        prefs.showSubLine,
        (v) => prefs.copyWith(showSubLine: v),
      ),
      UiPrefsKeys.leftHanded => toggle(
        prefs.leftHanded,
        (v) => prefs.copyWith(leftHanded: v),
      ),
      UiPrefsKeys.haptics => toggle(
        prefs.haptics,
        (v) => prefs.copyWith(haptics: v),
      ),
      UiPrefsKeys.keepScreenOn => toggle(
        prefs.keepScreenOn,
        (v) => prefs.copyWith(keepScreenOn: v),
      ),
      UiPrefsKeys.use24h => toggle(
        prefs.use24h,
        (v) => prefs.copyWith(use24h: v),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  /// Rounds a scale to two decimals, so stored values stay tidy (1.05, not
  /// 1.0499999).
  static double _snap(double value) => (value * 100).round() / 100;
}
