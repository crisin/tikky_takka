import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../l10n/formatters.dart';
import '../../../../theme/theme.dart';
import '../../tracks_strings.dart';
import 'strip_axis.dart';
import 'strip_model.dart';
import 'strip_viewport.dart';

/// Everything the painters need from the theme, resolved once per build.
@immutable
class StripStyle {
  const StripStyle({
    required this.tokens,
    required this.metrics,
    required this.textScaler,
    required this.tickSpacing,
  });

  /// Reads the tokens of [context] (per-set overrides included) and the
  /// system text size.
  factory StripStyle.of(BuildContext context) {
    final t = context.tikky;
    final scaler = MediaQuery.textScalerOf(context);
    final s = t.strip;
    // Lanes grow with the text so a label never leaves its lane.
    final textHeight = scaler.scale(t.text.caption.fontSize ?? 12) * 1.5;
    final laneHeight = math.max(s.lane, textHeight + t.space.sm);
    // A substance lane shows its name and its timer in the gutter.
    double lineHeight(TextStyle style) =>
        scaler.scale(style.fontSize ?? 12) * (style.height ?? 1.2);
    final twoLines =
        lineHeight(t.text.caption) +
        lineHeight(t.text.digitsSmall) +
        t.space.xs;
    final subLaneHeight = math.max(
      s.subLane,
      math.max(textHeight + t.space.xs, twoLines),
    );
    final sample = TextPainter(
      text: TextSpan(
        text: Fmt.time(
          // Any instant: the widest digits matter, not the time.
          DateTime(2000, 1, 1, 22, 58, 58).millisecondsSinceEpoch,
          use24h: t.prefs.use24h,
          seconds: true,
        ),
        style: t.text.caption,
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final tickSpacing = sample.width + s.tickPadding;
    sample.dispose();
    return StripStyle(
      tokens: t,
      textScaler: scaler,
      tickSpacing: tickSpacing,
      metrics: StripMetrics(
        laneHeight: laneHeight,
        subLaneHeight: subLaneHeight,
        barHeight: s.bar,
        subBarHeight: s.subBar,
        markerRadius: s.marker / 2,
        markerGap: s.markerGap,
        clusterHeight: math.max(s.clusterHeight, textHeight),
        clusterMinWidth: s.clusterMinWidth,
        labelGap: s.labelGap,
      ),
    );
  }

  final TikkyTokens tokens;
  final StripMetrics metrics;
  final TextScaler textScaler;

  /// Smallest distance between two ticks of the axis.
  final double tickSpacing;

  /// Height of the axis: grows with the text.
  double get axisHeight => math.max(
    tokens.strip.axis,
    textScaler.scale(tokens.text.caption.fontSize ?? 12) * 1.5 +
        tokens.space.sm,
  );

  @override
  bool operator ==(Object other) =>
      other is StripStyle &&
      other.tokens == tokens &&
      other.textScaler == textScaler &&
      other.tickSpacing == tickSpacing;

  @override
  int get hashCode => Object.hash(tokens, textScaler, tickSpacing);
}

/// Text painters by text, so panning does not shape the same words again
/// for every frame.
class _TextCache {
  _TextCache(this.scaler);

  final TextScaler scaler;
  final Map<(String, TextStyle), TextPainter> _cache = {};

  TextPainter get(String text, TextStyle style, {double? maxWidth}) {
    if (_cache.length > 600) dispose();
    final painter = _cache.putIfAbsent(
      (text, style),
      () => TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
        ellipsis: '…',
      ),
    );
    painter.layout(maxWidth: maxWidth ?? double.infinity);
    return painter;
  }

  void dispose() {
    for (final p in _cache.values) {
      p.dispose();
    }
    _cache.clear();
  }
}

/// The lanes: gridlines, lockout bands, session bars, markers, clusters
/// and the "now" line. Repaints when the viewport moves or the "now"
/// pulse fires - never through a widget rebuild.
class StripLanesPainter extends CustomPainter {
  StripLanesPainter({
    required this.data,
    required this.viewport,
    required this.now,
    required this.style,
    required this.semanticsEpoch,
    required this.onEvent,
    required this.onCluster,
    required Listenable repaint,
  }) : _texts = _TextCache(style.textScaler),
       super(repaint: repaint);

