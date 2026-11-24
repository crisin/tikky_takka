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
  static const prefDayStart = 'Tag beginnt um';
  static const prefDayStartHint =
      'Was davor passiert, zählt in der Zeitleiste zum Abend davor.';

  /// "06:00"
  static String hourOfDay(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

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
  static String overrideReset(String field) => 'App-Standard verwenden: $field';

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
  static const contrastInkOnTint = 'Schrift in Spurfarbe auf der Spur';
  static const contrastInkOnStrong = 'Schrift in Spurfarbe auf der Füllung';
  static const contrastOnSolid = 'Symbol auf der Spurfarbe';
  static const contrastTextOnStrong = 'Text auf der Füllung';
  static const contrastWarningOnTint = 'Warntext auf der Spur';

  /// "Spurfarbe 3 · Text auf der Füllung"
  static String contrastPaletteEntry(int number, String pair) =>
      'Spurfarbe $number · $pair';

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

  // ------------------------------------------------------------ diagnostics
  static const diagnostics = 'Diagnose';
  static const diagnosticsHint = 'Für Tests auf dem Gerät: Status und Fehler.';
  static const diagApp = 'App';
  static const diagBuild = 'Build';
  static const diagBuildLocal = 'lokal';
  static const diagMode = 'Modus';
  static const diagPlatform = 'Plattform';
  static const diagNotifications = 'Benachrichtigungen';
  static const diagSupported = 'Unterstützt';
  static const diagAllowed = 'Erlaubt';
  static const diagExact = 'Exakte Alarme';
  static const diagAppLock = 'App-Sperre möglich';
  static const diagYes = 'Ja';
  static const diagNo = 'Nein';
  static const diagTestAlarm = 'Test-Alarm in 10 Sekunden';
  static const diagTestAlarmHint =
      'Danach die App schließen oder das Gerät sperren.';
  static const diagTestAlarmSet = 'Test-Alarm kommt in 10 Sekunden.';
  static const diagRequest = 'Erlaubnis anfragen';
  static const diagErrors = 'Fehler dieser Sitzung';
  static const diagErrorsFooter =
      'Nur im Speicher, bis die App beendet wird. Verlässt das Gerät nur, '
      'wenn du es kopierst.';
  static const diagNoErrors = 'Keine Fehler.';
  static const diagCopy = 'Bericht kopieren';
  static const diagCopied = 'Bericht kopiert';
  static const diagClear = 'Fehler leeren';

  // -------------------------------------------------------------- developer
  static const dev = 'Entwickler';
  static const devHint = 'Offline-Cache, Daten, Leistung, Zurücksetzen.';
  static const devPwa = 'Offline (PWA)';
  static const devPwaFooter =
      'Die App-Dateien liegen im Cache des Browsers, damit sie ohne Netz '
      'startet. Eine neue Version gilt ab dem nächsten Start.';
  static const devWorker = 'Service Worker';
  static const devWorkerActive = 'Aktiv';
  static const devWorkerNone = 'Nicht registriert';
  static const devWorkerUnsupported = 'Nicht verfügbar';
  static const devControlled = 'Seite kommt vom Worker';
  static const devInstalled = 'Installiert';
  static const devOnline = 'Online';
  static const devPersisted = 'Speicher dauerhaft';
  static const devUsage = 'Belegt';
  static const devCachedVersion = 'Version im Cache';
  static const devCaches = 'Dateien im Cache';
  static const devNoCaches = 'Kein Cache vorhanden.';
  static const devCheckUpdate = 'Nach Update suchen';
  static const devUpdateFound =
      'Neue Version geladen. Gilt ab dem nächsten Start.';
  static const devUpdateNone = 'Kein Update gefunden.';
  static const devUpdateFailed = 'Update-Suche fehlgeschlagen.';
  static const devClearCache = 'Offline-Cache neu laden';
  static const devClearCacheHint =
      'Löscht die App-Dateien im Cache und lädt neu. Deine Daten bleiben.';
  static const devNeedsNetwork = 'Das geht nur mit Internet.';
  static const devData = 'Daten';
  static const devDbSize = 'Datenbank';
  static const devEvents = 'Ereignisse';
  static const devEntries = 'Einträge';
  static const devSessions = 'Sitzungen';
  static const devTracks = 'Spuren';
  static const devSettingsRows = 'Einstellungen';
  static const devPerf = 'Leistung';
  static const devStartup = 'Start bis erstes Bild';
  static const devFrames = 'Gemessene Bilder';
  static const devBuild = 'Aufbau (Ø)';
  static const devRaster = 'Zeichnen (Ø)';
  static const devWorst = 'Längstes Bild';
  static const devSlow = 'Zu langsam';
  static const devMemory = 'Arbeitsspeicher';
  static const devPerfReset = 'Messung neu starten';
  static const devUnknown = '–';

  /// Footer of the performance section.
  static String devPerfFooter(int capacity, double budgetMs) =>
      'Die letzten $capacity Bilder seit dem Start. Zu langsam heißt: länger '
      'als ${DevFormat.ms(budgetMs)}.';

  static const devReset = 'Zurücksetzen';
  static const devResetApp = 'App zurücksetzen';
  static const devResetHint = 'Löscht alle Daten und Einstellungen.';
  static const devResetTitle = 'Wirklich alles löschen?';
  static const devResetMessage =
      'Alle Spuren, Verläufe, Personen, Designs und Einstellungen werden '
      'gelöscht. Das lässt sich nicht rückgängig machen. Sichere vorher '
      'unter „Daten exportieren“, was du behalten willst.';
  static const devResetConfirm = 'Alles löschen';
  static const devResetDone = 'App zurückgesetzt';
  static const devResetFailed = 'Zurücksetzen fehlgeschlagen.';

  /// "42 Dateien · 3,1 MB"
  static String devCacheSummary(int files, int bytes) =>
      '$files ${files == 1 ? 'Datei' : 'Dateien'} · ${DevFormat.bytes(bytes)}';

  /// "3,2 MB von 2,0 GB"
  static String devUsageOf(int used, int quota) =>
      '${DevFormat.bytes(used)} von ${DevFormat.bytes(quota)}';

  /// "4 von 600"
  static String devCountOf(int part, int whole) => '$part von $whole';
}

/// Number formats of the developer page (German decimal comma).
abstract final class DevFormat {
  /// "812 B", "14 KB", "3,2 MB", "2,0 GB"
  static String bytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${_fixed(bytes / (1024 * 1024))} MB';
    }
    return '${_fixed(bytes / (1024 * 1024 * 1024))} GB';
  }

  /// "4,2 ms"; from 100 ms on without decimals.
  static String ms(double value) =>
      value >= 100 ? '${value.round()} ms' : '${_fixed(value)} ms';

  static String _fixed(double value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');
}
