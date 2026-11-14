import '../core/domain/enums.dart';

/// All user-facing strings of the app (German), in one place so that real
/// localisation can replace this class later.
///
/// Rules for feature code: never put a user-facing literal into a widget;
/// add a constant (or a function for strings with parameters) here instead.
/// Keep the sections ordered; feature owners append to "their" section.
abstract final class Strings {
  // ------------------------------------------------------------------ app
  static const appName = 'Tikky Takka';

  // ------------------------------------------------------------ navigation
  static const navTracks = 'Spuren';
  static const navHistory = 'Verlauf';
  static const navSettings = 'Einstellungen';

  // --------------------------------------------------------------- common
  static const ok = 'OK';
  static const cancel = 'Abbrechen';
  static const save = 'Speichern';
  static const done = 'Fertig';
  static const close = 'Schließen';
  static const delete = 'Löschen';
  static const edit = 'Bearbeiten';
  static const add = 'Hinzufügen';
  static const rename = 'Umbenennen';
  static const duplicate = 'Duplizieren';
  static const undo = 'Rückgängig';
  static const back = 'Zurück';
  static const more = 'Mehr';
  static const yes = 'Ja';
  static const no = 'Nein';
  static const on = 'An';
  static const off = 'Aus';
  static const none = 'Keine';
  static const all = 'Alle';
  static const unknown = 'Unbekannt';
  static const name = 'Name';
  static const note = 'Notiz';
  static const color = 'Farbe';
  static const loading = 'Lädt …';
  static const errorGeneric = 'Das hat leider nicht geklappt.';
  static const clockChanged =
      'Die Systemzeit wurde geändert. Laufende Timer können abweichen.';
  static const comingSoon = 'Dieser Bereich wird gerade gebaut.';
  static const share = 'Teilen';
  static const export = 'Exportieren';
  static const import = 'Importieren';
  static const reset = 'Zurücksetzen';
  static const archive = 'Archivieren';
  static const restore = 'Wiederherstellen';
  static const search = 'Suchen';
  static const today = 'Heute';
  static const yesterday = 'Gestern';
  static const now = 'Jetzt';

  // ---------------------------------------------------------------- units
  static const unitHoursShort = 'h';
  static const unitMinutesShort = 'min';
  static const unitSecondsShort = 's';
  static const unitDaysShort = 'T';
  static const hours = 'Stunden';
  static const minutes = 'Minuten';
  static const seconds = 'Sekunden';

  /// "vor 1 h 42 min"
  static String ago(String duration) => 'vor $duration';

  /// "in 1 h 42 min"
  static String inDuration(String duration) => 'in $duration';
  static const justNow = 'gerade eben';

  // ---------------------------------------------------------------- modes
  static const modeStopwatch = 'Stoppuhr';
  static const modeCountdown = 'Timer';
  static const modeInterval = 'Intervall';
  static const modeCounter = 'Zähler';
  static const modeReminder = 'Erinnerung';
  static const modeProtocol = 'Protokoll';

  static String modeName(TrackMode mode) => switch (mode) {
    TrackMode.stopwatch => modeStopwatch,
    TrackMode.countdown => modeCountdown,
    TrackMode.interval => modeInterval,
    TrackMode.counter => modeCounter,
    TrackMode.reminder => modeReminder,
    TrackMode.protocol => modeProtocol,
  };

  static String modeDescription(TrackMode mode) => switch (mode) {
    TrackMode.stopwatch => 'Zählt hoch, mit Runden und Pause.',
    TrackMode.countdown => 'Läuft von einer Dauer rückwärts und klingelt.',
    TrackMode.interval => 'Wechselt zwischen Arbeit und Pause, in Runden.',
    TrackMode.counter => 'Zählt Tipps und misst die Zeit dazwischen.',
    TrackMode.reminder => 'Erinnert regelmäßig, bis du bestätigst.',
    TrackMode.protocol => 'Hält fest, wer wann was genommen hat.',
  };

  static String eventTypeName(EventType type) => switch (type) {
    EventType.start => 'Start',
    EventType.pause => 'Pause',
    EventType.resume => 'Weiter',
    EventType.lap => 'Runde',
    EventType.tick => 'Tipp',
    EventType.entry => 'Eintrag',
    EventType.ack => 'Bestätigt',
    EventType.stop => 'Stopp',
  };

