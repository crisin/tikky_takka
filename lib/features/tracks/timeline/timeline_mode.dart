import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repo/settings_store.dart';

/// How the timeline view showed a set before the levels of Pult: only
/// read, to take over a stored choice (see [TimelineChoice.fromMode]).
///
/// The [name] of each value is the persisted identifier - never rename.
enum TimelineMode {
  /// "Streifen": time from left to right, one lane per track (the
  /// default).
  strip,

  /// "Liste": one row per event.
  list,

  /// "Zusammenfassung": what came together overall.
  summary;

  static TimelineMode fromName(String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return TimelineMode.strip;
  }
}

/// The level of the timeline (Pult 3.1 - 3.4): "Jetzt" the strip of the
/// open sessions, "Abend" one logical day, "Woche" and "Monat" the days
/// around it.
///
/// The [name] of each value is the persisted identifier - never rename.
enum TimelineLevel {
  now,
  evening,
  week,
  month;

  static TimelineLevel? fromName(String? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}

/// How a set shows its timeline: the level, and whether the evening is
/// "Kompakt" (its entries as a list, newest first).
@immutable
final class TimelineChoice {
  const TimelineChoice(this.level, {this.compact = false});

  static const initial = TimelineChoice(TimelineLevel.now);

  final TimelineLevel level;
  final bool compact;

  /// The choice of a set that only has the mode of before: the strip is
  /// "Jetzt", the list is the evening as a list, the summary the evening.
  factory TimelineChoice.fromMode(TimelineMode mode) => switch (mode) {
    TimelineMode.strip => initial,
    TimelineMode.list => const TimelineChoice(
      TimelineLevel.evening,
      compact: true,
    ),
    TimelineMode.summary => const TimelineChoice(TimelineLevel.evening),
  };

  @override
  bool operator ==(Object other) =>
      other is TimelineChoice &&
      other.level == level &&
      other.compact == compact;

  @override
  int get hashCode => Object.hash(level, compact);
}

/// The choice per set (set id -> choice), remembered under
/// `ui.timelineLevel.<setId>` and `ui.timelineCompact.<setId>`; where only
/// `ui.timelineMode.<setId>` is stored, that is read instead.
class TimelineChoiceController extends Notifier<Map<String, TimelineChoice>> {
  @override
  Map<String, TimelineChoice> build() {
    final store = ref.watch(settingsStoreProvider);
    const levelPrefix = SettingsKeys.timelineLevelPrefix;
    const compactPrefix = SettingsKeys.timelineCompactPrefix;
    const modePrefix = SettingsKeys.timelineModePrefix;
    final result = <String, TimelineChoice>{
      for (final e in store.withPrefix(modePrefix).entries)
        e.key.substring(modePrefix.length): TimelineChoice.fromMode(
          TimelineMode.fromName(e.value),
        ),
    };
    final compact = {
      for (final e in store.withPrefix(compactPrefix).entries)
        e.key.substring(compactPrefix.length): e.value == 'true',
    };
    for (final e in store.withPrefix(levelPrefix).entries) {
      final setId = e.key.substring(levelPrefix.length);
      final level = TimelineLevel.fromName(e.value);
      if (level == null) continue;
      result[setId] = TimelineChoice(
        level,
        compact: compact[setId] ?? result[setId]?.compact ?? false,
      );
    }
    return result;
  }

  TimelineChoice of(String setId) => state[setId] ?? TimelineChoice.initial;

  Future<void> show(String setId, TimelineLevel level) =>
      _save(setId, TimelineChoice(level, compact: of(setId).compact));

  Future<void> setCompact(String setId, {required bool compact}) =>
      _save(setId, TimelineChoice(of(setId).level, compact: compact));

  Future<void> _save(String setId, TimelineChoice choice) async {
    if (state[setId] == choice) return;
    state = {...state, setId: choice};
    final store = ref.read(settingsStoreProvider);
    await store.setString(
      '${SettingsKeys.timelineLevelPrefix}$setId',
      choice.level.name,
    );
    await store.setString(
      '${SettingsKeys.timelineCompactPrefix}$setId',
      '${choice.compact}',
    );
  }
}

final timelineChoicesProvider =
    NotifierProvider<TimelineChoiceController, Map<String, TimelineChoice>>(
      TimelineChoiceController.new,
    );

/// The timeline choice of one set.
final timelineChoiceProvider = Provider.family<TimelineChoice, String>(
  (ref, setId) => ref.watch(
    timelineChoicesProvider.select(
      (choices) => choices[setId] ?? TimelineChoice.initial,
    ),
  ),
);
