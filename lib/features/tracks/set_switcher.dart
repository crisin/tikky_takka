import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/domain/domain.dart';
import '../../core/repo/providers.dart';
import '../../core/services/haptics.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import '../protocol/protocol_scene_sheet.dart';
import '../protocol/protocol_strings.dart';
import '../protocol/protocol_widgets.dart';
import 'track_lane.dart';
import 'track_undo.dart';
import 'tracks_strings.dart';

/// Archived tracks of one set (the set sheet offers to restore them).
final archivedTracksProvider = StreamProvider.autoDispose
    .family<List<Track>, String>(
      (ref, setId) => ref
          .watch(trackRepositoryProvider)
          .watchTracks(setId, includeArchived: true)
          .map(
            (tracks) => [
              for (final t in tracks)
                if (t.archived) t,
            ],
          ),
    );

/// The title of the tracks screen: the active set's name, large, with how
/// many tracks it has and how many run; a tap opens "Sets und Szene".
class SetSwitcherButton extends ConsumerWidget {
  const SetSwitcherButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final set = ref.watch(activeSetProvider);
    final name = set?.name ?? Strings.tracksTitle;
    final tracks = set == null
        ? null
        : ref.watch(tracksInSetProvider(set.id)).value;
    final sessions = ref.watch(openSessionsProvider).value;
    final compact = MediaQuery.sizeOf(context).height < t.sizes.compactHeight;
    final summary = tracks == null || compact
        ? null
        : TracksStrings.setSummary(
            tracks.length,
            [
              for (final track in tracks)
                if (sessions?.containsKey(track.id) ?? false) track,
            ].length,
          );
    return Semantics(
      button: true,
      label: Strings.switchSet,
      value: summary == null ? name : '$name, $summary',
      excludeSemantics: true,
      child: Tooltip(
        message: Strings.switchSet,
        excludeFromSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: t.radii.smallAll,
            splashFactory: isCupertino(context) ? NoSplash.splashFactory : null,
            onTap: () => showSetSheet(context),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: t.sizes.minTapTarget),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: compact
                              ? t.text.pageTitleCompact
                              : t.text.pageTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: t.space.xs),
                      Icon(
                        AdaptiveIcons.chevronDown(context),
                        size: t.sizes.iconSm,
                        color: t.colors.text,
                      ),
                    ],
                  ),
                  if (summary != null)
                    Text(
                      summary,
                      style: t.text.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for a name, creates the set and makes it the active one. Returns
/// the new set, or `null` when cancelled.
Future<TrackSet?> createSetFlow(BuildContext context, WidgetRef ref) async {
  final sets = ref.read(setRepositoryProvider);
  final active = ref.read(activeSetIdProvider.notifier);
  final name = await showAdaptiveTextPrompt(
    context,
    title: Strings.newSet,
    hint: TracksStrings.newSetHint,
  );
  if (name == null || name.isEmpty) return null;
  final set = await sets.createSet(name: name);
  await active.select(set.id);
  return set;
}

/// Keys of "Sets und Szene" (for tests).
abstract final class SetSheetKeys {
  static const newSet = ValueKey('set-sheet-new');
  static const done = ValueKey('set-sheet-done');
}

/// Opens "Sets und Szene": the sets (switch, create, rename, delete,
/// reorder) and, below, the scene of the active set. Snackbars ("Rückgängig" after deleting a set) are
/// shown on [context] once the sheet is closed.
Future<void> showSetSheet(BuildContext context) async {
  final outcome = await showAdaptiveSheet<_SetSheetOutcome>(
    context,
    builder: (_) => const _SetSheet(),
  );
  if (outcome == null || !context.mounted) return;
  showUndoSnackBar(
    context,
    message: outcome.message,
    onUndo: () => outcome.undo(),
  );
}

class _SetSheetOutcome {
  const _SetSheetOutcome(this.message, this.undo);

  final String message;
  final Future<void> Function() undo;
}

enum _SetAction { rename, scene, delete }

class _SetSheet extends ConsumerStatefulWidget {
  const _SetSheet();

  @override
  ConsumerState<_SetSheet> createState() => _SetSheetState();
}

class _SetSheetState extends ConsumerState<_SetSheet> {
  /// Optimistic order while the database catches up after a drag.
  List<String>? _pendingOrder;

  List<TrackSet> _ordered(List<TrackSet> sets) {
    final pending = _pendingOrder;
    if (pending == null) return sets;
    if (pending.length != sets.length ||
        !sets.every((s) => pending.contains(s.id))) {
      return sets;
    }
    final byId = {for (final s in sets) s.id: s};
    return [for (final id in pending) byId[id]!];
  }

  Future<void> _reorder(List<TrackSet> sets, int from, int to) async {
    final ids = [for (final s in sets) s.id];
    if (from < 0 || from >= ids.length) return;
    final id = ids.removeAt(from);
    ids.insert(to.clamp(0, ids.length), id);
    setState(() => _pendingOrder = ids);
    ref.read(hapticsProvider).selection();
    await ref.read(setRepositoryProvider).reorderSets(ids);
  }

  Future<void> _select(TrackSet set) async {
    ref.read(hapticsProvider).selection();
    await ref.read(activeSetIdProvider.notifier).select(set.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _create() async {
    final set = await createSetFlow(context, ref);
    if (set != null && mounted) Navigator.of(context).pop();
  }

  Future<void> _options(TrackSet set) async {
    final action = await showAdaptiveActionSheet<_SetAction>(
      context,
      title: set.name,
      actions: [
        AdaptiveSheetAction(
          value: _SetAction.rename,
          label: Strings.rename,
          icon: AdaptiveIcons.edit(context),
        ),
        AdaptiveSheetAction(
          value: _SetAction.scene,
          label: ProtocolStrings.sceneEdit,
          icon: ProtocolIcons.scene(context),
        ),
        AdaptiveSheetAction(
          value: _SetAction.delete,
          label: Strings.deleteSet,
          icon: AdaptiveIcons.delete(context),
          destructive: true,
        ),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _SetAction.rename:
        await _rename(set);
      case _SetAction.scene:
        await showSceneEditor(context, setId: set.id);
      case _SetAction.delete:
        await _delete(set);
    }
  }

  Future<void> _rename(TrackSet set) async {
    final name = await showAdaptiveTextPrompt(
      context,
      title: Strings.editSet,
      initialValue: set.name,
      hint: Strings.setName,
    );
    if (name == null || name.isEmpty || name == set.name) return;
    await ref.read(setRepositoryProvider).renameSet(set.id, name);
  }

  Future<void> _delete(TrackSet set) async {
    // The one place with a confirmation: a whole set with its history is
    // more than a slip of the finger should be able to remove.
    final confirmed = await showAdaptiveConfirm(
      context,
      title: TracksStrings.deleteSetQuestion(set.name),
      message: TracksStrings.deleteSetBody,
      confirmLabel: Strings.delete,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final wasActive = ref.read(activeSetProvider)?.id == set.id;
    final active = ref.read(activeSetIdProvider.notifier);
    final restore = await ref.read(trackUndoProvider).deleteSet(set);
    ref.read(hapticsProvider).heavy();
    if (!mounted) return;
    Navigator.of(context).pop(
      _SetSheetOutcome(Strings.setDeleted, () async {
        await restore();
        if (wasActive) await active.select(set.id);
      }),
    );
  }

  Future<void> _restoreArchived(List<Track> archived) async {
    final track = await showAdaptiveActionSheet<Track>(
      context,
      title: TracksStrings.restoreTrackTitle,
      actions: [
        for (final t in archived) AdaptiveSheetAction(value: t, label: t.name),
      ],
    );
    if (track == null) return;
    await ref
        .read(trackRepositoryProvider)
        .setArchived(track.id, archived: false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final sets = _ordered(ref.watch(setsProvider).value ?? const <TrackSet>[]);
    final active = ref.watch(activeSetProvider);
    final archived = active == null
        ? const <Track>[]
        : ref.watch(archivedTracksProvider(active.id)).value ?? const <Track>[];
    // The scene only matters for a set that logs something.
    final activeTracks = active == null
        ? const <Track>[]
        : ref.watch(tracksInSetProvider(active.id)).value ?? const <Track>[];
    final showScene =
        active != null &&
        (activeTracks.any((track) => track.mode == TrackMode.protocol) ||
            active.scenePersonIds.isNotEmpty ||
            active.sceneSubstanceIds.isNotEmpty);
    final rows = ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: sets.length,
      onReorderItem: (from, to) => _reorder(sets, from, to),
      proxyDecorator: (child, _, _) =>
          Material(color: t.colors.surfaceAlt, child: child),
      itemBuilder: (context, index) {
        final set = sets[index];
        return _SetRow(
          key: ValueKey('set-${set.id}'),
          set: set,
          index: index,
          first: index == 0,
          selected: set.id == active?.id,
          onTap: () => _select(set),
          onOptions: () => _options(set),
        );
      },
    );
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: t.sizes.sheetMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.page,
                0,
                t.space.page,
                t.space.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(TracksStrings.setsTitle, style: t.text.title),
                    ),
                  ),
                  _OutlinedPillButton(
                    key: SetSheetKeys.newSet,
                    label: Strings.newSet,
                    icon: AdaptiveIcons.add(context),
                    onPressed: _create,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: t.space.page),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The sets as one group of rows.
                    Container(
                      decoration: BoxDecoration(
                        color: t.colors.background,
                        borderRadius: t.radii.smallAll,
                        border: t.sizes.hairline > 0
                            ? Border.all(
                                color: t.colors.border,
                                width: t.sizes.hairline,
                              )
                            : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: rows,
                    ),
                    if (archived.isNotEmpty)
                      AdaptiveTile(
                        leading: Icon(AdaptiveIcons.archive(context)),
                        title: TracksStrings.archivedTracks(archived.length),
                        onTap: () => _restoreArchived(archived),
                      ),
                    if (showScene) ...[
                      SizedBox(height: t.space.xl),
                      SceneEditor(
                        key: ValueKey('set-sheet-scene-${active.id}'),
                        setId: active.id,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                t.space.page,
                t.space.sm,
                t.space.page,
                t.space.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: t.sizes.bigTapTarget),
                child: AdaptiveFilledButton(
                  key: SetSheetKeys.done,
                  label: Strings.done,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pill with an outline: "+ Neues Set".
class _OutlinedPillButton extends StatelessWidget {
  const _OutlinedPillButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: t.colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: t.radii.pillAll,
          side: t.hairline,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: t.sizes.minTapTarget),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: t.sizes.iconSm, color: t.colors.text),
                  SizedBox(width: t.space.sm),
                  Text(label, style: t.text.label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One set: name, how many tracks (and how many run), its design, a tick
/// for the active one and "Mehr".
class _SetRow extends ConsumerWidget {
  const _SetRow({
    required this.set,
    required this.index,
    required this.first,
    required this.selected,
    required this.onTap,
    required this.onOptions,
    super.key,
  });

  final TrackSet set;
  final int index;
  final bool first;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final tracks = ref.watch(tracksInSetProvider(set.id)).value;
    final sessions = ref.watch(openSessionsProvider).value;
    final theme = ref.watch(themeForSetProvider(set.id));
    final summary = tracks == null
        ? null
        : TracksStrings.setSummary(
            tracks.length,
            [
              for (final track in tracks)
                if (sessions?.containsKey(track.id) ?? false) track,
            ].length,
          );
    return Material(
      color: t.colors.background,
      shape: first ? null : Border(top: t.hairline),
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: t.sizes.bigTapTarget),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const LaneDragHandle(),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: t.space.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        set.name,
                        style: t.text.headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (summary != null)
                        Text(
                          summary,
                          style: t.text.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: t.space.sm),
              // The design of the set, as a small outlined label.
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: t.space.sm,
                  vertical: t.space.xxs,
                ),
                decoration: BoxDecoration(
                  borderRadius: t.radii.pillAll,
                  border: Border.fromBorderSide(t.hairline),
                ),
                child: Text(theme.name, style: t.text.caption, maxLines: 1),
              ),
              if (selected)
                Padding(
                  padding: EdgeInsets.only(left: t.space.sm),
                  child: Icon(
                    AdaptiveIcons.check(context),
                    color: t.colors.text,
                    semanticLabel: TracksStrings.setSelected(set.name),
                  ),
                ),
              AdaptiveIconButton(
                icon: AdaptiveIcons.more(context),
                semanticLabel: '${TracksStrings.setOptions}: ${set.name}',
                onPressed: onOptions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
