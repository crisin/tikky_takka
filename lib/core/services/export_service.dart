import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:csv/csv.dart' show CsvEncoder, QuoteMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/formatters.dart';
import '../../l10n/strings.dart';
import '../../theme/ui_prefs.dart';
import '../domain/domain.dart';
import '../engine/engine.dart';
import '../repo/models.dart';

/// What to export.
final class ExportOptions {
  const ExportOptions({
    this.filter = HistoryFilter.all,
    this.includeProtocol = false,
    this.separator = CsvSeparator.semicolon,
  });

  /// The active history filter ("export honours the filter"). Its own
  /// `includeProtocol` flag is ignored by exports: [includeProtocol] below
  /// decides.
  final HistoryFilter filter;

  /// Explicit opt-in for protocol tracks. `false` by default: protocol
  /// sessions, entries, persons and substances are then left out of EVERY
  /// export.
  final bool includeProtocol;

  /// CSV field separator (semicolon for German Excel).
  final CsvSeparator separator;

  ExportOptions copyWith({
    HistoryFilter? filter,
    bool? includeProtocol,
    CsvSeparator? separator,
  }) => ExportOptions(
    filter: filter ?? this.filter,
    includeProtocol: includeProtocol ?? this.includeProtocol,
    separator: separator ?? this.separator,
  );
}

/// A generated file, ready to be shared or saved.
final class ExportFile {
  const ExportFile({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
  });

  /// e.g. `tikky-takka_sitzungen_2026-11-11_2105.csv`
  final String fileName;

  /// `text/csv` or `application/json`.
  final String mimeType;

  /// File content. CSV: UTF-8 WITH BOM.
  final Uint8List bytes;
}

/// CSV / JSON export and JSON import.
///
/// The real implementation is `ExportServiceImpl` in
/// `export_service_impl.dart`; it is registered in `main.dart`
/// (`productionOverrides`) with
/// `exportServiceProvider.overrideWith(ExportServiceImpl.fromRef)`.
///
/// The file CONTENT is produced by the pure functions of [ExportFormat]
/// below; reading the database and handing the file to the OS live in the
/// implementation.
abstract class ExportService {
  /// CSV "Sessions": one row per session - set, track, mode, start (ISO
  /// local with UTC offset), end, net duration (hh:mm:ss and seconds), paused seconds,
  /// laps / count, note.
  Future<ExportFile> buildSessionsCsv(ExportOptions options);

  /// CSV "Ereignisse": one row per event - time, set, track, mode, session
  /// id, type, running count, lap duration, label, person, substance,
  /// amount, note.
  Future<ExportFile> buildEventsCsv(ExportOptions options);

  /// JSON full backup (sets, tracks, config, sessions, events, persons,
  /// substances, themes, prefs) with a schema version.
  Future<ExportFile> buildJsonBackup(ExportOptions options);

  /// Merges a JSON backup into the database (by id, never destroying data)
  /// and refreshes the in-memory settings. Throws [FormatException] for
  /// files that are not a valid backup.
  Future<ImportReport> importJsonBackup(String json);

  /// Hands the file to the user: native share sheet on mobile, native
  /// "save as" dialog on desktop. [sharePositionOrigin] anchors the share
  /// popover on iPad. Returns `false` when the user cancelled.
  Future<bool> deliver(ExportFile file, {Rect? sharePositionOrigin});

  /// Lets the user pick a JSON file with the native file dialog and returns
  /// its content; `null` when cancelled.
  Future<String?> pickJsonFile();
}

/// Default when no implementation is registered (plain tests): every call
/// throws [UnimplementedError].
class UnimplementedExportService implements ExportService {
  const UnimplementedExportService();

  @override
  Future<ExportFile> buildSessionsCsv(ExportOptions options) =>
      throw UnimplementedError('ExportService.buildSessionsCsv');

  @override
  Future<ExportFile> buildEventsCsv(ExportOptions options) =>
      throw UnimplementedError('ExportService.buildEventsCsv');

  @override
  Future<ExportFile> buildJsonBackup(ExportOptions options) =>
      throw UnimplementedError('ExportService.buildJsonBackup');

  @override
  Future<ImportReport> importJsonBackup(String json) =>
      throw UnimplementedError('ExportService.importJsonBackup');

  @override
  Future<bool> deliver(ExportFile file, {Rect? sharePositionOrigin}) =>
      throw UnimplementedError('ExportService.deliver');

  @override
  Future<String?> pickJsonFile() =>
      throw UnimplementedError('ExportService.pickJsonFile');
}