  final StripData data;
  final StripViewport viewport;

  /// The shared "now" ticker (read while painting).
  final ValueListenable<int> now;
  final StripStyle style;

  /// Changes when the semantics nodes have to be built again (the
  /// viewport moved while a screen reader is on).
  final int semanticsEpoch;
  final ValueChanged<StripEvent> onEvent;
  final ValueChanged<StripCluster> onCluster;

  final _TextCache _texts;

  StripLayout layoutFor(Size size) => layoutStrip(
    data: data,
    scale: viewport.scale,
    width: size.width,
    nowMs: now.value,
    metrics: style.metrics,
  );

  Color _rowColor(StripRowData row) => style.tokens.trackColor(row.track);

  /// The colour of the lane's own thing (person, substance), else the
  /// track's.
  Color _laneColor(StripRowData row) =>
      row.dotArgb == null ? _rowColor(row) : Color(row.dotArgb!);

  @override
  void paint(Canvas canvas, Size size) {
    final t = style.tokens;
    final s = t.strip;
    final m = style.metrics;
    final layout = layoutFor(size);
    canvas
      ..save()
      ..clipRect(Offset.zero & size);

    // Lane separators: a hairline above every track.
    final separator = Paint()
      ..color = t.colors.border
      ..strokeWidth = math.max(t.sizes.hairline, 0.5);
    for (var r = 0; r < data.rows.length; r++) {
      if (data.rows[r].isSub || r == 0) continue;
      final y = layout.rowTops[r];
      canvas.drawLine(Offset(0, y), Offset(size.width, y), separator);
    }

    // Gridlines at the ticks of the axis; day separators stronger.
    final axis = computeAxis(
      scale: viewport.scale,
      width: size.width,
      minSpacingPx: style.tickSpacing,
      use24h: t.prefs.use24h,
    );
    final grid = Paint()
      ..color = t.colors.border.withValues(alpha: s.gridOpacity)
      ..strokeWidth = math.max(t.sizes.hairline, 0.5);
    final day = Paint()
      ..color = t.colors.textMuted
      ..strokeWidth = s.nowLine;
    for (final tick in axis.ticks) {
      canvas.drawLine(
        Offset(tick.x, 0),
        Offset(tick.x, size.height),
        tick.isDay && axis.stepMs < stripDayMs ? day : grid,
      );
    }

    // Folds behind everything else: the bars run through them.
    for (final fold in axis.folds) {
      _paintFold(canvas, fold, 0, size.height, t);
    }

    for (final band in layout.bands) {
      canvas.drawRect(
        band.rect,
        Paint()..color = Color(band.colorArgb).withValues(alpha: s.bandOpacity),
      );
    }

    final radius = Radius.circular(t.radii.sm);
    for (final bar in layout.bars) {
      final color = _rowColor(data.rows[bar.rowIndex]);
      // Even the shortest session stays visible.
      final rect = bar.rect.width >= 2
          ? bar.rect
          : Rect.fromLTWH(bar.rect.left, bar.rect.top, 2, bar.rect.height);
      final rrect = RRect.fromRectAndRadius(rect, radius);
      switch (bar.kind) {
        case StripBarKind.active:
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = color.withValues(
                alpha: bar.thin ? s.subBarOpacity : s.barOpacity,
              ),
          );
        case StripBarKind.phaseAlt:
          canvas.drawRRect(
            rrect,
            Paint()..color = color.withValues(alpha: s.phaseAltOpacity),
          );
        case StripBarKind.paused:
          canvas.drawRRect(
            rrect,
            Paint()..color = color.withValues(alpha: s.pauseOpacity),
          );
          if (!bar.thin) _hatch(canvas, rrect, color);
      }
    }

    _paintGaps(canvas, size, layout);

