import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'platform.dart';

/// Platform switch (Material switch / iOS toggle).
class AdaptiveSwitch extends StatelessWidget {
  const AdaptiveSwitch({
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final control = Switch.adaptive(
      value: value,
      onChanged: onChanged,
      activeTrackColor: isCupertino(context) ? t.colors.success : null,
    );
    if (semanticLabel == null) return control;
    return Semantics(label: semanticLabel, child: control);
  }
}

/// A settings row with a platform switch.
class AdaptiveSwitchTile extends StatelessWidget {
  const AdaptiveSwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return SwitchListTile.adaptive(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      secondary: leading,
      value: value,
      onChanged: onChanged,
      activeTrackColor: isCupertino(context) ? t.colors.success : null,
    );
  }
}

/// Platform slider.
class AdaptiveSlider extends StatelessWidget {
  const AdaptiveSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.semanticLabel,
    this.onChangeEnd,
    super.key,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final slider = Slider.adaptive(
      value: value.clamp(min, max).toDouble(),
      min: min,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
    if (semanticLabel == null) return slider;
    return Semantics(label: semanticLabel, child: slider);
  }
}

/// A small set of mutually exclusive choices: [SegmentedButton] on Material,
/// [CupertinoSlidingSegmentedControl] on iOS / macOS.
///
/// With [icons] every segment shows its icon in front of the label. With
/// [showLabels] false (needs [icons]) only the icons are shown - compact
/// enough for an app bar on a phone - and the label becomes the tooltip
/// and the semantics label of the segment.
class AdaptiveSegmented<T extends Object> extends StatelessWidget {
  const AdaptiveSegmented({
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.icons,
    this.showLabels = true,
    this.fitLabels = false,
    super.key,
  }) : assert(showLabels || icons != null, 'icon-only segments need icons');

  /// Value -> label, in display order.
  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Value -> icon; `null` = text only.
  final Map<T, IconData>? icons;

  /// Whether the labels are visible (always read by screen readers).
  final bool showLabels;

  /// Scales a label down instead of breaking it when the segments have to
  /// share little width (several long words on a phone).
  final bool fitLabels;

  Widget _fit(Widget label) =>
      fitLabels ? FittedBox(fit: BoxFit.scaleDown, child: label) : label;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final icons = this.icons;
    if (isCupertino(context)) {
      Widget child(T value, String label) {
        final icon = icons?[value];
        if (icon == null) return _fit(Text(label, style: t.text.label));
        if (!showLabels) {
          return Tooltip(
            message: label,
            child: Icon(
              icon,
              size: t.sizes.iconMd,
              color: t.colors.text,
              semanticLabel: label,
            ),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: t.sizes.iconSm, color: t.colors.text),
            SizedBox(width: t.space.xs),
            Text(label, style: t.text.label),
          ],
        );
      }

      return CupertinoSlidingSegmentedControl<T>(
        groupValue: selected,
        backgroundColor: t.colors.surfaceAlt,
        thumbColor: t.colors.surface,
        onValueChanged: (value) {
          if (value != null) onChanged(value);
        },
        children: {
          for (final e in segments.entries)
            e.key: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: showLabels ? t.space.md : t.space.sm,
                vertical: t.space.xs,
              ),
              child: child(e.key, e.value),
            ),
        },
      );
    }
    return SegmentedButton<T>(
      showSelectedIcon: false,
      style: showLabels
          ? null
          : ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: t.space.sm),
              ),
            ),
      segments: [
        for (final e in segments.entries)
          ButtonSegment<T>(
            value: e.key,
            icon: icons?[e.key] == null
                ? null
                : Icon(
                    icons![e.key],
                    size: t.sizes.iconSm,
                    semanticLabel: showLabels ? null : e.value,
                  ),
            label: showLabels ? _fit(Text(e.value, maxLines: 1)) : null,
            tooltip: showLabels ? null : e.value,
          ),
      ],
      selected: {selected},
      onSelectionChanged: (set) => onChanged(set.first),
    );
  }
}

/// An icon button that ALWAYS carries a semantics label (also shown as the
/// tooltip on Material / desktop).
class AdaptiveIconButton extends StatelessWidget {
  const AdaptiveIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.size,
    this.color,
    super.key,
  });

  final IconData icon;

  /// Read by screen readers and shown as tooltip. Required on purpose.
  final String semanticLabel;
  final VoidCallback? onPressed;

  /// Icon size; defaults to the medium icon token.
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final iconSize = size ?? t.sizes.iconMd;
    if (isCupertino(context)) {
      return Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: CupertinoButton(
          padding: EdgeInsets.all(t.space.sm),
          minimumSize: Size.square(t.sizes.minTapTarget - t.space.sm),
          onPressed: onPressed,
          child: Icon(
            icon,
            size: iconSize,
            color: onPressed == null
                ? t.colors.textMuted
                : (color ?? t.colors.text),
          ),
        ),
      );
    }
    return IconButton(
      // The label is set on the icon as well: a tooltip alone is exposed to
      // accessibility services as a tooltip, not as the node's label.
      icon: Icon(icon, size: iconSize, semanticLabel: semanticLabel),
      color: color,
      tooltip: semanticLabel,
      onPressed: onPressed,
    );
  }
}