/// The export service in use. Defaults to [UnimplementedExportService];
/// production registers `ExportServiceImpl`.
final exportServiceProvider = Provider<ExportService>(
  (ref) => const UnimplementedExportService(),
);

// ------------------------------------------------------------ file content

/// The kinds of files the export produces.
enum ExportKind {
  sessionsCsv('sitzungen', 'csv', 'text/csv'),
  eventsCsv('ereignisse', 'csv', 'text/csv'),
  backupJson('sicherung', 'json', 'application/json');

  const ExportKind(this.slug, this.extension, this.mimeType);

  /// Middle part of the file name.
  final String slug;
  final String extension;
  final String mimeType;
}

/// Pure generation of the export file content: rows, CSV text, JSON text
/// and bytes. No database, no plugins, no clock - everything is passed in,
/// so this is unit-testable on its own.
abstract final class ExportFormat {
  /// UTF-8 byte order mark; Excel needs it to recognise UTF-8 CSV files.
  static const List<int> utf8Bom = [0xEF, 0xBB, 0xBF];

  /// Line ending of CSV files (RFC 4180).
  static const String csvLineEnding = '\r\n';

  /// First part of every export file name.
  static const String fileNamePrefix = 'tikky-takka';

  /// e.g. `tikky-takka_sitzungen_2026-11-11_2105.csv` ([nowMs] in local
  /// time).
  static String fileName(ExportKind kind, int nowMs) =>
      '${fileNamePrefix}_${kind.slug}_${Fmt.fileStamp(nowMs)}.${kind.extension}';

  // ----------------------------------------------------------- sessions

  /// Column headers of the "Sitzungen" CSV.
  static const List<String> sessionsHeader = [
    Strings.colSet,
    Strings.colTrack,
    Strings.colMode,
    Strings.colStart,
    Strings.colEnd,
    Strings.colDuration,
    Strings.colDurationSeconds,
    Strings.colPausedSeconds,
    Strings.colCount,
    Strings.colNote,
  ];

  /// One row per session, oldest first: set, track, mode, start (ISO
  /// local with UTC offset), end, net duration `hh:mm:ss`, net seconds, paused seconds,
  /// laps / count, note. Without the header row.
  static List<List<Object>> sessionRows(Iterable<HistorySession> sessions) => [
    for (final s in _chronological(sessions))
      [
        s.set?.name ?? '',
        _trackName(s),
        Strings.modeName(s.session.mode),
        Fmt.isoLocalWithOffset(s.summary.startAt ?? s.session.startedAt),
        _isoOrEmpty(s.session.endedAt ?? s.summary.endAt),
        Fmt.hms(s.summary.netMs),
        s.summary.netMs ~/ 1000,
        s.summary.pausedMs ~/ 1000,
        s.summary.count,
        s.session.note ?? '',
      ],
  ];

  // ------------------------------------------------------------- events

  /// Column headers of the "Ereignisse" CSV.
  static const List<String> eventsHeader = [
    Strings.colTime,
    Strings.colSet,
    Strings.colTrack,
    Strings.colMode,
    Strings.colSessionId,
    Strings.colType,
    Strings.colRunningCount,
    Strings.colLapDuration,
    Strings.colLabel,
    Strings.colPerson,
    Strings.colSubstance,
    Strings.colAmount,
    Strings.colNote,
  ];

  /// One row per event in chronological order across all [sessions]: time
  /// (ISO local with UTC offset), set, track, mode, session id, type, running count, lap
  /// duration `hh:mm:ss`, label, person, substance, amount, note. Without
  /// the header row.
  ///
  /// The running count and the lap duration are per session (see
  /// `annotateEvents`). [personNames] and [substanceNames] map ids to
  /// display names; unknown ids show as "Unbekannt".
  static List<List<Object>> eventRows(
    Iterable<HistorySession> sessions, {
    Map<String, String> personNames = const {},
    Map<String, String> substanceNames = const {},
  }) {
    final entries = <(int, int, HistorySession, EventAnnotation)>[];
    var order = 0;
    for (final s in _chronological(sessions)) {
      for (final a in annotateEvents(s.events)) {
        entries.add((a.event.at, order++, s, a));
      }
    }
    // Chronological over all sessions; the running index keeps events with
    // equal timestamps in their session order.
    entries.sort((a, b) {
      final byTime = a.$1.compareTo(b.$1);
      return byTime != 0 ? byTime : a.$2.compareTo(b.$2);
    });

    String nameOf(String? id, Map<String, String> names) =>
        id == null ? '' : names[id] ?? Strings.unknown;

    return [
      for (final (_, _, s, a) in entries)
        [
          Fmt.isoLocalWithOffset(a.event.at),
          s.set?.name ?? '',
          _trackName(s),
          Strings.modeName(s.session.mode),
          s.session.id,
          Strings.eventTypeName(a.event.type),
          a.runningCount ?? '',
          a.lapMs == null ? '' : Fmt.hms(a.lapMs!),
          a.event.label ?? '',
          nameOf(a.event.personId, personNames),
          nameOf(a.event.substanceId, substanceNames),
          a.event.amount ?? '',
          a.event.note ?? '',
        ],
    ];
  }

