import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../adaptive/adaptive.dart';
import '../../../core/clock.dart';
import '../../../core/domain/domain.dart';
import '../../../core/now_ticker.dart';
import '../../../core/repo/repo.dart';
import '../../../core/services/haptics.dart';
import '../../../l10n/formatters.dart';
import '../../../l10n/strings.dart';
import '../../../theme/theme.dart';
import '../../protocol/protocol_entry_sheet.dart';
import '../../protocol/protocol_logic.dart';
import '../../protocol/protocol_widgets.dart';
import '../lane_view.dart';
import '../now_selector.dart';
import '../tracks_strings.dart';
import 'pad_actions.dart';
import 'pad_model.dart';

/// Keys of the tap pad (for tests).
abstract final class PadKeys {
  static const pad = ValueKey('tap-pad');
  static const undoBar = ValueKey('pad-undo-bar');
  static const back = ValueKey('pad-back');
  static const scroll = ValueKey('pad-scroll');

  /// A button, by [PadButton.id].
  static Key button(String id) => ValueKey('pad-$id');

  /// The large figure of a button.
  static Key value(String id) => ValueKey('pad-value-$id');

  /// The small "since last tap" line of a button.
  static Key sub(String id) => ValueKey('pad-sub-$id');
}

/// "Tippfeld": the fastest way to capture for one set.
///
/// A grid of large buttons that fills the screen - one per counter label,
/// stopwatch, timer and protocol person (see [buildMainPad]). One tap
/// writes; nothing asks, nothing confirms, no snackbar covers a button.
///
/// * The buttons never move while the pad is open ([mergePadButtons]).
/// * A fixed bar at the top shows the last action with a large
///   "Rückgängig" for [TikkyMotion.inlineUndoWindow]; it undoes exactly
///   that action.
/// * A person button of a protocol track switches to that person's
///   substance buttons; a tap on one writes the entry and returns here.
/// * Taps are written one after the other, in the order they came in;
///   none is dropped, except a bounce on the SAME button within
///   [padSameButtonGuardMs].
/// * Keyboard (through `TracksShortcuts`): 1-9 and 0 for the first ten
///   buttons, Backspace = undo, Escape = back from a person.
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

/// The person whose substance buttons are shown.
final class _PersonPage {
  const _PersonPage(this.trackId, this.personId);

  final String trackId;
  final String personId;
}

class _TapPadState extends ConsumerState<TapPad> {
  /// The buttons of the main pad in the order they were first shown.
  List<String> _mainIds = const [];

  _PersonPage? _page;

  /// The buttons of [_page], frozen like [_mainIds].
  List<String> _pageIds = const [];

  /// What is on screen right now (the keyboard shortcuts index into it).
  List<PadButton> _visible = const [];

  PadResult? _last;
  Timer? _lastTimer;

  String? _lastTapId;
  int _lastTapMonotonicMs = 0;

  /// Taps are written strictly one after the other.
  Future<void> _queue = Future<void>.value();

  final Map<String, ValueNotifier<int>> _flashes = {};

  late final PadKeyBridge _bridge;

  @override
  void initState() {
    super.initState();
    _bridge = ref.read(padKeyBridgeProvider)..handler = _onKey;
  }

