import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../adaptive/adaptive.dart';
import '../../../core/clock.dart';
import '../../../core/domain/domain.dart';
import '../../../core/engine/engine.dart';
import '../../../core/now_ticker.dart';
import '../../../core/repo/repo.dart';
import '../../../core/services/haptics.dart';
import '../../../l10n/formatters.dart';
import '../../../l10n/strings.dart';
import '../../../theme/theme.dart';
import '../../protocol/protocol_logic.dart';
import '../../protocol/protocol_widgets.dart';
import '../lane_view.dart';
import '../now_selector.dart';
import '../tracks_strings.dart';
import '../tracks_view.dart';
import 'pad_actions.dart';
import 'pad_model.dart';

/// Keys of the tap pad (for tests).
abstract final class PadKeys {
  static const pad = ValueKey('tap-pad');
  static const undoBar = ValueKey('pad-undo-bar');
  static const back = ValueKey('pad-back');

  /// "zuletzt Bier · vor 26 min" under the name on the page "Was?".
  static const last = ValueKey('pad-last');
  static const scroll = ValueKey('pad-scroll');

  /// The page "Anderes" and its field for a new substance.
  static const other = ValueKey('pad-other');
  static const newName = ValueKey('pad-new-name');
  static const newSave = ValueKey('pad-new-save');

  /// A button, by [PadButton.id].
  static Key button(String id) => ValueKey('pad-$id');

  /// The large figure of a button: the count or the time.
  static Key value(String id) => ValueKey('pad-value-$id');

  /// The small line of a button.
  static Key sub(String id) => ValueKey('pad-sub-$id');

  /// "Abstand: noch ..." on a substance button.
  static Key lockout(String id) => ValueKey('pad-lockout-$id');
}

/// "Tippfeld": the fastest way to capture for one set.
///
/// A grid of large fields that fills the screen - one per counter label,
/// stopwatch, timer and protocol person (see [buildMainPad]). One tap
/// writes; nothing asks, nothing confirms, no snackbar covers a field.
///
/// * The fields never move while the pad is open ([mergePadButtons]).
/// * A fixed bar at the top shows the last action with "Rückgängig" (and
///   "Ändern" for a protocol entry) for [TikkyMotion.inlineUndoWindow];
///   a thin bar along its lower edge shows the time left.
/// * A person field of a protocol track opens the page "Was?" with that
///   person's substances. A tap on one writes the entry, marks the field
///   "eingetragen" and returns to the pad after
///   [TikkyMotion.captureConfirm]. "Anderes" lists the remaining
///   substances and takes a new one.
/// * Taps are written one after the other, in the order they came in;
///   none is dropped, except a bounce on the SAME field within
///   [padSameButtonGuardMs].
/// * Keyboard (through `TracksShortcuts`): 1-9 and 0 for the first ten
///   fields, Backspace = undo, Escape = back.
///
/// The screen stays on while the pad is open when "Bildschirm anlassen"
/// is switched on: the app shell holds the wake lock for the whole app.
class TapPad extends ConsumerStatefulWidget {
  const TapPad({required this.setId, required this.tracks, super.key});

  final String setId;

  /// Ordered, non-archived tracks of the set.
  final List<Track> tracks;

  @override
  ConsumerState<TapPad> createState() => _TapPadState();
}

enum _Step {
  /// "Was?": the person's substances.
  what,

  /// "Anderes": the other substances and a new one.
  other,
}

/// The person whose page is shown.
final class _Page {
  const _Page(this.personId, {this.step = _Step.what, this.fromMain = false});

  final String personId;
  final _Step step;

  /// "Anderes" was opened from the main pad (a scene of one person shows
  /// that person's things right there): back goes to the pad.
  final bool fromMain;
}