  // ------------------------------------------------------------ seed data
  static const seedSetName = 'Allgemein';
  static const seedStopwatchName = 'Stoppuhr';
  static const seedTimerName = 'Timer';
  static const seedCounterName = 'Zähler';

  // --------------------------------------------------------------- tracks
  static const tracksTitle = 'Spuren';
  static const tracksEmptyTitle = 'Noch keine Spuren';
  static const tracksEmptyBody =
      'Lege deine erste Spur an – Stoppuhr, Timer, Zähler und mehr.';
  static const noSetsTitle = 'Kein Set vorhanden';
  static const noSetsBody = 'Lege ein Set an, um Spuren zu gruppieren.';
  static const addTrack = 'Spur hinzufügen';
  static const newTrack = 'Neue Spur';
  static const editTrack = 'Spur bearbeiten';
  static const deleteTrack = 'Spur löschen';
  static const archiveTrack = 'Spur archivieren';
  static const trackDeleted = 'Spur gelöscht';
  static const trackArchived = 'Spur archiviert';
  static const reorderTracks = 'Spuren sortieren';
  static const dragHandle = 'Ziehen zum Sortieren';
  static const startAll = 'Alle starten';
  static const pauseAll = 'Alle pausieren';
  static const switchSet = 'Set wechseln';
  static const manageSets = 'Sets verwalten';
  static const newSet = 'Neues Set';
  static const editSet = 'Set bearbeiten';
  static const deleteSet = 'Set löschen';
  static const setName = 'Name des Sets';
  static const setDeleted = 'Set gelöscht';

  // lane actions (semantic labels of the lane buttons)
  static const actionStart = 'Starten';
  static const actionPause = 'Pausieren';
  static const actionResume = 'Fortsetzen';
  static const actionStop = 'Stoppen';
  static const actionDismiss = 'Ausschalten';
  static const actionReset = 'Zurücksetzen';
  static const actionRestart = 'Neu starten';
  static const actionLap = 'Runde';
  static const actionTick = 'Zählen';
  static const actionUndoTick = 'Letzten Tipp zurücknehmen';
  static const actionAck = 'Erledigt';
  static const actionAddEntry = 'Eintrag hinzufügen';

  // lane status / sub-lines
  static const statusIdle = 'Bereit';
  static const statusRunning = 'Läuft';
  static const statusPaused = 'Pausiert';
  static const statusRinging = 'Fertig';
  static const statusDue = 'Fällig';
  static const statusStopped = 'Beendet';
  static const phaseWork = 'Arbeit';
  static const phaseRest = 'Pause';
  static const phaseDone = 'Geschafft';

  static String lapNumber(int n) => 'Runde $n';
  static String roundOf(int round, int rounds) => 'Runde $round von $rounds';
  static String totalTime(String duration) => 'Gesamt $duration';
  static String lastLap(String duration) => 'Letzte Runde $duration';
  static String overdueBy(String duration) => 'Überfällig seit $duration';
  static String dueIn(String duration) => 'Fällig in $duration';
  static String cyclesDone(int n) => n == 1 ? '1 Durchlauf' : '$n Durchläufe';
  static String countValue(int n) => '$n';
  static const sessionStopped = 'Sitzung beendet';
  static const sessionDiscarded = 'Sitzung verworfen';
  static const tickUndone = 'Tipp zurückgenommen';

  // track editor
  static const trackName = 'Name der Spur';
  static const trackMode = 'Art';
  static const trackColor = 'Farbe';
  static const customColor = 'Eigene Farbe';
  static const alarmSound = 'Ton beim Alarm';
  static const vibration = 'Vibration';
  static const moveToSet = 'In anderes Set verschieben';
  static const optExclusive = 'Exklusiv';
  static const optExclusiveHint =
      'Beim Start pausieren andere exklusive Stoppuhren in diesem Set.';
  static const optDuration = 'Dauer';
  static const optAutoRestart = 'Automatisch neu starten';
  static const optWork = 'Arbeit';
  static const optRest = 'Pause';
  static const optRounds = 'Runden';
  static const optLabels = 'Schnell-Labels';
  static const optLabelsHint = 'z. B. Eichhörnchen, Reiher, Hund';
  static const optAddLabel = 'Label hinzufügen';
  static const optInterval = 'Abstand';
  static const optNagEvery = 'Nachhaken alle';

