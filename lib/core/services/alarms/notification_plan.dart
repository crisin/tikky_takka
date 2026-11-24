import 'dart:convert';

import '../../../l10n/formatters.dart';
import '../../../l10n/strings.dart';
import '../../domain/enums.dart';
import '../../domain/track.dart';
import '../../domain/track_config.dart';
import '../../engine/alarm_plan.dart';
import 'alarm_service.dart' show AlarmAction, AlarmActionType;
import 'alarm_strings.dart';

/// Pure translation of a track's alarm plan (`planAlarms`) into concrete OS
/// notifications: ids, fire instants, texts, action button, channel.
///
/// Nothing in this file touches a plugin, so the whole "which notification
/// at which instant" logic is unit-tested without a device.

// ------------------------------------------------------------------- ids

/// Stable notification ids derived from track ids.
///
/// Every track owns a block of [slotsPerTrack] consecutive ids. The block
/// start is a 27 bit FNV-1a hash of the track id, so ids are the same after
/// an app restart and "everything of this track" can be cancelled without
/// any bookkeeping. All ids are positive 31 bit integers (the plugin and
/// Android require 32 bit ints).
abstract final class AlarmIds {
  /// Ids reserved per track; equals `AlarmSync.maxAlarmsPerTrack`.
  static const int slotsPerTrack = 16;

  static const int _hashMask = 0x07FFFFFF; // 27 bits

  /// First id of the block of [trackId].
  static int base(String trackId) =>
      (_fnv1a32(trackId) & _hashMask) * slotsPerTrack;

  /// The id of [slot] (0-based, `< slotsPerTrack`) of [trackId].
  static int forSlot(String trackId, int slot) {
    RangeError.checkValueInInterval(slot, 0, slotsPerTrack - 1, 'slot');
    return base(trackId) + slot;
  }

  /// Every id a track can ever use.
  static List<int> all(String trackId) {
    final first = base(trackId);
    return [for (var i = 0; i < slotsPerTrack; i++) first + i];
  }

  static int _fnv1a32(String text) {
    var hash = 0x811C9DC5;
    for (final byte in utf8.encode(text)) {
      hash = _mul32(hash ^ byte, 0x01000193);
    }
    return hash;
  }

  /// `(a * b) mod 2^32` without leaving the 53 bit safe integer range, so
  /// the result is identical on every Dart backend.
  static int _mul32(int a, int b) {
    final low = (a & 0xFFFF) * b;
    final high = ((a >> 16) & 0xFFFF) * b;
    return (low + (high & 0xFFFF) * 0x10000) & 0xFFFFFFFF;
  }
}

// --------------------------------------------------------------- payload

/// Identifiers of the notification action buttons (Android action id, iOS /
/// macOS category action identifier).
abstract final class AlarmActionIds {
  static const dismiss = 'tikky_dismiss';
  static const acknowledge = 'tikky_ack';

  /// iOS / macOS notification categories carrying exactly one action.
  static const dismissCategory = 'tikky_category_dismiss';
  static const acknowledgeCategory = 'tikky_category_ack';

  static String? of(AlarmActionType? type) => switch (type) {
    AlarmActionType.dismiss => dismiss,
    AlarmActionType.acknowledge => acknowledge,
    AlarmActionType.open || null => null,
  };

  static String? categoryOf(AlarmActionType? type) => switch (type) {
    AlarmActionType.dismiss => dismissCategory,
    AlarmActionType.acknowledge => acknowledgeCategory,
    AlarmActionType.open || null => null,
  };
}

/// The notification payload: which track, and (for Windows action buttons,
/// which only hand back one string) which action.
///
/// Format: `tt1:<action>:<trackId>`; the track id is everything after the
/// second colon, so it may contain any character.
abstract final class AlarmPayload {
  static const _prefix = 'tt1';

  static String encode(
    String trackId, [
    AlarmActionType type = AlarmActionType.open,
  ]) => '$_prefix:${type.name}:$trackId';

  static AlarmAction? decode(String? payload) {
    if (payload == null) return null;
    final first = payload.indexOf(':');
    if (first < 0 || payload.substring(0, first) != _prefix) return null;
    final second = payload.indexOf(':', first + 1);
    if (second < 0) return null;
    final name = payload.substring(first + 1, second);
    final trackId = payload.substring(second + 1);
    if (trackId.isEmpty) return null;
    for (final type in AlarmActionType.values) {
      if (type.name == name) return AlarmAction(trackId: trackId, type: type);
    }
    return null;
  }
}

