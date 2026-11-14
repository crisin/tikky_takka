import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/tokens.dart';
import 'adaptive_controls.dart';
import 'platform.dart';

/// "Rückgängig" as a part of the layout instead of a snackbar: a slim bar
/// that tells what just happened and carries a large undo button.
///
/// Unlike a snackbar it never covers anything, so it cannot be hit by
/// accident while tapping what is below it. The owner decides how long it
/// stays (`TikkyMotion.inlineUndoWindow`) and what it shows meanwhile.
///
/// * [onUndo] `null`: no undo button (the action cannot be taken back, or
///   the bar is idle).
/// * [secondaryLabel] / [onSecondary]: a second, flat action ("Details").
/// * [height]: a fixed height with a single line of text - use it where
///   nothing below the bar may ever move (the tap pad). Without it the bar
///   is as high as its content, at least one tap target.
/// * [muted]: an idle hint instead of a message.
class InlineUndoBar extends StatelessWidget {
  const InlineUndoBar({
    required this.message,
    this.onUndo,
    this.undoLabel = Strings.undo,
    this.secondaryLabel,
    this.onSecondary,
    this.height,
    this.muted = false,
    super.key,
  });

  /// Below this inner width the message is put above the buttons.
  static const double _sideBySideMinWidth = 440;

  /// Key of the undo button.
  static const undoKey = ValueKey('inline-undo');

  /// Key of the secondary button.
  static const secondaryKey = ValueKey('inline-undo-secondary');

  final String message;
  final VoidCallback? onUndo;
  final String undoLabel;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final double? height;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final hasSecondary = secondaryLabel != null && onSecondary != null;
    final text = Semantics(
      liveRegion: !muted,
      child: Text(
        message,
        style: muted ? t.text.caption : t.text.label,
        maxLines: height == null ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final buttons = [
      if (hasSecondary)
        KeyedSubtree(
          key: secondaryKey,
          child: AdaptiveTextButton(
            label: secondaryLabel!,
            onPressed: onSecondary,
          ),
        ),
      if (onUndo != null)
        KeyedSubtree(
          key: undoKey,
          child: AdaptiveFilledButton(
            label: undoLabel,
            icon: AdaptiveIcons.undo(context),
            onPressed: onUndo,
          ),
        ),
    ];
    final leftHanded = t.prefs.leftHanded;
    final gap = SizedBox(width: t.space.sm);
    final bar = DecoratedBox(
      decoration: t.surfaceDecoration(color: t.colors.surfaceAlt),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: t.sizes.minTapTarget),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.space.md,
            vertical: t.space.xxs,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Not enough room side by side (a lane on a phone, a tile):
              // the message goes above the buttons.
              final stacked =
                  height == null &&
                  buttons.isNotEmpty &&
                  constraints.maxWidth < _sideBySideMinWidth;
              if (stacked) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: t.space.xs),
                      child: text,
                    ),
                    Wrap(
                      alignment: leftHanded
                          ? WrapAlignment.start
                          : WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: t.space.sm,
                      children: leftHanded
                          ? buttons.reversed.toList()
                          : buttons,
                    ),
                  ],
                );
              }
              final message = Expanded(child: text);
              return Row(
                // Left-handed layout: the buttons lead.
                children: leftHanded
                    ? [
                        ...buttons.reversed,
                        if (buttons.isNotEmpty) gap,
                        message,
                      ]
                    : [message, if (buttons.isNotEmpty) gap, ...buttons],
              );
            },
          ),
        ),
      ),
    );
    return height == null ? bar : SizedBox(height: height, child: bar);
  }
}
