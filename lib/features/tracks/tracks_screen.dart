import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/domain/domain.dart';
import '../../core/repo/models.dart';
import '../../core/repo/providers.dart';
import '../../core/services/haptics.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import '../alarms/alarms.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'lane_actions.dart';
import 'lane_undo.dart';
import 'now_selector.dart';
import 'pad/pad_actions.dart';
import 'pad/pad_model.dart';
import 'pad/tap_pad.dart';
import 'ring_monitor.dart';
import 'set_switcher.dart';
import 'timeline/timeline_view.dart';
import 'track_editor_sheet.dart';
import 'track_lane.dart';
import 'tracks_strings.dart';
import 'tracks_view.dart';

/// Keys of the tracks screen's own controls (for tests).
abstract final class TracksScreenKeys {
  static const addTrack = ValueKey('tracks-add-track');
  static const toggleAll = ValueKey('tracks-toggle-all');
  static const more = ValueKey('tracks-more');
  static const settings = ValueKey('tracks-settings');
  static const emptyAddTrack = ValueKey('tracks-empty-add-track');
  static const list = ValueKey('tracks-list');
  static const grid = ValueKey('tracks-grid');
}

/// Opens the settings as a page of their own.
Future<void> openSettings(BuildContext context) =>
    pushAdaptivePage<void>(context, builder: (_) => const SettingsScreen());

/// Opens the history as a page of its own (until the timeline takes it
/// over).
Future<void> openHistory(BuildContext context) =>
    pushAdaptivePage<void>(context, builder: (_) => const HistoryScreen());

/// The icon of a view on the navigation rail.
IconData tracksViewIcon(BuildContext c, TracksView view) => switch (view) {
  TracksView.lanes =>
    isCupertino(c) ? CupertinoIcons.list_bullet : Icons.view_agenda_outlined,
  TracksView.pad =>
    isCupertino(c) ? CupertinoIcons.square_grid_2x2 : Icons.grid_view_rounded,
  TracksView.timeline =>
    isCupertino(c) ? CupertinoIcons.time : Icons.timeline_rounded,
};