  // -------------------------------------------------------------- history
  static const historyTitle = 'Verlauf';
  static const historyEmptyTitle = 'Noch nichts im Verlauf';
  static const historyEmptyBody =
      'Sobald du eine Spur stoppst, erscheint sie hier.';
  static const historyNoMatchTitle = 'Keine Treffer';
  static const historyNoMatchBody = 'Für diesen Filter gibt es keine Einträge.';
  static const filter = 'Filter';
  static const filterTracks = 'Spuren';
  static const filterSet = 'Set';
  static const filterDateRange = 'Zeitraum';
  static const filterFrom = 'Von';
  static const filterTo = 'Bis';
  static const filterReset = 'Filter zurücksetzen';
  static const allTracks = 'Alle Spuren';
  static const allSets = 'Alle Sets';
  static const allTime = 'Gesamter Zeitraum';
  static const dayTotal = 'Tagessumme';
  static const weekTotal = 'Wochensumme';
  static const sumsDaily = 'Pro Tag';
  static const sumsWeekly = 'Pro Woche';
  static const sessions = 'Sitzungen';
  static const sessionDetail = 'Sitzung';
  static const sessionDeleted = 'Sitzung gelöscht';
  static const deleteSession = 'Sitzung löschen';
  static const eventDeleted = 'Eintrag gelöscht';
  static const deleteEvent = 'Eintrag löschen';
  static const editNote = 'Notiz bearbeiten';
  static const netDuration = 'Netto';
  static const pausedDuration = 'Pausiert';
  static const started = 'Beginn';
  static const ended = 'Ende';
  static const events = 'Ereignisse';
  static const laps = 'Runden';
  static const count = 'Anzahl';
  static const deletedTrack = 'Gelöschte Spur';
  static String weekOf(String date) => 'Woche ab $date';
  static String sessionCount(int n) => n == 1 ? '1 Sitzung' : '$n Sitzungen';

  // --------------------------------------------------------------- export
  static const exportTitle = 'Export';
  static const exportSessionsCsv = 'Sitzungen (CSV)';
  static const exportEventsCsv = 'Ereignisse (CSV)';
  static const exportBackupJson = 'Vollständige Sicherung (JSON)';
  static const importBackupJson = 'Sicherung importieren (JSON)';
  static const exportIncludeProtocol = 'Protokoll-Spuren einschließen';
  static const exportIncludeProtocolHint =
      'Protokolle sind privat und werden nur exportiert, wenn du das hier '
      'ausdrücklich einschaltest.';
  static const exportUsesFilter = 'Der Export berücksichtigt den Filter.';
  static const exportDone = 'Export erstellt';
  static const exportFailed = 'Export fehlgeschlagen';
  static const importDone = 'Import abgeschlossen';
  static const importFailed = 'Import fehlgeschlagen';
  static const importInvalidFile = 'Das ist keine gültige Sicherungsdatei.';
  static String importSummary(int added, int updated, int kept) =>
      '$added neu, $updated aktualisiert, $kept unverändert';
  static const csvSeparator = 'CSV-Trennzeichen';
  static const csvSemicolon = 'Semikolon (Excel, deutsch)';
  static const csvComma = 'Komma';

  // CSV column headers
  static const colSet = 'Set';
  static const colTrack = 'Spur';
  static const colMode = 'Art';
  static const colStart = 'Beginn';
  static const colEnd = 'Ende';
  static const colDuration = 'Dauer';
  static const colDurationSeconds = 'Dauer (s)';
  static const colPausedSeconds = 'Pausiert (s)';
  static const colCount = 'Runden/Anzahl';
  static const colNote = 'Notiz';
  static const colTime = 'Zeit';
  static const colSessionId = 'Sitzung';
  static const colType = 'Typ';
  static const colRunningCount = 'Laufende Nr.';
  static const colLapDuration = 'Rundendauer';
  static const colLabel = 'Label';
  static const colPerson = 'Person';
  static const colSubstance = 'Substanz';
  static const colAmount = 'Menge';