  @override
  void didUpdateWidget(TapPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setId != widget.setId) {
      // Another set: another pad.
      _mainIds = const [];
      _page = null;
      _pageIds = const [];
      _clearLast();
    }
  }

  @override
  void dispose() {
    if (_bridge.handler == _onKey) _bridge.handler = null;
    _lastTimer?.cancel();
    for (final flash in _flashes.values) {
      flash.dispose();
    }
    super.dispose();
  }

  ValueNotifier<int> _flashOf(String id) =>
      _flashes.putIfAbsent(id, () => ValueNotifier<int>(0));

  void _clearLast() {
    _lastTimer?.cancel();
    _lastTimer = null;
    _last = null;
  }

  void _showLast(PadResult result) {
    _lastTimer?.cancel();
    _last = result;
    _lastTimer = Timer(context.tikky.motion.inlineUndoWindow, () {
      if (mounted) setState(_clearLast);
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
    setState(() {
      _page = null;
      _pageIds = const [];
    });
  }

  void _onTap(PadButton button) {
    final monotonic = ref.read(clockProvider).monotonicMs();
    if (_lastTapId == button.id &&
        monotonic - _lastTapMonotonicMs < padSameButtonGuardMs) {
      return;
    }
    _lastTapId = button.id;
    _lastTapMonotonicMs = monotonic;

    switch (button.kind) {
      case PadButtonKind.person:
        ref.read(hapticsProvider).selection();
        setState(() {
          _page = _PersonPage(button.track.id, button.personId!);
          _pageIds = const [];
        });
        return;
      case PadButtonKind.more:
        unawaited(_openSheet(button));
        return;
      case PadButtonKind.counter ||
          PadButtonKind.stopwatch ||
          PadButtonKind.timer ||
          PadButtonKind.substance:
        break;
    }
    // A running or paused timer does not react: no flash that would
    // pretend something was written.
    final open = ref.read(openSessionProvider(button.track.id));
    final now = ref.read(nowTickerProvider).value;
    final state = laneSnapshot(button.track, open, now).state;
    if (padTapAction(button, state) == PadTapAction.none) return;

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
              substanceLabel(button.substanceId, substances) ?? Strings.unknown,
        );
      } catch (_) {
        result = null;
      }
      if (!mounted || result == null) return;
      final written = result;
      setState(() {
        _showLast(written);
        // An entry from a person's buttons: back to the main pad.
        if (button.kind == PadButtonKind.substance && _page != null) {
          _page = null;
          _pageIds = const [];
        }
      });
    });
  }

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

  /// "+": the full entry sheet. What it saves shows up in the undo bar
  /// like a tap (the sheet stays quiet: no snackbar over the pad).
  Future<void> _openSheet(PadButton button) async {
    final track = button.track;
    final protocol = ref.read(protocolActionsProvider);
    final persons = ref.read(personsByIdProvider);
    final substances = ref.read(substancesByIdProvider);
    final hadSession = ref.read(openSessionProvider(track.id)) != null;
    unawaited(ref.read(hapticsProvider).primary());
    final saved = await showProtocolEntrySheet(
      context,
      track: track,
      initialPersonId: button.personId,
      quiet: true,
    );
    if (saved == null || !mounted) return;
    final added = AddedEntry(saved, createdSession: !hadSession);
    // Read again: person or substance may have been created in the sheet.
    final personsNow = {...persons, ...ref.read(personsByIdProvider)};
    final substancesNow = {...substances, ...ref.read(substancesByIdProvider)};
    setState(() {
      _showLast(
        PadResult(
          what: TracksStrings.padEntry(
            personLabel(saved.personId, personsNow),
            entrySummary(saved, substancesNow),
          ),
          at: saved.at,
          undo: () => protocol.undoAdd(added),
        ),
      );
      _page = null;
      _pageIds = const [];
    });
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final tracks = widget.tracks;
    final sessions = ref.watch(openSessionsProvider);
    final set = ref.watch(setProvider(widget.setId));
    final protocolTracks = [
      for (final track in tracks)
        if (track.mode == TrackMode.protocol) track,
    ];
    final personsAsync = ref.watch(personsProvider);
    final substancesAsync = ref.watch(substancesProvider);
    final personsById = ref.watch(personsByIdProvider);
    final substancesById = ref.watch(substancesByIdProvider);
    final useByTrack = <String, List<SubstanceUse>>{};
    var ready = sessions.hasValue;
    if (protocolTracks.isNotEmpty) {
      ready = ready && personsAsync.hasValue && substancesAsync.hasValue;
      for (final track in protocolTracks) {
        final use = ref.watch(protocolSubstanceUseProvider(track.id));
        if (use.hasValue) {
          useByTrack[track.id] = use.value!;
        } else {
          ready = false;
        }
      }
    }
    // Nothing is shown before everything is known: a button that arrives
    // late would have to be squeezed in between the others.
    if (!ready) return const SizedBox.expand(key: PadKeys.pad);

    final persons = personsAsync.value ?? const <Person>[];
    final substances = substancesAsync.value ?? const <Substance>[];
    final scenePersonIds = set?.scenePersonIds ?? const <String>[];
    final sceneSubstanceIds = set?.sceneSubstanceIds ?? const <String>[];

    List<PadButton> main({int? limit}) => buildMainPad(
      tracks: tracks,
      persons: persons,
      scenePersonIds: scenePersonIds,
      sceneSubstanceIds: sceneSubstanceIds,
      substances: substances,
      useByTrack: useByTrack,
      limit: limit,
    );
    final mainButtons = mergePadButtons(
      shownIds: _mainIds,
      fresh: main(limit: captureSubstanceLimit),
      candidates: main(),
    );
    _mainIds = [for (final b in mainButtons) b.id];

    var page = _page;
    Track? pageTrack;
    if (page != null) {
      for (final track in protocolTracks) {
        if (track.id == page.trackId) pageTrack = track;
      }
      // The track or the person is gone: back to the main pad.
      if (pageTrack == null || !personsById.containsKey(page.personId)) {
        page = null;
        _page = null;
        _pageIds = const [];
      }
    }

    final List<PadButton> buttons;
    if (page == null || pageTrack == null) {
      buttons = mainButtons;
    } else {
      List<PadButton> of({required int limit}) => buildSubstancePad(
        track: pageTrack!,
        personId: page!.personId,
        sceneSubstanceIds: sceneSubstanceIds,
        substances: substances,
        use: useByTrack[pageTrack.id] ?? const [],
        limit: limit,
      );
      buttons = mergePadButtons(
        shownIds: _pageIds,
        fresh: of(limit: captureSubstanceLimit),
        candidates: of(limit: substances.length),
      );
      _pageIds = [for (final b in buttons) b.id];
    }
    _visible = buttons;

    final open = sessions.value ?? const <String, OpenSession>{};
    final last = _last;
    final showShortcuts = isDesktop(context);
    final activePage = page;

    return Padding(
      key: PadKeys.pad,
      padding: EdgeInsets.all(t.space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InlineUndoBar(
            key: PadKeys.undoBar,
            height: t.sizes.undoBarHeight,
            muted: last == null,
            message: last == null
                ? TracksStrings.padUndoIdle
                : TracksStrings.padLastAction(
                    last.what,
                    Fmt.time(last.at, use24h: t.prefs.use24h, seconds: true),
                  ),
            onUndo: last?.undo == null ? null : _undo,
          ),
          SizedBox(height: t.space.sm),
          if (activePage != null) ...[
            _PageHeader(
              person: personsById[activePage.personId],
              onBack: _back,
            ),
            SizedBox(height: t.space.sm),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = computePadLayout(
                  count: buttons.length,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  minButtonHeight: t.sizes.padButtonMinHeight,
                  minButtonWidth: t.sizes.padButtonMinWidth,
                  gap: t.space.sm,
                );
                return _grid(
                  context,
                  buttons,
                  layout,
                  open: open,
                  personsById: personsById,
                  substancesById: substancesById,
                  showShortcuts: showShortcuts,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    List<PadButton> buttons,
    PadLayout layout, {
    required Map<String, OpenSession> open,
    required Map<String, Person> personsById,
    required Map<String, Substance> substancesById,
    required bool showShortcuts,
  }) {
    final t = context.tikky;
    final gap = t.space.sm;

    Widget tile(int index) {
      final button = buttons[index];
      final person = button.personId == null
          ? null
          : personsById[button.personId];
      final substance = button.substanceId == null
          ? null
          : substancesById[button.substanceId];
      return _PadTile(
        key: PadKeys.button(button.id),
        button: button,
        open: open[button.track.id],
        person: person,
        substance: substance,
        // 1 ... 9, then 0.
        shortcut: showShortcuts && index < padShortcutCount
            ? '${(index + 1) % 10}'
            : null,
        flash: _flashOf(button.id),
        onTap: () => _onTap(button),
      );
    }

    Widget row(int r) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var c = 0; c < layout.columns; c++) ...[
          if (c > 0) SizedBox(width: gap),
          Expanded(
            child: r * layout.columns + c < buttons.length
                ? tile(r * layout.columns + c)
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

/// Above a person's substance buttons: a clear way back and whose buttons
/// these are.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.person, required this.onBack});

  final Person? person;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final name = person?.name ?? Strings.unknown;
    return Semantics(
      button: true,
      label: TracksStrings.padBackToPad,
      value: name,
      onTap: onBack,
      excludeSemantics: true,
      child: Material(
        color: t.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: t.radii.mdAll,
          side: t.hairline,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: PadKeys.back,
          onTap: onBack,
          child: SizedBox(
            height: t.sizes.primaryButton,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.md),
              child: Row(
                children: [
                  Icon(
                    isCupertino(context)
                        ? Icons.arrow_back_ios_new_rounded
                        : Icons.arrow_back_rounded,
                    size: t.sizes.iconLg,
                    color: t.colors.text,
                  ),
                  SizedBox(width: t.space.sm),
                  Text(Strings.back, style: t.text.button),
                  SizedBox(width: t.space.lg),
                  ColorDot(
                    color: person == null
                        ? t.colors.textMuted
                        : Color(person!.color),
                    size: t.sizes.iconSm,
                  ),
                  SizedBox(width: t.space.sm),
                  Expanded(
                    child: Text(
                      TracksStrings.padPersonTitle(name),
                      style: t.text.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

/// One button of the pad: colour accent, large label, big count or time
/// and the small time since its last tap. Only the texts that show time
/// follow the shared ticker.
class _PadTile extends ConsumerStatefulWidget {
  const _PadTile({
    required this.button,
    required this.open,
    required this.person,
    required this.substance,
    required this.shortcut,
    required this.flash,
    required this.onTap,
    super.key,
  });

  final PadButton button;
  final OpenSession? open;
  final Person? person;
  final Substance? substance;

  /// The key that triggers this button, shown in a corner on desktop.
  final String? shortcut;

  /// Counts the accepted taps; every change lights the button up.
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
      PadButtonKind.more => button.track.name,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final button = widget.button;
    final track = button.track;
    final open = widget.open;
    final prefs = t.prefs;
    final accent = t.trackColor(track);
    final title = _title;
    final ticker = ref.watch(nowTickerProvider);
    final now = ticker.value;
    final live = padIsLive(button, open, now);
    final timed =
        button.kind == PadButtonKind.stopwatch ||
        button.kind == PadButtonKind.timer;
    final dotColor = switch (button.kind) {
      PadButtonKind.person =>
        widget.person == null ? null : Color(widget.person!.color),
      PadButtonKind.substance =>
        widget.substance == null ? null : Color(widget.substance!.color),
      _ => null,
    };
    final semantics = switch (button.kind) {
      PadButtonKind.person => TracksStrings.padPersonSemantics(
        track.name,
        title,
      ),
      PadButtonKind.more => TracksStrings.padMoreSemantics(track.name),
      _ => TracksStrings.padButtonSemantics(
        track.name,
        title,
        padValue(button, open, now, prefs: prefs),
      ),
    };
    final background = _lit
        ? Color.alphaBlend(accent.withValues(alpha: 0.4), t.colors.surface)
        : t.colors.surface;

    final lockouts = ref.watch(lockoutsProvider);
    final substanceId = button.substanceId;
    // Only for a lockout the user set. Shown, never enforced.
    final facts =
        button.kind == PadButtonKind.substance &&
            substanceId != null &&
            lockouts.containsKey(substanceId)
        ? ref.watch(protocolLastEntriesProvider(track.id)).value ??
              lastEntriesOfSession(open)
        : null;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != track.name)
          Text(
            track.name,
            style: t.text.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              ColorDot(color: dotColor),
              SizedBox(width: t.space.sm),
            ],
            Flexible(
              child: Text(
                title,
                style: t.text.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        NowSelector<String>(
          enabled: timed && live,
          selector: (nowMs) => padValue(button, open, nowMs, prefs: prefs),
          builder: (context, value) => Text(
            value,
            key: PadKeys.value(button.id),
            style: t.text.digitsLarge,
            maxLines: 1,
          ),
        ),
        NowSelector<String>(
          enabled: live,
          selector: (nowMs) => padSubText(button, open, nowMs),
          builder: (context, text) => Text(
            text,
            key: PadKeys.sub(button.id),
            style: t.text.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (facts != null && substanceId != null)
          NowSelector<String>(
            selector: (nowMs) {
              final remaining = lockoutRemainingFor(
                facts,
                personId: button.personId,
                substanceId: substanceId,
                nowMs: nowMs,
                lockouts: lockouts,
              );
              return remaining == null
                  ? ''
                  : TracksStrings.padLockout(formatRemaining(remaining));
            },
            builder: (context, text) => text.isEmpty
                ? const SizedBox.shrink()
                : Text(
                    text,
                    style: t.text.caption.copyWith(color: t.colors.warning),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
      ],
    );

    return Semantics(
      button: true,
      label: semantics,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: t.radii.mdAll,
          side: t.hairline,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: t.sizes.colorBar * 1.5,
                child: ColoredBox(color: accent),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  t.sizes.colorBar * 1.5 + t.space.sm,
                  t.space.xs,
                  t.space.sm,
                  t.space.xs,
                ),
                child: LayoutBuilder(
                  builder: (context, box) => FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ConstrainedBox(
                      // Long names are cut instead of shrinking the whole
                      // button to unreadable.
                      constraints: BoxConstraints(maxWidth: box.maxWidth * 1.4),
                      child: content,
                    ),
                  ),
                ),
              ),
              if (widget.shortcut != null)
                PositionedDirectional(
                  top: t.space.xs,
                  end: t.space.sm,
                  child: ExcludeSemantics(
                    child: Text(widget.shortcut!, style: t.text.caption),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