/// The pad's state: which page is open, the last capture with its undo.
class _TapPadState extends ConsumerState<TapPad>
    with SingleTickerProviderStateMixin {
  /// The buttons of the main pad in the order they were first shown.
  List<String> _mainIds = const [];

  _Page? _page;

  /// What is on screen right now (the keyboard shortcuts index into it).
  List<PadButton> _visible = const [];

  PadResult? _last;

  /// The share of the undo time that is left (1 -> 0).
  late final AnimationController _undoTime;

  /// The substance that was just written: shown as "eingetragen" until
  /// the pad goes back ([TikkyMotion.captureConfirm]).
  String? _hitId;
  Timer? _returnTimer;

  String? _lastTapId;
  int _lastTapMonotonicMs = 0;

  /// Taps are written strictly one after the other.
  Future<void> _queue = Future<void>.value();

  final Map<String, ValueNotifier<int>> _flashes = {};

  final _newName = TextEditingController();

  late final PadKeyBridge _bridge;

  @override
  void initState() {
    super.initState();
    _bridge = ref.read(padKeyBridgeProvider)..handler = _onKey;
    _undoTime = AnimationController(vsync: this, value: 0)
      ..addStatusListener((status) {
        if (status == AnimationStatus.dismissed && _last != null && mounted) {
          setState(() => _last = null);
        }
      });
    _take(ref.read(padPageRequestProvider));
  }

  /// Opens the page that was asked for elsewhere ([PadPageRequest]).
  void _take(PadPageRequest? request) {
    if (request == null) return;
    // Cleared after this frame: providers must not change while building.
    Future.microtask(() {
      if (mounted) ref.read(padPageRequestProvider.notifier).clear();
    });
    _closePage();
    // A person that does not exist is dropped again in build.
    _page = _Page(request.personId);
  }

  @override
  void didUpdateWidget(TapPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setId != widget.setId) {
      // Another set: another pad.
      _mainIds = const [];
      _closePage();
      _clearLast();
    }
  }

  @override
  void dispose() {
    if (_bridge.handler == _onKey) _bridge.handler = null;
    _undoTime.dispose();
    _returnTimer?.cancel();
    _newName.dispose();
    for (final flash in _flashes.values) {
      flash.dispose();
    }
    super.dispose();
  }

  ValueNotifier<int> _flashOf(String id) =>
      _flashes.putIfAbsent(id, () => ValueNotifier<int>(0));

  void _clearLast() {
    _undoTime.stop();
    _undoTime.value = 0;
    _last = null;
  }

  void _showLast(PadResult result) {
    _last = result;
    _undoTime
      ..duration = context.tikky.motion.inlineUndoWindow
      ..reverse(from: 1);
  }

  void _closePage() {
    _returnTimer?.cancel();
    _returnTimer = null;
    _hitId = null;
    _page = null;
    _newName.clear();
  }

  /// Marks [id] "eingetragen", then goes back to the pad.
  void _markHit(String id) {
    _hitId = id;
    _returnTimer?.cancel();
    _returnTimer = Timer(context.tikky.motion.captureConfirm, () {
      if (mounted) setState(_closePage);
    });
  }

  // ------------------------------------------------------------------ taps

  bool _onKey(PadKey key) {
    if (!mounted) return false;
    switch (key) {
      case PadKeyButton(:final index):
        if (index >= _visible.length) return false;
        _onTap(_visible[index]);
        return true;
      case PadKeyUndo():
        if (_last?.undo == null) return false;
        _undo();
        return true;
      case PadKeyBack():
        if (_page == null) return false;
        _back();
        return true;
    }
  }

  void _back() {
    ref.read(hapticsProvider).selection();
    final page = _page;
    setState(() {
      if (page != null && page.step == _Step.other && !page.fromMain) {
        _returnTimer?.cancel();
        _hitId = null;
        _newName.clear();
        _page = _Page(page.personId);
      } else {
        _closePage();
      }
    });
  }

  void _onTap(PadButton button, {String? substanceName}) {
    final monotonic = ref.read(clockProvider).monotonicMs();
    if (_lastTapId == button.id &&
        monotonic - _lastTapMonotonicMs < padSameButtonGuardMs) {
      return;
    }
    // The field that was just captured does not fire again while it still
    // says so: a double tap is one entry.
    if (button.kind == PadButtonKind.substance && _hitId == button.id) return;
    _lastTapId = button.id;
    _lastTapMonotonicMs = monotonic;

    switch (button.kind) {
      case PadButtonKind.person:
        ref.read(hapticsProvider).selection();
        setState(() {
          _closePage();
          _page = _Page(button.personId!);
        });
        return;
      case PadButtonKind.other:
        final personId = button.personId;
        if (personId == null) return;
        ref.read(hapticsProvider).selection();
        final fromMain = _page == null;
        setState(() {
          _returnTimer?.cancel();
          _hitId = null;
          _page = _Page(personId, step: _Step.other, fromMain: fromMain);
        });
        return;
      case PadButtonKind.counter ||
          PadButtonKind.stopwatch ||
          PadButtonKind.timer ||
          PadButtonKind.substance:
        break;
    }
    // A running or paused timer does not react: no flash that would
    // pretend something was written.
    final track = button.trackOrNull;
    if (track != null) {
      final open = ref.read(openSessionProvider(track.id));
      final now = ref.read(nowTickerProvider).value;
      final state = laneSnapshot(track, open, now).state;
      if (padTapAction(button, state) == PadTapAction.none) return;
    }

    _flashOf(button.id).value++;
    final persons = ref.read(personsByIdProvider);
    final substances = ref.read(substancesByIdProvider);
    final actions = ref.read(padActionsProvider);
    _queue = _queue.then((_) async {
      PadResult? result;
      try {
        result = await actions.tap(
          button,
          personName: personLabel(button.personId, persons),
          substanceName:
              substanceName ??
              substanceLabel(button.substanceId, substances) ??
              Strings.unknown,
        );
      } catch (_) {
        result = null;
      }
      if (!mounted || result == null) return;
      final written = result;
      setState(() {
        _showLast(written);
        if (button.kind == PadButtonKind.substance) _markHit(button.id);
      });
    });
  }

  /// Takes back the last capture; the bar then says so.
  void _undo() {
    final last = _last;
    if (last == null || last.undo == null) return;
    final actions = ref.read(padActionsProvider);
    final now = ref.read(clockProvider).nowMs();
    setState(() {
      _showLast(PadResult(what: TracksStrings.padUndone, at: now));
    });
    _queue = _queue.then((_) async {
      try {
        await actions.undo(last);
      } catch (_) {
        // Nothing to take back any more.
      }
    });
  }

  /// "Ändern": the entry that was just written, with time, amount and
  /// note.
  Future<void> _edit() async {}

  /// "Neu anlegen" on the page "Anderes": the thing is created (or found
  /// by its name) and entered right away.
  Future<void> _addNew(String personId) async {
    final name = _newName.text.trim();
    if (name.isEmpty) return;
    final protocol = ref.read(protocolActionsProvider);
    final count = ref.read(allSubstancesProvider).value?.length ?? 0;
    final color = context.tikky.paletteColor(count).toARGB32();
    Substance? substance;
    try {
      substance = await protocol.ensureSubstance(name, color: color);
    } catch (_) {
      substance = null;
    }
    if (substance == null || !mounted) return;
    _newName.clear();
    _onTap(
      PadButton.substance(personId: personId, substanceId: substance.id),
      substanceName: substance.name,
    );
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    ref.listen(padPageRequestProvider, (_, request) {
      if (request != null) setState(() => _take(request));
    });
    final t = context.tikky;
    final tracks = widget.tracks;
    final sessions = ref.watch(openSessionsProvider);
    final set = ref.watch(setProvider(widget.setId));
    final scenePersonIds = set?.scenePersonIds ?? const <String>[];
    final sceneSubstanceIds = set?.sceneSubstanceIds ?? const <String>[];
    final personsAsync = ref.watch(personsProvider);
    final substancesAsync = ref.watch(substancesProvider);
    final personsById = ref.watch(personsByIdProvider);
    final substancesById = ref.watch(substancesByIdProvider);
    final factsAsync = ref.watch(entryFactsProvider);
    final useAsync = ref.watch(entryUseProvider);
    var ready = sessions.hasValue;
    if (scenePersonIds.isNotEmpty || _page != null) {
      ready =
          ready &&
          personsAsync.hasValue &&
          substancesAsync.hasValue &&
          factsAsync.hasValue &&
          useAsync.hasValue;
    }
    // Nothing is shown before everything is known: a button that arrives
    // late would have to be squeezed in between the others.
    if (!ready) return const SizedBox.expand(key: PadKeys.pad);

    final persons = personsAsync.value ?? const <Person>[];
    final substances = substancesAsync.value ?? const <Substance>[];
    final facts = factsAsync.value ?? const <LastEntryFact>[];

    final fresh = buildMainPad(
      tracks: tracks,
      persons: persons,
      scenePersonIds: scenePersonIds,
      sceneSubstanceIds: sceneSubstanceIds,
      substances: substances,
    );
    // With one person the main pad is that person's page "Was?": its
    // things follow the scene. Everything else keeps its place.
    final mainButtons = fresh.any((b) => b.kind == PadButtonKind.substance)
        ? fresh
        : mergePadButtons(shownIds: _mainIds, fresh: fresh);
    _mainIds = [for (final b in mainButtons) b.id];

    var page = _page;
    // The person is gone: back to the main pad.
    if (page != null && !personsById.containsKey(page.personId)) {
      page = null;
      _closePage();
    }

    final List<PadButton> buttons;
    if (page == null) {
      buttons = mainButtons;
    } else {
      final what = page.fromMain
          ? mainButtons
          : buildSubstancePad(
              personId: page.personId,
              sceneSubstanceIds: sceneSubstanceIds,
              substances: substances,
            );
      if (page.step == _Step.what) {
        buttons = what;
      } else {
        final personId = page.personId;
        buttons = buildOtherPad(
          personId: personId,
          substances: substances,
          use: useAsync.value ?? const <SubstanceUse>[],
          shownIds: {
            for (final b in what)
              if (b.kind == PadButtonKind.substance && b.personId == personId)
                b.substanceId!,
          },
        );
      }
    }
    _visible = buttons;

    // The counts of today, only when they are shown (O5).
    final dayStart = t.prefs.dayStartMinutes;
    final nowMs = ref.read(clockProvider).nowMs();
    final day = logicalDayOf(nowMs, dayStart);
    final counts = t.prefs.showEntryCounts
        ? entryCountsOfDay(
            ref
                    .watch(
                      entriesInRangeProvider((
                        from: logicalDayStartMs(day, dayStart),
                        to: logicalDayEndMs(day, dayStart),
                      )),
                    )
                    .value ??
                const <Entry>[],
            nowMs,
            dayStart,
          )
        : const <String, Map<String, int>>{};

    final open = sessions.value ?? const <String, OpenSession>{};
    final showShortcuts = isDesktop(context);
    final activePage = page;

    Widget tile(PadButton button, int index, {_TileShape? shape}) {
      final person = button.personId == null
          ? null
          : personsById[button.personId];
      final substance = button.substanceId == null
          ? null
          : substancesById[button.substanceId];
      final track = button.trackOrNull;
      return _PadTile(
        key: PadKeys.button(button.id),
        button: button,
        open: track == null ? null : open[track.id],
        person: person,
        substance: substance,
        substances: substancesById,
        facts: facts,
        count: padEntryCount(button, counts),
        shape:
            shape ??
            (activePage == null ? _TileShape.regular : _TileShape.large),
        hit: _hitId == button.id,
        // 1 ... 9, then 0.
        shortcut: showShortcuts && index < padShortcutCount
            ? '${(index + 1) % 10}'
            : null,
        flash: _flashOf(button.id),
        onTap: () => _onTap(button),
      );
    }

    final Widget body;
    if (activePage != null && activePage.step == _Step.other) {
      body = _OtherPage(
        key: PadKeys.other,
        buttons: buttons,
        tile: (button, index) =>
            tile(button, index, shape: _TileShape.centered),
        controller: _newName,
        onAdd: () => _addNew(activePage.personId),
      );
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) {
          final layout = computePadLayout(
            // "Was?" always has the grid of its five things and "Anderes":
            // the fields keep their size however many there are.
            count: activePage == null
                ? buttons.length
                : max(buttons.length, captureSubstanceLimit + 1),
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            minButtonHeight: t.sizes.padButtonMinHeight,
            minButtonWidth: t.sizes.padButtonMinWidth,
            gap: t.space.sm,
            minColumns: 2,
          );
          return _grid(context, buttons, layout, tile);
        },
      );
    }

    // "zuletzt Bier · vor 26 min": always there, so the fields below do
    // not move when the first entry is written.
    Widget lastLine(String personId) {
      final latest = padLatestFact(personId, facts);
      final thing = latest == null
          ? null
          : substancesById[latest.substanceId]?.name ?? Strings.unknown;
      return NowSelector<String>(
        enabled: latest != null,
        selector: (nowMs) => latest == null || thing == null
            ? TracksStrings.padNothingYet
            : TracksStrings.padLastOf(thing, padSince(latest.at, nowMs)),
        builder: (context, text) => Text(
          text,
          key: PadKeys.last,
          style: t.text.caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return Padding(
      key: PadKeys.pad,
      padding: EdgeInsets.fromLTRB(
        t.space.pageLanes,
        t.space.sm,
        t.space.pageLanes,
        t.space.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bar(context, activePage),
          SizedBox(height: t.space.sm),
          if (activePage != null) ...[
            _PageHeader(
              person: personsById[activePage.personId],
              backLabel: activePage.step == _Step.other && !activePage.fromMain
                  ? TracksStrings.padBack
                  : TracksStrings.padBackToPad,
              onBack: _back,
              last: lastLine(activePage.personId),
            ),
            SizedBox(height: t.space.sm),
          ],
          Expanded(child: body),
        ],
      ),
    );
  }

  /// The fixed bar above the pad: the last capture with "Rückgängig", or
  /// what this page is for.
  Widget _bar(BuildContext context, _Page? page) {
    final t = context.tikky;
    final last = _last;
    if (last == null) {
      final (title, hint) = switch (page?.step) {
        null => (TracksStrings.padReady, TracksStrings.padUndoIdle),
        _Step.what => (TracksStrings.padWhatTitle, TracksStrings.padWhatHint),
        _Step.other => (
          TracksStrings.padOtherTitle,
          TracksStrings.padOtherHint,
        ),
      };
      return InlineUndoBar(
        key: PadKeys.undoBar,
        height: t.sizes.undoBarHeight,
        muted: true,
        message: title,
        detail: hint,
      );
    }
    final now = ref.read(clockProvider).nowMs();
    final ago = now - last.at;
    final relative = ago < Duration.millisecondsPerMinute
        ? TracksStrings.padNow
        : Strings.ago(Fmt.compact(ago));
    return AnimatedBuilder(
      animation: _undoTime,
      builder: (context, _) => InlineUndoBar(
        key: PadKeys.undoBar,
        height: t.sizes.undoBarHeight,
        message: last.what,
        detail: TracksStrings.padWhen(
          Fmt.time(last.at, use24h: t.prefs.use24h),
          relative,
        ),
        remaining: _undoTime.value,
        onUndo: last.undo == null ? null : _undo,
        secondaryLabel: last.entry == null ? null : TracksStrings.padEdit,
        secondarySemanticLabel: TracksStrings.padEditSemantics,
        onSecondary: last.entry == null ? null : _edit,
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    List<PadButton> buttons,
    PadLayout layout,
    Widget Function(PadButton button, int index) tile,
  ) {
    final t = context.tikky;
    final gap = t.space.sm;

    Widget row(int r) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var c = 0; c < layout.columns; c++) ...[
          if (c > 0) SizedBox(width: gap),
          Expanded(
            child: r * layout.columns + c < buttons.length
                ? tile(buttons[r * layout.columns + c], r * layout.columns + c)
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );

    if (layout.scrolls) {
      return ListView.separated(
        key: PadKeys.scroll,
        itemCount: layout.rows,
        separatorBuilder: (_, _) => SizedBox(height: gap),
        itemBuilder: (context, r) =>
            SizedBox(height: layout.rowHeight, child: row(r)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 0; r < layout.rows; r++) ...[
          if (r > 0) SizedBox(height: gap),
          Expanded(child: row(r)),
        ],
      ],
    );
  }
}

/// Above a person's page: back, the initial and the name.
class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.person,
    required this.backLabel,
    required this.onBack,
    required this.last,
  });

  final Person? person;
  final String backLabel;
  final VoidCallback onBack;

  /// The line under the name: the person's last entry.
  final Widget last;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final name = person?.name ?? Strings.unknown;
    return Row(
      children: [
        HeaderRoundButton(
          key: PadKeys.back,
          icon: isCupertino(context)
              ? Icons.arrow_back_ios_new_rounded
              : Icons.arrow_back_rounded,
          label: backLabel,
          onPressed: onBack,
        ),
        SizedBox(width: t.space.md),
        PersonInitial(
          name: name,
          color: person == null ? null : Color(person!.color),
          size: t.sizes.padAvatar,
          style: t.text.padInitial,
        ),
        SizedBox(width: t.space.md),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  name,
                  style: t.text.pageTitleCompact,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              last,
            ],
          ),
        ),
      ],
    );
  }
}