  // ------------------------------------------------------------- protocol
  static const protocolEmpty = 'Noch kein Eintrag';
  static const protocolNewEntry = 'Neuer Eintrag';
  static const protocolEditEntry = 'Eintrag bearbeiten';
  static const protocolWho = 'Wer';
  static const protocolWhat = 'Was';
  static const protocolAmount = 'Menge';
  static const protocolAmountHint = 'Freitext';
  static const protocolNote = 'Notiz';
  static const protocolTime = 'Zeitpunkt';
  static const protocolSaved = 'Eintrag gespeichert';
  static const protocolDeleted = 'Eintrag gelöscht';
  static const protocolNoPerson = 'Ohne Person';
  static const protocolNoSubstance = 'Ohne Angabe';
  static const protocolAddPerson = 'Person hinzufügen';
  static const protocolAddSubstance = 'Substanz hinzufügen';
  static const persons = 'Personen';
  static const substances = 'Substanzen';
  static const personName = 'Name der Person';
  static const substanceName = 'Name der Substanz';
  static const lockout = 'Frühestens wieder in';
  static const lockoutHint =
      'Eigener Mindestabstand. Die App gibt keine Werte vor.';
  static const lockoutNone = 'Kein Mindestabstand';

  /// "Alex · vor 1 h 42 min"
  static String protocolPersonSince(String person, String duration) =>
      '$person · vor $duration';

  /// "frühestens wieder in 2 h 18 min"
  static String lockoutRemaining(String duration) =>
      'frühestens wieder in $duration';

  // ------------------------------------------------------------- settings
  static const settingsTitle = 'Einstellungen';
  static const settingsAppearance = 'Darstellung';
  static const settingsBehaviour = 'Verhalten';
  static const settingsData = 'Daten';
  static const settingsPrivacy = 'Privatsphäre';
  static const settingsNotifications = 'Benachrichtigungen';
  static const settingsAbout = 'Über';

  // theme
  static const theme = 'Design';
  static const themeSystem = 'System';
  static const themeSystemHint = 'Folgt Hell/Dunkel des Geräts.';
  static const themeLight = 'Hell';
  static const themeDark = 'Dunkel';
  static const themeBlack = 'Schwarz';
  static const themeLightForSystem = 'Design bei hellem System';
  static const themeDarkForSystem = 'Design bei dunklem System';
  static const dynamicColor = 'Systemfarben verwenden';
  static const dynamicColorHint = 'Material You (Android 12 und neuer).';
  static const themeEditor = 'Design bearbeiten';
  static const themeCustom = 'Eigene Designs';
  static const themeNew = 'Neues Design';
  static const themeDuplicate = 'Als eigenes Design duplizieren';
  static const themeExport = 'Design exportieren';
  static const themeImport = 'Design importieren';
  static const themeImportFailed = 'Das ist keine gültige Design-Datei.';
  static const themeDeleted = 'Design gelöscht';
  static const themePreview = 'Vorschau';
  static const themePresetReadOnly =
      'Vorlagen lassen sich nicht ändern – dupliziere sie zuerst.';
  static String themeCopyName(String name) => '$name (Kopie)';
  static const tokenBrightness = 'Helligkeit';
  static const tokenBackground = 'Hintergrund';
  static const tokenSurface = 'Fläche';
  static const tokenSurfaceAlt = 'Fläche (abgesetzt)';
  static const tokenPrimary = 'Akzent';
  static const tokenOnPrimary = 'Auf Akzent';
  static const tokenText = 'Text';
  static const tokenTextMuted = 'Text (gedämpft)';
  static const tokenBorder = 'Rahmen';
  static const tokenDanger = 'Gefahr';
  static const tokenSuccess = 'Erfolg';
  static const tokenWarning = 'Warnung';
  static const tokenTrackPalette = 'Spurfarben';
  static const tokenFontFamily = 'Schrift';
  static const tokenDigitTabular = 'Ziffern gleich breit';
  static const tokenDigitMonospace = 'Ziffern in Festbreitenschrift';
  static const tokenDigitWeight = 'Strichstärke der Ziffern';
  static const tokenCornerRadius = 'Eckenradius';
  static const tokenBorderWidth = 'Rahmenstärke';
  static const fontSystem = 'System';
  static const fontSerif = 'Serif';
  static const fontMono = 'Monospace';
  static const fontCondensed = 'Schmal';

