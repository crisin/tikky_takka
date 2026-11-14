import '../../core/domain/enums.dart';

/// German UI text of the history feature that is not (yet) part of
/// `lib/l10n/strings.dart`. Same rules as there: no user-facing literal in
/// a widget.
abstract final class HistoryStrings {
  // ------------------------------------------------------------- filter
  static const presetThisWeek = 'Diese Woche';
  static const presetLast7Days = 'Letzte 7 Tage';
  static const presetThisMonth = 'Dieser Monat';
  static const presetLastMonth = 'Letzter Monat';
  static const presetCustom = 'Eigener Zeitraum …';

  /// "01.11.2026 – 11.11.2026"
  static String dateRange(String from, String to) => '$from – $to';

  /// "ab 01.11.2026"
  static String dateFrom(String from) => 'ab $from';

  /// "bis 11.11.2026"
  static String dateUntil(String to) => 'bis $to';

  static String tracksSelected(int n) => n == 1 ? '1 Spur' : '$n Spuren';
  static const archivedSuffix = 'archiviert';
  static const filterTracksTitle = 'Spuren filtern';
  static const filterSetTitle = 'Set filtern';


  // --------------------------------------------------------------- list
  static const view = 'Ansicht';
  static const sessionActions = 'Aktionen zur Sitzung';
  static const eventActions = 'Aktionen zum Ereignis';
  static const addNote = 'Notiz hinzufügen';
  static const eventNote = 'Notiz zum Ereignis';
  static const noteSaved = 'Notiz gespeichert';
  static const sessionGone = 'Diese Sitzung gibt es nicht mehr.';
  static const sessionRunning = 'läuft noch';

  /// "09:00 – 09:20"
  static String timeRange(String from, String to) => '$from – $to';

  /// The "laps / count" figure of a session in words, by mode.
  static String countLabel(TrackMode mode, int n) => switch (mode) {
    TrackMode.stopwatch ||
    TrackMode.interval => n == 1 ? '1 Runde' : '$n Runden',
    TrackMode.countdown => n == 1 ? '1 Durchlauf' : '$n Durchläufe',
    TrackMode.counter => n == 1 ? '1 Tipp' : '$n Tipps',
    TrackMode.reminder => '$n× bestätigt',
    TrackMode.protocol => n == 1 ? '1 Eintrag' : '$n Einträge',
  };

  /// "Tagessumme 1 h 42 min"
  static String total(String label, String duration) => '$label $duration';

  /// "KW 46 · 09.11.2026 – 15.11.2026"
  static String week(int number, String from, String to) =>
      'KW $number · $from – $to';

  // ------------------------------------------------------------- detail
  static String tickNumber(int n) => 'Tipp $n';
  static String entryNumber(int n) => 'Eintrag $n';
  static const ackOnTime = 'pünktlich bestätigt';

  /// "3 min nach Fälligkeit bestätigt"
  static String ackDelayed(String duration) =>
      '$duration nach Fälligkeit bestätigt';

  /// "Label · Detail"
  static String joined(Iterable<String> parts) =>
      parts.where((p) => p.isNotEmpty).join(' · ');
  static const editEntry = 'Eintrag bearbeiten';
  static const sessionSummary = 'Überblick';

  // ------------------------------------------------------------- export
  static const exportAllSessions = 'Kein Filter aktiv: alle Sitzungen.';

  /// "Der Export berücksichtigt den Filter: Heute · Büro"
  static String exportFilter(String description) =>
      'Der Export berücksichtigt den Filter: $description';

  /// "CSV-Trennzeichen: Semikolon (Excel, deutsch)"
  static String separatorInfo(String name) => 'CSV-Trennzeichen: $name';
  static const exportSessionsHint = 'Eine Zeile pro Sitzung.';
  static const exportEventsHint = 'Eine Zeile pro Ereignis.';
  static const exportBackupHint =
      'Sets, Spuren, Sitzungen, Designs und Einstellungen.';
  static const importHint =
      'Fügt eine Sicherung hinzu. Vorhandene Daten bleiben erhalten.';
  static const exportBusy = 'Export wird erstellt';

  static const tableSets = 'Sets';
  static const tableTracks = 'Spuren';
  static const tableSessions = 'Sitzungen';
  static const tableEvents = 'Ereignisse';
  static const tablePersons = 'Personen';
  static const tableSubstances = 'Substanzen';
  static const tableSettings = 'Einstellungen';

  /// Display name of an `ImportReport` table key.
  static String tableName(String key) => switch (key) {
    'sets' => tableSets,
    'tracks' => tableTracks,
    'sessions' => tableSessions,
    'events' => tableEvents,
    'persons' => tablePersons,
    'substances' => tableSubstances,
    'settings' => tableSettings,
    _ => key,
  };

  /// "Spuren: 3 neu, 0 aktualisiert, 1 unverändert"
  static String importRow(String table, String summary) => '$table: $summary';
  static const importNothingNew =
      'Die Sicherung enthielt nichts Neues. Es wurde nichts verändert.';
}
