import 'enums.dart';
import 'json_utils.dart';

/// Mode-specific configuration of a track. Immutable, JSON (de)serialisable.
///
/// Use [TrackConfig.fromJson] with the track's [TrackMode] to decode and
/// [TrackConfig.defaultFor] to get sensible defaults for a new track.
sealed class TrackConfig {
  const TrackConfig();

  TrackMode get mode;

  JsonMap toJson();

  static TrackConfig defaultFor(TrackMode mode) => switch (mode) {
    TrackMode.stopwatch => const StopwatchConfig(),
    TrackMode.countdown => const CountdownConfig(),
    TrackMode.interval => const IntervalConfig(),
    TrackMode.counter => const CounterConfig(),
    TrackMode.reminder => const ReminderConfig(),
    TrackMode.protocol => const ProtocolConfig(),
  };

  static TrackConfig fromJson(TrackMode mode, JsonMap json) => switch (mode) {
    TrackMode.stopwatch => StopwatchConfig.fromJson(json),
    TrackMode.countdown => CountdownConfig.fromJson(json),
    TrackMode.interval => IntervalConfig.fromJson(json),
    TrackMode.counter => CounterConfig.fromJson(json),
    TrackMode.reminder => ReminderConfig.fromJson(json),
    TrackMode.protocol => ProtocolConfig.fromJson(json),
  };
}

/// Counts up. With [exclusive] set, starting this track pauses every other
/// running exclusive stopwatch in the same set (work time tracking).
final class StopwatchConfig extends TrackConfig {
  const StopwatchConfig({this.exclusive = false});

  factory StopwatchConfig.fromJson(JsonMap json) =>
      StopwatchConfig(exclusive: jsonBool(json['exclusive'], false));

  final bool exclusive;

  @override
  TrackMode get mode => TrackMode.stopwatch;

  StopwatchConfig copyWith({bool? exclusive}) =>
      StopwatchConfig(exclusive: exclusive ?? this.exclusive);

  @override
  JsonMap toJson() => {'exclusive': exclusive};

  @override
  bool operator ==(Object other) =>
      other is StopwatchConfig && other.exclusive == exclusive;

  @override
  int get hashCode => Object.hash(mode, exclusive);

  @override
  String toString() => 'StopwatchConfig(exclusive: $exclusive)';
}

/// Counts down from [durationMs]. With [autoRestart] a finished cycle
/// immediately starts the next one instead of ringing until dismissed.
final class CountdownConfig extends TrackConfig {
  const CountdownConfig({
    this.durationMs = defaultDurationMs,
    this.autoRestart = false,
  });

  factory CountdownConfig.fromJson(JsonMap json) => CountdownConfig(
    durationMs: jsonInt(json['durationMs'], defaultDurationMs),
    autoRestart: jsonBool(json['autoRestart'], false),
  );

  static const int defaultDurationMs = 10 * 60 * 1000;

  final int durationMs;
  final bool autoRestart;

  @override
  TrackMode get mode => TrackMode.countdown;

  CountdownConfig copyWith({int? durationMs, bool? autoRestart}) =>
      CountdownConfig(
        durationMs: durationMs ?? this.durationMs,
        autoRestart: autoRestart ?? this.autoRestart,
      );

  @override
  JsonMap toJson() => {'durationMs': durationMs, 'autoRestart': autoRestart};

  @override
  bool operator ==(Object other) =>
      other is CountdownConfig &&
      other.durationMs == durationMs &&
      other.autoRestart == autoRestart;

  @override
  int get hashCode => Object.hash(mode, durationMs, autoRestart);

  @override
  String toString() =>
      'CountdownConfig(durationMs: $durationMs, autoRestart: $autoRestart)';
}

/// [rounds] repetitions of a work phase ([workMs]) followed by a rest phase
/// ([restMs], may be 0). There is no rest after the last round, so the total
/// duration is `rounds * workMs + (rounds - 1) * restMs`.
final class IntervalConfig extends TrackConfig {
  const IntervalConfig({
    this.workMs = 30 * 1000,
    this.restMs = 10 * 1000,
    this.rounds = 8,
  });

  factory IntervalConfig.fromJson(JsonMap json) => IntervalConfig(
    workMs: jsonInt(json['workMs'], 30 * 1000),
    restMs: jsonInt(json['restMs'], 10 * 1000),
    rounds: jsonInt(json['rounds'], 8),
  );

