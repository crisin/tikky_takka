import 'package:flutter/material.dart';

import '../../../adaptive/adaptive.dart';
import '../../../core/domain/enums.dart';
import '../../../l10n/formatters.dart';
import '../../../l10n/strings.dart';
import '../../../theme/theme.dart';
import '../settings_strings.dart';

/// The state a sample lane is shown in.
enum SampleLaneState { running, paused, ringing }

/// Content of one sample lane of the preview.
@immutable
class SampleLaneData {
  const SampleLaneData({
    required this.name,
    required this.mode,
    required this.state,
    required this.valueMs,
    required this.subLine,
    required this.colorIndex,
    this.progress,
  });

  final String name;
  final TrackMode mode;
  final SampleLaneState state;

  /// The time shown in large digits.
  final int valueMs;
  final String subLine;

  /// Index into the theme's track palette.
  final int colorIndex;

  /// 0..1 for lanes with a progress bar, `null` for none.
  final double? progress;

  /// The lanes of the standard preview: one running, one ringing and one
  /// paused, so every state colour of a theme is visible at once.
  static const List<SampleLaneData> standard = [
    SampleLaneData(
      name: SettingsStrings.sampleStopwatch,
      mode: TrackMode.stopwatch,
      state: SampleLaneState.running,
      valueMs: 5025600,
      subLine: SettingsStrings.sampleStopwatchSub,
      colorIndex: 0,
    ),
    SampleLaneData(
      name: SettingsStrings.sampleTimer,
      mode: TrackMode.countdown,
      state: SampleLaneState.ringing,
      valueMs: 0,
      subLine: SettingsStrings.sampleTimerSub,
      colorIndex: 1,
      progress: 1,
    ),
    SampleLaneData(
      name: SettingsStrings.sampleInterval,
      mode: TrackMode.interval,
      state: SampleLaneState.paused,
      valueMs: 228400,
      subLine: SettingsStrings.sampleIntervalSub,
      colorIndex: 2,
      progress: 0.62,
    ),
  ];
}

/// A non-interactive lane that mirrors the look of the real lanes on the
/// tracks screen: colour bar, name + mode line, large digits, progress bar,
/// sub-line, round primary button and a secondary icon button.
///
/// Everything is read from `context.tikky`, so it reacts to the theme and
/// to every UI preference (layout, density, scales, tenths, progress bar,
/// sub-line, left-handed).
class SampleLane extends StatelessWidget {
  const SampleLane({required this.data, super.key});

  final SampleLaneData data;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final prefs = t.prefs;
    final trackColor = t.paletteColor(data.colorIndex);
    final ringing = data.state == SampleLaneState.ringing;
    final paused = data.state == SampleLaneState.paused;
    final tiles = prefs.layout == LaneLayout.tiles;

    final digits = data.mode == TrackMode.stopwatch
        ? Fmt.clock(data.valueMs, tenths: prefs.showTenths)
        : Fmt.remaining(data.valueMs, tenths: prefs.showTenths);
    final digitColor = ringing
        ? t.colors.danger
        : (paused ? t.colors.textMuted : t.colors.text);

