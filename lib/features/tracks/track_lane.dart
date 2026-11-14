import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/domain/domain.dart';
import '../../core/now_ticker.dart';
import '../../core/repo/providers.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'lane_actions.dart';
import 'lane_view.dart';
import 'now_selector.dart';
import 'tracks_strings.dart';

/// Keys of the parts of a lane (for tests and for finding a lane's button
/// from the outside).
abstract final class LaneKeys {
  static Key lane(String trackId) => ValueKey('lane-$trackId');
  static Key primary(String trackId) => ValueKey('lane-primary-$trackId');
  static Key secondary(String trackId, LaneSecondaryKind kind) =>
      ValueKey('lane-${kind.name}-$trackId');
  static Key label(String trackId, String label) =>
      ValueKey('lane-label-$trackId-$label');
  static Key digits(String trackId) => ValueKey('lane-digits-$trackId');
  static Key subLine(String trackId) => ValueKey('lane-subline-$trackId');

  /// The fill behind a timer, interval or reminder lane.
  static Key progress(String trackId) => ValueKey('lane-progress-$trackId');
  static Key handle(String trackId) => ValueKey('lane-handle-$trackId');
}

/// The lane of a stopwatch, countdown, interval, counter or reminder track.
///
/// A lane is a surface in the colour of its track (`roles(..).tint`); a
/// paused one keeps only the outline, a ready one a thin neutral outline
/// and a single line, a ringing one turns into the alarm colour. Timer,
/// interval and reminder fill the surface with the time that is left.
///
/// Everything shown is derived from the open session's event log and the
/// shared "now" ticker. Only the time text, the fill and the lamp follow
/// the ticker; the surface and the buttons rebuild when the state changes.
class TrackLane extends ConsumerWidget {
  const TrackLane({
    required this.track,
    this.layout = LaneLayout.rows,
    this.dragHandle,
    this.onEdit,
    super.key,
  });

  final Track track;
  final LaneLayout layout;

  /// The reorder handle (built by the list / grid that owns the ordering).
  final Widget? dragHandle;

  /// Long-press / secondary click: open the track editor.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final open = ref.watch(openSessionProvider(track.id));
    final ticker = ref.watch(nowTickerProvider);
    final model = LaneModel(
      track: track,
      open: open,
      prefs: t.prefs,
      blinkMs: t.motion.ringBlink.inMilliseconds,
    );
    // Time-driven state changes (running -> ringing) keep the lane ticking;
    // every other change of "ticking" arrives as a new event log.
    final ticking = model.at(ticker.value).ticking;
    return NowSelector<LaneControls>(
      enabled: ticking,
      selector: (now) => model.at(now).controls,
      builder: (context, controls) => _LaneFrame(
        track: track,
        model: model,
        controls: controls,
        ticking: ticking,
        layout: layout,
        dragHandle: dragHandle,
        onEdit: onEdit,
      ),
    );
  }
}

/// The colours of one lane in one look.
@immutable
final class _LanePaint {
  const _LanePaint({
    required this.surface,
    required this.outline,
    required this.outlineWidth,
    required this.name,
    required this.ink,
    required this.digits,
    required this.lamp,
    required this.lampLit,
    required this.primaryBackground,
    required this.primaryForeground,
    required this.primaryOutline,
    required this.secondaryBackground,
    required this.secondaryForeground,
    required this.secondaryOutline,
    required this.fill,
    required this.segmentDone,
    required this.segmentNow,
    required this.segmentLater,
  });

