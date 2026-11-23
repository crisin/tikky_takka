/// Behaviour of a track ("Spur").
///
/// The [name] of each value is the persisted identifier - never rename.
enum TrackMode {
  stopwatch,
  countdown,
  interval,
  counter,
  reminder,
  protocol;

  static TrackMode fromName(String? name) {
    for (final m in values) {
      if (m.name == name) return m;
    }
    return TrackMode.stopwatch;
  }

  /// Modes that react to "Alle starten" / "Alle pausieren".
  bool get supportsStartPause =>
      this == stopwatch ||
      this == countdown ||
      this == interval ||
      this == reminder;

  /// Modes that can ring and therefore need OS alarms.
  bool get hasAlarms =>
      this == countdown || this == interval || this == reminder;
}

/// Type of a logged event.
///
/// The [name] of each value is the persisted identifier - never rename.
enum EventType {
  start,
  pause,
  resume,
  lap,
  tick,
  entry,
  ack,
  stop,

  /// More time for a ringing timer ("+1′") or a due reminder ("+10′"):
  /// it is due `extra['ms']` of counting time after this event (or after
  /// its current due time, when that is later). See `TrackEvent.extendMs`.
  extend,

  /// "nächste Runde" of an interval: the program jumps to the start of the
  /// next round.
  skip;

  static EventType? tryFromName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}