    final info = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${data.name} · ${Strings.modeName(data.mode)}',
          style: t.text.laneTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            digits,
            style: t.text.digitsLarge.copyWith(color: digitColor),
            maxLines: 1,
          ),
        ),
        if (prefs.showProgressBar && data.progress != null)
          Padding(
            padding: EdgeInsets.only(top: t.space.xs),
            child: _SampleProgress(
              value: data.progress!,
              color: ringing ? t.colors.danger : trackColor,
            ),
          ),
        if (prefs.showSubLine)
          Padding(
            padding: EdgeInsets.only(top: t.space.xs),
            child: Text(
              data.subLine,
              style: t.text.subLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );

    final primary = _SamplePrimaryButton(
      icon: switch (data.state) {
        SampleLaneState.running => AdaptiveIcons.pause(context),
        SampleLaneState.paused => AdaptiveIcons.play(context),
        SampleLaneState.ringing => AdaptiveIcons.stop(context),
      },
      background: ringing ? t.colors.danger : t.colors.primary,
      foreground: ringing ? t.onColor(t.colors.danger) : t.colors.onPrimary,
    );
    final secondary = SizedBox.square(
      dimension: t.sizes.secondaryButton,
      child: Icon(
        data.mode == TrackMode.stopwatch
            ? AdaptiveIcons.lap(context)
            : AdaptiveIcons.reset(context),
        size: t.sizes.secondaryIcon,
        color: t.colors.textMuted,
      ),
    );
    final gap = SizedBox(width: t.space.sm);
    final buttons = prefs.leftHanded
        ? [primary, gap, secondary]
        : [secondary, gap, primary];

    final Widget content;
    if (tiles) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          info,
          SizedBox(height: t.space.md),
          Row(
            mainAxisAlignment: prefs.leftHanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.end,
            children: buttons,
          ),
        ],
      );
    } else {
      final spacer = SizedBox(width: t.space.md);
      content = Row(
        children: prefs.leftHanded
            ? [...buttons, spacer, Expanded(child: info)]
            : [Expanded(child: info), spacer, ...buttons],
      );
    }

    final decoration = t.surfaceDecoration();
    return DecoratedBox(
      decoration: ringing && t.sizes.hairline > 0
          ? decoration.copyWith(
              border: Border.all(
                color: t.colors.danger,
                width: t.sizes.hairline,
              ),
            )
          : decoration,
      child: ClipRRect(
        borderRadius: t.radii.mdAll,
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: tiles ? t.sizes.tileMinHeight : t.sizes.laneMinHeight,
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  t.sizes.colorBar + t.space.md,
                  t.space.sm,
                  t.space.md,
                  t.space.sm,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  heightFactor: 1,
                  child: content,
                ),
              ),
            ),
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              width: t.sizes.colorBar,
              child: ColoredBox(color: trackColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _SamplePrimaryButton extends StatelessWidget {
  const _SamplePrimaryButton({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Container(
      width: t.sizes.primaryButton,
      height: t.sizes.primaryButton,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: t.sizes.primaryIcon, color: foreground),
    );
  }
}

class _SampleProgress extends StatelessWidget {
  const _SampleProgress({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return ClipRRect(
      borderRadius: t.radii.smAll,
      child: SizedBox(
        width: double.infinity,
        height: t.sizes.progressBar,
        child: ColoredBox(
          color: t.colors.surfaceAlt,
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: value.clamp(0, 1).toDouble(),
            child: ColoredBox(color: color),
          ),
        ),
      ),
    );
  }
}

/// Sample lanes drawn with [theme] and [prefs] on the theme's background:
/// the live preview of the theme editor and of the display settings.
class ThemePreview extends StatelessWidget {
  const ThemePreview({
    required this.theme,
    required this.prefs,
    this.lanes = SampleLaneData.standard,
    super.key,
  });

  final TikkyTheme theme;
  final UiPrefs prefs;
  final List<SampleLaneData> lanes;

  @override
  Widget build(BuildContext context) {
    final data = buildMaterialTheme(
      theme,
      prefs,
      platform: Theme.of(context).platform,
    );
    return Theme(
      data: data,
      child: Builder(
        builder: (context) {
          final t = context.tikky;
          final Widget body;
          if (prefs.layout == LaneLayout.tiles) {
            body = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < lanes.length; i += 2) ...[
                  if (i > 0) SizedBox(height: t.space.sm),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: SampleLane(data: lanes[i])),
                        SizedBox(width: t.space.sm),
                        Expanded(
                          child: i + 1 < lanes.length
                              ? SampleLane(data: lanes[i + 1])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          } else {
            body = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < lanes.length; i++) ...[
                  if (i > 0) SizedBox(height: t.space.sm),
                  SampleLane(data: lanes[i]),
                ],
              ],
            );
          }
          return Semantics(
            container: true,
            image: true,
            label: SettingsStrings.previewLabel,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: ColoredBox(
                  color: t.colors.background,
                  child: Padding(
                    padding: EdgeInsets.all(t.space.md),
                    child: body,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The preview pinned above a settings list: at most [maxHeight] tall
/// (scrolls inside when the lanes are taller) with a hairline below.
/// [footer] sits under the lanes (e.g. the contrast warning).
class PinnedPreview extends StatelessWidget {
  const PinnedPreview({
    required this.theme,
    required this.prefs,
    required this.maxHeight,
    this.footer,
    super.key,
  });

  final TikkyTheme theme;
  final UiPrefs prefs;
  final double maxHeight;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(border: Border(bottom: t.hairline)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ThemePreview(theme: theme, prefs: prefs),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// A settings page body with a live preview: pinned above [child] on
/// phones, in a side panel on wide layouts. The preview never takes more
/// than a share of the available height, so the list stays usable while
/// the keyboard is open.
class PreviewLayout extends StatelessWidget {
  const PreviewLayout({
    required this.theme,
    required this.prefs,
    required this.child,
    this.footer,
    super.key,
  });

  final TikkyTheme theme;
  final UiPrefs prefs;

  /// The scrollable settings list.
  final Widget child;

  /// Shown under the preview lanes (e.g. the contrast warning).
  final Widget? footer;

  /// Share of the available height the pinned preview may take.
  static const double pinnedHeightFactor = 0.45;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= TikkyTokens.wideBreakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: child),
              VerticalDivider(
                width: t.sizes.hairline,
                thickness: t.sizes.hairline,
                color: t.colors.border,
              ),
              Expanded(
                flex: 2,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ThemePreview(theme: theme, prefs: prefs),
                      ?footer,
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PinnedPreview(
              theme: theme,
              prefs: prefs,
              maxHeight: constraints.maxHeight * pinnedHeightFactor,
              footer: footer,
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