  factory _LanePaint.of(TikkyTokens t, Track track, LaneLook look) {
    final r = t.trackRoles(track);
    final c = t.colors;
    switch (look) {
      case LaneLook.ringing:
        return _LanePaint(
          surface: c.danger,
          outline: null,
          outlineWidth: 0,
          name: c.onDanger,
          ink: c.onDanger,
          digits: c.onDanger,
          lamp: c.onDanger,
          lampLit: true,
          primaryBackground: c.onDanger,
          primaryForeground: c.danger,
          primaryOutline: null,
          secondaryBackground: null,
          secondaryForeground: c.onDanger,
          secondaryOutline: c.onDanger,
          fill: r.strong,
          segmentDone: c.onDanger,
          segmentNow: c.onDanger,
          segmentLater: c.onDanger,
        );
      case LaneLook.idle:
        return _LanePaint(
          surface: null,
          outline: c.border,
          outlineWidth: t.sizes.laneOutlineIdle,
          name: c.text,
          ink: c.textMuted,
          digits: c.textMuted,
          lamp: r.solid,
          lampLit: false,
          primaryBackground: null,
          primaryForeground: r.ink,
          primaryOutline: r.solid,
          secondaryBackground: r.strong,
          secondaryForeground: c.text,
          secondaryOutline: null,
          fill: r.strong,
          segmentDone: r.solid,
          segmentNow: c.text,
          segmentLater: r.strong,
        );
      case LaneLook.running || LaneLook.paused || LaneLook.due:
        final paused = look == LaneLook.paused;
        final due = look == LaneLook.due;
        return _LanePaint(
          surface: paused ? null : r.tint,
          outline: paused ? r.strong : (due ? c.warning : null),
          outlineWidth: paused
              ? t.sizes.laneOutlinePaused
              : (due ? t.sizes.laneOutlineDue : 0),
          name: r.ink,
          ink: r.ink,
          digits: c.text,
          lamp: r.solid,
          lampLit: !paused,
          primaryBackground: r.solid,
          primaryForeground: r.on,
          primaryOutline: null,
          secondaryBackground: r.strong,
          secondaryForeground: c.text,
          secondaryOutline: null,
          fill: r.strong,
          segmentDone: r.solid,
          segmentNow: c.text,
          segmentLater: r.strong,
        );
    }
  }

  /// `null` = no surface (the page shows through).
  final Color? surface;
  final Color? outline;
  final double outlineWidth;

  /// The name in the head line; [ink] for the mode and the sub-line.
  final Color name;
  final Color ink;
  final Color digits;
  final Color lamp;

  /// A lit lamp is filled, an unlit one only outlined.
  final bool lampLit;
  final Color? primaryBackground;
  final Color primaryForeground;
  final Color? primaryOutline;
  final Color? secondaryBackground;
  final Color secondaryForeground;
  final Color? secondaryOutline;
  final Color fill;
  final Color segmentDone;
  final Color segmentNow;
  final Color segmentLater;
}

class _LaneFrame extends ConsumerWidget {
  const _LaneFrame({
    required this.track,
    required this.model,
    required this.controls,
    required this.ticking,
    required this.layout,
    required this.dragHandle,
    required this.onEdit,
  });

  final Track track;
  final LaneModel model;
  final LaneControls controls;
  final bool ticking;
  final LaneLayout layout;
  final Widget? dragHandle;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final actions = ref.read(laneActionsProvider);
    final leftHanded = t.prefs.leftHanded;
    final tiles = layout == LaneLayout.tiles;
    final look = controls.look;
    final idle = look == LaneLook.idle && !tiles;
    final paint = _LanePaint.of(t, track, look);
    final stop = controls.canStop ? () => actions.stop(track) : null;

    final head = _LaneHead(
      track: track,
      paint: paint,
      ticking: ticking,
      showMode: !idle,
    );
    Widget timeBlock({required bool digits, required bool subLine}) =>
        NowSelector<LaneTime>(
          enabled: ticking,
          selector: (now) => model.at(now).time,
          builder: (context, time) => _LaneTimeBlock(
            track: track,
            time: time,
            paint: paint,
            showDigits: digits,
            showSubLine: subLine,
            idle: idle,
          ),
        );

