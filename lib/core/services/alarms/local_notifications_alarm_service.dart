import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../clock.dart';
import '../../domain/track.dart';
import 'alarm_service.dart';
import 'notification_backend.dart';
import 'notification_plan.dart';
import 'plugin_notification_backend.dart';

/// The real [AlarmService]: OS notifications scheduled for the due times of
/// countdowns, interval phases and reminders, so they ring while the app is
/// in the background or closed.
///
/// How it works
/// * Every track owns 16 stable notification ids ([AlarmIds]).
///   [scheduleForTrack] cancels whatever the track had and schedules the
///   new plan ([buildNotificationPlan]) into those ids, so the OS always
///   mirrors the event log. Nothing is persisted here: after a restart the
///   repositories call `cancelAll` + `scheduleForTrack` for every open
///   session (`AlarmSync.syncAll`).
/// * Android: exact alarms when allowed, otherwise the same notifications
///   inexact (they may arrive a little late, never not at all).
/// * iOS / macOS: at most 60 pending notifications for the whole app; when
///   the budget is exhausted the latest alarms of a track are left out and
///   added again as soon as there is room (or on the next app resume).
/// * Notification permission is requested when the first alarm is
///   scheduled (the moment the user starts a timer), never at app start
///   without reason. [requestPermissions] runs the full flow including the
///   Android exact alarm page.
/// * Taps and action buttons arrive on [actions], including the one that
///   launched the app; events are buffered until someone listens.
///
/// Platform trouble never reaches the caller: every plugin call is guarded
/// and reported to [onError] (debug console by default). When the plugin
/// cannot be initialised (unsupported platform, Windows without the native
/// library, tests) the service turns itself into a no-op and reports
/// [AlarmPermissionStatus.unsupported].
class LocalNotificationsAlarmService implements AlarmService {
  LocalNotificationsAlarmService({
    NotificationBackend? backend,
    this._clock = const SystemClock(),
    this.requestPermissionOnFirstSchedule = true,
    this.onError,
  }) : _backend = backend ?? PluginNotificationBackend();

  final NotificationBackend _backend;
  final Clock _clock;

  /// Ask for the notification permission when the first alarm is scheduled.
  final bool requestPermissionOnFirstSchedule;

  /// Receives every swallowed platform error.
  final void Function(Object error, StackTrace stack)? onError;

  Future<bool>? _init;

  /// All backend work runs one after the other in call order.
  Future<void> _queue = Future<void>.value();

  /// What should be scheduled, per track id.
  final Map<String, _TrackPlan> _plans = {};

  /// Ids handed to the OS per track since this process touched the track.
  final Map<String, List<int>> _handedOut = {};

  /// Tracks whose plan did not fit into the pending-notification budget.
  final Set<String> _truncated = {};

  /// A `cancelAll` succeeded: tracks missing in [_handedOut] have nothing
  /// scheduled, so their 16 ids need not be cancelled one by one.
  bool _cleanSlate = false;

  bool _permissionAsked = false;

  /// App lock on: notifications are private on the lock screen.
  bool _contentHidden = false;

  final List<AlarmAction> _pendingActions = [];
  late final StreamController<AlarmAction> _actions =
      StreamController<AlarmAction>.broadcast(onListen: _flushPendingActions);

  // ------------------------------------------------------------- set-up

  @override
  Future<void> init() async {
    await _ensureInit();
  }

  /// Whether the OS backend is usable. Completes after [init].
  Future<bool> get isReady => _ensureInit();

  Future<bool> _ensureInit() => _init ??= _doInit();

  Future<bool> _doInit() async {
    var ready = false;
    try {
      ready = await _backend.init(_onReply);
    } catch (error, stack) {
      _report(error, stack);
    }
    if (!ready) return false;
    try {
      final launch = await _backend.launchReply();
      if (launch != null) _onReply(launch);
    } catch (error, stack) {
      _report(error, stack);
    }
    return true;
  }

  // -------------------------------------------------------- permissions

  @override
  Future<AlarmPermissionStatus> permissionStatus() async {
    if (!await _ensureInit()) return AlarmPermissionStatus.unsupported;
    var notifications = false;
    var exact = false;
    try {
      notifications = await _backend.notificationsGranted();
      exact = await _backend.exactAlarmsGranted();
    } catch (error, stack) {
      _report(error, stack);
    }
    return AlarmPermissionStatus(
      supported: true,
      notificationsGranted: notifications,
      exactAlarmsGranted: exact,
    );
  }

  @override
  Future<AlarmPermissionStatus> requestPermissions() async {
    if (!await _ensureInit()) return AlarmPermissionStatus.unsupported;
    _permissionAsked = true;
    // Deliberately outside the queue: the prompts wait for the user and
    // must not hold up scheduling.
    try {
      final granted = await _backend.requestNotifications();
      if (granted && !await _backend.exactAlarmsGranted()) {
        await _backend.requestExactAlarms();
      }
    } catch (error, stack) {
      _report(error, stack);
    }
    final status = await permissionStatus();
    // Alarms scheduled without permission are dropped by iOS, and inexact
    // ones can now become exact on Android.
    if (status.notificationsGranted) await _reapplyAll();
    return status;
  }

  void _requestPermissionOnce() {
    if (!requestPermissionOnFirstSchedule || _permissionAsked) return;
    _permissionAsked = true;
    unawaited(() async {
      try {
        if (await _backend.notificationsGranted()) return;
        if (await _backend.requestNotifications()) await _reapplyAll();
      } catch (error, stack) {
        _report(error, stack);
      }
    }());
  }

  // --------------------------------------------------------- scheduling

