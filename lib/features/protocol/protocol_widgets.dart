import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/now_ticker.dart';
import '../../theme/theme.dart';
import 'protocol_strings.dart';

/// Icons of the protocol feature that the adaptive layer does not offer.
abstract final class ProtocolIcons {
  static IconData entries(BuildContext c) => isCupertino(c)
      ? CupertinoIcons.list_bullet
      : Icons.format_list_bulleted_rounded;
  static IconData time(BuildContext c) =>
      isCupertino(c) ? CupertinoIcons.clock : Icons.schedule_rounded;
  static IconData substance(BuildContext c) =>
      isCupertino(c) ? CupertinoIcons.tag : Icons.label_outline_rounded;
  static IconData info(BuildContext c) =>
      isCupertino(c) ? CupertinoIcons.info : Icons.info_outline_rounded;
  static IconData scene(BuildContext c) =>
      isCupertino(c) ? CupertinoIcons.person_2 : Icons.group_outlined;
}

/// Rebuilds [builder] with the shared "now" only when the time has moved
/// into another [stepMs] bucket.
///
/// Protocol lanes show minutes ("vor 1 h 42 min"), so following every
/// 100 ms tick of the shared ticker would rebuild for nothing.
class CoarseNowBuilder extends ConsumerStatefulWidget {
  const CoarseNowBuilder({
    required this.builder,
    this.stepMs = 1000,
    super.key,
  });

  final Widget Function(BuildContext context, int nowMs) builder;
  final int stepMs;

  @override
  ConsumerState<CoarseNowBuilder> createState() => _CoarseNowBuilderState();
}

class _CoarseNowBuilderState extends ConsumerState<CoarseNowBuilder> {
  NowTicker? _ticker;
  int _bucket = 0;

  void _attach(NowTicker ticker) {
    if (identical(ticker, _ticker)) return;
    _ticker?.removeListener(_onTick);
    _ticker = ticker..addListener(_onTick);
    _bucket = ticker.value ~/ widget.stepMs;
  }

  void _onTick() {
    final bucket = _ticker!.value ~/ widget.stepMs;
    if (bucket != _bucket && mounted) setState(() => _bucket = bucket);
  }

  @override
  void dispose() {
    _ticker?.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticker = ref.watch(nowTickerProvider);
    _attach(ticker);
    return widget.builder(context, ticker.value);
  }
}

/// A round colour mark for a person or substance.
class ColorDot extends StatelessWidget {
  const ColorDot({required this.color, this.size, super.key});

  final Color color;

  /// Diameter; defaults to the small dot token.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final diameter = size ?? t.sizes.dot;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(t.hairline),
      ),
    );
  }
}