    final secondaryAction = controls.secondary;
    final secondary = secondaryAction == null
        ? null
        : _SecondaryButton(
            key: LaneKeys.secondary(track.id, secondaryAction.kind),
            track: track,
            action: secondaryAction,
            paint: paint,
            onPressed: secondaryAction.enabled
                ? () => actions.secondary(track, secondaryAction.kind)
                : null,
          );
    final primary = controls.primary == LanePrimary.none
        ? null
        : _PrimaryButton(
            key: LaneKeys.primary(track.id),
            track: track,
            action: controls.primary,
            paint: paint,
            idle: idle,
            onPressed: () => actions.toggle(track),
            onLongPress: stop,
          );
    final labels = controls.hasLabels
        ? _LabelGrid(
            track: track,
            counts: controls.labelCounts,
            onTick: (label) => actions.tick(track, label: label),
          )
        : null;
    final segments = NowSelector<LaneSegments?>(
      enabled: ticking,
      selector: (now) => model.at(now).time.segments,
      builder: (context, segments) => segments == null
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(top: t.space.sm),
              child: _Segments(segments: segments, paint: paint),
            ),
    );

    final gap = SizedBox(width: t.space.sm);
    final Widget content;
    if (idle) {
      final text = Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            head,
            SizedBox(height: t.space.xxs),
            timeBlock(digits: false, subLine: true),
          ],
        ),
      );
      final digits = timeBlock(digits: true, subLine: false);
      final info = [
        text,
        SizedBox(width: t.space.md),
        // Its own width, at most a share of the lane: large digits shrink.
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: t.sizes.laneDigitsIdleMax),
          child: digits,
        ),
      ];
      final row = [
        Expanded(
          child: MergeSemantics(
            child: Semantics(
              value: controls.status,
              child: Row(children: leftHanded ? info.reversed.toList() : info),
            ),
          ),
        ),
        if (primary != null) ...[gap, primary],
      ];
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: leftHanded ? row.reversed.toList() : row),
          if (labels != null) ...[SizedBox(height: t.space.sm), labels],
        ],
      );
    } else {
      final info = MergeSemantics(
        child: Semantics(
          value: controls.status,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              head,
              SizedBox(height: t.space.xxs),
              timeBlock(digits: true, subLine: true),
            ],
          ),
        ),
      );
      final buttons = [
        ?secondary,
        if (secondary != null && primary != null) gap,
        ?primary,
      ];
      if (tiles) {
        content = ConstrainedBox(
          constraints: BoxConstraints(minHeight: t.sizes.tileMinHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              info,
              segments,
              SizedBox(height: t.space.sm),
              Row(
                mainAxisAlignment: leftHanded
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.end,
                children: leftHanded ? buttons.reversed.toList() : buttons,
              ),
              if (labels != null) ...[SizedBox(height: t.space.sm), labels],
            ],
          ),
        );
      } else {
        final row = [
          Expanded(child: info),
          if (buttons.isNotEmpty) gap,
          ...buttons,
        ];
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: leftHanded ? row.reversed.toList() : row),
            segments,
            if (labels != null) ...[SizedBox(height: t.space.sm), labels],
          ],
        );
      }
    }

    // The grip sits at the leading edge (the trailing one for left-handed
    // use, where the buttons lead).
    final handle = dragHandle;
    final verticalPad = idle ? t.space.sm : t.space.md;
    final padded = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        handle == null && !leftHanded ? t.space.lg : 0,
        verticalPad,
        handle == null && leftHanded ? t.space.lg : t.space.md,
        verticalPad,
      ),
      child: Row(
        children: [
          if (handle != null && !leftHanded) handle,
          Expanded(child: content),
          if (handle != null && leftHanded) handle,
        ],
      ),
    );

    final showFill =
        t.prefs.showProgressBar &&
        (look == LaneLook.running || look == LaneLook.paused) &&
        track.mode != TrackMode.stopwatch &&
        track.mode != TrackMode.counter;
    final minHeight = idle
        ? t.sizes.laneHeightIdle
        : (tiles ? t.sizes.tileMinHeight : t.sizes.laneHeightActive);
    final outline = paint.outline;

    return Semantics(
      container: true,
      onLongPress: onEdit,
      onLongPressHint: onEdit == null ? null : TracksStrings.actionEditTrack,
      customSemanticsActions: stop == null
          ? null
          : {
              const CustomSemanticsAction(label: TracksStrings.actionStopHint):
                  stop,
            },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onLongPress: onEdit,
        onSecondaryTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            color: paint.surface,
            borderRadius: t.radii.laneAll,
          ),
          foregroundDecoration: outline == null
              ? null
              : BoxDecoration(
                  borderRadius: t.radii.laneAll,
                  border: Border.all(color: outline, width: paint.outlineWidth),
                ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [
                if (showFill)
                  Positioned.fill(
                    child: NowSelector<double?>(
                      enabled: ticking,
                      selector: (now) => model.at(now).time.progress,
                      builder: (context, progress) => progress == null
                          ? const SizedBox.shrink()
                          : _Fill(
                              key: LaneKeys.progress(track.id),
                              remaining: 1 - progress,
                              color: paint.fill,
                            ),
                    ),
                  ),
                padded,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The surface behind the content, filled with the share of time that is
/// left; it shrinks towards the leading edge. Redrawn from "now", never
/// animated.
class _Fill extends StatelessWidget {
  const _Fill({required this.remaining, required this.color, super.key});

  final double remaining;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: remaining.clamp(0, 1).toDouble(),
      heightFactor: 1,
      child: ColoredBox(color: color),
    ),
  );
}