/// The app's main screen: the active set in one of three views.
///
/// * Head: the set's name (a tap opens "Sets und Szene"), how many tracks
///   it has and how many run, "Alle pausieren / starten" and "···"
///   (settings, history).
/// * Navigation: the three views "Spuren", "Tippfeld", "Zeitleiste"
///   (remembered per set) and "Neue Spur" - as a pill at the bottom of a
///   phone, as a rail on wide layouts.
/// * Body, by view:
///   * lanes: one lane per track, as rows or tiles, in several columns on
///     wide screens; drag the grip to reorder, long-press (or right-click)
///     a lane to edit it;
///   * [TapPad]: large buttons for the fastest possible capture;
///   * [TimelineView]: everything that happened, and its summary.
/// * Keyboard: N adds a track in every view. Lanes: 1-9 toggles the n-th
///   track, Space starts / pauses all. Tap pad: 1-9 and 0 press the first
///   ten buttons, Backspace takes the last action back, Escape leaves a
///   person's buttons.
/// * The set's theme and UI preference overrides apply to everything below
///   [SetThemeScope], the navigation included.
class TracksScreen extends ConsumerWidget {
  const TracksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(setsProvider);
    final set = ref.watch(activeSetProvider);
    return SetThemeScope(
      child: RingMonitor(
        child: TracksShortcuts(
          child: Builder(
            builder: (context) {
              final view = set == null
                  ? TracksView.lanes
                  : ref.watch(tracksViewProvider(set.id));
              return AdaptiveNavScaffold(
                destinations: [
                  for (final v in TracksView.values)
                    AdaptiveDestination(
                      label: tracksViewLabel(v),
                      icon: tracksViewIcon(context, v),
                      selectedIcon: tracksViewIcon(context, v),
                    ),
                ],
                selectedIndex: view.index,
                onDestinationSelected: (index) {
                  if (set == null) return;
                  ref.read(hapticsProvider).selection();
                  ref
                      .read(tracksViewsProvider.notifier)
                      .show(set.id, TracksView.values[index]);
                },
                action: set == null
                    ? null
                    : AdaptiveNavAction(
                        key: TracksScreenKeys.addTrack,
                        label: Strings.addTrack,
                        icon: AdaptiveIcons.add(context),
                        onPressed: () =>
                            showTrackEditorSheet(context, setId: set.id),
                      ),
                railActions: [
                  AdaptiveNavAction(
                    key: TracksScreenKeys.settings,
                    label: Strings.navSettings,
                    icon: AdaptiveIcons.settings(context),
                    onPressed: () => openSettings(context),
                  ),
                ],
                body: SafeArea(
                  bottom: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TracksHeader(set: set),
                      Expanded(child: _body(context, ref, sets, set)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TrackSet>> sets,
    TrackSet? set,
  ) {
    if (set == null) {
      if (!sets.hasValue) {
        return sets.hasError
            ? _error(context, sets.error)
            : const SizedBox.shrink();
      }
      return AdaptiveEmptyState(
        icon: AdaptiveIcons.tracks(context),
        title: Strings.noSetsTitle,
        message: Strings.noSetsBody,
        action: AdaptiveFilledButton(
          label: TracksStrings.createSet,
          icon: AdaptiveIcons.add(context),
          onPressed: () => createSetFlow(context, ref),
        ),
      );
    }
    final tracks = ref.watch(tracksInSetProvider(set.id));
    final list = tracks.value;
    if (list == null) {
      return tracks.hasError
          ? _error(context, tracks.error)
          : const SizedBox.shrink();
    }
    if (list.isEmpty) {
      return AdaptiveEmptyState(
        icon: AdaptiveIcons.tracks(context),
        title: Strings.tracksEmptyTitle,
        message: Strings.tracksEmptyBody,
        action: AdaptiveFilledButton(
          key: TracksScreenKeys.emptyAddTrack,
          label: Strings.addTrack,
          icon: AdaptiveIcons.add(context),
          onPressed: () => showTrackEditorSheet(context, setId: set.id),
        ),
      );
    }
    return _withBanners(set, switch (ref.watch(tracksViewProvider(set.id))) {
      TracksView.lanes => TrackLanes(setId: set.id, tracks: list),
      TracksView.pad => TapPad(setId: set.id, tracks: list),
      TracksView.timeline => TimelineView(setId: set.id, tracks: list),
    });
  }

  /// Above the lanes (or the pad, or the timeline): the request for a missing alarm permission and
  /// whatever rings in OTHER sets (their lanes are not on screen). Both
  /// render nothing most of the time.
  Widget _withBanners(TrackSet set, Widget lanes) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AlarmPermissionBanner(),
      RingingBanner(excludeSetId: set.id),
      Expanded(child: lanes),
    ],
  );

  Widget _error(BuildContext context, Object? error) => AdaptiveEmptyState(
    icon: AdaptiveIcons.close(context),
    title: Strings.errorGeneric,
    message: '$error',
  );
}

//// The head of the tracks screen: the set (title, count) and two round
/// buttons, "Alle pausieren / starten" and "···".
class _TracksHeader extends StatelessWidget {
  const _TracksHeader({required this.set});

  final TrackSet? set;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final set = this.set;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.page,
        t.space.sm,
        t.space.page,
        t.space.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(child: SetSwitcherButton()),
          SizedBox(width: t.space.md),
          if (set != null) ...[
            _ToggleAllButton(setId: set.id),
            SizedBox(width: t.space.sm),
          ],
          HeaderRoundButton(
            key: TracksScreenKeys.more,
            icon: AdaptiveIcons.moreHorizontal(context),
            label: TracksStrings.moreMenu,
            onPressed: () => _openMore(context),
          ),
        ],
      ),
    );
  }
}

enum _More { settings, history }

/// "···": settings and the history.
Future<void> _openMore(BuildContext context) async {
  final choice = await showAdaptiveActionSheet<_More>(
    context,
    actions: [
      AdaptiveSheetAction(
        value: _More.settings,
        label: Strings.navSettings,
        icon: AdaptiveIcons.settings(context),
      ),
      AdaptiveSheetAction(
        value: _More.history,
        label: Strings.navHistory,
        icon: AdaptiveIcons.history(context),
      ),
    ],
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _More.settings:
      await openSettings(context);
    case _More.history:
      await openHistory(context);
  }
}

/// "Alle pausieren" while something runs in the set, otherwise "Alle
/// starten". Hidden when the set has nothing that can be started.
class _ToggleAllButton extends ConsumerWidget {
  const _ToggleAllButton({required this.setId});