  /// Display name of a font choice id (see `TikkyFonts.choices`).
  static String fontName(String id) => switch (id) {
    'serif' => fontSerif,
    'mono' => fontMono,
    'condensed' => fontCondensed,
    _ => fontSystem,
  };

  // ui prefs
  static const prefLayout = 'Anordnung';
  static const prefLayoutRows = 'Zeilen';
  static const prefLayoutTiles = 'Kacheln';
  static const prefDensity = 'Dichte';
  static const prefDensityCompact = 'Kompakt';
  static const prefDensityNormal = 'Normal';
  static const prefDensityRoomy = 'Luftig';
  static const prefDigitScale = 'Größe der Ziffern';
  static const prefButtonScale = 'Größe der Knöpfe';
  static const prefShowTenths = 'Zehntelsekunden anzeigen';
  static const prefShowProgress = 'Fortschritt in der Spur zeigen';
  static const prefShowSubLine = 'Zusatzzeile anzeigen';
  static const prefLeftHanded = 'Linkshänder-Layout';
  static const prefLeftHandedHint = 'Hauptknopf auf der linken Seite.';
  static const prefHaptics = 'Haptisches Feedback';
  static const prefKeepScreenOn = 'Bildschirm anlassen';
  static const prefUse24h = '24-Stunden-Format';
  static const setOverrides = 'Für dieses Set anpassen';
  static const setOverrideTheme = 'Eigenes Design für dieses Set';
  static const setOverridePrefs = 'Eigene Darstellung für dieses Set';
  static const useAppDefault = 'App-Standard verwenden';

  // privacy / lock
  static const appLock = 'App-Sperre';
  static const appLockHint =
      'Entsperren mit Biometrie oder Geräte-PIN beim Öffnen.';
  static const appLockUnavailable = 'Auf diesem Gerät nicht verfügbar.';
  static const appLockReason = 'Entsperre Tikky Takka';
  static const appLocked = 'Gesperrt';
  static const unlock = 'Entsperren';

  // notifications
  static const notificationsPermission = 'Benachrichtigungen erlauben';
  static const notificationsPermissionHint =
      'Damit Timer und Erinnerungen auch klingeln, wenn die App zu ist.';
  static const exactAlarmsPermission = 'Genaue Alarme erlauben';
  static const exactAlarmsPermissionHint =
      'Damit Alarme auf die Sekunde pünktlich kommen.';
  static const notificationsUnsupported =
      'Auf diesem Gerät sind keine Hintergrund-Alarme möglich.';
  static const permissionGranted = 'Erlaubt';
  static const permissionMissing = 'Nicht erlaubt';
  static const notifChannelName = 'Timer und Erinnerungen';
  static const notifChannelDescription =
      'Alarme für abgelaufene Timer, Intervalle und Erinnerungen.';
  static String notifCountdownDone(String track) => '$track ist abgelaufen';
  static String notifCountdownCycle(String track, int n) =>
      '$track: Durchlauf $n fertig';
  static String notifIntervalWork(String track, int round) =>
      '$track: Runde $round – los!';
  static String notifIntervalRest(String track, int round) =>
      '$track: Pause nach Runde $round';
  static String notifIntervalDone(String track) => '$track: geschafft';
  static String notifReminderDue(String track) => track;
  static String notifReminderNag(String track) => '$track – noch offen';
  static const notifActionDismiss = 'Stopp';
  static const notifActionAck = 'Erledigt';

  // about
  static const aboutLocalOnly =
      'Alle Daten bleiben auf diesem Gerät. Keine Konten, keine Cloud.';
  static const version = 'Version';

  // ---------------------------------------------------- adaptive / pickers
  static const pickDuration = 'Dauer wählen';
  static const pickDate = 'Datum wählen';
  static const pickTime = 'Uhrzeit wählen';
  static const pickColor = 'Farbe wählen';
  static const hexColor = 'Hex-Farbwert';
}
