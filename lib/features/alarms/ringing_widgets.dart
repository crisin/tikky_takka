import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/now_ticker.dart';
import '../../core/repo/providers.dart';
import '../../core/services/alarms/alarm_strings.dart';
import '../../core/services/haptics.dart';
import '../../l10n/formatters.dart';
import '../../l10n/strings.dart';
import '../../theme/tokens.dart';
import 'alarm_permission.dart';
import 'ringing_providers.dart';

/// Blinks [child] while [active] (a ringing lane, a due reminder).
///
/// The blink period is the theme's `motion.ringBlink`. With "reduce motion"
/// switched on in the OS the child is shown steadily instead. Costs nothing
/// while inactive: no ticker runs.
class RingingPulse extends StatefulWidget {
  const RingingPulse({required this.active, required this.child, super.key});

  /// How far the child fades at the low point of the blink.
  static const double dimmedOpacity = 0.35;

  final bool active;
  final Widget child;

  @override
  State<RingingPulse> createState() => _RingingPulseState();
}

class _RingingPulseState extends State<RingingPulse>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _opacity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RingingPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  void _sync() {
    final animate = widget.active && !MediaQuery.disableAnimationsOf(context);
    if (!animate) {
      _controller?.stop();
      _controller?.value = 0;
      return;
    }
    final period = context.tikky.motion.ringBlink;
    final controller = _controller ??= AnimationController(vsync: this);
    _opacity ??= Tween<double>(
      begin: 1,
      end: RingingPulse.dimmedOpacity,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    if (controller.duration != period || !controller.isAnimating) {
      controller.duration = period;
      controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = _opacity;
    if (opacity == null) return widget.child;
    return FadeTransition(opacity: opacity, child: widget.child);
  }
}

/// [RingingPulse] bound to the ringing state of one track.
class TrackRingingPulse extends ConsumerWidget {
  const TrackRingingPulse({
    required this.trackId,
    required this.child,
    super.key,
  });

  final String trackId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => RingingPulse(
    active: ref.watch(trackRingingProvider(trackId)),
    child: child,
  );
}

/// A compact list of everything that is ringing, each with its one button
/// ("Stopp" for timers and intervals, "Erledigt" for reminders).
///
/// Meant for places where the lane itself is not visible: above the tracks
/// when another set is active, on "Verlauf" and "Einstellungen". Renders
/// nothing while nothing rings. No confirmation dialogs.
class RingingBanner extends ConsumerWidget {
  const RingingBanner({this.setId, this.excludeSetId, super.key});

  /// Only tracks of this set.
  final String? setId;

  /// Leave out the tracks of this set (their lanes are on screen).
  final String? excludeSetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ringing = [
      for (final entry in ref.watch(ringingTracksProvider))
        if ((setId == null || entry.track.setId == setId) &&
            (excludeSetId == null || entry.track.setId != excludeSetId))
          entry,
    ];
    if (ringing.isEmpty) return const SizedBox.shrink();
    final t = context.tikky;
    return Semantics(
      container: true,
      liveRegion: true,
      label: AlarmStrings.ringingCount(ringing.length),
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: t.space.page,
          vertical: t.space.sm,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md,
          vertical: t.space.xs,
        ),
        decoration: t.surfaceDecoration(color: t.colors.surfaceAlt),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final entry in ringing) _RingingRow(entry: entry)],
        ),
      ),
    );
  }
}

class _RingingRow extends ConsumerWidget {
  const _RingingRow({required this.entry});

  final RingingTrack entry;

  Future<void> _handle(WidgetRef ref) async {
    unawaited(ref.read(hapticsProvider).heavy());
    final commands = ref.read(trackCommandsProvider);
    if (entry.isReminder) {
      await commands.ack(entry.trackId);
    } else {
      await commands.stopTrack(entry.trackId);
    }
    ref.read(nowTickerProvider).tickNow();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final track = entry.track;
    final name = track.name.trim().isEmpty
        ? Strings.modeName(track.mode)
        : track.name;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space.xs),
      child: Row(
        children: [
          RingingPulse(
            active: true,
            child: Container(
              width: t.sizes.dot,
              height: t.sizes.dot,
              decoration: BoxDecoration(
                color: t.trackColor(track),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: t.space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: t.text.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                NowBuilder(
                  builder: (context, nowMs, _) {
                    final since = Fmt.compact(nowMs - entry.sinceMs);
                    return Text(
                      entry.isReminder
                          ? AlarmStrings.dueSince(since)
                          : AlarmStrings.ringingSince(since),
                      style: t.text.subLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
          SizedBox(width: t.space.md),
          AdaptiveFilledButton(
            label: entry.isReminder
                ? Strings.notifActionAck
                : Strings.notifActionDismiss,
            onPressed: () => _handle(ref),
          ),
        ],
      ),
    );
  }
}

/// Asks for the missing alarm permission, in place, without a dialog of its
/// own: one line of explanation and an "Erlauben" button that starts the
/// system flow.
///
/// Renders nothing when alarms are unsupported on the device, when
/// everything is granted, or (with [onlyWithAlarmTracks]) while no track
/// could ring at all. Re-checks the state when the app returns from the
/// system settings.
class AlarmPermissionBanner extends ConsumerStatefulWidget {
  const AlarmPermissionBanner({this.onlyWithAlarmTracks = true, super.key});

  final bool onlyWithAlarmTracks;

  @override
  ConsumerState<AlarmPermissionBanner> createState() =>
      _AlarmPermissionBannerState();
}

class _AlarmPermissionBannerState extends ConsumerState<AlarmPermissionBanner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(alarmPermissionProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(alarmPermissionProvider).value;
    if (status == null || !status.supported || status.allGranted) {
      return const SizedBox.shrink();
    }
    if (widget.onlyWithAlarmTracks) {
      final tracks = ref.watch(allTracksProvider).value ?? const [];
      final relevant = tracks.any(
        (track) => !track.archived && track.mode.hasAlarms,
      );
      if (!relevant) return const SizedBox.shrink();
    }
    final t = context.tikky;
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: t.space.page,
        vertical: t.space.sm,
      ),
      padding: EdgeInsets.all(t.space.md),
      decoration: t.surfaceDecoration(color: t.colors.surfaceAlt),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AlarmStrings.permissionBannerTitle, style: t.text.label),
                SizedBox(height: t.space.xxs),
                Text(
                  status.notificationsGranted
                      ? AlarmStrings.permissionBannerExactBody
                      : AlarmStrings.permissionBannerBody,
                  style: t.text.subLine,
                ),
              ],
            ),
          ),
          SizedBox(width: t.space.md),
          AdaptiveFilledButton(
            label: AlarmStrings.permissionAllow,
            onPressed: () => unawaited(
              ref.read(alarmPermissionProvider.notifier).request(),
            ),
          ),
        ],
      ),
    );
  }
}