/// The filled call-to-action button.
class AdaptiveFilledButton extends StatelessWidget {
  const AdaptiveFilledButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final background = destructive ? t.colors.danger : t.colors.primary;
    final foreground = destructive
        ? t.onColor(t.colors.danger)
        : t.colors.onPrimary;
    if (isCupertino(context)) {
      return CupertinoButton(
        color: background,
        borderRadius: t.radii.mdAll,
        padding: EdgeInsets.symmetric(
          horizontal: t.space.lg,
          vertical: t.space.md,
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: t.sizes.iconSm, color: foreground),
              SizedBox(width: t.space.sm),
            ],
            Flexible(
              child: Text(
                label,
                style: t.text.button.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      );
    }
    final style = destructive
        ? FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
          )
        : null;
    if (icon == null) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: t.sizes.iconSm),
      label: Text(label),
    );
  }
}

/// A flat text button.
class AdaptiveTextButton extends StatelessWidget {
  const AdaptiveTextButton({
    required this.label,
    required this.onPressed,
    this.destructive = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final color = destructive ? t.colors.danger : t.colors.text;
    if (isCupertino(context)) {
      return CupertinoButton(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md,
          vertical: t.space.sm,
        ),
        onPressed: onPressed,
        child: Text(label, style: t.text.button.copyWith(color: color)),
      );
    }
    return TextButton(
      onPressed: onPressed,
      style: destructive ? TextButton.styleFrom(foregroundColor: color) : null,
      child: Text(label),
    );
  }
}

/// Platform activity indicator.
class AdaptiveProgress extends StatelessWidget {
  const AdaptiveProgress({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator.adaptive());
}

/// A titled group of rows (settings sections, editor groups): flat surface
/// with a hairline outline and hairline dividers between rows.
class AdaptiveSection extends StatelessWidget {
  const AdaptiveSection({
    required this.children,
    this.header,
    this.footer,
    super.key,
  });

  final String? header;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    // iOS: the inset grouped lists of the system apps - small capitals
    // above the group, the separators start where the text starts.
    final cupertino = isCupertino(context);
    final headerText = header == null
        ? null
        : cupertino
        ? Text(
            header!.toUpperCase(),
            style: t.text.caption.copyWith(letterSpacing: 0.3),
          )
        : Text(header!, style: t.text.laneTitle);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.page,
        cupertino ? t.space.lg : t.space.md,
        t.space.page,
        t.space.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (headerText != null)
            Padding(
              padding: EdgeInsets.only(
                left: cupertino ? t.space.lg : t.space.xs,
                bottom: cupertino ? t.space.xs : t.space.sm,
              ),
              child: Semantics(header: true, child: headerText),
            ),
          DecoratedBox(
            decoration: t.surfaceDecoration(),
            child: ClipRRect(
              borderRadius: t.radii.mdAll,
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0)
                        Divider(height: t.sizes.hairline, indent: t.space.page),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: EdgeInsets.only(
                left: cupertino ? t.space.lg : t.space.xs,
                right: cupertino ? t.space.lg : 0,
                top: t.space.sm,
              ),
              child: Text(footer!, style: t.text.caption),
            ),
        ],
      ),
    );
  }
}

/// A row inside an [AdaptiveSection]. With [onTap] and no [trailing] it
/// shows the platform's disclosure chevron.
class AdaptiveTile extends StatelessWidget {
  const AdaptiveTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.value,
    this.onTap,
    this.destructive = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Current value shown muted at the trailing edge (e.g. "Dunkel").
  final String? value;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    Widget? end = trailing;
    if (end == null && (value != null || onTap != null)) {
      end = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Flexible(
              child: Text(
                value!,
                style: t.text.bodyMuted,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (onTap != null && !destructive)
            Icon(
              AdaptiveIcons.chevronRight(context),
              size: t.sizes.iconSm,
              color: t.colors.textMuted,
            ),
        ],
      );
    }
    if (isCupertino(context)) {
      // A row of the iOS system lists: 17 pt text, at least 48 px high,
      // grey subtitle, no ripple.
      return ListTile(
        leading: leading,
        title: Text(
          title,
          style: destructive
              ? t.text.body.copyWith(color: t.colors.danger)
              : t.text.body,
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: t.text.subLine),
        trailing: end,
        onTap: onTap,
        minTileHeight: t.sizes.minTapTarget,
        splashColor: Colors.transparent,
        contentPadding: EdgeInsets.symmetric(horizontal: t.space.lg),
      );
    }
    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: destructive
            ? t.text.body.copyWith(color: t.colors.danger)
            : null,
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: end,
      onTap: onTap,
    );
  }
}

/// What shows behind a list row while it is swiped away to delete it (the
/// iOS system lists: red, the bin at the trailing edge). Use as the
/// `background` of a [Dismissible] with `DismissDirection.endToStart`.
class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({required this.semanticLabel, super.key});

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return ColoredBox(
      color: t.colors.danger,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: t.space.lg),
          child: Icon(
            AdaptiveIcons.delete(context),
            color: t.onColor(t.colors.danger),
            size: t.sizes.iconMd,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );
  }
}
