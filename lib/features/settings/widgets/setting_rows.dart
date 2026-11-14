import 'package:flutter/material.dart';

import '../../../adaptive/adaptive.dart';
import '../../../theme/theme.dart';

/// Scrollable body of a settings page: a list of sections, centred and
/// width-limited on wide screens.
class SettingsBody extends StatelessWidget {
  const SettingsBody({required this.children, this.controller, super.key});

  final List<Widget> children;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: t.sizes.maxContentWidth),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.only(top: t.space.sm, bottom: t.space.xxl),
          children: children,
        ),
      ),
    );
  }
}

/// Title (+ optional caption and trailing widget) of a custom settings row,
/// styled like a list tile.
class SettingRowHeader extends StatelessWidget {
  const SettingRowHeader({
    required this.title,
    this.caption,
    this.value,
    this.trailing,
    super.key,
  });

  final String title;
  final String? caption;

  /// Current value, shown muted at the trailing edge.
  final String? value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.text.body),
              if (caption != null) Text(caption!, style: t.text.caption),
            ],
          ),
        ),
        if (value != null)
          Padding(
            padding: EdgeInsets.only(left: t.space.sm),
            child: Text(value!, style: t.text.bodyMuted),
          ),
        ?trailing,
      ],
    );
  }
}

/// A settings row with a platform slider below its title.
class SliderSettingTile extends StatelessWidget {
  const SliderSettingTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.valueLabel,
    this.caption,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeEnd,
    this.trailing,
    super.key,
  });

  final String title;
  final String? caption;
  final String? valueLabel;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Padding(
      padding: EdgeInsets.fromLTRB(t.space.page, t.space.md, t.space.page, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingRowHeader(
            title: title,
            caption: caption,
            value: valueLabel,
            trailing: trailing,
          ),
          AdaptiveSlider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            semanticLabel: title,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}

/// A settings row with a segmented choice below its title.
class SegmentedSettingTile<T extends Object> extends StatelessWidget {
  const SegmentedSettingTile({
    required this.title,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.caption,
    this.trailing,
    super.key,
  });

  final String title;
  final String? caption;
  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.page,
        t.space.md,
        t.space.page,
        t.space.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingRowHeader(title: title, caption: caption, trailing: trailing),
          SizedBox(height: t.space.sm),
          Semantics(
            label: title,
            container: true,
            child: AdaptiveSegmented<T>(
              segments: segments,
              selected: selected,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// A round colour swatch, optionally tappable and marked as selected.
class ColorSwatchDot extends StatelessWidget {
  const ColorSwatchDot({
    required this.color,
    this.semanticLabel,
    this.selected = false,
    this.onTap,
    this.size,
    super.key,
  });

  final Color color;
  final String? semanticLabel;
  final bool selected;
  final VoidCallback? onTap;

  /// Diameter; defaults to the swatch token.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final diameter = size ?? t.sizes.swatch;
    final dot = Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? t.colors.text : t.colors.border,
          width: selected ? t.sizes.hairline + t.space.xxs : t.sizes.hairline,
        ),
      ),
      child: selected
          ? Icon(
              AdaptiveIcons.check(context),
              size: diameter / 2,
              color: t.onColor(color),
            )
          : null,
    );
    if (onTap == null) {
      return semanticLabel == null
          ? ExcludeSemantics(child: dot)
          : Semantics(label: semanticLabel, child: dot);
    }
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: InkResponse(
        onTap: onTap,
        radius: t.sizes.minTapTarget / 2,
        child: SizedBox.square(
          dimension: t.sizes.minTapTarget,
          child: Center(child: dot),
        ),
      ),
    );
  }
}