/// The page "Anderes": the other things, and a field for a new one.
class _OtherPage extends StatelessWidget {
  const _OtherPage({
    required this.buttons,
    required this.tile,
    required this.controller,
    required this.onAdd,
    super.key,
  });

  final List<PadButton> buttons;
  final Widget Function(PadButton button, int index) tile;
  final TextEditingController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final gap = t.space.sm;
    final rows = (buttons.length + 1) ~/ 2;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var r = 0; r < rows; r++) ...[
            if (r > 0) SizedBox(height: gap),
            SizedBox(
              height: t.sizes.padOtherField,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < 2; c++) ...[
                    if (c > 0) SizedBox(width: gap),
                    Expanded(
                      child: r * 2 + c < buttons.length
                          ? tile(buttons[r * 2 + c], r * 2 + c)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
          SizedBox(height: t.space.lg),
          Text(TracksStrings.padNewLabel, style: t.text.caption),
          SizedBox(height: t.space.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: PadKeys.newName,
                  controller: controller,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onAdd(),
                  decoration: const InputDecoration(
                    hintText: TracksStrings.padNewHint,
                  ),
                ),
              ),
              SizedBox(width: t.space.sm),
              PillButton(
                key: PadKeys.newSave,
                label: TracksStrings.padNewSave,
                onPressed: onAdd,
              ),
            ],
          ),
          SizedBox(height: t.space.sm),
          Text(TracksStrings.padNewNote, style: t.text.caption),
        ],
      ),
    );
  }
}