    final labelStyle = t.text.caption.copyWith(color: t.colors.text);
    final outline = Paint()
      ..color = t.colors.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.nowLine;
    final ink = Paint()
      ..color = t.colors.text
      ..strokeWidth = s.nowLine
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final r = m.markerRadius;
    for (final marker in layout.markers) {
      final c = marker.center;
      final row = data.rows[marker.rowIndex];
      final color = _rowColor(row);
      switch (marker.kind) {
        case StripMarkerKind.tick || StripMarkerKind.entry:
          final argb = marker.event?.colorArgb;
          canvas
            ..drawCircle(
              c,
              r,
              Paint()..color = argb == null ? color : Color(argb),
            )
            ..drawCircle(c, r, outline);
        case StripMarkerKind.lap:
          final half = (row.isSub ? m.subBarHeight : m.barHeight) / 2 + r / 2;
          canvas.drawLine(c.translate(0, -half), c.translate(0, half), ink);
        case StripMarkerKind.ack:
          canvas
            ..drawCircle(c, r, Paint()..color = t.colors.surface)
            ..drawCircle(
              c,
              r,
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = s.nowLine,
            )
            ..drawPath(
              Path()
                ..moveTo(c.dx - r * 0.5, c.dy)
                ..lineTo(c.dx - r * 0.1, c.dy + r * 0.4)
                ..lineTo(c.dx + r * 0.55, c.dy - r * 0.4),
              ink,
            );
        case StripMarkerKind.lifecycle:
          canvas
            ..drawCircle(c, r * 0.6, Paint()..color = t.colors.surface)
            ..drawCircle(
              c,
              r * 0.6,
              Paint()
                ..color = t.colors.textMuted
                ..style = PaintingStyle.stroke
                ..strokeWidth = s.nowLine,
            );
        case StripMarkerKind.finish:
          final top = c.dy - r * 1.7;
          canvas
            ..drawLine(Offset(c.dx, top), Offset(c.dx, c.dy + r * 1.2), ink)
            ..drawPath(
              Path()
                ..moveTo(c.dx, top)
                ..lineTo(c.dx + r * 1.5, top + r * 0.75)
                ..lineTo(c.dx, top + r * 1.5)
                ..close(),
              Paint()..color = t.colors.text,
            );
      }
      final label = marker.event?.label;
      if (label == null || label.isEmpty) continue;
      final room = math.min(
        marker.labelRoom,
        style.textScaler.scale(s.labelMaxWidth),
      );
      if (room < style.textScaler.scale(s.labelMinWidth)) continue;
      final text = _texts.get(label, labelStyle, maxWidth: room);
      text.paint(canvas, Offset(c.dx + r + s.labelGap, c.dy - text.height / 2));
    }

    final countStyle = t.text.caption.copyWith(
      color: t.colors.text,
      fontWeight: FontWeight.w600,
    );
    for (final cluster in layout.clusters) {
      final color = _rowColor(data.rows[cluster.rowIndex]);
      final text = _texts.get('${cluster.count}', countStyle);
      final width = math.max(cluster.rect.width, text.width + 2 * s.labelGap);
      final rect = Rect.fromCenter(
        center: cluster.rect.center,
        width: width,
        height: cluster.rect.height,
      );
      final pill = RRect.fromRectAndRadius(
        rect,
        Radius.circular(rect.height / 2),
      );
      canvas
        ..drawRRect(pill, Paint()..color = t.colors.surface)
        ..drawRRect(
          pill,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.nowLine,
        );
      // Wider than the viewport: the number stays in sight.
      final cx = rect.center.dx.clamp(
        math.max(rect.left, 0) + text.width / 2,
        math.max(
          math.max(rect.left, 0) + text.width / 2,
          math.min(rect.right, size.width) - text.width / 2,
        ),
      );
      text.paint(
        canvas,
        Offset(cx - text.width / 2, rect.center.dy - text.height / 2),
      );
    }

    if (layout.nowX >= 0 && layout.nowX <= size.width) {
      canvas.drawLine(
        Offset(layout.nowX, 0),
        Offset(layout.nowX, size.height),
        Paint()
          ..color = t.colors.primary
          ..strokeWidth = s.nowLine,
      );
    }
    canvas.restore();
  }

