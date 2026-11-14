import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repo/settings_store.dart';

/// How the timeline view shows a set.
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

/// The mode chosen per set (set id -> mode), remembered in the settings
/// store under `ui.timelineMode.<setId>`. Sets without an entry show the
/// strip.
class TimelineModeController extends Notifier<Map<String, TimelineMode>> {
  @override
  Map<String, TimelineMode> build() {
    const prefix = SettingsKeys.timelineModePrefix;
    final stored = ref.watch(settingsStoreProvider).withPrefix(prefix);
    return {
      for (final e in stored.entries)
        e.key.substring(prefix.length): TimelineMode.fromName(e.value),
    };
  }

  /// Shows [mode] for [setId] and remembers it.
  Future<void> show(String setId, TimelineMode mode) async {
    if (state[setId] == mode) return;
    state = {...state, setId: mode};
    await ref
        .read(settingsStoreProvider)
        .setString('${SettingsKeys.timelineModePrefix}$setId', mode.name);
  }
}

final timelineModesProvider =
    NotifierProvider<TimelineModeController, Map<String, TimelineMode>>(
      TimelineModeController.new,
    );

/// The timeline mode of one set.
final timelineModeProvider = Provider.family<TimelineMode, String>(
  (ref, setId) => ref.watch(
    timelineModesProvider.select((modes) => modes[setId] ?? TimelineMode.strip),
  ),
);
