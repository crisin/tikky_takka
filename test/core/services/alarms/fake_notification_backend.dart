import 'package:tikky_takka/core/services/alarms/notification_backend.dart';
import 'package:tikky_takka/core/services/alarms/notification_plan.dart';

/// An in-memory "operating system" for the alarm service tests.
class FakeNotificationBackend implements NotificationBackend {
  // ------------------------------------------------------------ knobs
  bool initResult = true;
  Object? initError;
  NotificationReply? launch;
  Object? launchError;

  @override
  int? maxPending;

  bool notifications = true;
  bool exact = true;

  /// What the user answers to the permission prompts.
  bool grantNotificationsOnRequest = true;
  bool grantExactOnRequest = true;

  /// `exactAlarmsGranted()` says yes, but scheduling exact is refused.
  bool refuseExactWhenScheduling = false;

  /// Ids for which `schedule` reports that the instant has passed.
  final Set<int> inPast = {};

  /// Ids for which `schedule` fails outright.
  final Set<int> failing = {};
  bool failCancel = false;
  bool failCancelAll = false;
  bool failPermissionQueries = false;

  // ------------------------------------------------------------ state
  /// Pending notifications by id.
  final Map<int, NotificationSpec> pending = {};

  /// Whether a pending notification was scheduled exact.
  final Map<int, bool> exactById = {};

  /// Notifications shown immediately.
  final List<NotificationSpec> shown = [];

  /// Chronological calls: `schedule:<id>`, `cancel:<id>`, `cancelAll`,
  /// `show:<id>`, `requestNotifications`, `requestExactAlarms`.
  final List<String> log = [];
  int initCalls = 0;
  void Function(NotificationReply reply)? _onReply;

  /// Simulates a tap on a notification while the app runs.
  void tap({String? payload, String? actionId}) =>
      _onReply!((payload: payload, actionId: actionId));

  List<int> get cancelledIds => [
    for (final entry in log)
      if (entry.startsWith('cancel:')) int.parse(entry.substring(7)),
  ];

  int count(String prefix) => log.where((e) => e.startsWith(prefix)).length;

  // -------------------------------------------------------------- api
  @override
  Future<bool> init(void Function(NotificationReply reply) onReply) async {
    initCalls++;
    final error = initError;
    if (error != null) throw error;
    _onReply = onReply;
    return initResult;
  }

  @override
  Future<NotificationReply?> launchReply() async {
    final error = launchError;
    if (error != null) throw error;
    return launch;
  }

  @override
  Future<bool> notificationsGranted() async {
    if (failPermissionQueries) throw StateError('no permission api');
    return notifications;
  }

  @override
  Future<bool> exactAlarmsGranted() async {
    if (failPermissionQueries) throw StateError('no permission api');
    return exact;
  }

  @override
  Future<bool> requestNotifications() async {
    log.add('requestNotifications');
    if (grantNotificationsOnRequest) notifications = true;
    return notifications;
  }

  @override
  Future<bool> requestExactAlarms() async {
    log.add('requestExactAlarms');
    if (grantExactOnRequest) exact = true;
    return exact;
  }

  @override
  Future<void> schedule(NotificationSpec spec, {required bool exact}) async {
    log.add('schedule:${spec.id}');
    if (failing.contains(spec.id)) throw StateError('platform says no');
    if (exact && refuseExactWhenScheduling) throw const ExactAlarmsDenied();
    if (inPast.contains(spec.id)) throw const NotificationInPast();
    pending[spec.id] = spec;
    exactById[spec.id] = exact;
  }

  @override
  Future<void> showNow(NotificationSpec spec) async {
    log.add('show:${spec.id}');
    shown.add(spec);
  }

  @override
  Future<void> cancel(int id) async {
    log.add('cancel:$id');
    if (failCancel) throw StateError('cannot cancel');
    pending.remove(id);
    exactById.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    log.add('cancelAll');
    if (failCancelAll) throw StateError('cannot cancel all');
    pending.clear();
    exactById.clear();
  }
}
