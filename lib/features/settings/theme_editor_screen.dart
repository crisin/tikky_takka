import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'color_utils.dart';
import 'contrast.dart';
import 'settings_strings.dart';
import 'theme_actions.dart';
import 'widgets/color_picker.dart';
import 'widgets/setting_rows.dart';
import 'widgets/settings_icons.dart';
import 'widgets/theme_preview.dart';

/// One semantic colour of a theme: how to read and replace it.
@immutable
class _ColorToken {
  const _ColorToken(this.key, this.label, this.read, this.write);

  final String key;
  final String label;
  final Color Function(TikkyColors colors) read;
  final TikkyColors Function(TikkyColors colors, Color value) write;
}

final List<_ColorToken> _colorTokens = [
  _ColorToken(
    'background',
    Strings.tokenBackground,
    (c) => c.background,
    (c, v) => c.copyWith(background: v),
  ),
  _ColorToken(
    'surface',
    Strings.tokenSurface,
    (c) => c.surface,
    (c, v) => c.copyWith(surface: v),
  ),
  _ColorToken(
    'surfaceAlt',
    Strings.tokenSurfaceAlt,
    (c) => c.surfaceAlt,
    (c, v) => c.copyWith(surfaceAlt: v),
  ),
  _ColorToken(
    'primary',
    Strings.tokenPrimary,
    (c) => c.primary,
    (c, v) => c.copyWith(primary: v),
  ),
  _ColorToken(
    'onPrimary',
    Strings.tokenOnPrimary,
    (c) => c.onPrimary,
    (c, v) => c.copyWith(onPrimary: v),
  ),
  _ColorToken(
    'text',
    Strings.tokenText,
    (c) => c.text,
    (c, v) => c.copyWith(text: v),
  ),
  _ColorToken(
    'textMuted',
    Strings.tokenTextMuted,
    (c) => c.textMuted,
    (c, v) => c.copyWith(textMuted: v),
  ),
  _ColorToken(
    'border',
    Strings.tokenBorder,
    (c) => c.border,
    (c, v) => c.copyWith(border: v),
  ),
  _ColorToken(
    'danger',
    Strings.tokenDanger,
    (c) => c.danger,
    (c, v) => c.copyWith(danger: v),
  ),
  _ColorToken(
    'success',
    Strings.tokenSuccess,
    (c) => c.success,
    (c, v) => c.copyWith(success: v),
  ),
  _ColorToken(
    'warning',
    Strings.tokenWarning,
    (c) => c.warning,
    (c, v) => c.copyWith(warning: v),
  ),
];

enum _EditorAction { use, duplicate, export, delete }

/// The theme editor: every token of a custom theme, with a live preview of
/// sample lanes and a contrast warning.
///
/// Changes are saved as they are made (so they show at once wherever the
/// theme is in use); "Änderungen verwerfen" restores the theme as it was
/// when the editor opened.
class ThemeEditorScreen extends ConsumerStatefulWidget {
  const ThemeEditorScreen({required this.themeId, super.key});

  /// Id of a CUSTOM theme. Presets are read-only: duplicate them first.
  final String themeId;

  @override
  ConsumerState<ThemeEditorScreen> createState() => _ThemeEditorScreenState();
}

class _ThemeEditorScreenState extends ConsumerState<ThemeEditorScreen> {
  /// The theme as edited (may be ahead of the stored one mid-drag).
  TikkyTheme? _draft;

  /// The theme as it was when the editor opened.
  TikkyTheme? _original;

  /// The row whose colour picker is open: `color.<token>` or
  /// `palette.<index>`.
  String? _expanded;

  @override
  void initState() {
    super.initState();
    final theme = findTheme(ref.read(customThemesProvider), widget.themeId);
    _draft = theme;
    _original = theme;
  }

  /// Applies an edit to the preview and, unless [commit] is false (slider
  /// still moving), saves it.
  void _update(TikkyTheme next, {bool commit = true}) {
    setState(() => _draft = next);
    if (commit) {
      unawaited(ref.read(customThemesProvider.notifier).save(next));
    }
  }

  void _toggle(String key) =>
      setState(() => _expanded = _expanded == key ? null : key);

  /// Quick choices offered by the colour pickers: the colours the theme had
  /// when the editor opened (stable while editing), without duplicates.
  List<Color> get _swatches {
    final source = _original ?? _draft;
    if (source == null) return const [];
    final seen = <int>{};
    return [
      for (final color in [
        for (final token in _colorTokens) token.read(source.colors),
        ...source.trackPalette,
      ])
        if (seen.add(color.toARGB32())) color,
    ];
  }

  Future<void> _rename(TikkyTheme draft) async {
    final name = await showAdaptiveTextPrompt(
      context,
      title: Strings.rename,
      initialValue: draft.name,
      hint: SettingsStrings.themeName,
    );
    final current = _draft;
    if (name == null || current == null || !mounted) return;
    _update(current.copyWith(name: name));
  }