/// Lamp, name and mode.
class _LaneHead extends StatelessWidget {
  const _LaneHead({
    required this.track,
    required this.paint,
    required this.ticking,
    required this.showMode,
  });

  final Track track;
  final _LanePaint paint;
  final bool ticking;
  final bool showMode;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final mode = Strings.modeName(track.mode);
    // The lamp sits in the text's leading padding, so a very narrow lane
    // (large buttons) shortens the text instead of overflowing.
    return Stack(
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(start: t.sizes.lamp + t.space.sm),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: track.name,
                  style: t.text.laneName.copyWith(color: paint.name),
                ),
                if (showMode && mode != track.name)
                  TextSpan(
                    text: '  $mode',
                    style: t.text.laneMode.copyWith(color: paint.ink),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          child: Center(
            child: _Lamp(color: paint.lamp, lit: paint.lampLit, pulse: ticking),
          ),
        ),
      ],
    );
  }
}

/// The lamp in the head line: lit (filled) or not (outlined). A lit lamp
/// of a ticking lane pulses with the clock - no animation of its own, so
/// nothing runs while "Bewegung reduzieren" is on or the lane is still.
class _Lamp extends StatelessWidget {
  const _Lamp({required this.color, required this.lit, required this.pulse});

  final Color color;
  final bool lit;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final dot = ExcludeSemantics(
      child: SizedBox.square(
        dimension: t.sizes.lamp,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: lit ? color : null,
            borderRadius: t.radii.pillAll,
            border: lit
                ? null
                : Border.all(color: color, width: t.sizes.laneButtonOutline),
          ),
        ),
      ),
    );
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!lit || !pulse || reduceMotion) return dot;
    final half = t.motion.lampPulse;
    return NowSelector<bool>(
      selector: (now) => (now ~/ half.inMilliseconds).isEven,
      builder: (context, bright) => AnimatedOpacity(
        opacity: bright ? 1 : t.motion.lampDim,
        duration: half,
        curve: Curves.easeInOut,
        child: dot,
      ),
    );
  }
}

/// Digits and sub-line: the only text that follows the ticker.
class _LaneTimeBlock extends StatelessWidget {
  const _LaneTimeBlock({
    required this.track,
    required this.time,
    required this.paint,
    required this.showDigits,
    required this.showSubLine,
    required this.idle,
  });

  final Track track;
  final LaneTime time;
  final _LanePaint paint;
  final bool showDigits;
  final bool showSubLine;

