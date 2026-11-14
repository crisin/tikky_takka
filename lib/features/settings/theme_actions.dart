import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/services/export_service.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'color_utils.dart';
import 'settings_strings.dart';

/// Result of [showThemeChoiceSheet]: a theme id, or `null` for the
/// "no specific theme" entry (System / App-Standard).
@immutable
final class ThemeChoice {
  const ThemeChoice(this.themeId);

  final String? themeId;
}

/// Lets the user pick one of [themes] in the platform's action sheet.
///
/// With [nullLabel] the sheet starts with an extra entry that stands for
/// "no specific theme". Returns `null` when the sheet is dismissed.
Future<ThemeChoice?> showThemeChoiceSheet(
  BuildContext context, {
  required List<TikkyTheme> themes,
  required String? selectedId,
  required String title,
  String? nullLabel,
  String? message,
}) {
  return showAdaptiveActionSheet<ThemeChoice>(
    context,
    title: title,
    message: message,
    actions: [
      if (nullLabel != null)
        AdaptiveSheetAction(
          value: const ThemeChoice(null),
          label: nullLabel,
          selected: selectedId == null,
        ),
      for (final theme in themes)
        AdaptiveSheetAction(
          value: ThemeChoice(theme.id),
          label: theme.name,
          selected: theme.id == selectedId,
        ),
    ],
  );
}

/// Display name of the theme with [id]; the matching preset's name when the
/// id is unknown (e.g. a deleted custom theme).
String themeNameFor(
  List<TikkyTheme> themes,
  String id, {
  required TikkyTheme fallback,
}) => (findTheme(themes, id) ?? fallback).name;

/// The on-screen rectangle of [context]'s widget: anchor of the share
/// popover on tablets.
Rect? shareOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is RenderBox && box.hasSize) {
    return box.localToGlobal(Offset.zero) & box.size;
  }
  return null;
}

/// File name of an exported theme, e.g. `tikky-takka_design_mein-blau.json`.
String themeFileName(TikkyTheme theme) =>
    'tikky-takka_design_${fileSlug(theme.name)}.json';

/// Hands [theme] to the user as a JSON file: native share sheet on mobile,
/// native "save as" dialog on desktop (both through the export service).
/// Returns `true` when the file was delivered.
Future<bool> exportThemeFile(
  BuildContext context,
  WidgetRef ref,
  TikkyTheme theme,
) async {
  final content =
      ref.read(customThemesProvider.notifier).exportFile(theme.id) ??
      theme.toFileContent();
  final file = ExportFile(
    fileName: themeFileName(theme),
    mimeType: 'application/json',
    bytes: Uint8List.fromList(utf8.encode(content)),
  );
  final service = ref.read(exportServiceProvider);
  final origin = shareOriginOf(context);
  try {
    final delivered = await service.deliver(file, sharePositionOrigin: origin);
    if (delivered && context.mounted) {
      showInfoSnackBar(context, SettingsStrings.themeExported);
    }
    return delivered;
  } catch (_) {
    // No export service on this platform / in this build.
    if (context.mounted) {
      showInfoSnackBar(context, SettingsStrings.themeExportFailed);
    }
    return false;
  }
}

/// Lets the user pick a theme file with the native file dialog and adds it
/// as a new custom theme. Returns the imported theme, or `null` when
/// cancelled or invalid (the user is told why).
Future<TikkyTheme?> importThemeFile(BuildContext context, WidgetRef ref) async {
  final service = ref.read(exportServiceProvider);
  final notifier = ref.read(customThemesProvider.notifier);
  final String? source;
  try {
    source = await service.pickJsonFile();
  } catch (_) {
    if (context.mounted) {
      showInfoSnackBar(context, SettingsStrings.themeImportUnavailable);
    }
    return null;
  }
  if (source == null) return null;
  final theme = await notifier.importFile(source);
  if (!context.mounted) return theme;
  if (theme == null) {
    await showAdaptiveAlert(context, title: Strings.themeImportFailed);
    return null;
  }
  showInfoSnackBar(context, SettingsStrings.themeImported);
  return theme;
}

/// Deletes a custom theme and offers "Rückgängig" instead of asking first.
Future<bool> deleteThemeWithUndo(
  BuildContext context,
  WidgetRef ref,
  TikkyTheme theme,
) async {
  final notifier = ref.read(customThemesProvider.notifier);
  final deleted = await notifier.delete(theme.id);
  if (deleted == null) return false;
  if (context.mounted) {
    showUndoSnackBar(
      context,
      message: Strings.themeDeleted,
      onUndo: () => notifier.save(deleted),
    );
  }
  return true;
}