  Future<void> _pickFont(TikkyTheme draft) async {
    final choice = await showAdaptiveActionSheet<String>(
      context,
      title: Strings.tokenFontFamily,
      actions: [
        for (final id in TikkyFonts.choices)
          AdaptiveSheetAction(
            value: id,
            label: Strings.fontName(id),
            selected: id == draft.fontFamily,
          ),
      ],
    );
    final current = _draft;
    if (choice == null || current == null || !mounted) return;
    _update(current.copyWith(fontFamily: choice));
  }

  void _discardChanges() {
    final original = _original;
    final previous = _draft;
    if (original == null || previous == null) return;
    setState(() => _expanded = null);
    _update(original);
    showUndoSnackBar(
      context,
      message: SettingsStrings.themeChangesDiscarded,
      onUndo: () {
        if (mounted) {
          _update(previous);
        } else {
          unawaited(ref.read(customThemesProvider.notifier).save(previous));
        }
      },
    );
  }

  Future<void> _showActions(TikkyTheme draft) async {
    final action = await showAdaptiveActionSheet<_EditorAction>(
      context,
      title: draft.name,
      actions: [
        AdaptiveSheetAction(
          value: _EditorAction.use,
          label: SettingsStrings.themeUse,
          icon: AdaptiveIcons.check(context),
        ),
        AdaptiveSheetAction(
          value: _EditorAction.duplicate,
          label: Strings.duplicate,
          icon: AdaptiveIcons.copy(context),
        ),
        AdaptiveSheetAction(
          value: _EditorAction.export,
          label: Strings.themeExport,
          icon: AdaptiveIcons.export(context),
        ),
        AdaptiveSheetAction(
          value: _EditorAction.delete,
          label: Strings.delete,
          icon: AdaptiveIcons.delete(context),
          destructive: true,
        ),
      ],
    );
    final current = _draft;
    if (action == null || current == null || !mounted) return;
    switch (action) {
      case _EditorAction.use:
        await ref.read(themeSettingsProvider.notifier).selectTheme(current.id);
        if (mounted) showInfoSnackBar(context, SettingsStrings.themeApplied);
      case _EditorAction.duplicate:
        final copy = await ref
            .read(customThemesProvider.notifier)
            .duplicate(current);
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ThemeEditorScreen(themeId: copy.id),
          ),
        );
      case _EditorAction.export:
        await exportThemeFile(context, ref, current);
      case _EditorAction.delete:
        final deleted = await deleteThemeWithUndo(context, ref, current);
        if (deleted && mounted) Navigator.of(context).pop();
    }
  }

  // ---------------------------------------------------------------- palette

  void _setPalette(
    TikkyTheme draft,
    List<Color> palette, {
    bool commit = true,
  }) => _update(draft.copyWith(trackPalette: palette), commit: commit);

  void _addPaletteColor(TikkyTheme draft) {
    final palette = [...draft.trackPalette, draft.trackPalette.last];
    setState(() => _expanded = 'palette.${palette.length - 1}');
    _setPalette(draft, palette);
  }

  void _removePaletteColor(TikkyTheme draft, int index) {
    if (draft.trackPalette.length <= 1) return;
    final palette = [...draft.trackPalette]..removeAt(index);
    setState(() => _expanded = null);
    _setPalette(draft, palette);
    showUndoSnackBar(
      context,
      message: SettingsStrings.colorRemoved,
      onUndo: () {
        final current = _draft;
        if (mounted && current != null) {
          _setPalette(current, draft.trackPalette);
        }
      },
    );
  }

  void _movePaletteColor(TikkyTheme draft, int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= draft.trackPalette.length) return;
    final palette = [...draft.trackPalette];
    final color = palette.removeAt(index);
    palette.insert(target, color);
    setState(() => _expanded = 'palette.$target');
    _setPalette(draft, palette);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final draft = _draft;
    if (draft == null) {
      return AdaptivePageScaffold(
        title: const Text(Strings.themeEditor),
        body: AdaptiveEmptyState(
          icon: AdaptiveIcons.palette(context),
          title: SettingsStrings.themeNotFound,
        ),
      );
    }
    final prefs = ref.watch(uiPrefsProvider);
    final issues = contrastIssues(draft);

    return AdaptivePageScaffold(
      title: Text(draft.name, overflow: TextOverflow.ellipsis),
      actions: [
        AdaptiveIconButton(
          icon: SettingsIcons.restore(context),
          semanticLabel: SettingsStrings.themeResetChanges,
          onPressed: draft == _original ? null : _discardChanges,
        ),
        AdaptiveIconButton(
          icon: AdaptiveIcons.more(context),
          semanticLabel: SettingsStrings.themeActions,
          onPressed: () => _showActions(draft),
        ),
      ],
      body: PreviewLayout(
        theme: draft,
        prefs: prefs,
        footer: issues.isEmpty ? null : ContrastWarning(issues: issues),
        child: SettingsBody(
          children: [
            AdaptiveSection(
              header: SettingsStrings.editorGeneral,
              children: [
                AdaptiveTile(
                  title: Strings.name,
                  value: draft.name,
                  onTap: () => _rename(draft),
                ),
                SegmentedSettingTile<Brightness>(
                  title: Strings.tokenBrightness,
                  segments: const {
                    Brightness.light: SettingsStrings.themeBright,
                    Brightness.dark: SettingsStrings.themeDim,
                  },
                  selected: draft.brightness,
                  onChanged: (v) => _update(draft.copyWith(brightness: v)),
                ),
              ],
            ),
            AdaptiveSection(
              header: SettingsStrings.editorColors,
              children: [
                for (final token in _colorTokens) _colorRow(draft, token),
              ],
            ),
            AdaptiveSection(
              header: Strings.tokenTrackPalette,
              footer: SettingsStrings.paletteHint,
              children: [_paletteEditor(context, draft)],
            ),
            AdaptiveSection(
              header: SettingsStrings.editorTypography,
              children: [
                AdaptiveTile(
                  title: Strings.tokenFontFamily,
                  value: Strings.fontName(draft.fontFamily),
                  onTap: () => _pickFont(draft),
                ),
                AdaptiveSwitchTile(
                  title: Strings.tokenDigitTabular,
                  value: draft.digitStyle.tabular,
                  onChanged: (v) => _update(
                    draft.copyWith(
                      digitStyle: draft.digitStyle.copyWith(tabular: v),
                    ),
                  ),
                ),
                AdaptiveSwitchTile(
                  title: Strings.tokenDigitMonospace,
                  value: draft.digitStyle.monospace,
                  onChanged: (v) => _update(
                    draft.copyWith(
                      digitStyle: draft.digitStyle.copyWith(monospace: v),
                    ),
                  ),
                ),
                SliderSettingTile(
                  title: Strings.tokenDigitWeight,
                  valueLabel: '${draft.digitStyle.weight}',
                  value: draft.digitStyle.weight.toDouble(),
                  min: 100,
                  max: 900,
                  divisions: 8,
                  onChanged: (v) => _update(
                    draft.copyWith(
                      digitStyle: draft.digitStyle.copyWith(weight: v.round()),
                    ),
                  ),
                ),
              ],
            ),
            AdaptiveSection(
              header: SettingsStrings.editorShape,
              children: [
                SliderSettingTile(
                  title: Strings.tokenCornerRadius,
                  valueLabel: SettingsStrings.pixels(draft.cornerRadius),
                  value: draft.cornerRadius,
                  max: 40,
                  divisions: 40,
                  onChanged: (v) =>
                      _update(draft.copyWith(cornerRadius: v.roundToDouble())),
                ),
                SliderSettingTile(
                  title: Strings.tokenBorderWidth,
                  valueLabel: SettingsStrings.pixels(draft.borderWidth),
                  value: draft.borderWidth,
                  max: 4,
                  divisions: 8,
                  onChanged: (v) =>
                      _update(draft.copyWith(borderWidth: (v * 2).round() / 2)),
                ),
              ],
            ),
            SizedBox(height: t.space.xl),
          ],
        ),
      ),
    );
  }

  Widget _colorRow(TikkyTheme draft, _ColorToken token) {
    final key = 'color.${token.key}';
    final expanded = _expanded == key;
    final color = token.read(draft.colors);
    void apply(Color value, {required bool commit}) {
      final current = _draft;
      if (current == null) return;
      _update(
        current.copyWith(colors: token.write(current.colors, value)),
        commit: commit,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColorTile(
          label: token.label,
          color: color,
          expanded: expanded,
          onTap: () => _toggle(key),
        ),
        if (expanded)
          ColorPickerPanel(
            key: ValueKey(key),
            color: color,
            swatches: _swatches,
            onChanged: (value) => apply(value, commit: false),
            onChangeEnd: (value) => apply(value, commit: true),
          ),
      ],
    );
  }

  Widget _paletteEditor(BuildContext context, TikkyTheme draft) {
    final t = context.tikky;
    final palette = draft.trackPalette;
    int? selected;
    final expanded = _expanded;
    if (expanded != null && expanded.startsWith('palette.')) {
      final index = int.tryParse(expanded.substring('palette.'.length));
      if (index != null && index >= 0 && index < palette.length) {
        selected = index;
      }
    }

    void apply(int index, Color value, {required bool commit}) {
      final current = _draft;
      if (current == null || index >= current.trackPalette.length) return;
      final next = [...current.trackPalette];
      next[index] = value;
      _setPalette(current, next, commit: commit);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.space.sm,
            vertical: t.space.xs,
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < palette.length; i++)
                ColorSwatchDot(
                  color: palette[i],
                  semanticLabel: SettingsStrings.paletteColor(i + 1),
                  selected: selected == i,
                  onTap: () => _toggle('palette.$i'),
                ),
              AdaptiveIconButton(
                icon: AdaptiveIcons.add(context),
                semanticLabel: SettingsStrings.paletteAdd,
                onPressed: () => _addPaletteColor(draft),
              ),
            ],
          ),
        ),
        if (selected != null) ...[
          Divider(height: t.sizes.hairline, indent: t.space.page),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.xs),
            child: Row(
              children: [
                AdaptiveIconButton(
                  icon: SettingsIcons.moveEarlier(context),
                  semanticLabel: SettingsStrings.paletteMoveEarlier,
                  onPressed: selected > 0
                      ? () => _movePaletteColor(draft, selected!, -1)
                      : null,
                ),
                AdaptiveIconButton(
                  icon: SettingsIcons.moveLater(context),
                  semanticLabel: SettingsStrings.paletteMoveLater,
                  onPressed: selected < palette.length - 1
                      ? () => _movePaletteColor(draft, selected!, 1)
                      : null,
                ),
                Expanded(
                  child: Text(
                    '${SettingsStrings.paletteColor(selected + 1)} · '
                    '${colorToHex(palette[selected])}',
                    style: t.text.caption,
                    textAlign: TextAlign.center,
                  ),
                ),
                AdaptiveIconButton(
                  icon: AdaptiveIcons.delete(context),
                  semanticLabel: SettingsStrings.paletteRemove,
                  color: t.colors.danger,
                  onPressed: palette.length > 1
                      ? () => _removePaletteColor(draft, selected!)
                      : null,
                ),
              ],
            ),
          ),
          ColorPickerPanel(
            key: ValueKey('palette.$selected'),
            color: palette[selected],
            swatches: _swatches,
            onChanged: (value) => apply(selected!, value, commit: false),
            onChangeEnd: (value) => apply(selected!, value, commit: true),
          ),
        ],
      ],
    );
  }
}