  /// The time between two markers, written on a small pill in the middle
  /// of the visible part of the stretch; the running timer of a lane
  /// (from its last marker up to "now") stands out. Left out where the
  /// text does not fit.
  void _paintGaps(Canvas canvas, Size size, StripLayout layout) {
    if (layout.gaps.isEmpty) return;
    final t = style.tokens;
    final s = t.strip;
    final m = style.metrics;
    final quiet = t.text.caption.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final loud = quiet.copyWith(
      color: t.colors.text,
      fontWeight: FontWeight.w600,
    );
    final pillPaint = Paint()..color = t.colors.surface;
    final inset = m.markerRadius + s.labelGap;
    for (final gap in layout.gaps) {
      final from = math.max(gap.fromX, 0.0) + inset;
      final to = math.min(gap.toX, size.width) - inset;
      if (to <= from) continue;
      final text = _texts.get(Fmt.compact(gap.ms), gap.live ? loud : quiet);
      final pillWidth = text.width + 2 * s.labelGap;
      if (pillWidth > to - from) continue;
      final rect = Rect.fromCenter(
        center: Offset((from + to) / 2, gap.centerY),
        width: pillWidth,
        height: text.height,
      );
      final pill = RRect.fromRectAndRadius(
        rect,
        Radius.circular(rect.height / 2),
      );
      canvas.drawRRect(pill, pillPaint);
      if (gap.live) {
        canvas.drawRRect(
          pill,
          Paint()
            ..color = _laneColor(data.rows[gap.rowIndex])
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.nowLine,
        );
      }
      text.paint(canvas, Offset(rect.left + s.labelGap, rect.top));
    }
  }

  void _hatch(Canvas canvas, RRect rrect, Color color) {
    final s = style.tokens.strip;
    final rect = rrect.outerRect;
    final paint = Paint()
      ..color = color.withValues(alpha: s.barOpacity)
      ..strokeWidth = 1;
    canvas
      ..save()
      ..clipRRect(rrect);
    // Anchored to the time, not to the screen: the lines move with the bar.
    final phase =
        (viewport.scale.drawnMs(viewport.startMs) / viewport.msPerPx) %
        s.hatchSpacing;
    for (
      var x = rect.left - rect.height - phase;
      x < rect.right;
      x += s.hatchSpacing
    ) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        paint,
      );
    }
    canvas
      ..restore()
      ..drawRRect(
        rrect,
        Paint()
          ..color = color.withValues(alpha: s.barOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(StripLanesPainter oldDelegate) {
    final changed =
        !identical(oldDelegate.data, data) ||
        oldDelegate.style != style ||
        !identical(oldDelegate.viewport, viewport);
    if (changed || !identical(oldDelegate, this)) oldDelegate._texts.dispose();
    return changed;
  }

  // The canvas says nothing to a screen reader: every visible marker and
  // cluster becomes a node with the text of the list row.
  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final layout = layoutFor(size);
    final use24h = style.tokens.prefs.use24h;
    final slop = style.tokens.strip.hitSlop;
    return [
      for (final marker in layout.markers)
        if (marker.event case final event?)
          if (marker.center.dx >= 0 && marker.center.dx <= size.width)
            CustomPainterSemantics(
              key: ValueKey(event.row.event.id),
              rect: Rect.fromCircle(center: marker.center, radius: slop),
              properties: SemanticsProperties(
                button: true,
                textDirection: TextDirection.ltr,
                label: stripEventSemantics(
                  event,
                  data.rows[marker.rowIndex],
                  use24h: use24h,
                ),
                onTap: () => onEvent(event),
              ),
            ),
      for (final cluster in layout.clusters)
        CustomPainterSemantics(
          key: ValueKey('cluster-${cluster.events.first.row.event.id}'),
          rect: cluster.rect.intersect(Offset.zero & size).inflate(1),
          properties: SemanticsProperties(
            button: true,
            textDirection: TextDirection.ltr,
            label: TracksStrings.stripClusterSemantics(
              cluster.count,
              Fmt.time(cluster.fromMs, use24h: use24h, seconds: true),
              Fmt.time(cluster.toMs, use24h: use24h, seconds: true),
            ),
            onTap: () => onCluster(cluster),
          ),
        ),
    ];
  };

  @override
  bool shouldRebuildSemantics(StripLanesPainter oldDelegate) =>
      oldDelegate.semanticsEpoch != semanticsEpoch ||
      !identical(oldDelegate.data, data);
}

