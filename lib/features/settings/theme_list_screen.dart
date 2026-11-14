import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'settings_strings.dart';
import 'theme_actions.dart';
import 'theme_editor_screen.dart';
import 'widgets/setting_rows.dart';

enum _ThemeAction { use, edit, duplicate, rename, export, delete }

/// "Designs": the presets and the user's own themes, with duplicate,
/// rename, delete, export and import. Custom themes open in the editor;
/// presets are read-only and are duplicated first.
class ThemeListScreen extends ConsumerWidget {
  const ThemeListScreen({super.key});

  static Future<void> _openEditor(BuildContext context, String themeId) =>
      pushAdaptivePage<void>(
        context,
        builder: (_) => ThemeEditorScreen(themeId: themeId),
      );

  static Future<void> _duplicate(
    BuildContext context,
    WidgetRef ref,
    TikkyTheme theme,
  ) async {
    final copy = await ref.read(customThemesProvider.notifier).duplicate(theme);
    if (context.mounted) await _openEditor(context, copy.id);
  }

  static Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    TikkyTheme theme,
  ) async {
    final preset = ThemePresets.isPresetId(theme.id);
    final action = await showAdaptiveActionSheet<_ThemeAction>(
      context,
      title: theme.name,
      message: preset ? Strings.themePresetReadOnly : null,
      actions: [
        AdaptiveSheetAction(
          value: _ThemeAction.use,
          label: SettingsStrings.themeUse,
          icon: AdaptiveIcons.check(context),
        ),
        if (!preset)
          AdaptiveSheetAction(
            value: _ThemeAction.edit,
            label: Strings.edit,
            icon: AdaptiveIcons.edit(context),
          ),
        AdaptiveSheetAction(
          value: _ThemeAction.duplicate,
          label: preset ? Strings.themeDuplicate : Strings.duplicate,
          icon: AdaptiveIcons.copy(context),
        ),
        if (!preset)
          AdaptiveSheetAction(
            value: _ThemeAction.rename,
            label: Strings.rename,
            icon: AdaptiveIcons.note(context),
          ),
        AdaptiveSheetAction(
          value: _ThemeAction.export,
          label: Strings.themeExport,
          icon: AdaptiveIcons.export(context),
        ),
        if (!preset)
          AdaptiveSheetAction(
            value: _ThemeAction.delete,
            label: Strings.delete,
            icon: AdaptiveIcons.delete(context),
            destructive: true,
          ),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case _ThemeAction.use:
        await ref.read(themeSettingsProvider.notifier).selectTheme(theme.id);
        if (context.mounted) {
          showInfoSnackBar(context, SettingsStrings.themeApplied);
        }
      case _ThemeAction.edit:
        await _openEditor(context, theme.id);
      case _ThemeAction.duplicate:
        await _duplicate(context, ref, theme);
      case _ThemeAction.rename:
        final name = await showAdaptiveTextPrompt(
          context,
          title: Strings.rename,
          initialValue: theme.name,
          hint: SettingsStrings.themeName,
        );
        if (name != null) {
          await ref.read(customThemesProvider.notifier).rename(theme.id, name);
        }
      case _ThemeAction.export:
        await exportThemeFile(context, ref, theme);
      case _ThemeAction.delete:
        await deleteThemeWithUndo(context, ref, theme);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final custom = ref.watch(customThemesProvider);
    final activeId = ref.watch(appThemeProvider).id;

    Widget row(TikkyTheme theme) => _ThemeRow(
      theme: theme,
      active: theme.id == activeId,
      onTap: ThemePresets.isPresetId(theme.id)
          ? () => _showActions(context, ref, theme)
          : () => _openEditor(context, theme.id),
      onMore: () => _showActions(context, ref, theme),
    );

    return AdaptivePageScaffold(
      title: const Text(SettingsStrings.themesTitle),
      actions: [
        AdaptiveIconButton(
          icon: AdaptiveIcons.import(context),
          semanticLabel: Strings.themeImport,
          onPressed: () => importThemeFile(context, ref),
        ),
        AdaptiveIconButton(
          icon: AdaptiveIcons.add(context),
          semanticLabel: Strings.themeNew,
          onPressed: () => _duplicate(context, ref, ref.read(appThemeProvider)),
        ),
      ],
      body: SettingsBody(
        children: [
          AdaptiveSection(
            header: SettingsStrings.themePresets,
            footer: Strings.themePresetReadOnly,
            children: [for (final theme in ThemePresets.all) row(theme)],
          ),
          AdaptiveSection(
            header: Strings.themeCustom,
            children: [
              if (custom.isEmpty)
                Padding(
                  padding: EdgeInsets.all(t.space.page),
                  child: Text(
                    SettingsStrings.themeCustomEmpty,
                    style: t.text.bodyMuted,
                  ),
                ),
              for (final theme in custom) row(theme),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.theme,
    required this.active,
    required this.onTap,
    required this.onMore,
  });

  final TikkyTheme theme;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final brightness = theme.isDark
        ? SettingsStrings.themeDim
        : SettingsStrings.themeBright;
    return ListTile(
      leading: ThemeChip(theme: theme),
      title: Text(theme.name),
      subtitle: Text(
        active ? '${SettingsStrings.themeInUse} · $brightness' : brightness,
      ),
      trailing: AdaptiveIconButton(
        icon: AdaptiveIcons.more(context),
        semanticLabel: SettingsStrings.themeActionsFor(theme.name),
        onPressed: onMore,
      ),
      onTap: onTap,
    );
  }
}

/// A tiny picture of a theme: its background with the accent and the first
/// two track colours as dots.
class ThemeChip extends StatelessWidget {
  const ThemeChip({required this.theme, super.key});

  final TikkyTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    Widget dot(Color color) => Container(
      width: t.sizes.dot,
      height: t.sizes.dot,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return ExcludeSemantics(
      child: Container(
        width: t.sizes.iconXl,
        height: t.sizes.iconXl,
        decoration: BoxDecoration(
          color: theme.colors.background,
          borderRadius: t.radii.smAll,
          border: Border.all(color: t.colors.border, width: t.sizes.hairline),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            dot(theme.colors.primary),
            SizedBox(width: t.space.xxs),
            dot(theme.paletteColor(0)),
            SizedBox(width: t.space.xxs),
            dot(theme.paletteColor(1)),
          ],
        ),
      ),
    );
  }
}
