import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/services/export_service.dart';
import '../../core/services/settings_refresh.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'settings_strings.dart';
import 'theme_actions.dart';

enum _ExportKind { sessions, events, backup }

/// FALLBACK export entry point of the settings screen, used while
/// `SettingsHooks.openExport` is not wired to the real export sheet.
///
/// Exports everything (no history filter) through `exportServiceProvider`
/// with the CSV separator from the preferences. Protocol tracks are never
/// included here: their explicit opt-in lives in the export sheet.
Future<void> runDefaultExport(BuildContext context, WidgetRef ref) async {
  final kind = await showAdaptiveActionSheet<_ExportKind>(
    context,
    title: Strings.exportTitle,
    message: SettingsStrings.dataExportProtocolNote,
    actions: const [
      AdaptiveSheetAction(
        value: _ExportKind.sessions,
        label: Strings.exportSessionsCsv,
      ),
      AdaptiveSheetAction(
        value: _ExportKind.events,
        label: Strings.exportEventsCsv,
      ),
      AdaptiveSheetAction(
        value: _ExportKind.backup,
        label: Strings.exportBackupJson,
      ),
    ],
  );
  if (kind == null || !context.mounted) return;
  final service = ref.read(exportServiceProvider);
  final options = ExportOptions(
    separator: ref.read(uiPrefsProvider).csvSeparator,
  );
  final origin = shareOriginOf(context);
  try {
    final file = switch (kind) {
      _ExportKind.sessions => await service.buildSessionsCsv(options),
      _ExportKind.events => await service.buildEventsCsv(options),
      _ExportKind.backup => await service.buildJsonBackup(options),
    };
    final delivered = await service.deliver(file, sharePositionOrigin: origin);
    if (!context.mounted) return;
    showInfoSnackBar(
      context,
      delivered ? Strings.exportDone : SettingsStrings.exportCancelled,
    );
  } catch (_) {
    if (context.mounted) showInfoSnackBar(context, Strings.exportFailed);
  }
}

/// FALLBACK backup import of the settings screen, used while
/// `SettingsHooks.openImport` is not wired: native file dialog, then a
/// merge by id through `exportServiceProvider` (never destroys data).
Future<void> runDefaultImport(BuildContext context, WidgetRef ref) async {
  final service = ref.read(exportServiceProvider);
  final String? source;
  try {
    source = await service.pickJsonFile();
  } catch (_) {
    if (context.mounted) {
      showInfoSnackBar(context, SettingsStrings.dataUnavailable);
    }
    return;
  }
  if (source == null) return;
  try {
    final report = await service.importJsonBackup(source);
    refreshSettingsAfterImport(ref);
    if (!context.mounted) return;
    showInfoSnackBar(
      context,
      '${Strings.importDone}: ${Strings.importSummary(report.insertedTotal, report.updatedTotal, report.skippedTotal)}',
    );
  } on FormatException {
    if (context.mounted) {
      await showAdaptiveAlert(
        context,
        title: Strings.importFailed,
        message: Strings.importInvalidFile,
      );
    }
  } catch (_) {
    if (context.mounted) showInfoSnackBar(context, Strings.importFailed);
  }
}