  /// A ready lane: small digits on the side, the mode in the sub-line.
  final bool idle;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final prefs = t.prefs;
    final secondaryDigits = time.secondaryDigits;
    final digitStyle = (idle ? t.text.laneDigitsIdle : t.text.laneDigits)
        .copyWith(color: paint.digits);
    final digits = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            time.digits,
            key: LaneKeys.digits(track.id),
            style: digitStyle,
            maxLines: 1,
            softWrap: false,
          ),
          if (secondaryDigits != null) ...[
            SizedBox(width: t.space.md),
            Text(
              secondaryDigits,
              style: t.text.laneDigitsIdle.copyWith(color: paint.ink),
              maxLines: 1,
              softWrap: false,
            ),
          ],
        ],
      ),
    );
    if (!showSubLine) return digits;

    final mode = Strings.modeName(track.mode);
    final subStyle = t.text.laneSub.copyWith(color: paint.ink);
    final Widget? sub;
    if (prefs.showSubLine && time.subLine.isNotEmpty) {
      sub = Text(
        idle ? '$mode${TracksStrings.separator}${time.subLine}' : time.subLine,
        key: LaneKeys.subLine(track.id),
        style: subStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    } else if (idle && mode != track.name) {
      sub = Text(mode, style: subStyle, maxLines: 1);
    } else {
      sub = null;
    }
    if (!showDigits) return sub ?? const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [digits, ?sub],
    );
  }
}

/// The rounds of an interval: done, running, still to come.
class _Segments extends StatelessWidget {
  const _Segments({required this.segments, required this.paint});

  final LaneSegments segments;
  final _LanePaint paint;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 1; i <= segments.total; i++) ...[
            if (i > 1) SizedBox(width: t.space.xs),
            Expanded(
              child: SizedBox(
                height: t.sizes.laneSegment,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: t.radii.pillAll,
                    color: i < segments.current
                        ? paint.segmentDone
                        : (i == segments.current
                              ? paint.segmentNow
                              : paint.segmentLater),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A round (or, in a square design, square) flat button with a semantics
/// label and tooltip.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.semanticLabel,
    required this.onPressed,
    required this.diameter,
    required this.iconSize,
    required this.background,
    required this.foreground,
    this.outline,
    this.onLongPress,
    this.longPressHint,
  });

  final IconData icon;
  final String tooltip;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double diameter;
  final double iconSize;
  final Color? background;
  final Color foreground;
  final Color? outline;
  final VoidCallback? onLongPress;
  final String? longPressHint;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final enabled = onPressed != null;
    final hit = diameter < t.sizes.minTapTarget
        ? t.sizes.minTapTarget
        : diameter;
    final outline = this.outline;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: semanticLabel,
      onTap: onPressed,
      onLongPress: onLongPress,
      onLongPressHint: onLongPress == null ? null : longPressHint,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: hit,
          child: Center(
            child: Material(
              type: background == null
                  ? MaterialType.transparency
                  : MaterialType.canvas,
              color: background,
              shape: RoundedRectangleBorder(
                borderRadius: t.radii.pillAll,
                side: outline == null
                    ? BorderSide.none
                    : BorderSide(
                        color: outline,
                        width: t.sizes.laneButtonOutline,
                      ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                splashFactory: isCupertino(context)
                    ? NoSplash.splashFactory
                    : null,
                onTap: onPressed,
                onLongPress: onLongPress,
                child: SizedBox.square(
                  dimension: diameter,
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: enabled ? foreground : t.colors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.track,
    required this.action,
    required this.paint,
    required this.idle,
    required this.onPressed,
    required this.onLongPress,
    super.key,
  });

  final Track track;
  final LanePrimary action;
  final _LanePaint paint;

  /// The smaller, outlined button of a ready lane.
  final bool idle;
  final VoidCallback onPressed;

  /// Stops the run (E2); `null` while nothing runs.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final (IconData icon, String label) = switch (action) {
      LanePrimary.start => (AdaptiveIcons.play(context), Strings.actionStart),
      LanePrimary.resume => (AdaptiveIcons.play(context), Strings.actionResume),
      LanePrimary.pause => (AdaptiveIcons.pause(context), Strings.actionPause),
      LanePrimary.dismiss => (
        AdaptiveIcons.stop(context),
        Strings.actionDismiss,
      ),
      LanePrimary.ack => (AdaptiveIcons.check(context), Strings.actionAck),
      LanePrimary.tick ||
      LanePrimary.none => (AdaptiveIcons.plusOne(context), Strings.actionTick),
    };
    return _RoundButton(
      icon: icon,
      tooltip: label,
      semanticLabel: '${track.name}: $label',
      onPressed: onPressed,
      onLongPress: onLongPress,
      longPressHint: TracksStrings.actionStopHint,
      diameter: idle ? t.sizes.primaryButtonIdle : t.sizes.primaryButton,
      iconSize: t.sizes.primaryIcon,
      background: paint.primaryBackground,
      foreground: paint.primaryForeground,
      outline: paint.primaryOutline,
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.track,
    required this.action,
    required this.paint,
    required this.onPressed,
    super.key,
  });

  final Track track;
  final LaneSecondary action;
  final _LanePaint paint;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final (IconData icon, String label) = switch (action.kind) {
      LaneSecondaryKind.lap => (AdaptiveIcons.lap(context), Strings.actionLap),
      LaneSecondaryKind.restart => (
        AdaptiveIcons.reset(context),
        Strings.actionRestart,
      ),
      LaneSecondaryKind.reset => (
        AdaptiveIcons.stop(context),
        Strings.actionStop,
      ),
      LaneSecondaryKind.stop => (
        AdaptiveIcons.stop(context),
        TracksStrings.actionStopHint,
      ),
      LaneSecondaryKind.undo => (
        AdaptiveIcons.undo(context),
        Strings.actionUndoTick,
      ),
      LaneSecondaryKind.ackEarly => (
        AdaptiveIcons.check(context),
        TracksStrings.actionAckEarly,
      ),
    };
    return _RoundButton(
      icon: icon,
      tooltip: label,
      semanticLabel: '${track.name}: $label',
      onPressed: onPressed,
      diameter: t.sizes.secondaryButton,
      iconSize: t.sizes.secondaryIcon,
      background: paint.secondaryBackground,
      foreground: paint.secondaryForeground,
      outline: paint.secondaryOutline,
    );
  }
}