class _ColorTile extends StatelessWidget {
  const _ColorTile({
    required this.label,
    required this.color,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return ListTile(
      leading: ColorSwatchDot(color: color),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(colorToHex(color), style: t.text.bodyMuted),
          SizedBox(width: t.space.xs),
          Icon(
            expanded
                ? SettingsIcons.expandLess(context)
                : AdaptiveIcons.chevronDown(context),
            size: t.sizes.iconSm,
            color: t.colors.textMuted,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Tells which colour pairs of a theme are hard to read.
class ContrastWarning extends StatelessWidget {
  const ContrastWarning({required this.issues, super.key});

  final List<ContrastIssue> issues;

  static String pairName(ContrastPair pair) => switch (pair) {
    ContrastPair.textOnBackground => SettingsStrings.contrastTextOnBackground,
    ContrastPair.textOnSurface => SettingsStrings.contrastTextOnSurface,
    ContrastPair.mutedOnSurface => SettingsStrings.contrastMutedOnSurface,
    ContrastPair.mutedOnBackground => SettingsStrings.contrastMutedOnBackground,
    ContrastPair.onPrimaryOnPrimary => SettingsStrings.contrastOnPrimary,
    ContrastPair.inkOnTint => SettingsStrings.contrastInkOnTint,
    ContrastPair.inkOnStrong => SettingsStrings.contrastInkOnStrong,
    ContrastPair.onOnSolid => SettingsStrings.contrastOnSolid,
    ContrastPair.textOnStrong => SettingsStrings.contrastTextOnStrong,
    ContrastPair.warningTextOnTint => SettingsStrings.contrastWarningOnTint,
  };

  /// The pair, with the palette entry it belongs to.
  static String issueName(ContrastIssue issue) {
    final index = issue.paletteIndex;
    final pair = pairName(issue.pair);
    return index == null
        ? pair
        : SettingsStrings.contrastPaletteEntry(index + 1, pair);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Semantics(
      container: true,
      liveRegion: true,
      child: ColoredBox(
        color: t.colors.surface,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.space.page,
            vertical: t.space.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                SettingsIcons.warning(context),
                size: t.sizes.iconMd,
                color: t.colors.warning,
              ),
              SizedBox(width: t.space.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(SettingsStrings.contrastTitle, style: t.text.label),
                    for (final issue in issues)
                      Text(
                        SettingsStrings.contrastLine(
                          issueName(issue),
                          issue.ratio,
                          issue.minimum,
                        ),
                        style: t.text.caption,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