enum _TileShape {
  /// The main pad.
  regular,

  /// The page "Was?": the name larger.
  large,

  /// The page "Anderes": only the name, in the middle.
  centered,
}

/// How a field is painted.
@immutable
final class _TilePaint {
  const _TilePaint({
    required this.surface,
    required this.outline,
    required this.outlineWidth,
    required this.text,
    required this.ink,
  });

  factory _TilePaint.of(
    TikkyTokens t,
    TrackRoles roles, {
    required LaneLook look,
    required bool lit,
  }) {
    final c = t.colors;
    if (look == LaneLook.ringing) {
      return _TilePaint(
        surface: c.danger,
        outline: lit ? c.onDanger : null,
        outlineWidth: lit ? t.sizes.padHitOutline : 0,
        text: c.onDanger,
        ink: c.onDanger,
      );
    }
    if (lit) {
      return _TilePaint(
        surface: roles.strong,
        outline: roles.solid,
        outlineWidth: t.sizes.padHitOutline,
        text: c.text,
        ink: roles.ink,
      );
    }
    return switch (look) {
      LaneLook.idle || LaneLook.paused => _TilePaint(
        surface: null,
        outline: roles.strong,
        outlineWidth: t.sizes.padOutline,
        text: c.text,
        ink: look == LaneLook.idle ? c.textMuted : roles.ink,
      ),
      LaneLook.due => _TilePaint(
        surface: roles.tint,
        outline: c.warning,
        outlineWidth: t.sizes.laneOutlineDue,
        text: c.text,
        ink: roles.ink,
      ),
      LaneLook.running || LaneLook.ringing => _TilePaint(
        surface: roles.tint,
        outline: null,
        outlineWidth: 0,
        text: c.text,
        ink: roles.ink,
      ),
    };
  }