/// A large, flat, tappable choice ("chip") of the quick entry sheet: a
/// person, a substance, an earlier amount or a time shortcut.
///
/// [big] choices are at least `bigTapTarget` high so they can be hit
/// reliably; the others still keep the minimum tap target.
class ProtocolChoice extends StatelessWidget {
  const ProtocolChoice({
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.color,
    this.icon,
    this.big = true,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;

  /// A second way on the same choice (the scene: edit name and colour).
  final VoidCallback? onLongPress;
  final bool selected;

  /// Shows a [ColorDot] in front of the label.
  final Color? color;

  /// Shows an icon in front of the label (ignored when [color] is set).
  final IconData? icon;
  final bool big;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final minSize = big ? t.sizes.bigTapTarget : t.sizes.minTapTarget;
    final outline = t.sizes.hairline;
    final side = selected
        ? BorderSide(
            color: t.colors.primary,
            width: outline * 2,
            style: outline <= 0 ? BorderStyle.none : BorderStyle.solid,
          )
        : t.hairline;
    final textStyle = big ? t.text.headline : t.text.label;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: selected ? t.colors.surfaceAlt : t.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: t.radii.mdAll, side: side),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minSize, minWidth: minSize),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: big ? t.space.lg : t.space.md,
                vertical: t.space.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (color != null) ...[
                    ColorDot(color: color!),
                    SizedBox(width: t.space.sm),
                  ] else if (icon != null) ...[
                    Icon(icon, size: t.sizes.iconSm, color: t.colors.textMuted),
                    SizedBox(width: t.space.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: textStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected) ...[
                    SizedBox(width: t.space.sm),
                    Icon(
                      AdaptiveIcons.check(context),
                      size: t.sizes.iconSm,
                      color: t.colors.primary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The inline "new person / substance" field with confirm and discard.
class ProtocolInlineAdd extends StatelessWidget {
  const ProtocolInlineAdd({
    required this.controller,
    required this.hint,
    required this.onSubmit,
    required this.onCancel,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Padding(
      padding: EdgeInsets.only(top: t.space.sm),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              style: t.text.headline,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(hintText: hint),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          SizedBox(width: t.space.xs),
          AdaptiveIconButton(
            icon: AdaptiveIcons.check(context),
            semanticLabel: ProtocolStrings.confirmAdd,
            size: t.sizes.iconLg,
            color: t.colors.primary,
            onPressed: onSubmit,
          ),
          AdaptiveIconButton(
            icon: AdaptiveIcons.close(context),
            semanticLabel: ProtocolStrings.cancelAdd,
            size: t.sizes.iconLg,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// The small muted heading above a group of choices or a field.
class ProtocolSectionLabel extends StatelessWidget {
  const ProtocolSectionLabel(this.text, {this.trailing, super.key});

  final String text;

  /// Muted addition behind the label, e.g. "optional".
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Padding(
      padding: EdgeInsets.only(top: t.space.lg, bottom: t.space.sm),
      child: Semantics(
        header: true,
        child: Text.rich(
          TextSpan(
            text: text,
            children: [
              if (trailing != null)
                TextSpan(text: '  $trailing', style: t.text.caption),
            ],
          ),
          style: t.text.laneTitle,
        ),
      ),
    );
  }
}

/// The short neutral note: the app records, it does not advise.
class ProtocolNeutralNote extends StatelessWidget {
  const ProtocolNeutralNote({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.page,
        vertical: t.space.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ProtocolIcons.info(context),
            size: t.sizes.iconSm,
            color: t.colors.textMuted,
          ),
          SizedBox(width: t.space.sm),
          Expanded(
            child: Text(ProtocolStrings.neutralNote, style: t.text.caption),
          ),
        ],
      ),
    );
  }
}

/// A row of palette swatches to pick the colour of a person or substance.
class ProtocolColorPicker extends StatelessWidget {
  const ProtocolColorPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// ARGB of the current colour (may be outside the palette).
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final palette = [for (final c in t.theme.trackPalette) c.toARGB32()];
    // Keep a colour that is not part of the current theme's palette.
    final colors = [if (!palette.contains(selected)) selected, ...palette];
    return Wrap(
      children: [
        for (var i = 0; i < colors.length; i++)
          Semantics(
            button: true,
            selected: colors[i] == selected,
            label: ProtocolStrings.colorNumber(i + 1),
            excludeSemantics: true,
            child: InkResponse(
              onTap: () => onChanged(colors[i]),
              radius: t.sizes.minTapTarget / 2,
              child: SizedBox.square(
                dimension: t.sizes.minTapTarget,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(t.space.xxs + t.sizes.hairline),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: colors[i] == selected
                          ? Border.all(color: t.colors.text, width: t.space.xxs)
                          : null,
                    ),
                    child: ColorDot(
                      color: Color(colors[i]),
                      size: t.sizes.swatch,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The initial of a person in a circle of the person's colour.
class PersonInitial extends StatelessWidget {
  const PersonInitial({
    required this.name,
    required this.color,
    required this.size,
    this.style,
    super.key,
  });

  final String name;

  /// The person's colour; `null` for someone unknown.
  final Color? color;
  final double size;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final roles = color == null ? null : t.roles(color!);
    final initial = name.isEmpty ? '' : name.characters.first.toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: roles?.solid ?? t.colors.textMuted,
          borderRadius: t.radii.pillAll,
        ),
        child: Text(
          initial,
          style: (style ?? t.text.laneLabel).copyWith(
            color: roles?.on ?? t.onColor(t.colors.textMuted),
          ),
        ),
      ),
    );
  }
}
