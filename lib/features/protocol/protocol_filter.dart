import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/domain.dart';
import '../../core/repo/providers.dart';
import '../../core/services/haptics.dart';
import '../../theme/theme.dart';
import 'entry_edit_sheet.dart';
import 'protocol_strings.dart';

/// Keys for tests.
abstract final class ProtocolFilterKeys {
  static const row = ValueKey('protocol-filter');
  static const all = ValueKey('protocol-filter-all');
  static Key thing(String substanceId) =>
      ValueKey('protocol-filter-$substanceId');
}

/// The thing the protocol of a set is narrowed to ("nur Bier"), per set.
/// In memory only: a filter changes what is SHOWN - on the board and in
/// the timeline alike - and never writes anything.
class ProtocolFilters extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  /// Narrows [setId] to [substanceId]; `null` shows everything again.
  void choose(String setId, String? substanceId) {
    if (state[setId] == substanceId) return;
    final next = {...state};
    if (substanceId == null) {
      next.remove(setId);
    } else {
      next[setId] = substanceId;
    }
    state = next;
  }
}

final protocolFiltersProvider =
    NotifierProvider<ProtocolFilters, Map<String, String>>(ProtocolFilters.new);

/// The thing [setId] is narrowed to, or `null`. A thing that no longer
/// exists does not filter.
final protocolFilterProvider = Provider.family<String?, String>((ref, setId) {
  final id = ref.watch(protocolFiltersProvider)[setId];
  if (id == null) return null;
  return ref.watch(substancesByIdProvider).containsKey(id) ? id : null;
});

/// The things a filter offers: those of the scene of [set], in its order,
/// and what is [chosen] also when it has left the scene.
List<Substance> protocolFilterThings(
  TrackSet? set,
  Map<String, Substance> byId,
  String? chosen,
) {
  final things = <Substance>[
    for (final id in set?.sceneSubstanceIds ?? const <String>[])
      if (byId[id] case final s? when !s.archived) s,
  ];
  if (chosen != null && things.every((s) => s.id != chosen)) {
    if (byId[chosen] case final s?) things.add(s);
  }
  return things;
}

/// "Alles · Bier · Wasser · …": the things of the scene of [setId] as a
/// row that scrolls sideways. One tap narrows the protocol to a thing,
/// "Alles" (or the same thing again) shows everything.
class ProtocolFilterRow extends ConsumerWidget {
  const ProtocolFilterRow({required this.setId, super.key});

  final String setId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final set = ref.watch(setProvider(setId));
    final byId = ref.watch(substancesByIdProvider);
    final chosen = ref.watch(protocolFilterProvider(setId));
    final things = protocolFilterThings(set, byId, chosen);
    void choose(String? id) {
      ref.read(hapticsProvider).selection();
      ref.read(protocolFiltersProvider.notifier).choose(setId, id);
    }

    return SingleChildScrollView(
      key: ProtocolFilterKeys.row,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SheetChip(
            key: ProtocolFilterKeys.all,
            label: ProtocolStrings.filterAll,
            semanticLabel: ProtocolStrings.filterAllSemantics,
            selected: chosen == null,
            onTap: () => choose(null),
          ),
          for (final s in things) ...[
            SizedBox(width: t.space.xs),
            SheetChip(
              key: ProtocolFilterKeys.thing(s.id),
              label: s.name,
              semanticLabel: ProtocolStrings.filterOnly(s.name),
              roles: t.roles(Color(s.color)),
              selected: chosen == s.id,
              onTap: () => choose(chosen == s.id ? null : s.id),
            ),
          ],
        ],
      ),
    );
  }
}