  /// `null`: no surface, only the outline.
  final Color? surface;
  final Color? outline;
  final double outlineWidth;

  /// The name, and the small lines in the colour of the field.
  final Color text;
  final Color ink;
}

/// The face of a stopwatch or timer field at one moment.
typedef _TimedFace = ({
  LaneLook look,
  String digits,
  String hint,
  double? fill,
});

/// One field of the pad. Only what shows time follows the shared ticker.
class _PadTile extends ConsumerStatefulWidget {
  const _PadTile({
    required this.button,
    required this.open,
    required this.person,
    required this.substance,
    required this.substances,
    required this.facts,
    required this.count,
    required this.shape,
    required this.hit,
    required this.shortcut,
    required this.flash,
    required this.onTap,
    super.key,
  });

  final PadButton button;
  final OpenSession? open;
  final Person? person;
  final Substance? substance;

  /// For the last entry of a person ("Kippe · vor 8 min").
  final Map<String, Substance> substances;

  /// When each person last had each thing (person tiles, lockouts).
  final List<LastEntryFact> facts;

  /// How often the person of a thing button had that thing today.
  final int count;
  final _TileShape shape;

  /// Just written: "eingetragen".
  final bool hit;

  /// The key that triggers this field, shown in a corner on desktop.
  final String? shortcut;

