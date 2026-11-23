import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/repo/settings_store.dart';

/// Which persons of the strip are open, per set (set id -> lane ids of
/// the open persons), remembered under `ui.stripOpen.<setId>`. A set
/// without an entry shows every person open.
class StripOpenController extends Notifier<Map<String, Set<String>>> {
  @override
  Map<String, Set<String>> build() {
    const prefix = SettingsKeys.stripOpenPrefix;
    final stored = ref.watch(settingsStoreProvider).withPrefix(prefix);
    return {
      for (final e in stored.entries)
        e.key.substring(prefix.length): {
          for (final id in e.value.split('\n'))
            if (id.isNotEmpty) id,
        },
    };
  }

  /// Opens or folds the person lane [laneId] of [setId]; [shownIds] are
  /// the person lanes on screen (all open when nothing is remembered).
  Future<void> toggle(
    String setId,
    String laneId, {
    required Iterable<String> shownIds,
  }) async {
    final open = {...(state[setId] ?? shownIds)};
    if (!open.remove(laneId)) open.add(laneId);
    state = {...state, setId: open};
    await ref
        .read(settingsStoreProvider)
        .setString('${SettingsKeys.stripOpenPrefix}$setId', open.join('\n'));
  }
}

final stripOpenProvider =
    NotifierProvider<StripOpenController, Map<String, Set<String>>>(
      StripOpenController.new,
    );