  final int workMs;
  final int restMs;
  final int rounds;

  @override
  TrackMode get mode => TrackMode.interval;

  /// Total active duration of the whole interval programme.
  int get totalMs {
    final r = rounds < 1 ? 1 : rounds;
    final w = workMs < 0 ? 0 : workMs;
    final p = restMs < 0 ? 0 : restMs;
    return r * w + (r - 1) * p;
  }

  IntervalConfig copyWith({int? workMs, int? restMs, int? rounds}) =>
      IntervalConfig(
        workMs: workMs ?? this.workMs,
        restMs: restMs ?? this.restMs,
        rounds: rounds ?? this.rounds,
      );

  @override
  JsonMap toJson() => {'workMs': workMs, 'restMs': restMs, 'rounds': rounds};

  @override
  bool operator ==(Object other) =>
      other is IntervalConfig &&
      other.workMs == workMs &&
      other.restMs == restMs &&
      other.rounds == rounds;

  @override
  int get hashCode => Object.hash(mode, workMs, restMs, rounds);

  @override
  String toString() =>
      'IntervalConfig(workMs: $workMs, restMs: $restMs, rounds: $rounds)';
}

/// Tap counter. With [labels] the lane shows one button per label and every
/// tick stores the tapped label.
final class CounterConfig extends TrackConfig {
  const CounterConfig({this.labels = const []});

  factory CounterConfig.fromJson(JsonMap json) =>
      CounterConfig(labels: List.unmodifiable(jsonStringList(json['labels'])));

  final List<String> labels;

  @override
  TrackMode get mode => TrackMode.counter;

  CounterConfig copyWith({List<String>? labels}) => CounterConfig(
    labels: labels == null ? this.labels : List.unmodifiable(labels),
  );

  @override
  JsonMap toJson() => {'labels': labels};

  @override
  bool operator ==(Object other) =>
      other is CounterConfig && jsonListEquals(other.labels, labels);

  @override
  int get hashCode => Object.hash(mode, Object.hashAll(labels));

  @override
  String toString() => 'CounterConfig(labels: $labels)';
}

/// Repeating reminder. Next due = (last ack, or start) + [intervalMs]. While
/// due it nags every [nagEveryMs] until acknowledged.
final class ReminderConfig extends TrackConfig {
  const ReminderConfig({
    this.intervalMs = 30 * 60 * 1000,
    this.nagEveryMs = defaultNagEveryMs,
  });

  factory ReminderConfig.fromJson(JsonMap json) => ReminderConfig(
    intervalMs: jsonInt(json['intervalMs'], 30 * 60 * 1000),
    nagEveryMs: jsonInt(json['nagEveryMs'], defaultNagEveryMs),
  );

  static const int defaultNagEveryMs = 60 * 1000;

  final int intervalMs;
  final int nagEveryMs;

  @override
  TrackMode get mode => TrackMode.reminder;

  ReminderConfig copyWith({int? intervalMs, int? nagEveryMs}) => ReminderConfig(
    intervalMs: intervalMs ?? this.intervalMs,
    nagEveryMs: nagEveryMs ?? this.nagEveryMs,
  );

  @override
  JsonMap toJson() => {'intervalMs': intervalMs, 'nagEveryMs': nagEveryMs};

  @override
  bool operator ==(Object other) =>
      other is ReminderConfig &&
      other.intervalMs == intervalMs &&
      other.nagEveryMs == nagEveryMs;

  @override
  int get hashCode => Object.hash(mode, intervalMs, nagEveryMs);

  @override
  String toString() =>
      'ReminderConfig(intervalMs: $intervalMs, nagEveryMs: $nagEveryMs)';
}

/// Protocol ("Protokoll") tracks have no timing configuration of their own:
/// lockouts are a user-set property of each substance. The app never ships
/// or suggests any dosing or interval value.
final class ProtocolConfig extends TrackConfig {
  const ProtocolConfig();

  factory ProtocolConfig.fromJson(JsonMap json) => const ProtocolConfig();

  @override
  TrackMode get mode => TrackMode.protocol;

  @override
  JsonMap toJson() => const {};

  @override
  bool operator ==(Object other) => other is ProtocolConfig;

  @override
  int get hashCode => mode.hashCode;

  @override
  String toString() => 'ProtocolConfig()';
}
