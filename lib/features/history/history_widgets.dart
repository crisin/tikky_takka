import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Centres page content and limits its width on wide screens.
class HistoryContentWidth extends StatelessWidget {
  const HistoryContentWidth({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: t.sizes.maxContentWidth),
        child: child,
      ),
    );
  }
}

/// A titled block of rows: heading on the left, an optional figure (day
/// total) on the right, then a flat surface with hairline dividers.
class HistoryGroup extends StatelessWidget {
  const HistoryGroup({
    required this.title,
    required this.children,
    this.trailing,
    this.caption,
    super.key,
  });

  final String title;

  /// Shown muted at the trailing edge of the heading (e.g. the day total).
  final String? trailing;

  /// Shown muted below the heading.
  final String? caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.page,
        t.space.md,
        t.space.page,
        t.space.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: t.space.xs,
              right: t.space.xs,
              bottom: t.space.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: t.text.headline),
                      ),
                      if (caption != null)
                        Text(caption!, style: t.text.caption),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  SizedBox(width: t.space.md),
                  Text(trailing!, style: t.text.laneTitle),
                ],
              ],
            ),
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
        ],
      ),
    );
  }
}

/// A small round colour marker (track colour).
class HistoryColorDot extends StatelessWidget {
  const HistoryColorDot({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Container(
      width: t.sizes.dot,
      height: t.sizes.dot,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// A row with the track colour as a thin bar at its leading edge, as on the
/// lanes of the tracks screen.
class HistoryColorBarRow extends StatelessWidget {
  const HistoryColorBarRow({
    required this.color,
    required this.child,
    super.key,
  });

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(color: color, width: t.sizes.colorBar),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: t.sizes.colorBar),
        child: child,
      ),
    );
  }
}
