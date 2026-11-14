import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/core.dart';
import '../../core/services/settings_refresh.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'history_filter_logic.dart';
import 'history_strings.dart';

/// Opens the export sheet: "Sitzungen" CSV, "Ereignisse" CSV or the JSON
/// backup, plus the import of a JSON backup.
///
/// * The export covers the sessions of the active history filter
///   (`historyFilterProvider`).
/// * Protocol tracks are left out unless the switch in the sheet is turned
///   on; it is off every time the sheet opens.
/// * The CSV separator comes from the UI preferences.
/// * Files go to the native share sheet on phones and the native "save as"
///   dialog on desktop (`ExportService.deliver`).
///
/// Can be opened from anywhere (history app bar, settings "Daten").
Future<void> showExportSheet(BuildContext context) async {
  final result = await showAdaptiveSheet<_ExportSheetResult>(
    context,
    builder: (context) => const _ExportSheet(),
  );
  // Snackbars would hide behind the sheet, so success is reported once it
  // has closed.
  if (result == _ExportSheetResult.exported && context.mounted) {
    showInfoSnackBar(context, Strings.exportDone);
  }
}

enum _ExportSheetResult { exported, imported }

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet();

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  /// Explicit opt-in, never remembered.
  bool _includeProtocol = false;
  bool _busy = false;

  /// Where the share popover is anchored on tablets: the tapped row.
  static Rect? _originOf(BuildContext rowContext) {
    final box = rowContext.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _export(ExportKind kind, BuildContext rowContext) async {
    if (_busy) return;
    final service = ref.read(exportServiceProvider);
    final options = ExportOptions(
      filter: ref.read(historyFilterProvider),
      includeProtocol: _includeProtocol,
      separator: ref.read(uiPrefsProvider).csvSeparator,
    );
    final origin = _originOf(rowContext);
    setState(() => _busy = true);
    try {
      final file = await switch (kind) {
        ExportKind.sessionsCsv => service.buildSessionsCsv(options),
        ExportKind.eventsCsv => service.buildEventsCsv(options),
        ExportKind.backupJson => service.buildJsonBackup(options),
      };
      final delivered = await service.deliver(
        file,
        sharePositionOrigin: origin,
      );
      if (!mounted) return;
      // Cancelled: the sheet stays open for another try.
      if (delivered) Navigator.of(context).pop(_ExportSheetResult.exported);
    } catch (_) {
      if (!mounted) return;
      await showAdaptiveAlert(
        context,
        title: Strings.exportFailed,
        message: Strings.errorGeneric,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    final service = ref.read(exportServiceProvider);
    setState(() => _busy = true);
    try {
      final source = await service.pickJsonFile();
      if (source == null) return;
      final report = await service.importJsonBackup(source);
      refreshSettingsAfterImport(ref);
      if (!mounted) return;
      await showAdaptiveAlert(
        context,
        title: Strings.importDone,
        message: describeImport(report),
      );
      if (mounted) Navigator.of(context).pop(_ExportSheetResult.imported);
    } on FormatException {
      if (!mounted) return;
      await showAdaptiveAlert(
        context,
        title: Strings.importFailed,
        message: Strings.importInvalidFile,
      );
    } catch (_) {
      if (!mounted) return;
      await showAdaptiveAlert(
        context,
        title: Strings.importFailed,
        message: Strings.errorGeneric,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final filter = ref.watch(historyFilterProvider);
    final separator = ref.watch(uiPrefsProvider.select((p) => p.csvSeparator));
    final description = HistoryFilterLogic.describe(
      filter,
      nowMs: ref.watch(clockProvider).nowMs(),
      sets: ref.watch(allSetsProvider).value ?? const [],
      tracks: ref.watch(allTracksProvider).value ?? const [],
    );

    Widget exportTile(ExportKind kind, String title, String hint) => Builder(
      builder: (rowContext) => AdaptiveTile(
        leading: Icon(AdaptiveIcons.export(context)),
        title: title,
        subtitle: hint,
        onTap: _busy ? null : () => _export(kind, rowContext),
      ),
    );

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.space.page,
              0,
              t.space.page,
              t.space.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(Strings.exportTitle, style: t.text.title),
                  ),
                ),
                if (_busy)
                  Semantics(
                    label: HistoryStrings.exportBusy,
                    child: SizedBox.square(
                      dimension: t.sizes.iconMd,
                      child: const AdaptiveProgress(),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.page),
            child: Text(
              description == null
                  ? HistoryStrings.exportAllSessions
                  : HistoryStrings.exportFilter(description),
              style: t.text.caption,
            ),
          ),
          SizedBox(height: t.space.sm),
          AdaptiveSwitchTile(
            title: Strings.exportIncludeProtocol,
            subtitle: Strings.exportIncludeProtocolHint,
            value: _includeProtocol,
            onChanged: _busy
                ? null
                : (value) => setState(() => _includeProtocol = value),
          ),
          Divider(height: t.sizes.hairline),
          exportTile(
            ExportKind.sessionsCsv,
            Strings.exportSessionsCsv,
            HistoryStrings.exportSessionsHint,
          ),
          exportTile(
            ExportKind.eventsCsv,
            Strings.exportEventsCsv,
            HistoryStrings.exportEventsHint,
          ),
          exportTile(
            ExportKind.backupJson,
            Strings.exportBackupJson,
            HistoryStrings.exportBackupHint,
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              t.space.page,
              t.space.xs,
              t.space.page,
              t.space.sm,
            ),
            child: Text(
              HistoryStrings.separatorInfo(switch (separator) {
                CsvSeparator.semicolon => Strings.csvSemicolon,
                CsvSeparator.comma => Strings.csvComma,
              }),
              style: t.text.caption,
            ),
          ),
          Divider(height: t.sizes.hairline),
          AdaptiveTile(
            leading: Icon(AdaptiveIcons.import(context)),
            title: Strings.importBackupJson,
            subtitle: HistoryStrings.importHint,
            onTap: _busy ? null : _import,
          ),
          SizedBox(height: t.space.sm),
        ],
      ),
    );
  }
}

/// The merge summary shown after an import: totals first, then one line
/// per table that was touched.
String describeImport(ImportReport report) {
  if (report.insertedTotal == 0 && report.updatedTotal == 0) {
    return HistoryStrings.importNothingNew;
  }
  final lines = [
    Strings.importSummary(
      report.insertedTotal,
      report.updatedTotal,
      report.skippedTotal,
    ),
    '',
    for (final table in ImportReport.tables)
      if ((report.inserted[table] ?? 0) +
              (report.updated[table] ?? 0) +
              (report.skipped[table] ?? 0) >
          0)
        HistoryStrings.importRow(
          HistoryStrings.tableName(table),
          Strings.importSummary(
            report.inserted[table] ?? 0,
            report.updated[table] ?? 0,
            report.skipped[table] ?? 0,
          ),
        ),
  ];
  return lines.join('\n');
}
