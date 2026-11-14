import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../clock.dart';
import '../domain/domain.dart';
import '../engine/engine.dart';
import '../repo/repo.dart';
import 'export_service.dart';

/// Hands a generated file to the OS and picks files to import. Split from
/// [ExportServiceImpl] so that everything else can be tested without
/// plugins.
abstract class ExportDelivery {
  /// Shares or saves [file]. Returns `false` when the user cancelled.
  Future<bool> deliver(ExportFile file, {Rect? sharePositionOrigin});

  /// Lets the user pick a JSON file and returns its text; `null` when
  /// cancelled.
  Future<String?> pickJsonFile();
}

/// The real [ExportService]: reads through the repositories, formats with
/// the pure [ExportFormat] functions and delivers through an
/// [ExportDelivery].
///
/// Register in `main.dart`:
/// `exportServiceProvider.overrideWith(ExportServiceImpl.fromRef)`.
class ExportServiceImpl implements ExportService {
  ExportServiceImpl({
    required this._history,
    required this._backup,
    required this._people,
    required this._settings,
    required this._clock,
    ExportDelivery? delivery,
  }) : _delivery = delivery ?? const PlatformExportDelivery();

  /// Wires the service to the app's providers.
  /// [delivery] replaces the share sheet / save dialog (tests).
  factory ExportServiceImpl.fromRef(Ref ref, {ExportDelivery? delivery}) =>
      ExportServiceImpl(
        history: ref.watch(historyRepositoryProvider),
        backup: ref.watch(backupRepositoryProvider),
        people: ref.watch(peopleRepositoryProvider),
        settings: ref.watch(settingsStoreProvider),
        clock: ref.watch(clockProvider),
        delivery: delivery,
      );

  final HistoryRepository _history;
  final BackupRepository _backup;
  final PeopleRepository _people;
  final SettingsStore _settings;
  final Clock _clock;
  final ExportDelivery _delivery;

  /// The sessions an export covers: the active filter, with the protocol
  /// decision taken from the explicit opt-in and nothing else.
  Future<List<HistorySession>> _sessions(ExportOptions options) =>
      _history.getSessions(
        options.filter.copyWith(includeProtocol: options.includeProtocol),
      );

  ExportFile _file(ExportKind kind, Uint8List bytes) => ExportFile(
    fileName: ExportFormat.fileName(kind, _clock.nowMs()),
    mimeType: kind.mimeType,
    bytes: bytes,
  );

  @override
  Future<ExportFile> buildSessionsCsv(ExportOptions options) async {
    final sessions = await _sessions(options);
    return _file(
      ExportKind.sessionsCsv,
      ExportFormat.csvBytes(
        ExportFormat.sessionsHeader,
        ExportFormat.sessionRows(sessions),
        separator: options.separator,
      ),
    );
  }

  @override
  Future<ExportFile> buildEventsCsv(ExportOptions options) async {
    final sessions = await _sessions(options);
    // Names are only needed (and only read) when protocol tracks are part
    // of the export.
    var personNames = const <String, String>{};
    var substanceNames = const <String, String>{};
    if (options.includeProtocol) {
      personNames = {
        for (final Person p in await _people.getPersons(includeArchived: true))
          p.id: p.name,
      };
      substanceNames = {
        for (final Substance s in await _people.getSubstances(
          includeArchived: true,
        ))
          s.id: s.name,
      };
    }
    return _file(
      ExportKind.eventsCsv,
      ExportFormat.csvBytes(
        ExportFormat.eventsHeader,
        ExportFormat.eventRows(
          sessions,
          personNames: personNames,
          substanceNames: substanceNames,
        ),
        separator: options.separator,
      ),
    );
  }

  @override
  Future<ExportFile> buildJsonBackup(ExportOptions options) async {
    final data = await _backup.readAll(
      filter: options.filter,
      includeProtocol: options.includeProtocol,
    );
    return _file(ExportKind.backupJson, ExportFormat.backupBytes(data));
  }

  @override
  Future<ImportReport> importJsonBackup(String json) async {
    final data = ExportFormat.decodeBackup(json);
    final report = await _backup.merge(data);
    await _settings.reload();
    return report;
  }

  @override
  Future<bool> deliver(ExportFile file, {Rect? sharePositionOrigin}) =>
      _delivery.deliver(file, sharePositionOrigin: sharePositionOrigin);

  @override
  Future<String?> pickJsonFile() => _delivery.pickJsonFile();
}

/// Delivery through the OS: the native share sheet on Android / iOS
/// (share_plus), the native "save as" dialog on Windows / macOS / Linux
/// (file_picker), and the native "open" dialog for imports.
class PlatformExportDelivery implements ExportDelivery {
  const PlatformExportDelivery();

  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> deliver(ExportFile file, {Rect? sharePositionOrigin}) async {
    if (_isMobile) {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              file.bytes,
              mimeType: file.mimeType,
              name: file.fileName,
            ),
          ],
          // XFile.fromData ignores the name off the web; this keeps it.
          fileNameOverrides: [file.fileName],
          subject: file.fileName,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return result.status != ShareResultStatus.dismissed;
    }
    final saved = await FilePicker.saveFile(
      fileName: file.fileName,
      bytes: file.bytes,
      mimeType: file.mimeType,
    );
    return saved != null;
  }

  @override
  Future<String?> pickJsonFile() async {
    // Android document providers often report .json files with a generic
    // MIME type, which an extension filter would grey out.
    final filterByExtension =
        kIsWeb || defaultTargetPlatform != TargetPlatform.android;
    final picked = await FilePicker.pickFile(
      type: filterByExtension ? FileType.custom : FileType.any,
      allowedExtensions: filterByExtension ? const ['json'] : null,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return utf8.decode(bytes, allowMalformed: true);
  }
}
