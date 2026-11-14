import 'package:flutter/material.dart';
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
  static Key progress(String trackId) => ValueKey('lane-progress-$trackId');
  static Key handle(String trackId) => ValueKey('lane-handle-$trackId');
}

/// The lane of a stopwatch, countdown, interval, counter or reminder track.
///
/// Everything shown is derived from the open session's event log and the
/// shared "now" ticker. Only the time text follows the ticker; the frame and
/// the buttons rebuild when the state changes.
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

Color _alertColor(TikkyTokens t, Track track) =>
    track.mode == TrackMode.reminder ? t.colors.warning : t.colors.danger;

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

    final title = _LaneTitle(track: track);
    final time = NowSelector<LaneTime>(
      enabled: ticking,
      selector: (now) => model.at(now).time,
      builder: (context, time) => _LaneTimeBlock(track: track, time: time),
    );
    final info = MergeSemantics(
      child: Semantics(
        value: controls.status,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            SizedBox(height: t.space.xxs),
            time,
          ],
        ),
      ),
    );

    final secondary = [
      for (final s in controls.secondary)
        _SecondaryButton(
          key: LaneKeys.secondary(track.id, s.kind),
          track: track,
          action: s,
          onPressed: s.enabled
              ? () => actions.secondary(context, track, s.kind)
              : null,
        ),
    ];
    final primary = controls.primary == LanePrimary.none
        ? null
        : _PrimaryButton(
            key: LaneKeys.primary(track.id),
            track: track,
            action: controls.primary,
            onPressed: () => actions.toggle(track),
          );
    final labels = controls.hasLabels
        ? Wrap(
            spacing: t.space.sm,
            runSpacing: t.space.sm,
            alignment: leftHanded ? WrapAlignment.start : WrapAlignment.end,
            children: [
              for (final entry in controls.labelCounts.entries)
                _LabelButton(
                  key: LaneKeys.label(track.id, entry.key),
                  track: track,
                  label: entry.key,
                  count: entry.value,
                  onPressed: () => actions.tick(track, label: entry.key),
                ),
            ],
          )
        : null;

    final Widget content;
    if (tiles) {
      // The secondary buttons wrap onto further lines when a narrow tile
      // (large button scale, several columns) cannot hold them in one.
      final buttonRow = [
        Expanded(
          child: Wrap(
            alignment: leftHanded ? WrapAlignment.end : WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: leftHanded ? secondary.reversed.toList() : secondary,
          ),
        ),
        ?primary,
      ];
      content = ConstrainedBox(
        constraints: BoxConstraints(minHeight: t.sizes.tileMinHeight),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            t.space.md + t.sizes.colorBar,
            t.space.sm,
            t.space.sm,
            t.space.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: t.space.xs),
                      child: info,
                    ),
                  ),
                  ?dragHandle,
                ],
              ),
              SizedBox(height: t.space.sm),
              Row(
                children: leftHanded
                    ? buttonRow.reversed.toList()
                    : buttonRow,
              ),
              if (labels != null) ...[SizedBox(height: t.space.sm), labels],
            ],
          ),
        ),
      );
    } else {
      final buttons = Padding(
        padding: EdgeInsets.symmetric(horizontal: t.space.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: leftHanded
              ? [?primary, ...secondary.reversed]
              : [...secondary, ?primary],
        ),
      );
      final text = Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: t.space.sm,
            horizontal: t.space.xs,
          ),
          child: info,
        ),
      );
      final handle = dragHandle ?? SizedBox(width: t.space.sm);
      content = ConstrainedBox(
        constraints: BoxConstraints(minHeight: t.sizes.laneMinHeight),
        child: Padding(
          padding: EdgeInsets.only(left: t.sizes.colorBar),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: leftHanded
                    ? [buttons, text, handle]
                    : [handle, text, buttons],
              ),
              if (labels != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space.md,
                    0,
                    t.space.md,
                    t.space.md,
                  ),
                  child: labels,
                ),
            ],
          ),
        ),
      );
    }

    final alert = _alertColor(t, track);
    return Semantics(
      container: true,
      onLongPress: onEdit,
      onLongPressHint: onEdit == null ? null : TracksStrings.actionEditTrack,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onLongPress: onEdit,
        onSecondaryTap: onEdit,
        child: Container(
          decoration: t.surfaceDecoration(
            color: controls.ringing ? t.colors.surfaceAlt : null,
          ),
          foregroundDecoration: controls.ringing
              ? BoxDecoration(
                  borderRadius: t.radii.mdAll,
                  border: Border.all(
                    color: alert,
                    width: t.sizes.progressBar,
                  ),
                )
              : null,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              content,
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: t.sizes.colorBar,
                child: ColoredBox(color: t.trackColor(track)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small muted "name · mode" line.
class _LaneTitle extends StatelessWidget {
  const _LaneTitle({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final mode = Strings.modeName(track.mode);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: track.name,
            style: TextStyle(color: t.colors.text),
          ),
          if (mode != track.name)
            TextSpan(text: '${TracksStrings.separator}$mode'),
        ],
      ),
      style: t.text.laneTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Digits, progress bar and sub-line: the only part that follows the
/// ticker.
class _LaneTimeBlock extends StatelessWidget {
  const _LaneTimeBlock({required this.track, required this.time});

  final Track track;
  final LaneTime time;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final prefs = t.prefs;
    final alert = _alertColor(t, track);
    final digitStyle = time.alert && time.blinkOn
        ? t.text.digitsLarge.copyWith(color: alert)
        : t.text.digitsLarge;
    final progress = time.progress;
    final secondaryDigits = time.secondaryDigits;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
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
                  style: t.text.digitsMedium.copyWith(
                    color: t.colors.textMuted,
                  ),
                  maxLines: 1,
                  softWrap: false,
                ),
              ],
            ],
          ),
        ),
        if (prefs.showProgressBar && progress != null)
          Padding(
            padding: EdgeInsets.only(top: t.space.xs),
            child: _ProgressBar(
              key: LaneKeys.progress(track.id),
              value: progress,
              color: time.alert ? alert : t.trackColor(track),
            ),
          ),
        if (prefs.showSubLine && time.subLine.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: t.space.xs),
            child: Text(
              time.subLine,
              key: LaneKeys.subLine(track.id),
              style: time.alert
                  ? t.text.subLine.copyWith(color: alert)
                  : t.text.subLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// Thin flat progress bar (no animation: it is redrawn from "now").
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color, super.key});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: t.radii.smAll,
        child: SizedBox(
          height: t.sizes.progressBar,
          child: ColoredBox(
            color: t.colors.border,
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value.clamp(0, 1).toDouble(),
              heightFactor: 1,
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round, flat button with a semantics label and tooltip.
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
    this.outlined = false,
    this.hitSize,
  });

  final IconData icon;
  final String tooltip;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final double diameter;
  final double iconSize;
  final Color? background;
  final Color foreground;
  final bool outlined;

  /// Side of the (square) tap target when it is larger than the circle.
  final double? hitSize;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final enabled = onPressed != null;
    final hit = hitSize == null || hitSize! < diameter ? diameter : hitSize!;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: Material(
          type: background == null
              ? MaterialType.transparency
              : MaterialType.canvas,
          color: background,
          shape: CircleBorder(
            side: outlined ? t.hairline : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            splashFactory: isCupertino(context)
                ? NoSplash.splashFactory
                : null,
            onTap: onPressed,
            child: SizedBox.square(
              dimension: hit,
              child: Icon(
                icon,
                size: iconSize,
                color: enabled ? foreground : t.colors.border,
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
    required this.onPressed,
    super.key,
  });

  final Track track;
  final LanePrimary action;
  final VoidCallback onPressed;

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
      LanePrimary.tick || LanePrimary.none => (
        AdaptiveIcons.plusOne(context),
        Strings.actionTick,
      ),
    };
    final (Color background, Color foreground, bool outlined) =
        switch (action) {
          LanePrimary.pause => (t.colors.surfaceAlt, t.colors.text, true),
          LanePrimary.dismiss => (
            t.colors.danger,
            t.onColor(t.colors.danger),
            false,
          ),
          LanePrimary.ack => (
            t.colors.warning,
            t.onColor(t.colors.warning),
            false,
          ),
          _ => (t.colors.primary, t.colors.onPrimary, false),
        };
    return _RoundButton(
      icon: icon,
      tooltip: label,
      semanticLabel: '${track.name}: $label',
      onPressed: onPressed,
      diameter: t.sizes.primaryButton,
      iconSize: t.sizes.primaryIcon,
      background: background,
      foreground: foreground,
      outlined: outlined,
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.track,
    required this.action,
    required this.onPressed,
    super.key,
  });

  final Track track;
  final LaneSecondary action;
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
        TracksStrings.actionStopSession,
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
      hitSize: t.sizes.minTapTarget,
      iconSize: t.sizes.secondaryIcon,
      background: null,
      foreground: t.colors.textMuted,
    );
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
    return Semantics(
      button: true,
      label: '${track.name}: ${TracksStrings.tickLabel(label)}',
      value: Strings.countValue(count),
      excludeSemantics: true,
      child: Material(
        color: t.colors.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: t.radii.smAll,
          side: t.hairline,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashFactory: isCupertino(context) ? NoSplash.splashFactory : null,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: t.sizes.minTapTarget,
              minWidth: t.sizes.primaryButton,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.md,
                vertical: t.space.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      style: t.text.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: t.space.sm),
                  Text(
                    Strings.countValue(count),
                    style: t.text.digitsSmall.copyWith(color: t.colors.text),
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