/// Maps what the OS reports about a tapped notification to an
/// [AlarmAction]; `null` for notifications that are not ours.
///
/// * Android / iOS / macOS: [payload] is the notification payload and
///   [actionId] one of [AlarmActionIds] (or `null` for a tap on the body).
/// * Windows: both [payload] and [actionId] carry the launch argument of
///   whatever was clicked, i.e. an encoded payload that already names the
///   action.
AlarmAction? alarmActionFromResponse({String? payload, String? actionId}) {
  final fromActionArgument = AlarmPayload.decode(actionId);
  if (fromActionArgument != null) return fromActionArgument;
  final base = AlarmPayload.decode(payload);
  if (base == null) return null;
  return switch (actionId) {
    AlarmActionIds.dismiss => AlarmAction(
      trackId: base.trackId,
      type: AlarmActionType.dismiss,
    ),
    AlarmActionIds.acknowledge => AlarmAction(
      trackId: base.trackId,
      type: AlarmActionType.acknowledge,
    ),
    _ => base,
  };
}

// --------------------------------------------------------------- channel

/// How a notification alerts. Android notification channels cannot change
/// sound or vibration after creation, so there is one channel per
/// combination of the two per-track switches.
enum AlarmChannel {
  soundAndVibration(
    'tikky_alarms_sound_vibration',
    AlarmStrings.channelSoundAndVibration,
    playSound: true,
    vibrate: true,
  ),
  soundOnly(
    'tikky_alarms_sound',
    AlarmStrings.channelSoundOnly,
    playSound: true,
    vibrate: false,
  ),
  vibrationOnly(
    'tikky_alarms_vibration',
    AlarmStrings.channelVibrationOnly,
    playSound: false,
    vibrate: true,
  ),
  silent(
    'tikky_alarms_silent',
    AlarmStrings.channelSilent,
    playSound: false,
    vibrate: false,
  );

  const AlarmChannel(
    this.id,
    this.label, {
    required this.playSound,
    required this.vibrate,
  });

  /// Android channel id. Never change: users configure channels in the
  /// system settings.
  final String id;

  /// User-visible channel name.
  final String label;
  final bool playSound;
  final bool vibrate;

  static AlarmChannel of(Track track) => track.alarmSound
      ? (track.vibration ? soundAndVibration : soundOnly)
      : (track.vibration ? vibrationOnly : silent);
}

// ------------------------------------------------------------------ spec

/// One OS notification, fully described and platform independent.
final class NotificationSpec {
  const NotificationSpec({
    required this.id,
    required this.slot,
    required this.trackId,
    required this.kind,
    required this.dueAtMs,
    required this.fireAtMs,
    required this.title,
    required this.payload,
    required this.channel,
    this.body,
    this.action,
    this.supersededAtMs,
    this.lastOfCutPlan = false,
    this.hideOnLockScreen = false,
  });

  /// Notification id, see [AlarmIds].
  final int id;

  /// Position inside the block of the track (0 = next to fire).
  final int slot;
  final String trackId;
  final AlarmKind kind;

  /// The exact instant from the engine (UTC ms).
  final int dueAtMs;

  /// When the OS fires it: [dueAtMs] rounded UP to a full second. The OS
  /// schedulers work with second precision and truncate; rounding up makes
  /// sure a notification never claims "abgelaufen" before the lane does.
  final int fireAtMs;

  final String title;
  final String? body;

  /// Encoded with [AlarmPayload]; a tap on the body opens the track.
  final String payload;
  final AlarmChannel channel;

  /// The single action button, if any ([AlarmActionType.dismiss] or
  /// [AlarmActionType.acknowledge]).
  final AlarmActionType? action;

  /// When the next notification of the same track fires, i.e. when this
  /// one is out of date. `null` for the last one, which stays until it is
  /// handled. Android removes the notification at that instant.
  final int? supersededAtMs;

  /// Nothing is scheduled after this one although the track keeps ringing
  /// (plan cut at the cap or at the OS budget); [body] tells the user to
  /// open the app.
  final bool lastOfCutPlan;

  /// The app lock is on: the text (track name) must not be readable on a
  /// secure lock screen (Android: private visibility).
  final bool hideOnLockScreen;

  bool get playSound => channel.playSound;
  bool get vibrate => channel.vibrate;