  @override
  Future<void> scheduleForTrack(Track track, List<PlannedAlarm> alarms) =>
      _serial(() async {
        if (!await _ensureInit()) return;
        if (alarms.isEmpty) {
          _plans.remove(track.id);
          _truncated.remove(track.id);
          await _cancelIds(track.id);
          await _refill();
          return;
        }
        _plans[track.id] = _TrackPlan(track, List.unmodifiable(alarms));
        await _apply(track.id);
        await _refill(except: track.id);
        _requestPermissionOnce();
      });

  @override
  Future<void> cancelForTrack(String trackId) => _serial(() async {
    _plans.remove(trackId);
    _truncated.remove(trackId);
    if (!await _ensureInit()) return;
    await _cancelIds(trackId);
    await _refill();
  });

  @override
  Future<void> cancelAll() => _serial(() async {
    _plans.clear();
    _truncated.clear();
    if (!await _ensureInit()) return;
    try {
      await _backend.cancelAll();
      _handedOut.clear();
      _cleanSlate = true;
    } catch (error, stack) {
      _report(error, stack);
      for (final trackId in _handedOut.keys.toList()) {
        await _cancelIds(trackId);
      }
    }
  });

  @override
  Future<void> setContentHidden(bool hidden) async {
    if (_contentHidden == hidden) return;
    _contentHidden = hidden;
    // What is already pending was built with the old visibility.
    await _reapplyAll();
  }

  @override
  Stream<AlarmAction> get actions => _actions.stream;

  /// Releases the action stream. The service must not be used afterwards.
  Future<void> dispose() => _actions.close();

  // ------------------------------------------------------------ helpers

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _reapplyAll() => _serial(() async {
    if (!await _ensureInit()) return;
    for (final trackId in _plans.keys.toList()) {
      await _apply(trackId);
    }
  });

  /// Replaces what the OS holds for [trackId] by its current plan.
  Future<void> _apply(String trackId) async {
    final plan = _plans[trackId];
    if (plan == null) return;
    await _cancelIds(trackId);

    final nowMs = _clock.nowMs();
    final unlimited = buildNotificationPlan(
      track: plan.track,
      alarms: plan.alarms,
      nowMs: nowMs,
      hideOnLockScreen: _contentHidden,
    );
    final budget = _budgetFor(trackId);
    final specs = budget >= unlimited.length
        ? unlimited
        : buildNotificationPlan(
            track: plan.track,
            alarms: plan.alarms,
            nowMs: nowMs,
            maxCount: budget,
            hideOnLockScreen: _contentHidden,
          );
    if (specs.length < unlimited.length) {
      _truncated.add(trackId);
    } else {
      _truncated.remove(trackId);
    }
    if (specs.isEmpty) return;

    var exact = false;
    try {
      exact = await _backend.exactAlarmsGranted();
    } catch (error, stack) {
      _report(error, stack);
    }
    final ids = <int>[];
    for (final spec in specs) {
      try {
        exact = await _scheduleOne(spec, exact: exact);
        ids.add(spec.id);
      } catch (error, stack) {
        _report(error, stack);
      }
    }
    if (ids.isNotEmpty) _handedOut[trackId] = ids;
  }

  /// Schedules one notification with the graceful fallbacks: exact ->
  /// inexact when Android refuses, and "show now" when the instant passed
  /// while we were busy. Returns whether exact scheduling still works.
  Future<bool> _scheduleOne(
    NotificationSpec spec, {
    required bool exact,
  }) async {
    var useExact = exact;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _backend.schedule(spec, exact: useExact);
        return useExact;
      } on ExactAlarmsDenied {
        if (!useExact) rethrow;
        useExact = false;
      } on NotificationInPast {
        await _backend.showNow(spec);
        return useExact;
      }
    }
    return useExact;
  }

  /// How many notifications [trackId] may hold right now.
  int _budgetFor(String trackId) {
    final max = _backend.maxPending;
    if (max == null) return AlarmIds.slotsPerTrack;
    var others = 0;
    for (final entry in _handedOut.entries) {
      if (entry.key != trackId) others += entry.value.length;
    }
    final free = max - others;
    if (free <= 0) return 0;
    return free < AlarmIds.slotsPerTrack ? free : AlarmIds.slotsPerTrack;
  }

  /// Gives tracks that were cut short another chance after room was freed.
  Future<void> _refill({String? except}) async {
    if (_truncated.isEmpty) return;
    for (final trackId in _truncated.toList()) {
      if (trackId == except) continue;
      await _apply(trackId);
    }
  }

  Future<void> _cancelIds(String trackId) async {
    final known = _handedOut.remove(trackId);
    final ids =
        known ?? (_cleanSlate ? const <int>[] : AlarmIds.all(trackId));
    for (final id in ids) {
      try {
        await _backend.cancel(id);
      } catch (error, stack) {
        _report(error, stack);
      }
    }
  }

  void _onReply(NotificationReply reply) {
    final action = alarmActionFromResponse(
      payload: reply.payload,
      actionId: reply.actionId,
    );
    if (action == null || _actions.isClosed) return;
    if (_actions.hasListener) {
      _actions.add(action);
    } else {
      _pendingActions.add(action);
    }
  }

  void _flushPendingActions() {
    if (_pendingActions.isEmpty) return;
    // After the subscription is fully set up.
    scheduleMicrotask(() {
      if (_actions.isClosed) return;
      if (!_actions.hasListener) return;
      final pending = List.of(_pendingActions);
      _pendingActions.clear();
      pending.forEach(_actions.add);
    });
  }

  void _report(Object error, StackTrace stack) {
    final handler = onError;
    if (handler != null) {
      handler(error, stack);
    } else if (kDebugMode) {
      debugPrint('AlarmService: $error');
    }
  }
}

final class _TrackPlan {
  const _TrackPlan(this.track, this.alarms);

  final Track track;
  final List<PlannedAlarm> alarms;
}