  /// Counts the accepted taps; every change lights the field up.
  final ValueListenable<int> flash;
  final VoidCallback onTap;

  @override
  ConsumerState<_PadTile> createState() => _PadTileState();
}

class _PadTileState extends ConsumerState<_PadTile> {
  bool _lit = false;
  Timer? _litTimer;

  @override
  void initState() {
    super.initState();
    widget.flash.addListener(_onFlash);
  }

  @override
  void didUpdateWidget(_PadTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.flash, widget.flash)) {
      oldWidget.flash.removeListener(_onFlash);
      widget.flash.addListener(_onFlash);
    }
  }

  @override
  void dispose() {
    widget.flash.removeListener(_onFlash);
    _litTimer?.cancel();
    super.dispose();
  }

  void _onFlash() {
    if (!mounted) return;
    _litTimer?.cancel();
    setState(() => _lit = true);
    _litTimer = Timer(context.tikky.motion.tapFlash, () {
      if (mounted) setState(() => _lit = false);
    });
  }

  String get _title {
    final button = widget.button;
    return switch (button.kind) {
      PadButtonKind.counter => button.label ?? button.track.name,
      PadButtonKind.stopwatch || PadButtonKind.timer => button.track.name,
      PadButtonKind.person => widget.person?.name ?? Strings.unknown,
      PadButtonKind.substance => widget.substance?.name ?? Strings.unknown,
      PadButtonKind.other => TracksStrings.padMore,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final button = widget.button;
    switch (button.kind) {
      case PadButtonKind.other:
        return _DashedTile(
          label: _title,
          caption: null,
          semanticLabel: TracksStrings.padOtherSemantics,
          shortcut: widget.shortcut,
          onTap: widget.onTap,
        );
      case PadButtonKind.stopwatch || PadButtonKind.timer:
        final open = widget.open;
        final prefs = t.prefs;
        final now = ref.watch(nowTickerProvider).value;
        _TimedFace face(int nowMs) {
          final view = buildLaneView(
            track: button.track,
            open: open,
            nowMs: nowMs,
            prefs: prefs,
          );
          final look = view.controls.look;
          final progress = view.time.progress;
          final fill =
              prefs.showProgressBar &&
                  progress != null &&
                  (look == LaneLook.running || look == LaneLook.paused)
              ? 1 - progress
              : null;
          return (
            look: look,
            digits: view.time.digits,
            hint: padSubText(button, open, nowMs),
            fill: fill,
          );
        }

        return NowSelector<_TimedFace>(
          enabled: padIsLive(button, open, now),
          selector: face,
          builder: (context, face) => _timed(context, face),
        );
      case PadButtonKind.person:
        return _person(context);
      case PadButtonKind.counter || PadButtonKind.substance:
        return _capture(context);
    }
  }

  /// The roles of the field: the substance's colour on "Was?" and
  /// "Anderes", the track's otherwise.
  TrackRoles _roles(TikkyTokens t) {
    final button = widget.button;
    final color = switch (button.kind) {
      PadButtonKind.substance => widget.substance?.color,
      PadButtonKind.person => widget.person?.color,
      _ => null,
    };
    if (color != null) return t.roles(Color(color));
    final track = button.trackOrNull;
    return track == null ? t.roles(t.colors.primary) : t.trackRoles(track);
  }

  Widget _timed(BuildContext context, _TimedFace face) {
    final t = context.tikky;
    final button = widget.button;
    final paint = _TilePaint.of(t, _roles(t), look: face.look, lit: _lit);
    final fill = face.fill;
    return _TileFrame(
      paint: paint,
      semanticLabel: TracksStrings.padButtonSemantics(
        button.track.name,
        _title,
        face.digits,
      ),
      shortcut: widget.shortcut,
      onTap: widget.onTap,
      background: fill == null
          ? null
          : ExcludeSemantics(
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: fill.clamp(0, 1).toDouble(),
                heightFactor: 1,
                child: ColoredBox(color: _roles(t).strong),
              ),
            ),
      top: _name(t, paint, _title),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            face.digits,
            key: PadKeys.value(button.id),
            style: t.text.padDigits.copyWith(color: paint.text),
            maxLines: 1,
          ),
          Text(
            face.hint,
            key: PadKeys.sub(button.id),
            style: t.text.padHint.copyWith(color: paint.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _name(TikkyTokens t, _TilePaint paint, String title) => Text(
    title,
    style:
        (widget.shape == _TileShape.large
                ? t.text.padNameLarge
                : t.text.padName)
            .copyWith(color: paint.text),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  /// Counter, person and substance fields.
  /// A counter or a thing: one tap writes.
  Widget _capture(BuildContext context) {
    final t = context.tikky;
    final button = widget.button;
    final open = widget.open;
    final roles = _roles(t);
    final lit = _lit || widget.hit;
    final paint = _TilePaint.of(t, roles, look: LaneLook.running, lit: lit);
    final title = _title;
    final isCounter = button.kind == PadButtonKind.counter;
    final count = isCounter ? padCount(button, open) : widget.count;
    final substanceId = button.substanceId;

    // The count: always on a counter, on a thing only when asked for (and
    // never "×0").
    final showCount = isCounter || (t.prefs.showEntryCounts && count > 0);

    // Only for a lockout the user set. Shown, never enforced.
    final lockouts = ref.watch(lockoutsProvider);
    final facts =
        !isCounter && substanceId != null && lockouts.containsKey(substanceId)
        ? widget.facts
        : null;
    final now = ref.watch(nowTickerProvider).value;
    PadLockout? lockoutAt(int nowMs) => facts == null
        ? null
        : padLockout(button, facts: facts, lockouts: lockouts, nowMs: nowMs);

    final countText = showCount
        ? Text(
            TracksStrings.padCount(count),
            key: PadKeys.value(button.id),
            style: t.text.padCount.copyWith(color: paint.ink),
            maxLines: 1,
          )
        : null;

    if (widget.shape == _TileShape.centered) {
      return _TileFrame(
        paint: paint,
        semanticLabel: TracksStrings.padSubstanceSemantics(
          title,
          captured: widget.hit,
        ),
        shortcut: widget.shortcut,
        onTap: widget.onTap,
        centered: true,
        top: _name(t, paint, title),
        bottom: widget.hit ? _captured(t, paint) : null,
      );
    }

    final Widget top = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: _name(t, paint, title)),
        if (countText != null) ...[SizedBox(width: t.space.sm), countText],
      ],
    );

    final Widget? bottom;
    if (isCounter) {
      bottom = NowSelector<String>(
        enabled: padIsLive(button, open, now),
        selector: (nowMs) => padSubText(button, open, nowMs),
        builder: (context, text) => _hint(t, paint, text, button.id),
      );
    } else if (widget.hit) {
      bottom = _captured(t, paint);
    } else if (facts == null) {
      bottom = null;
    } else {
      bottom = NowSelector<PadLockout?>(
        selector: lockoutAt,
        builder: (context, lockout) =>
            lockout == null ? const SizedBox.shrink() : _lockout(t, lockout),
      );
    }

    final String semantics;
    if (isCounter) {
      semantics = TracksStrings.padButtonSemantics(
        button.track.name,
        title,
        Strings.countValue(count),
      );
    } else {
      final lockout = lockoutAt(now);
      semantics = TracksStrings.padSubstanceSemantics(
        title,
        count: showCount ? count : null,
        lockout: lockout == null
            ? null
            : TracksStrings.padLockout(formatRemaining(lockout.remainingMs)),
        captured: widget.hit,
      );
    }

    return _TileFrame(
      paint: paint,
      semanticLabel: semantics,
      shortcut: widget.shortcut,
      onTap: widget.onTap,
      top: top,
      bottom: bottom,
    );
  }

  /// A person of the scene: where they stand, and the way to "Was?".
  Widget _person(BuildContext context) {
    final t = context.tikky;
    final button = widget.button;
    final personId = button.personId!;
    final roles = _roles(t);
    final title = _title;
    final lockouts = ref.watch(lockoutsProvider);
    final substances = widget.substances;
    final facts = widget.facts;
    PadPersonFace face(int nowMs) => padPersonFace(
      personStand(personId, facts, nowMs, lockoutMsBySubstance: lockouts),
      substances,
    );
    return NowSelector<PadPersonFace>(
      enabled: padLatestFact(personId, facts) != null,
      selector: face,
      builder: (context, face) {
        final paint = _TilePaint.of(
          t,
          roles,
          look: face.any ? LaneLook.running : LaneLook.idle,
          lit: _lit,
        );
        return _TileFrame(
          paint: paint,
          semanticLabel: TracksStrings.padPersonSemantics(
            title,
            face.digits,
            face.line,
          ),
          shortcut: widget.shortcut,
          onTap: widget.onTap,
          top: Row(
            children: [
              PersonInitial(
                name: title,
                color: widget.person == null
                    ? null
                    : Color(widget.person!.color),
                size: t.sizes.padAvatar,
                style: t.text.padInitial,
              ),
              SizedBox(width: t.space.md),
              Flexible(child: _name(t, paint, title)),
            ],
          ),
          bottom: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                face.digits,
                key: PadKeys.value(button.id),
                style: t.text.padDigits.copyWith(color: paint.text),
                maxLines: 1,
              ),
              Text(
                face.line,
                key: PadKeys.sub(button.id),
                style: t.text.padHint.copyWith(
                  color: face.warn ? t.colors.warningText : paint.ink,
                  fontWeight: face.warn ? FontWeight.w600 : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _hint(TikkyTokens t, _TilePaint paint, String text, String id) => Text(
    text,
    key: PadKeys.sub(id),
    style: t.text.padHint.copyWith(color: paint.ink),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );

  /// "✓ eingetragen"
  Widget _captured(TikkyTokens t, _TilePaint paint) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        AdaptiveIcons.check(context),
        size: t.sizes.iconSm,
        color: paint.text,
      ),
      SizedBox(width: t.space.xs),
      Flexible(
        child: Text(
          TracksStrings.padCaptured,
          style: t.text.padHint.copyWith(
            color: paint.text,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  /// "Abstand: noch 34 min" and a bar of how much of it has passed.
  Widget _lockout(TikkyTokens t, PadLockout lockout) {
    final roles = _roles(t);
    return Column(
      key: PadKeys.lockout(widget.button.id),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          TracksStrings.padLockout(formatRemaining(lockout.remainingMs)),
          style: t.text.padHint.copyWith(
            color: t.colors.warningText,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: t.space.xs),
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: t.radii.pillAll,
            child: SizedBox(
              height: t.sizes.padLockoutBar,
              child: ColoredBox(
                color: roles.strong,
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: lockout.passed,
                  child: ColoredBox(color: t.colors.warning),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The frame of a field: surface or outline, the name at the top, the
/// small part at the bottom, the shortcut in a corner.
class _TileFrame extends StatelessWidget {
  const _TileFrame({
    required this.paint,
    required this.semanticLabel,
    required this.shortcut,
    required this.onTap,
    required this.top,
    required this.bottom,
    this.background,
    this.centered = false,
  });

  final _TilePaint paint;
  final String semanticLabel;
  final String? shortcut;
  final VoidCallback onTap;
  final Widget top;
  final Widget? bottom;

  /// Behind the content: the fill of a timer.
  final Widget? background;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final outline = paint.outline;
    final content = Column(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.spaceBetween,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: [
        top,
        if (bottom != null) ...[SizedBox(height: t.space.xs), bottom!],
      ],
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: paint.surface ?? Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: t.radii.padAll,
          side: outline == null
              ? BorderSide.none
              : BorderSide(color: outline, width: paint.outlineWidth),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashFactory: isCupertino(context) ? NoSplash.splashFactory : null,
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ?background,
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  t.space.lg,
                  t.space.md,
                  t.space.md,
                  t.space.md,
                ),
                // The content keeps its natural size and is only scaled
                // down where a row is lower than it needs (many fields,
                // large text).
                child: LayoutBuilder(
                  builder: (context, box) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: centered
                        ? Alignment.center
                        : AlignmentDirectional.topStart,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: box.maxWidth,
                        maxWidth: box.maxWidth,
                        minHeight: box.maxHeight,
                      ),
                      child: IntrinsicHeight(child: content),
                    ),
                  ),
                ),
              ),
              if (shortcut != null)
                PositionedDirectional(
                  top: t.space.xs,
                  end: t.space.sm,
                  child: ExcludeSemantics(
                    child: Text(
                      shortcut!,
                      style: t.text.caption.copyWith(color: paint.ink),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "+ Anderes": a field with a dashed outline.
class _DashedTile extends StatelessWidget {
  const _DashedTile({
    required this.label,
    required this.caption,
    required this.semanticLabel,
    required this.shortcut,
    required this.onTap,
  });

  final String label;
  final String? caption;
  final String semanticLabel;
  final String? shortcut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final caption = this.caption;
    return Semantics(
      button: true,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: CustomPaint(
        foregroundPainter: _DashedOutline(
          color: t.colors.textMuted,
          width: t.sizes.padOutline,
          radius: t.radii.pad,
          dash: t.sizes.padDash,
        ),
        child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: t.radii.padAll),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            splashFactory: isCupertino(context) ? NoSplash.splashFactory : null,
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: EdgeInsets.all(t.space.sm),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AdaptiveIcons.add(context),
                          size: t.sizes.iconLg,
                          color: t.colors.text,
                        ),
                        SizedBox(height: t.space.xs),
                        Text(label, style: t.text.labelStrong),
                        if (caption != null)
                          Text(caption, style: t.text.caption, maxLines: 1),
                      ],
                    ),
                  ),
                ),
                if (shortcut != null)
                  PositionedDirectional(
                    top: t.space.xs,
                    end: t.space.sm,
                    child: ExcludeSemantics(
                      child: Text(shortcut!, style: t.text.caption),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed rounded outline.
class _DashedOutline extends CustomPainter {
  const _DashedOutline({
    required this.color,
    required this.width,
    required this.radius,
    required this.dash,
  });

  final Color color;
  final double width;
  final double radius;
  final double dash;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = width / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - width, size.height - width),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final dashed = Path();
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash * 2) {
        dashed.addPath(metric.extractPath(d, d + dash), Offset.zero);
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(_DashedOutline old) =>
      old.color != color ||
      old.width != width ||
      old.radius != radius ||
      old.dash != dash;
}