  // ---------------------------------------------------------------- csv

  /// Encodes [rows] as CSV text with [separator], CRLF line endings and a
  /// trailing line ending. Fields are quoted only when needed (separator,
  /// quote, line break, leading / trailing blank); quotes are doubled.
  /// Text cells are made formula-safe with [csvSafeText].
  /// WITHOUT byte order mark - see [csvBytes].
  static String encodeCsv(
    List<List<Object?>> rows, {
    CsvSeparator separator = CsvSeparator.semicolon,
  }) {
    if (rows.isEmpty) return '';
    rows = [
      for (final row in rows)
        [for (final cell in row) cell is String ? csvSafeText(cell) : cell],
    ];
    final encoder = CsvEncoder(
      fieldDelimiter: separator.char,
      lineDelimiter: csvLineEnding,
      quoteMode: QuoteMode.necessary,
    );
    return '${encoder.convert(rows)}$csvLineEnding';
  }

  /// Defuses spreadsheet formula injection: a text cell whose first
  /// character (ignoring leading blanks, tabs and line breaks) is `=`, `+`,
  /// `-` or `@` would be evaluated as a formula by Excel / LibreOffice /
  /// Sheets, so it gets a leading apostrophe and is shown as text. So does
  /// a cell that starts with a tab or line break.
  ///
  /// Only strings pass through here: numeric cells are numbers, and the
  /// durations and timestamps the app generates start with a digit.
  static String csvSafeText(String text) {
    if (text.isEmpty) return text;
    var i = 0;
    while (i < text.length && _csvBlank.contains(text[i])) {
      i++;
    }
    final control = text[0] == '\t' || text[0] == '\r' || text[0] == '\n';
    final formula = i < text.length && _csvFormulaStart.contains(text[i]);
    return control || formula ? "'$text" : text;
  }

  static const _csvBlank = {' ', '\t', '\r', '\n', '\u{00A0}'};
  static const _csvFormulaStart = {'=', '+', '-', '@'};

  /// [header] plus [rows] as a CSV file: UTF-8 WITH byte order mark.
  static Uint8List csvBytes(
    List<String> header,
    List<List<Object?>> rows, {
    CsvSeparator separator = CsvSeparator.semicolon,
  }) {
    final text = encodeCsv([header, ...rows], separator: separator);
    return Uint8List.fromList([...utf8Bom, ...utf8.encode(text)]);
  }

  // --------------------------------------------------------------- json

  /// The backup as indented JSON text.
  static String encodeBackup(BackupData data) =>
      '${const JsonEncoder.withIndent('  ').convert(data.toJson())}\n';

  /// The backup as a JSON file: UTF-8 without byte order mark.
  static Uint8List backupBytes(BackupData data) =>
      Uint8List.fromList(utf8.encode(encodeBackup(data)));

  /// Parses the text of a backup file. A leading byte order mark is
  /// tolerated. Throws [FormatException] when [source] is not JSON, not a
  /// backup of this app, or from an incompatible newer version.
  static BackupData decodeBackup(String source) {
    final text = source.startsWith('\u{FEFF}') ? source.substring(1) : source;
    final Object? decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('Backup must be a JSON object');
    }
    return BackupData.fromJson(jsonMap(decoded));
  }

  // ------------------------------------------------------------ helpers

  static List<HistorySession> _chronological(
    Iterable<HistorySession> sessions,
  ) {
    final indexed = sessions.indexed.toList()
      ..sort((a, b) {
        final byStart = a.$2.session.startedAt.compareTo(
          b.$2.session.startedAt,
        );
        if (byStart != 0) return byStart;
        final byId = a.$2.session.id.compareTo(b.$2.session.id);
        return byId != 0 ? byId : a.$1.compareTo(b.$1);
      });
    return [for (final (_, s) in indexed) s];
  }

  static String _trackName(HistorySession s) =>
      s.track?.name ?? Strings.deletedTrack;

  static String _isoOrEmpty(int? ms) => ms == null ? '' : Fmt.isoLocalWithOffset(ms);
}