/// "14:02:11, Zelt, Jacke · GBL · 1 ml": what a screen reader says for a
/// marker - the wording of the list row.
String stripEventSemantics(
  StripEvent event,
  StripRowData row, {
  required bool use24h,
}) {
  final note = event.row.note;
  return TracksStrings.timelineRowSemantics(
    Fmt.time(event.at, use24h: use24h, seconds: true),
    row.track.name,
    note == null || note.isEmpty ? event.row.text : '${event.row.text}, $note',
  );
}

/// The time axis above the lanes: ticks with their times, the date at a
/// day separator, and the current time at the "now" line.
class StripAxisPainter extends CustomPainter {
  StripAxisPainter({
    required this.viewport,
    required this.now,
    required this.style,
    required Listenable repaint,
  }) : _texts = _TextCache(style.textScaler),
       super(repaint: repaint);

  final StripViewport viewport;
  final ValueListenable<int> now;
  final StripStyle style;
  final _TextCache _texts;

  @override
  void paint(Canvas canvas, Size size) {
    final t = style.tokens;
    final s = t.strip;
    canvas
      ..save()
      ..clipRect(Offset.zero & size);
    final axis = computeAxis(
      scale: viewport.scale,
      width: size.width,
      minSpacingPx: style.tickSpacing,
      use24h: t.prefs.use24h,
    );
    final line = Paint()
      ..color = t.colors.border
      ..strokeWidth = math.max(t.sizes.hairline, 0.5);
    canvas.drawLine(
      Offset(0, size.height - line.strokeWidth / 2),
      Offset(size.width, size.height - line.strokeWidth / 2),
      line,
    );
    final tickLength = t.space.xs;
    final taken = <Rect>[];

    // A fold continues through the axis and carries its length.
    final foldLabels = <(TextPainter, Rect)>[];
    for (final fold in axis.folds) {
      _paintFold(canvas, fold, 0, size.height, t);
      final text = _texts.get(Fmt.coarse(fold.ms), t.text.caption);
      final width = text.width + 2 * s.labelGap;
      // Inside the width, like the current time.
      final left = (fold.center - width / 2)
          .clamp(0.0, math.max(0.0, size.width - width))
          .toDouble();
      final rect = Rect.fromLTWH(
        left,
        (size.height - tickLength - text.height) / 2,
        width,
        text.height,
      );
      foldLabels.add((text, rect));
    }

    // The current time at the "now" line wins over the tick labels.
    final nowMs = now.value;
    final nowX = viewport.xOf(nowMs);
    TextPainter? nowText;
    Rect? nowRect;
    if (nowX >= 0 && nowX <= size.width) {
      nowText = _texts.get(
        Fmt.time(nowMs, use24h: t.prefs.use24h, seconds: true),
        t.text.caption.copyWith(
          color: t.colors.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      );
      final width = nowText.width + 2 * s.labelGap;
      final left = (nowX - width / 2)
          .clamp(0.0, math.max(0.0, size.width - width))
          .toDouble();
      nowRect = Rect.fromLTWH(
        left,
        (size.height - tickLength - nowText.height) / 2,
        width,
        nowText.height,
      );
      taken.add(nowRect.inflate(s.labelGap));
    }

    void label(StripTick tick, {required bool isDay}) {
      final text = _texts.get(
        tick.label,
        isDay
            ? t.text.caption.copyWith(
                color: t.colors.text,
                fontWeight: FontWeight.w600,
              )
            : t.text.caption,
      );
      final left = isDay ? tick.x + s.labelGap : tick.x - text.width / 2;
      final rect = Rect.fromLTWH(
        left,
        (size.height - tickLength - text.height) / 2,
        text.width,
        text.height,
      );
      canvas.drawLine(
        Offset(tick.x, size.height - (isDay ? size.height : tickLength)),
        Offset(tick.x, size.height),
        isDay
            ? (Paint()
                ..color = t.colors.textMuted
                ..strokeWidth = s.nowLine)
            : line,
      );
      if (taken.any((r) => r.overlaps(rect))) return;
      taken.add(rect.inflate(s.labelGap));
      text.paint(canvas, rect.topLeft);
    }

    // Fold lengths before the ticks, after the current time.
    for (final (text, rect) in foldLabels) {
      if (taken.any((r) => r.overlaps(rect))) continue;
      taken.add(rect.inflate(s.labelGap));
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(t.radii.sm)),
        Paint()..color = t.colors.background,
      );
      text.paint(canvas, rect.topLeft.translate(s.labelGap, 0));
    }