  final String setId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(tracksInSetProvider(setId)).value ?? const [];
    if (!tracks.any((t) => t.mode.supportsStartPause)) {
      return const SizedBox.shrink();
    }
    final sessions =
        ref.watch(openSessionsProvider).value ?? const <String, OpenSession>{};
    final anyOpen = tracks.any((t) => sessions.containsKey(t.id));
    return NowSelector<bool>(
      // A running timer can stop running by itself (it starts ringing).
      enabled: anyOpen,
      selector: (now) => LaneActions.anyRunning(tracks, sessions, now),
      builder: (context, running) => HeaderRoundButton(
        key: TracksScreenKeys.toggleAll,
        icon: running
            ? AdaptiveIcons.pause(context)
            : AdaptiveIcons.play(context),
        label: running ? Strings.pauseAll : Strings.startAll,
        onPressed: () =>
            ref.read(laneActionsProvider).toggleAll(context, setId),
      ),
    );
  }
}

// ------------------------------------------------------------------ layout

/// How many lanes fit next to each other.
///
/// * rows: one column on phones; on wide layouts as many as fit with a
///   comfortable row width;
/// * tiles: at least two columns, more as the width allows.
int laneColumns({
  required LaneLayout layout,
  required double width,
  required double tileMinWidth,
  required bool wide,
}) {
  // Rows need room for digits and buttons side by side; tiles stack them.
  const rowWidthFactor = 1.4;
  const tileWidthFactor = 0.8;
  const minTileColumns = 2;
  switch (layout) {
    case LaneLayout.rows:
      if (!wide) return 1;
      final columns = (width / (tileMinWidth * rowWidthFactor)).floor();
      return columns < 1 ? 1 : columns;
    case LaneLayout.tiles:
      final columns = (width / (tileMinWidth * tileWidthFactor)).floor();
      return columns < minTileColumns ? minTileColumns : columns;
  }
}

/// The lanes of one set: a reorderable list (one column) or a grid with
/// drag-and-drop reordering (several columns).
class TrackLanes extends ConsumerStatefulWidget {
  const TrackLanes({required this.setId, required this.tracks, super.key});

  final String setId;

  /// Ordered, non-archived tracks of the set.
  final List<Track> tracks;

  @override
  ConsumerState<TrackLanes> createState() => _TrackLanesState();
}

class _TrackLanesState extends ConsumerState<TrackLanes> {
  /// Optimistic order while the database catches up after a drag.
  List<String>? _pendingOrder;