  /// Lifetime after firing, see [supersededAtMs].
  int? get timeoutAfterMs {
    final until = supersededAtMs;
    if (until == null || until <= fireAtMs) return null;
    return until - fireAtMs;
  }

  /// Reminders are "Erinnerung" for the OS, everything else is an alarm.
  bool get isReminder =>
      kind == AlarmKind.reminderDue || kind == AlarmKind.reminderNag;

  /// The session is waiting for the user after this alarm (as opposed to a
  /// phase change that needs no reaction).
  bool get needsAttention => switch (kind) {
    AlarmKind.countdownDone ||
    AlarmKind.intervalDone ||
    AlarmKind.reminderDue ||
    AlarmKind.reminderNag => true,
    AlarmKind.countdownCycle ||
    AlarmKind.intervalWork ||
    AlarmKind.intervalRest => false,
  };

  @override
  bool operator ==(Object other) =>
      other is NotificationSpec &&
      other.id == id &&
      other.slot == slot &&
      other.trackId == trackId &&
      other.kind == kind &&
      other.dueAtMs == dueAtMs &&
      other.fireAtMs == fireAtMs &&
      other.title == title &&
      other.body == body &&
      other.payload == payload &&
      other.channel == channel &&
      other.action == action &&
      other.supersededAtMs == supersededAtMs &&
      other.lastOfCutPlan == lastOfCutPlan &&
      other.hideOnLockScreen == hideOnLockScreen;

  @override
  int get hashCode => Object.hash(
    id,
    slot,
    trackId,
    kind,
    dueAtMs,
    fireAtMs,
    title,
    body,
    payload,
    channel,
    action,
    supersededAtMs,
    lastOfCutPlan,
    hideOnLockScreen,
  );

  @override
  String toString() =>
      'NotificationSpec(#$id ${kind.name} @$fireAtMs "$title")';
}

/// Rounds an instant up to the next full second.
int ceilToSecond(int ms) => (ms + 999) ~/ 1000 * 1000;

/// The action button a notification of [kind] carries.
AlarmActionType? actionForKind(AlarmKind kind) => switch (kind) {
  AlarmKind.countdownDone ||
  AlarmKind.countdownCycle ||
  AlarmKind.intervalDone => AlarmActionType.dismiss,
  AlarmKind.reminderDue || AlarmKind.reminderNag => AlarmActionType.acknowledge,
  AlarmKind.intervalWork || AlarmKind.intervalRest => null,
};

/// Shortens a plan to [limit] alarms: the earliest ones win, but the final
/// "interval finished" alarm is never dropped.
List<PlannedAlarm> truncateAlarms(List<PlannedAlarm> alarms, int limit) {
  if (limit <= 0) return const [];
  if (alarms.length <= limit) return alarms;
  final last = alarms.last;
  if (last.kind == AlarmKind.intervalDone && limit > 1) {
    return [...alarms.take(limit - 1), last];
  }
  return alarms.take(limit).toList();
}

/// Turns the alarm plan of [track] into the notifications to hand to the
/// OS.
///
/// * Alarms at or before [nowMs] are dropped (they have fired already; the
///   lane shows the ringing state).
/// * At most [maxCount] (and never more than [AlarmIds.slotsPerTrack])
///   notifications are returned, earliest first, see [truncateAlarms].
/// * Slot `n` always gets the id `AlarmIds.forSlot(track.id, n)`.
/// * When alarms are missing behind a notification - the engine cut the
///   plan at its cap (`PlannedAlarm.planEndsHere`) or [maxCount] cut it
///   here - that notification says "open the app" in its body
///   ([AlarmStrings.openAppForMore]) instead of the alarms silently
///   running dry.
/// * With [hideOnLockScreen] (app lock enabled) the notifications are
///   marked private.
List<NotificationSpec> buildNotificationPlan({
  required Track track,
  required Iterable<PlannedAlarm> alarms,
  required int nowMs,
  int maxCount = AlarmIds.slotsPerTrack,
  bool hideOnLockScreen = false,
}) {
  final limit = maxCount < AlarmIds.slotsPerTrack
      ? maxCount
      : AlarmIds.slotsPerTrack;
  if (limit <= 0) return const [];

  final future =
      [
        for (final alarm in alarms)
          if (alarm.at > nowMs) alarm,
      ]..sort((a, b) {
        final byTime = a.at.compareTo(b.at);
        return byTime != 0 ? byTime : a.index.compareTo(b.index);
      });
  final kept = truncateAlarms(future, limit);
  if (kept.isEmpty) return const [];

  final channel = AlarmChannel.of(track);
  final payload = AlarmPayload.encode(track.id);
  final fireTimes = [for (final alarm in kept) ceilToSecond(alarm.at)];

  // The slot behind which alarms were dropped right here, if any: the
  // last one, or the one before a preserved "interval finished".
  int? cutSlot;
  if (kept.length < future.length) {
    final keepsDone =
        kept.length > 1 && kept.last.kind == AlarmKind.intervalDone;
    cutSlot = keepsDone ? kept.length - 2 : kept.length - 1;
    if (kept[cutSlot].kind == AlarmKind.intervalDone) cutSlot = null;
  }
  bool isCut(int slot) => kept[slot].planEndsHere || slot == cutSlot;

  return [
    for (var slot = 0; slot < kept.length; slot++)
      NotificationSpec(
        id: AlarmIds.forSlot(track.id, slot),
        slot: slot,
        trackId: track.id,
        kind: kept[slot].kind,
        dueAtMs: kept[slot].at,
        fireAtMs: fireTimes[slot],
        title: notificationTitle(track, kept[slot]),
        body: isCut(slot)
            ? AlarmStrings.openAppForMore
            : notificationBody(track, kept[slot]),
        payload: payload,
        channel: channel,
        action: actionForKind(kept[slot].kind),
        supersededAtMs: _nextLater(fireTimes, slot),
        lastOfCutPlan: isCut(slot),
        hideOnLockScreen: hideOnLockScreen,
      ),
  ];
}