    final dayLines = axis.stepMs < stripDayMs;
    for (final tick in axis.ticks) {
      if (tick.isDay) label(tick, isDay: dayLines);
    }
    for (final tick in axis.ticks) {
      if (!tick.isDay) label(tick, isDay: false);
    }

    if (nowText != null && nowRect != null) {
      canvas
        ..drawLine(
          Offset(nowX, 0),
          Offset(nowX, size.height),
          Paint()
            ..color = t.colors.primary
            ..strokeWidth = s.nowLine,
        )
        ..drawRRect(
          RRect.fromRectAndRadius(nowRect, Radius.circular(t.radii.sm)),
          Paint()..color = t.colors.primary,
        );
      nowText.paint(canvas, nowRect.topLeft.translate(s.labelGap, 0));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(StripAxisPainter oldDelegate) {
    final changed =
        oldDelegate.style != style ||
        !identical(oldDelegate.viewport, viewport);
    if (changed || !identical(oldDelegate, this)) oldDelegate._texts.dispose();
    return changed;
  }
}

/// The corner above the track names: the date at the left edge of the
/// strip (the axis itself only shows times of day).
class StripCornerPainter extends CustomPainter {
  StripCornerPainter({required this.viewport, required this.style})
    : super(repaint: viewport);

  final StripViewport viewport;
  final StripStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final t = style.tokens;
    final line = Paint()
      ..color = t.colors.border
      ..strokeWidth = math.max(t.sizes.hairline, 0.5);
    canvas.drawLine(
      Offset(0, size.height - line.strokeWidth / 2),
      Offset(size.width, size.height - line.strokeWidth / 2),
      line,
    );
    if (viewport.width <= 0) return;
    final text = TextPainter(
      text: TextSpan(
        text: stripDayLabel(viewport.startMs.floor()),
        style: t.text.caption,
      ),
      textDirection: TextDirection.ltr,
      textScaler: style.textScaler,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(0, size.width - 2 * t.space.sm));
    text
      ..paint(canvas, Offset(t.space.sm, (size.height - text.height) / 2))
      ..dispose();
  }

  @override
  bool shouldRepaint(StripCornerPainter oldDelegate) =>
      oldDelegate.style != style || !identical(oldDelegate.viewport, viewport);
}

/// A fold from [top] to [bottom]: a narrow column on the surface colour,
/// hatched, with dashed edges (Pult 3.1).
void _paintFold(
  Canvas canvas,
  StripFoldMark fold,
  double top,
  double bottom,
  TikkyTokens t,
) {
  final rect = Rect.fromLTRB(fold.left, top, fold.right, bottom);
  if (rect.width <= 0 || rect.height <= 0) return;
  final line = Paint()
    ..color = t.colors.border
    ..strokeWidth = 1;
  canvas
    ..drawRect(rect, Paint()..color = t.colors.surface)
    ..save()
    ..clipRect(rect);
  // Anchored to the top of the column: the lines do not crawl.
  final step = t.strip.foldHatchSpacing;
  for (var x = rect.left - rect.height; x < rect.right; x += step) {
    canvas.drawLine(
      Offset(x, rect.bottom),
      Offset(x + rect.height, rect.top),
      line,
    );
  }
  canvas.restore();
  // Dashed edges.
  final dash = t.strip.foldHatchSpacing / 2;
  for (final x in [rect.left, rect.right]) {
    for (var y = rect.top; y < rect.bottom; y += 2 * dash) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(rect.bottom, y + dash)),
        line,
      );
    }
  }
}
