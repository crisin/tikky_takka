/// User-facing strings (German) of the settings feature that are not part
/// of the shared `Strings` class. Kept in one place so they can move into
/// the central localisation later.
abstract final class SettingsStrings {
  // ------------------------------------------------------------ appearance
  static const themeManage = 'Designs verwalten';
  static const themeManageHint = 'Vorlagen, eigene Designs, Editor.';
  static const displaySettings = 'Anzeige der Spuren';
  static const displaySettingsHint = 'Anordnung, Größen, Zusatzinfos.';
  static const sectionLanes = 'Spuren';
  static const sectionSizes = 'Größen';
  static const sectionSets = 'Sets';
  static const sectionSetsFooter =
      'Ein Set kann ein eigenes Design und eine eigene Darstellung bekommen. '
      'Sie gelten, solange das Set aktiv ist.';
  static const noSets = 'Noch keine Sets vorhanden.';

  /// "115 %"
  static String percent(double factor) => '${(factor * 100).round()} %';

  // ------------------------------------------------------------- behaviour
  static const prefHapticsHint = 'Kurzes Vibrieren bei Tipps und Alarmen.';
  static const prefKeepScreenOnHint =
      'Der Bildschirm bleibt an, solange die App offen ist.';
  static const prefUse24hHint = 'Aus: Uhrzeiten mit AM/PM.';

  // ---------------------------------------------------------- set overrides
  static const overrideActive = 'Angepasst';
  static const overrideInherited = 'App-Standard';
  static const overrideResetAll = 'Alle Anpassungen entfernen';
  static const overridesRemoved = 'Anpassungen entfernt';
  static const setNotFound = 'Dieses Set gibt es nicht mehr.';
  static const setThemeHint =
      'Gilt nur, solange dieses Set aktiv ist. Ohne Auswahl wird das Design '
      'der App verwendet.';
  static const setPrefsFooter =
      'Nur angepasste Werte weichen vom App-Standard ab. Mit dem Pfeil '
      'stellst du einen Wert wieder auf den App-Standard.';

  /// Semantic label of the per-field reset button.
  static String overrideReset(String field) =>
      'App-Standard verwenden: $field';

  // ----------------------------------------------------------- theme list
  static const themesTitle = 'Designs';
  static const themePresets = 'Vorlagen';
  static const themeCustomEmpty =
      'Noch kein eigenes Design. Dupliziere eine Vorlage, um sie anzupassen.';
  static const themeUse = 'Verwenden';
  static const themeInUse = 'Aktiv';
  static const themeBright = 'Hell';
  static const themeDim = 'Dunkel';
  static const themeImported = 'Design importiert';
  static const themeExported = 'Design exportiert';
  static const themeExportFailed = 'Das Design konnte nicht exportiert werden.';
  static const themeImportUnavailable =
      'Die Dateiauswahl ist hier nicht verfügbar.';
  static const themeNotFound = 'Dieses Design gibt es nicht mehr.';
  static const themeName = 'Name des Designs';
  static const themeActions = 'Aktionen für das Design';
  static const themeResetChanges = 'Änderungen verwerfen';
  static const themeChangesDiscarded = 'Änderungen verworfen';
  static const themeApplied = 'Design wird verwendet';

  /// Semantic label of the "more" button of a theme row.
  static String themeActionsFor(String name) => 'Aktionen für $name';

  // ---------------------------------------------------------- theme editor
  static const editorGeneral = 'Allgemein';
  static const editorColors = 'Farben';
  static const editorTypography = 'Schrift und Ziffern';
  static const editorShape = 'Form';
  static const paletteAdd = 'Spurfarbe hinzufügen';
  static const paletteRemove = 'Spurfarbe entfernen';
  static const paletteMoveEarlier = 'Nach vorne verschieben';
  static const paletteMoveLater = 'Nach hinten verschieben';
  static const paletteHint =
      'Spuren durchlaufen diese Farben der Reihe nach. Tippe eine Farbe an, '
      'um sie zu ändern.';

  /// Semantic label of a palette swatch.
  static String paletteColor(int number) => 'Spurfarbe $number';
  static const colorRemoved = 'Spurfarbe entfernt';

  /// "3 px" / "1,5 px"
  static String pixels(double value) {
    final rounded = (value * 10).round() / 10;
    final text = rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toString().replaceAll('.', ',');
    return '$text px';
  }

  // ---------------------------------------------------------- colour picker
  static const hue = 'Farbton';
  static const saturation = 'Sättigung';
  static const brightnessValue = 'Helligkeit';
  static const hexInvalid = 'Bitte sechs Hex-Ziffern, z. B. #2F6FED.';
  static const swatches = 'Farben aus diesem Design';

  /// Semantic label of a swatch in the picker.
  static String swatchLabel(String hex) => 'Farbe $hex';

  /// "42 %"
  static String percentInt(double fraction) => '${(fraction * 100).round()} %';

  /// "210°"
  static String degrees(double value) => '${value.round()}°';

  // --------------------------------------------------------------- contrast
  static const contrastTitle = 'Geringer Kontrast';
  static const contrastTextOnBackground = 'Text auf Hintergrund';
  static const contrastTextOnSurface = 'Text auf Fläche';
  static const contrastMutedOnSurface = 'Gedämpfter Text auf Fläche';
  static const contrastMutedOnBackground = 'Gedämpfter Text auf Hintergrund';
  static const contrastOnPrimary = 'Symbol auf Akzent';

  /// "Text auf Fläche: 2,1:1 (empfohlen mindestens 4,5:1)"
  static String contrastLine(String pair, double ratio, double required) =>
      '$pair: ${_ratio(ratio)}:1 (empfohlen mindestens ${_ratio(required)}:1)';

  static String _ratio(double value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');

  // ---------------------------------------------------------------- preview
  static const sampleStopwatch = 'Arbeit';
  static const sampleTimer = 'Nudeln';
  static const sampleInterval = 'Training';
  static const sampleStopwatchSub = 'Runde 3 · letzte 04:12';
  static const sampleTimerSub = 'Abgelaufen vor 12 s';
  static const sampleIntervalSub = 'Runde 2 von 5 · pausiert';
  static const previewLabel = 'Vorschau mit Beispielspuren';

  // ------------------------------------------------------------------- data
  static const dataExport = 'Daten exportieren';
  static const dataExportHint = 'CSV oder vollständige Sicherung.';
  static const dataImport = 'Sicherung importieren';
  static const dataImportHint =
      'Führt eine JSON-Sicherung mit den vorhandenen Daten zusammen.';
  static const dataExportProtocolNote =
      'Protokoll-Spuren sind hier nicht enthalten.';
  static const dataPersonsHint = 'Für Protokoll-Spuren.';
  static const dataSubstancesHint = 'Mit eigenem Mindestabstand.';
  static const dataUnavailable = 'Diese Funktion ist hier nicht verfügbar.';
  static const exportCancelled = 'Export abgebrochen';

  // ---------------------------------------------------------- notifications
  static const notificationsRequest = 'Tippen, um die Erlaubnis anzufragen.';
  static const notificationsChecking = 'Wird geprüft …';

  // ------------------------------------------------------------------ about
  static const licenses = 'Open-Source-Lizenzen';
  static const aboutTagline = 'Mehrere Timer nebeneinander, komplett lokal.';
}