/// The quick-label buttons of a counter, up to three in a row.
class _LabelGrid extends StatelessWidget {
  const _LabelGrid({
    required this.track,
    required this.counts,
    required this.onTick,
  });

  static const int _perRow = 3;

  final Track track;
  final Map<String, int> counts;
  final ValueChanged<String> onTick;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final entries = counts.entries.toList();
    final rows = <Widget>[];
    for (var start = 0; start < entries.length; start += _perRow) {
      final row = entries.skip(start).take(_perRow).toList();
      if (rows.isNotEmpty) rows.add(SizedBox(height: t.space.sm));
      rows.add(
        Row(
          children: [
            for (var i = 0; i < _perRow; i++) ...[
              if (i > 0) SizedBox(width: t.space.sm),
              Expanded(
                child: i < row.length
                    ? _LabelButton(
                        key: LaneKeys.label(track.id, row[i].key),
                        track: track,
                        label: row[i].key,
                        count: row[i].value,
                        onPressed: () => onTick(row[i].key),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// One quick-label button of a counter: label plus its count.
class _LabelButton extends StatelessWidget {
  const _LabelButton({
    required this.track,
    required this.label,
    required this.count,
    required this.onPressed,
    super.key,
  });

  final Track track;
  final String label;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final roles = t.trackRoles(track);
    return Semantics(
      button: true,
      label: '${track.name}: ${TracksStrings.tickLabel(label)}',
      value: Strings.countValue(count),
      excludeSemantics: true,
      child: Material(
        color: roles.strong,
        shape: RoundedRectangleBorder(borderRadius: t.radii.smallAll),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashFactory: isCupertino(context) ? NoSplash.splashFactory : null,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: t.sizes.minTapTarget),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: t.text.laneLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: t.space.sm),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Strings.countValue(count),
                        style: t.text.laneLabelCount.copyWith(color: roles.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The grip a lane is dragged by. The list / grid wraps it in its own drag
/// listener.
class LaneDragHandle extends StatelessWidget {
  const LaneDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Semantics(
      label: Strings.dragHandle,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: SizedBox(
          width: t.sizes.iconSm + t.space.md,
          height: t.sizes.minTapTarget,
          child: Icon(
            AdaptiveIcons.dragHandle(context),
            size: t.sizes.iconSm,
            color: t.colors.textMuted,
          ),
        ),
      ),
    );
  }
}