  @override
  void didUpdateWidget(TrackLanes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setId != widget.setId ||
        !_sameIds(oldWidget.tracks, widget.tracks)) {
      _pendingOrder = null;
    }
  }

  static bool _sameIds(List<Track> a, List<Track> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  List<Track> get _ordered {
    final pending = _pendingOrder;
    final tracks = widget.tracks;
    if (pending == null) return tracks;
    final byId = {for (final t in tracks) t.id: t};
    if (pending.length != tracks.length || !pending.every(byId.containsKey)) {
      return tracks;
    }
    return [for (final id in pending) byId[id]!];
  }

  Future<void> _applyOrder(List<String> ids) async {
    setState(() => _pendingOrder = ids);
    ref.read(hapticsProvider).selection();
    await ref.read(trackRepositoryProvider).reorderTracks(widget.setId, ids);
  }

  /// List reordering: [to] is the index in the list without the moved item.
  Future<void> _move(int from, int to) async {
    final ids = [for (final t in _ordered) t.id];
    if (from < 0 || from >= ids.length) return;
    final id = ids.removeAt(from);
    ids.insert(to.clamp(0, ids.length), id);
    await _applyOrder(ids);
  }

  /// Grid reordering: the dragged track takes the place of the target.
  Future<void> _dropOn(String draggedId, String targetId) async {
    final ids = [for (final t in _ordered) t.id];
    final target = ids.indexOf(targetId);
    if (target < 0 || !ids.remove(draggedId)) return;
    ids.insert(target.clamp(0, ids.length), draggedId);
    await _applyOrder(ids);
  }

  void _edit(Track track) {
    ref.read(hapticsProvider).selection();
    showTrackEditorSheet(context, setId: track.setId, track: track);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final layout = t.prefs.layout;
    final tracks = _ordered;
    final lanes = LayoutBuilder(
      builder: (context, constraints) {
        final columns = laneColumns(
          layout: layout,
          width: constraints.maxWidth - 2 * t.space.pageLanes,
          tileMinWidth: t.sizes.tileMinWidth,
          wide: isWide(context),
        );
        return columns <= 1
            ? _list(context, tracks, layout)
            : _grid(context, tracks, layout, columns);
      },
    );
    // "Rückgängig" after a stop sits above the lanes, never over them.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            t.space.pageLanes,
            t.space.sm,
            t.space.pageLanes,
            0,
          ),
          child: const LaneUndoBar(),
        ),
        Expanded(child: lanes),
      ],
    );
  }

  Widget _list(BuildContext context, List<Track> tracks, LaneLayout layout) {
    final t = context.tikky;
    return ReorderableListView.builder(
      key: TracksScreenKeys.list,
      padding: EdgeInsets.fromLTRB(
        t.space.pageLanes,
        t.space.xs,
        t.space.pageLanes,
        t.space.pageLanes,
      ),
      buildDefaultDragHandles: false,
      itemCount: tracks.length,
      onReorderItem: _move,
      proxyDecorator: (child, _, _) =>
          Material(type: MaterialType.transparency, child: child),
      itemBuilder: (context, index) {
        final track = tracks[index];
        return Padding(
          key: ValueKey('cell-${track.id}'),
          padding: EdgeInsets.only(bottom: t.space.sm),
          child: _LaneCell(
            track: track,
            layout: layout,
            onEdit: () => _edit(track),
            dragHandle: ReorderableDragStartListener(
              index: index,
              child: LaneDragHandle(key: LaneKeys.handle(track.id)),
            ),
          ),
        );
      },
    );
  }

  Widget _grid(
    BuildContext context,
    List<Track> tracks,
    LaneLayout layout,
    int columns,
  ) {
    final t = context.tikky;
    final rowCount = (tracks.length + columns - 1) ~/ columns;
    final theme = Theme.of(context);
    return ListView.builder(
      key: TracksScreenKeys.grid,
      padding: EdgeInsets.fromLTRB(
        t.space.pageLanes,
        t.space.xs,
        t.space.pageLanes,
        t.space.pageLanes,
      ),
      itemCount: rowCount,
      itemBuilder: (context, rowIndex) {
        final start = rowIndex * columns;
        final rowTracks = tracks.skip(start).take(columns).toList();
        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) SizedBox(width: t.space.sm),
              Expanded(
                child: c < rowTracks.length
                    ? _GridCell(
                        key: ValueKey('cell-${rowTracks[c].id}'),
                        track: rowTracks[c],
                        layout: layout,
                        theme: theme,
                        onEdit: () => _edit(rowTracks[c]),
                        onDrop: _dropOn,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        );
        return Padding(
          padding: EdgeInsets.only(bottom: t.space.sm),
          child: IntrinsicHeight(child: row),
        );
      },
    );
  }
}

