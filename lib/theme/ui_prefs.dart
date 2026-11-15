import '../core/domain/json_utils.dart';

/// How tracks are laid out on the tracks screen.
enum LaneLayout { rows, tiles }

enum UiDensity { compact, normal, roomy }

enum CsvSeparator {
  /// For German Excel.
  semicolon(';'),
  comma(',');

  const CsvSeparator(this.char);

  final String char;
}

/// JSON keys of [UiPrefs]. A set's `uiPrefsOverride` map uses the same keys.
abstract final class UiPrefsKeys {
  static const layout = 'layout';
  static const density = 'density';
  static const digitScale = 'digitScale';
  static const buttonScale = 'buttonScale';
  static const showTenths = 'showTenths';
  static const showProgressBar = 'showProgressBar';
  static const showSubLine = 'showSubLine';
  static const showEntryCounts = 'showEntryCounts';
  static const leftHanded = 'leftHanded';
  static const haptics = 'haptics';
  static const keepScreenOn = 'keepScreenOn';
  static const use24h = 'use24h';
  static const csvSeparator = 'csvSeparator';

  static const all = [
    layout,
    density,
    digitScale,
    buttonScale,
    showTenths,
    showProgressBar,
    showSubLine,
    showEntryCounts,
    leftHanded,
    haptics,
    keepScreenOn,
    use24h,
    csvSeparator,
  ];
}

/// User interface preferences. Immutable, JSON (de)serialisable.
final class UiPrefs {
  const UiPrefs({
    this.layout = LaneLayout.rows,
    this.density = UiDensity.normal,
    this.digitScale = 1,
    this.buttonScale = 1,
    this.showTenths = false,
    this.showProgressBar = true,
    this.showSubLine = true,
    this.showEntryCounts = false,
    this.leftHanded = false,
    this.haptics = true,
    this.keepScreenOn = false,
    this.use24h = true,
    this.csvSeparator = CsvSeparator.semicolon,
  });

  factory UiPrefs.fromJson(JsonMap json) => UiPrefs(
    layout: _byName(
      LaneLayout.values,
      json[UiPrefsKeys.layout],
      LaneLayout.rows,
    ),
    density: _byName(
      UiDensity.values,
      json[UiPrefsKeys.density],
      UiDensity.normal,
    ),
    digitScale: _scale(
      json[UiPrefsKeys.digitScale],
      minDigitScale,
      maxDigitScale,
    ),
    buttonScale: _scale(
      json[UiPrefsKeys.buttonScale],
      minButtonScale,
      maxButtonScale,
    ),
    showTenths: jsonBool(json[UiPrefsKeys.showTenths], false),
    showProgressBar: jsonBool(json[UiPrefsKeys.showProgressBar], true),
    showSubLine: jsonBool(json[UiPrefsKeys.showSubLine], true),
    showEntryCounts: jsonBool(json[UiPrefsKeys.showEntryCounts], false),
    leftHanded: jsonBool(json[UiPrefsKeys.leftHanded], false),
    haptics: jsonBool(json[UiPrefsKeys.haptics], true),
    keepScreenOn: jsonBool(json[UiPrefsKeys.keepScreenOn], false),
    use24h: jsonBool(json[UiPrefsKeys.use24h], true),
    csvSeparator: _byName(
      CsvSeparator.values,
      json[UiPrefsKeys.csvSeparator],
      CsvSeparator.semicolon,
    ),
  );

  static const defaults = UiPrefs();

  static const double minDigitScale = 0.7;
  static const double maxDigitScale = 1.6;
  static const double minButtonScale = 0.8;
  static const double maxButtonScale = 1.5;

  final LaneLayout layout;
  final UiDensity density;

  /// Multiplier for the large time / count digits.
  final double digitScale;

  /// Multiplier for the lane buttons.
  final double buttonScale;
  final bool showTenths;
  final bool showProgressBar;
  final bool showSubLine;

  /// "×3" on the capture fields of the tap pad (how often today's
  /// session has it). Off by default.
  final bool showEntryCounts;

  /// Primary button on the left side of a lane.
  final bool leftHanded;
  final bool haptics;
  final bool keepScreenOn;
  final bool use24h;
  final CsvSeparator csvSeparator;

  static T _byName<T extends Enum>(List<T> values, Object? name, T fallback) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }

  static double _scale(Object? v, double min, double max) =>
      jsonDouble(v, 1).clamp(min, max).toDouble();

  /// These preferences with a partial override applied (the
  /// `uiPrefsOverride` of a set). Unknown keys and wrong types are ignored.
  UiPrefs applyOverride(JsonMap? override) {
    if (override == null || override.isEmpty) return this;
    return UiPrefs.fromJson({...toJson(), ...override});
  }

  /// The partial override that turns [base] into `this`: only the keys
  /// whose values differ. `null` when nothing differs.
  JsonMap? overrideAgainst(UiPrefs base) {
    final mine = toJson();
    final theirs = base.toJson();
    final diff = <String, Object?>{
      for (final key in UiPrefsKeys.all)
        if (mine[key] != theirs[key]) key: mine[key],
    };
    return diff.isEmpty ? null : diff;
  }

  UiPrefs copyWith({
    LaneLayout? layout,
    UiDensity? density,
    double? digitScale,
    double? buttonScale,
    bool? showTenths,
    bool? showProgressBar,
    bool? showSubLine,
    bool? showEntryCounts,
    bool? leftHanded,
    bool? haptics,
    bool? keepScreenOn,
    bool? use24h,
    CsvSeparator? csvSeparator,
  }) => UiPrefs(
    layout: layout ?? this.layout,
    density: density ?? this.density,
    digitScale: (digitScale ?? this.digitScale)
        .clamp(minDigitScale, maxDigitScale)
        .toDouble(),
    buttonScale: (buttonScale ?? this.buttonScale)
        .clamp(minButtonScale, maxButtonScale)
        .toDouble(),
    showTenths: showTenths ?? this.showTenths,
    showProgressBar: showProgressBar ?? this.showProgressBar,
    showSubLine: showSubLine ?? this.showSubLine,
    showEntryCounts: showEntryCounts ?? this.showEntryCounts,
    leftHanded: leftHanded ?? this.leftHanded,
    haptics: haptics ?? this.haptics,
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    use24h: use24h ?? this.use24h,
    csvSeparator: csvSeparator ?? this.csvSeparator,
  );

  JsonMap toJson() => {
    UiPrefsKeys.layout: layout.name,
    UiPrefsKeys.density: density.name,
    UiPrefsKeys.digitScale: digitScale,
    UiPrefsKeys.buttonScale: buttonScale,
    UiPrefsKeys.showTenths: showTenths,
    UiPrefsKeys.showProgressBar: showProgressBar,
    UiPrefsKeys.showSubLine: showSubLine,
    UiPrefsKeys.showEntryCounts: showEntryCounts,
    UiPrefsKeys.leftHanded: leftHanded,
    UiPrefsKeys.haptics: haptics,
    UiPrefsKeys.keepScreenOn: keepScreenOn,
    UiPrefsKeys.use24h: use24h,
    UiPrefsKeys.csvSeparator: csvSeparator.name,
  };

  @override
  bool operator ==(Object other) =>
      other is UiPrefs && jsonMapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);

  @override
  String toString() => 'UiPrefs(${toJson()})';
}