int? _nextLater(List<int> fireTimes, int slot) {
  for (var i = slot + 1; i < fireTimes.length; i++) {
    if (fireTimes[i] > fireTimes[slot]) return fireTimes[i];
  }
  return null;
}

/// The name shown for a track; unnamed tracks fall back to the mode name.
String notificationTrackName(Track track) {
  final name = track.name.trim();
  return name.isEmpty ? Strings.modeName(track.mode) : name;
}

/// Headline of the notification.
String notificationTitle(Track track, PlannedAlarm alarm) {
  final name = notificationTrackName(track);
  return switch (alarm.kind) {
    AlarmKind.countdownDone => Strings.notifCountdownDone(name),
    AlarmKind.countdownCycle => Strings.notifCountdownCycle(
      name,
      alarm.round ?? 1,
    ),
    AlarmKind.intervalWork => Strings.notifIntervalWork(name, alarm.round ?? 1),
    AlarmKind.intervalRest => Strings.notifIntervalRest(name, alarm.round ?? 1),
    AlarmKind.intervalDone => Strings.notifIntervalDone(name),
    AlarmKind.reminderDue => Strings.notifReminderDue(name),
    AlarmKind.reminderNag => Strings.notifReminderNag(name),
  };
}

/// Second line of the notification; `null` when there is nothing useful to
/// add (e.g. the track config no longer matches the alarm kind).
String? notificationBody(Track track, PlannedAlarm alarm) {
  final config = track.config;
  switch (alarm.kind) {
    case AlarmKind.countdownDone:
      if (config is! CountdownConfig) return null;
      return AlarmStrings.modeAndDuration(
        Strings.modeName(TrackMode.countdown),
        Fmt.compact(config.durationMs),
      );
    case AlarmKind.countdownCycle:
      return AlarmStrings.nextCycleRunning;
    case AlarmKind.intervalWork:
      if (config is! IntervalConfig) return null;
      return AlarmStrings.modeAndDuration(
        AlarmStrings.roundOf(alarm.round ?? 1, _rounds(config)),
        Fmt.compact(config.workMs),
      );
    case AlarmKind.intervalRest:
      if (config is! IntervalConfig) return null;
      return AlarmStrings.restFor(Fmt.compact(config.restMs));
    case AlarmKind.intervalDone:
      if (config is! IntervalConfig) return null;
      return AlarmStrings.roundsDone(
        _rounds(config),
        Fmt.compact(config.totalMs),
      );
    case AlarmKind.reminderDue:
      if (config is! ReminderConfig) return null;
      return AlarmStrings.reminderEvery(Fmt.compact(config.intervalMs));
    case AlarmKind.reminderNag:
      if (config is! ReminderConfig) return null;
      final nag = alarm.round ?? 1;
      return AlarmStrings.overdueSince(Fmt.compact(nag * config.nagEveryMs));
  }
}

int _rounds(IntervalConfig config) => config.rounds < 1 ? 1 : config.rounds;