/// A grid cell: drop target for other lanes, with a draggable grip.
class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.track,
    required this.layout,
    required this.theme,
    required this.onEdit,
    required this.onDrop,
    super.key,
  });

  final Track track;
  final LaneLayout layout;

  /// The set's theme, for the drag feedback (it is painted in the overlay,
  /// outside the set's theme scope).
  final ThemeData theme;
  final VoidCallback onEdit;
  final void Function(String draggedId, String targetId) onDrop;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != track.id,
      onAcceptWithDetails: (details) => onDrop(details.data, track.id),
      builder: (context, candidates, _) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: candidates.isEmpty
            ? const BoxDecoration()
            : BoxDecoration(
                borderRadius: t.radii.laneAll,
                border: Border.all(
                  color: t.colors.primary,
                  width: t.sizes.progressBar,
                ),
              ),
        child: _LaneCell(
          track: track,
          layout: layout,
          onEdit: onEdit,
          dragHandle: Draggable<String>(
            data: track.id,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            feedback: Theme(
              data: theme,
              child: _DragFeedback(track: track),
            ),
            child: LaneDragHandle(key: LaneKeys.handle(track.id)),
          ),
        ),
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Material(
      color: t.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: t.radii.smAll,
        side: BorderSide(
          color: t.trackColor(track),
          width: t.sizes.progressBar,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.md,
          vertical: t.space.sm,
        ),
        child: Text(track.name, style: t.text.label),
      ),
    );
  }
}

/// One lane: the regular [TrackLane], or the protocol feature's lane with
/// the grip and an edit button next to it.
class _LaneCell extends StatelessWidget {
  const _LaneCell({
    required this.track,
    required this.layout,
    required this.onEdit,
    required this.dragHandle,
  });

  final Track track;
  final LaneLayout layout;
  final VoidCallback onEdit;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    return TrackLane(
      key: LaneKeys.lane(track.id),
      track: track,
      layout: layout,
      dragHandle: dragHandle,
      onEdit: onEdit,
    );
  }
}

// --------------------------------------------------------------- shortcuts

/// Keyboard shortcuts of the tracks screen.
///
/// * Every view: N adds a track.
/// * Lanes: 1-9 toggles the n-th track, Space starts / pauses all.
/// * Tap pad: 1-9 and 0 press the first ten buttons, Backspace takes the
///   last action back, Escape leaves a person's buttons (see [TapPad]).
/// * Timeline: only N (a digit must not start or stop something that is
///   not on screen).
///
/// They work without the screen holding the focus (a click on the
/// navigation rail does not switch them off), but only while the tracks
/// destination is the visible one, nothing is open on top of it (sheet,
/// dialog, page) and no text field has the focus.
class TracksShortcuts extends ConsumerStatefulWidget {
  const TracksShortcuts({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<TracksShortcuts> createState() => _TracksShortcutsState();
}

class _TracksShortcutsState extends ConsumerState<TracksShortcuts> {
  static final Map<LogicalKeyboardKey, int> _digits = {
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.numpad9: 9,
  };

  /// The pad also uses 0, for its tenth button.
  static bool _isZero(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0;

  /// Hands a key to the pad that is on screen. Returns whether it was
  /// used.
  bool _padKey(LogicalKeyboardKey key) {
    final handler = ref.read(padKeyBridgeProvider).handler;
    if (handler == null) return false;
    final digit = _digits[key];
    if (digit != null) return handler(PadKeyButton(digit - 1));
    if (_isZero(key)) return handler(const PadKeyButton(padShortcutCount - 1));
    if (key == LogicalKeyboardKey.backspace) return handler(const PadKeyUndo());
    if (key == LogicalKeyboardKey.escape) return handler(const PadKeyBack());
    return false;
  }

  bool _visible = true;
  bool _current = true;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _typing() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    return focused.widget is EditableText ||
        focused.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted || !_visible || !_current) {
      return false;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return false;
    }
    if (_typing()) return false;
    final set = ref.read(activeSetProvider);
    if (set == null) return false;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.keyN) {
      showTrackEditorSheet(context, setId: set.id);
      return true;
    }
    switch (ref.read(tracksViewProvider(set.id))) {
      case TracksView.lanes:
        break;
      case TracksView.pad:
        return _padKey(key);
      case TracksView.timeline:
        return false;
    }
    final digit = _digits[key];
    if (digit != null) {
      final tracks = ref.read(activeTracksProvider);
      if (digit > tracks.length) return false;
      final track = tracks[digit - 1];
      ref.read(laneActionsProvider).toggle(track);
      return true;
    }
    if (key == LogicalKeyboardKey.space) {
      ref.read(laneActionsProvider).toggleAll(context, set.id);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    _visible = Visibility.of(context);
    _current = ModalRoute.isCurrentOf(context) ?? true;
    return widget.child;
  }
}
