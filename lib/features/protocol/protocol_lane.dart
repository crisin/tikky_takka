import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/domain/domain.dart';
import '../../core/engine/engine.dart';
import '../../core/repo/repo.dart';
import '../../core/services/haptics.dart';
import '../../l10n/formatters.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'protocol_entry_sheet.dart';
import 'protocol_logic.dart';
import 'protocol_scene_sheet.dart';
import 'protocol_session_screen.dart';
import 'protocol_strings.dart';
import 'protocol_widgets.dart';

/// The lane of a protocol-mode track. The tracks screen uses this instead
/// of its regular lane whenever `track.mode == TrackMode.protocol`.
///
/// One-tap capture in two steps:
///
/// 1. "Wer bist du?": one card per person (name, colour, last entry, time
///    since and, while one of the user's own lockouts is still running,
///    "frühestens wieder in ..."). With a scene on the track's set only
///    the scene's persons are shown, the rest waits behind "Andere";
///    without a scene everybody is listed. A scene with exactly one
///    person skips this step.
/// 2. Up to five large substance buttons for that person (the scene's
///    substances, then what the person logged most often). ONE TAP WRITES
///    THE ENTRY: person, substance, now - no amount, no note, no dialog,
///    also while a lockout is running. A bar INSIDE the lane (never a
///    snackbar: that would cover buttons and get hit by accident) then
///    offers "Rückgängig" and "Details" (the entry sheet, to add amount,
///    note or another time) for `TikkyMotion.inlineUndoWindow`.
///
/// The round "+" opens the full entry sheet (with the chosen person) for
/// anything else. Secondary buttons: the entry list of the session, and
/// "Sitzung beenden" (undoable, no confirmation).
///
/// Narrow lanes (phones, tiles) stack the capture part above the buttons;
/// wide ones put them side by side. Works in a list row (height follows
/// the content) and in a box of fixed height (the capture part scrolls).
/// Long-press is left to the surrounding screen (track editor /
/// reordering).
///
/// The app never shows or suggests dosing or interval values of its own:
/// a button shows a count, and a remaining time only for a substance the
/// user gave a lockout.
class ProtocolLane extends ConsumerStatefulWidget {
  const ProtocolLane({required this.track, super.key});

  final Track track;

  @override
  ConsumerState<ProtocolLane> createState() => _ProtocolLaneState();
}

/// The one-tap entry that can still be taken back.
final class _Captured {
  const _Captured(this.message, this.entry);

  /// "Jacke · GBL eingetragen"
  final String message;
  final AddedEntry entry;
}

/// The person chosen in step 1 (`personId` `null` = "Ohne Person").
final class _Pick {
  const _Pick(this.personId);

  final String? personId;
}

class _ProtocolLaneState extends ConsumerState<ProtocolLane> {
  /// The explicit choice of step 1; `null` = nobody chosen.
  _Pick? _pick;

  /// Step 1 was asked for although the scene has a single person.
  bool _forceWho = false;

  /// "Andere" was tapped: persons outside the scene are listed too.
  bool _showOthers = false;

  /// A one-tap entry is being written or was just written: further taps
  /// are ignored until the lane has shown it.
  bool _busy = false;

  /// The substance of the entry that was just written.
  String? _justLogged;

  Timer? _confirmTimer;

  /// What the inline undo bar shows; `null` = no bar.
  _Captured? _captured;
  Timer? _capturedTimer;
  final GlobalKey _undoBarKey = GlobalKey();

  Track get _track => widget.track;

  @override
  void dispose() {
    _confirmTimer?.cancel();
    _capturedTimer?.cancel();
    super.dispose();
  }

  void _hideCaptured() {
    _capturedTimer?.cancel();
    _capturedTimer = null;
    _captured = null;
  }

  /// Shows the inline undo bar for [captured] and brings it into view
  /// (a lane of fixed height scrolls its capture part).
  void _showCaptured(_Captured captured) {
    _capturedTimer?.cancel();
    _captured = captured;
    _capturedTimer = Timer(context.tikky.motion.inlineUndoWindow, () {
      if (mounted) setState(_hideCaptured);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bar = _undoBarKey.currentContext;
      if (bar == null || !mounted) return;
      Scrollable.ensureVisible(
        bar,
        alignment: 1,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  /// "Rückgängig" of the bar. Ignored while the entry is still being
  /// confirmed on its button ([_busy]): the bar has just appeared - and
  /// may have been scrolled into view - so a second, hasty tap must not
  /// land on it and take the entry back by accident.
  Future<void> _undoCaptured() async {
    final captured = _captured;
    if (captured == null || _busy) return;
    final actions = ref.read(protocolActionsProvider);
    setState(_hideCaptured);
    unawaited(actions.haptics.selection());
    await actions.undoAdd(captured.entry);
  }

  void _detailsOfCaptured() {
    final captured = _captured;
    if (captured == null || _busy) return;
    setState(_hideCaptured);
    showProtocolEntrySheet(
      context,
      track: _track,
      existing: captured.entry.event,
    );
  }

  void _backToWho() {
    setState(() {
      _pick = null;
      _forceWho = true;
    });
  }

  void _choose(String? personId) {
    ref.read(hapticsProvider).selection();
    setState(() {
      _pick = _Pick(personId);
      _forceWho = false;
    });
  }

  void _resetSteps() {
    _pick = null;
    _forceWho = false;
    _showOthers = false;
  }

  Future<void> _finish() async {
    final actions = ref.read(protocolActionsProvider);
    final sessionId = await actions.finishSession(_track.id);
    await actions.haptics.heavy();
    if (sessionId == null || !mounted) return;
    showUndoSnackBar(
      context,
      message: ProtocolStrings.sessionFinished,
      onUndo: () => actions.reopenSession(sessionId),
    );
  }

  /// The full entry sheet, for anything the buttons do not cover.
  Future<void> _openSheet(String? personId) async {
    ref.read(hapticsProvider).primary();
    final saved = await showProtocolEntrySheet(
      context,
      track: _track,
      initialPersonId: personId,
    );
    if (saved != null && mounted) setState(_resetSteps);
  }

  /// One tap: writes the entry right away. Never asks, never blocks.
  Future<void> _capture(String? personId, Substance substance) async {
    if (_busy) return;
    final actions = ref.read(protocolActionsProvider);
    final person = personLabel(personId, ref.read(personsByIdProvider));
    final track = _track;
    setState(() {
      _busy = true;
      _justLogged = substance.id;
    });
    AddedEntry? added;
    try {
      added = await actions.addEntry(
        track.id,
        personId: personId,
        substanceId: substance.id,
      );
    } catch (_) {
      added = null;
    }
    if (!mounted) return;
    if (added == null) {
      setState(() {
        _busy = false;
        _justLogged = null;
      });
      showInfoSnackBar(context, Strings.errorGeneric);
      return;
    }
    final entry = added;
    unawaited(actions.haptics.tick());
    setState(() {
      _showCaptured(
        _Captured(ProtocolStrings.captured(person, substance.name), entry),
      );
    });
    _confirmTimer?.cancel();
    _confirmTimer = Timer(context.tikky.motion.captureConfirm, () {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _justLogged = null;
        // Back to "Wer bist du?" (a single-person scene stays on its
        // buttons, see build).
        _resetSteps();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final track = _track;
    final open = ref.watch(openSessionProvider(track.id));
    final set = ref.watch(setProvider(track.setId));
    final active = ref.watch(personsProvider).value ?? const <Person>[];
    final known = ref.watch(personsByIdProvider);
    final entryCount =
        open?.events.where((e) => e.type == EventType.entry).length ?? 0;

    // The scene's persons that are still on the user's list, in its order.
    final scenePersonIds = [
      for (final id in set?.scenePersonIds ?? const <String>[])
        if (active.any((p) => p.id == id)) id,
    ];
    var pick = _pick;
    if (pick?.personId case final id? when !known.containsKey(id)) {
      // Deleted in the meantime.
      pick = null;
    }
    // Exactly one person in the scene: no need to ask who it is.
    if (pick == null && scenePersonIds.length == 1 && !_forceWho) {
      pick = _Pick(scenePersonIds.single);
    }

    final title = Text(
      [
        track.name,
        Strings.modeProtocol,
        if (entryCount > 0) ProtocolStrings.entryCount(entryCount),
      ].join(' · '),
      style: t.text.laneTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final chosen = pick;
    final Widget step = chosen == null
        ? _PersonCards(
            track: track,
            open: open,
            scenePersonIds: scenePersonIds,
            showOthers: _showOthers,
            onChoose: _choose,
            onShowOthers: () => setState(() => _showOthers = true),
            onEditScene: () => showSceneEditor(context, setId: track.setId),
          )
        : _CapturePanel(
            // A fresh panel (and button order) per person.
            key: ValueKey('capture-panel-${chosen.personId}'),
            track: track,
            open: open,
            personId: chosen.personId,
            sceneSubstanceIds: set?.sceneSubstanceIds ?? const [],
            busy: _busy,
            justLogged: _justLogged,
            onBack: _backToWho,
            onCapture: (substance) => _capture(chosen.personId, substance),
          );

    final primary = _PrimaryButton(
      onPressed: () => _openSheet(chosen?.personId),
    );

    final secondary = open == null
        ? const <Widget>[]
        : [
            AdaptiveIconButton(
              icon: ProtocolIcons.entries(context),
              semanticLabel: ProtocolStrings.showEntries,
              size: t.sizes.secondaryIcon,
              color: t.colors.textMuted,
              onPressed: () => openProtocolSession(context, track: track),
            ),
            AdaptiveIconButton(
              icon: AdaptiveIcons.stop(context),
              semanticLabel: ProtocolStrings.finishSession,
              size: t.sizes.secondaryIcon,
              color: t.colors.textMuted,
              onPressed: _finish,
            ),
          ];

    final captured = _captured;
    final info = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        SizedBox(height: t.space.xs),
        step,
        // Below everything else of the capture part: nothing that is
        // being tapped moves when the bar comes or goes.
        if (captured != null)
          Padding(
            key: _undoBarKey,
            padding: EdgeInsets.only(top: t.space.sm),
            child: InlineUndoBar(
              key: const ValueKey('capture-undo-bar'),
              message: captured.message,
              onUndo: _undoCaptured,
              secondaryLabel: ProtocolStrings.details,
              onSecondary: _detailsOfCaptured,
            ),
          ),
      ],
    );
    final direction = t.prefs.leftHanded
        ? TextDirection.rtl
        : TextDirection.ltr;

    return Semantics(
      container: true,
      label: track.name,
      child: Material(
        color: t.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: t.radii.mdAll,
          side: t.hairline,
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: t.sizes.laneMinHeight),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: t.sizes.colorBar,
                child: ColoredBox(color: t.trackColor(track)),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  t.sizes.colorBar + t.space.md,
                  t.space.md,
                  t.space.md,
                  t.space.md,
                ),
                // The tracks screen never measures this lane intrinsically
                // (see its grid), so the layout may depend on the width.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        constraints.maxWidth < t.sizes.tileMinWidth * 1.5;
                    return stacked
                        ? _stacked(t, constraints, info, secondary, primary)
                        : _sideBySide(t, info, secondary, primary, direction);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Wide lanes: the capture part, the buttons beside it.
  Widget _sideBySide(
    TikkyTokens t,
    Widget info,
    List<Widget> secondary,
    Widget primary,
    TextDirection direction,
  ) {
    // The info part scrolls when the lane gets a fixed height that is too
    // small; in a list row it simply takes the height it needs.
    final infoPart = Expanded(child: SingleChildScrollView(child: info));
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: direction,
      children: [
        // Stacked, so the capture buttons keep as much width as possible.
        if (secondary.isNotEmpty)
          Column(mainAxisSize: MainAxisSize.min, children: secondary),
        SizedBox(width: t.space.xs),
        primary,
      ],
    );
    final gap = SizedBox(width: t.space.md);
    return Row(
      // Left-handed layout: the buttons lead.
      children: t.prefs.leftHanded
          ? [actions, gap, infoPart]
          : [infoPart, gap, actions],
    );
  }

  /// Phones and tiles: the capture part gets the whole width, the buttons
  /// sit in a line below it (on the side of the hand that holds the phone).
  Widget _stacked(
    TikkyTokens t,
    BoxConstraints constraints,
    Widget info,
    List<Widget> secondary,
    Widget primary,
  ) {
    final actions = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      // Left-handed layout: the "+" leads.
      textDirection: t.prefs.leftHanded ? TextDirection.ltr : TextDirection.rtl,
      children: [
        primary,
        Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: secondary,
        ),
      ],
    );
    final gap = SizedBox(height: t.space.sm);
    // A tile of fixed height: the capture part scrolls above the buttons.
    return constraints.hasBoundedHeight
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: SingleChildScrollView(child: info)),
              gap,
              actions,
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [info, gap, actions],
          );
  }
}

/// The round "add entry" button, at least `bigTapTarget` across.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final size = t.sizes.bigTapTarget > t.sizes.primaryButton
        ? t.sizes.bigTapTarget
        : t.sizes.primaryButton;
    return Tooltip(
      message: Strings.actionAddEntry,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: Strings.actionAddEntry,
        excludeSemantics: true,
        child: Material(
          color: t.colors.primary,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('protocol-add'),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(
                AdaptiveIcons.add(context),
                size: t.sizes.primaryIcon,
                color: t.colors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ step 1

/// What a person card shows besides the name.
final class _PersonInfo {
  const _PersonInfo({
    required this.sinceMs,
    required this.lastEntry,
    required this.lockouts,
  });

  /// Wall time since the person's last entry.
  final int sinceMs;

  /// The last entry of the open session; `null` for a person who is only
  /// known from an earlier session (a lockout that is still running).
  final TrackEvent? lastEntry;

  /// Running lockouts, longest first.
  final List<LockoutStatus> lockouts;
}

/// Step 1, "Wer bist du?": the person cards. Only this part follows the
/// clock.
///
/// * With a scene: the scene's persons in the scene's order; everybody
///   else behind "Andere".
/// * Without a scene: the persons with entries in the open session (most
///   recent first), then those who are still locked out from an earlier
///   session, then the rest of the list.
/// * The lockouts come from the last entries of the whole TRACK, so they
///   keep counting down after "Sitzung beenden".
class _PersonCards extends ConsumerWidget {
  const _PersonCards({
    required this.track,
    required this.open,
    required this.scenePersonIds,
    required this.showOthers,
    required this.onChoose,
    required this.onShowOthers,
    required this.onEditScene,
  });

  final Track track;
  final OpenSession? open;
  final List<String> scenePersonIds;
  final bool showOthers;
  final ValueChanged<String?> onChoose;
  final VoidCallback onShowOthers;
  final VoidCallback onEditScene;

  static int _since(int nowMs, int? at) =>
      at == null || at > nowMs ? 0 : nowMs - at;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final lockouts = ref.watch(lockoutsProvider);
    // Without any lockout set there is nothing to look up across sessions.
    final facts = lockouts.isEmpty
        ? null
        : ref.watch(protocolLastEntriesProvider(track.id)).value;
    final persons = ref.watch(personsByIdProvider);
    final substances = ref.watch(substancesByIdProvider);
    final active = ref.watch(personsProvider).value ?? const <Person>[];
    final hasScene = scenePersonIds.isNotEmpty;

    return CoarseNowBuilder(
      builder: (context, nowMs) {
        final snapshot = protocolSnapshotOf(
          open,
          nowMs: nowMs,
          lockouts: lockouts,
        );
        // While the track-wide facts are loading, the session's own
        // lockouts (part of the snapshot) are shown.
        final running = facts == null
            ? null
            : deriveLockouts(facts, nowMs, lockoutMsBySubstance: lockouts);
        final lastAt = facts == null
            ? const <String?, int>{}
            : lastEntryAtByPerson(facts);

        // Insertion order: this session (most recent first), then persons
        // who are still locked out from an earlier one.
        final info = <String?, _PersonInfo>{
          for (final status
              in snapshot?.persons ?? const <PersonProtocolStatus>[])
            status.personId: _PersonInfo(
              sinceMs: status.sinceMs,
              lastEntry: status.lastEntry.event,
              lockouts: running == null
                  ? status.lockouts
                  : running[status.personId] ?? const [],
            ),
        };
        for (final entry
            in running?.entries ??
                const <MapEntry<String?, List<LockoutStatus>>>[]) {
          info.putIfAbsent(
            entry.key,
            () => _PersonInfo(
              sinceMs: _since(nowMs, lastAt[entry.key]),
              lastEntry: null,
              lockouts: entry.value,
            ),
          );
        }

        final rest = <String?>[
          for (final id in info.keys)
            if (!scenePersonIds.contains(id)) id,
          for (final p in active)
            if (!scenePersonIds.contains(p.id) && !info.containsKey(p.id))
              p.id,
        ];
        final shown = <String?>[
          ...scenePersonIds,
          if (!hasScene || showOthers) ...rest,
        ];

        final cards = [
          for (final id in shown)
            Padding(
              padding: EdgeInsets.only(bottom: t.space.xs),
              child: _PersonCard(
                key: ValueKey('person-card-${id ?? 'none'}'),
                personId: id,
                info: info[id],
                persons: persons,
                substances: substances,
                onTap: () => onChoose(id),
              ),
            ),
        ];
        final footer = Wrap(
          spacing: t.space.sm,
          runSpacing: t.space.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (hasScene && !showOthers && rest.isNotEmpty)
              _FooterButton(
                key: const ValueKey('capture-others'),
                label: ProtocolStrings.others,
                semanticLabel: ProtocolStrings.showOthers,
                icon: AdaptiveIcons.person(context),
                minHeight: t.sizes.primaryButton,
                onTap: onShowOthers,
              ),
            _FooterButton(
              key: const ValueKey('scene-edit'),
              label: ProtocolStrings.scene,
              semanticLabel: ProtocolStrings.sceneEdit,
              icon: ProtocolIcons.scene(context),
              minHeight: t.sizes.minTapTarget,
              onTap: onEditScene,
            ),
          ],
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cards.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: t.space.xs),
                child: Semantics(
                  header: true,
                  child: Text(ProtocolStrings.whoAreYou, style: t.text.headline),
                ),
              ),
            if (info.isEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: t.space.xs),
                child: _EmptyStatus(
                  // Nobody on the list yet: the "+" is the way in.
                  showHint: cards.isEmpty && t.prefs.showSubLine,
                  prominent: cards.isEmpty,
                ),
              ),
            // Full width, one below the other: always the same place.
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: cards,
            ),
            footer,
          ],
        );
      },
    );
  }
}

/// A button below the person cards ("Andere", "Szene").
class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.minHeight,
    required this.onTap,
    super.key,
  });

  final String label;
  final String semanticLabel;
  final IconData icon;
  final double minHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: t.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: t.radii.mdAll,
          side: t.hairline,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minHeight,
              minWidth: minHeight,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.md),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: t.sizes.iconSm, color: t.colors.textMuted),
                  SizedBox(width: t.space.sm),
                  Flexible(
                    child: Text(
                      label,
                      style: t.text.label,
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

class _EmptyStatus extends StatelessWidget {
  const _EmptyStatus({required this.showHint, required this.prominent});

  final bool showHint;

  /// The only content of the lane (large), or a line above the cards.
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Strings.protocolEmpty,
          style: prominent
              ? t.text.headline.copyWith(color: t.colors.textMuted)
              : t.text.subLine,
        ),
        if (showHint) ...[
          SizedBox(height: t.space.xxs),
          Text(ProtocolStrings.tapToAdd, style: t.text.subLine),
        ],
      ],
    );
  }
}

/// One person of step 1: a large card, the whole of it is the button.
class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.personId,
    required this.info,
    required this.persons,
    required this.substances,
    required this.onTap,
    super.key,
  });

  final String? personId;

  /// `null` for a person without entries (just the name).
  final _PersonInfo? info;
  final Map<String, Person> persons;
  final Map<String, Substance> substances;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final person = personId == null ? null : persons[personId];
    final name = personLabel(personId, persons);
    final info = this.info;
    final String headlineText;
    if (info == null) {
      headlineText = name;
    } else if (info.sinceMs < 60000) {
      headlineText = ProtocolStrings.personJustNow(name);
    } else {
      headlineText = Strings.protocolPersonSince(
        name,
        Fmt.coarse(info.sinceMs),
      );
    }
    final lastEntry = info?.lastEntry;

    return Semantics(
      button: true,
      hint: ProtocolStrings.choosePerson(name),
      child: Material(
        color: t.colors.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: t.radii.mdAll,
          side: t.hairline,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: t.sizes.bigTapTarget),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.md,
                vertical: t.space.xs,
              ),
              child: Row(
                children: [
                  ColorDot(
                    color: person == null
                        ? t.colors.textMuted
                        : Color(person.color),
                    size: t.sizes.iconSm,
                  ),
                  SizedBox(width: t.space.md),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(headlineText, style: t.text.headline),
                        if (t.prefs.showSubLine && lastEntry != null)
                          Text(
                            entrySummary(lastEntry, substances),
                            style: t.text.subLine,
                          ),
                        // The user's own lockouts; always shown in full.
                        for (final lockout
                            in info?.lockouts ?? const <LockoutStatus>[])
                          Text(
                            ProtocolStrings.lockoutFor(
                              substanceLabel(lockout.substanceId, substances) ??
                                  Strings.unknown,
                              formatRemaining(lockout.remainingMs),
                            ),
                            style: t.text.subLine.copyWith(
                              color: t.colors.warning,
                            ),
                          ),
                      ],
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

// ------------------------------------------------------------------ step 2

/// Step 2: the chosen person and up to five one-tap substance buttons.
class _CapturePanel extends ConsumerStatefulWidget {
  const _CapturePanel({
    required this.track,
    required this.open,
    required this.personId,
    required this.sceneSubstanceIds,
    required this.busy,
    required this.justLogged,
    required this.onBack,
    required this.onCapture,
    super.key,
  });

  final Track track;
  final OpenSession? open;
  final String? personId;
  final List<String> sceneSubstanceIds;
  final bool busy;
  final String? justLogged;
  final VoidCallback onBack;
  final ValueChanged<Substance> onCapture;

  @override
  ConsumerState<_CapturePanel> createState() => _CapturePanelState();
}

class _CapturePanelState extends ConsumerState<_CapturePanel> {
  /// The buttons as last shown; they keep their places while the panel is
  /// in use (see [keepButtonOrder]).
  List<String> _shown = const [];
  List<String> _sceneOfShown = const [];

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final track = widget.track;
    final personId = widget.personId;
    final persons = ref.watch(personsByIdProvider);
    final substances =
        ref.watch(substancesProvider).value ?? const <Substance>[];
    final byId = {for (final s in substances) s.id: s};
    final use =
        ref.watch(protocolSubstanceUseProvider(track.id)).value ??
        const <SubstanceUse>[];
    final lockouts = ref.watch(lockoutsProvider);
    // Until the track-wide facts have loaded, the open session's entries.
    final facts = lockouts.isEmpty
        ? const <LastEntryFact>[]
        : ref.watch(protocolLastEntriesProvider(track.id)).value ??
              lastEntriesOfSession(widget.open);

    final available = byId.keys.toSet();
    final fresh = topSubstanceIds(
      sceneSubstanceIds: widget.sceneSubstanceIds,
      use: use,
      personId: personId,
      available: available,
    );
    // An edited scene starts over: its order comes first again.
    final sameScene = jsonListEquals(_sceneOfShown, widget.sceneSubstanceIds);
    _shown = sameScene
        ? keepButtonOrder(_shown, fresh, available: available)
        : fresh;
    _sceneOfShown = widget.sceneSubstanceIds;
    final ids = _shown;
    final counts = sessionCounts(widget.open, personId);

    final person = personId == null ? null : persons[personId];
    final name = personLabel(personId, persons);
    final header = Semantics(
      button: true,
      label: name,
      hint: ProtocolStrings.backToPersons,
      excludeSemantics: true,
      child: Material(
        color: t.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: t.radii.mdAll,
          side: t.hairline,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('capture-back'),
          onTap: widget.busy ? null : widget.onBack,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: t.sizes.primaryButton),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.md),
              child: Row(
                children: [
                  ColorDot(
                    color: person == null
                        ? t.colors.textMuted
                        : Color(person.color),
                    size: t.sizes.iconSm,
                  ),
                  SizedBox(width: t.space.md),
                  Expanded(
                    child: Text(
                      name,
                      style: t.text.headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    AdaptiveIcons.close(context),
                    size: t.sizes.iconMd,
                    color: t.colors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (ids.isNotEmpty) SizedBox(height: t.space.sm),
        if (ids.isNotEmpty)
          CoarseNowBuilder(
            builder: (context, nowMs) => Wrap(
              spacing: t.space.sm,
              runSpacing: t.space.sm,
              children: [
                for (final id in ids)
                  _SubstanceButton(
                    key: ValueKey('capture-$id'),
                    substance: byId[id]!,
                    count: counts[id] ?? 0,
                    // Only for a lockout the user set, and only while it
                    // is running. Shown, never enforced.
                    remainingMs: lockouts.containsKey(id)
                        ? lockoutRemainingFor(
                            facts,
                            personId: personId,
                            substanceId: id,
                            nowMs: nowMs,
                            lockouts: lockouts,
                          )
                        : null,
                    justLogged: widget.justLogged == id,
                    onTap: widget.busy
                        ? null
                        : () => widget.onCapture(byId[id]!),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A one-tap substance button: name, the person's count in this session
/// and - only for a running lockout the user set - the remaining time.
class _SubstanceButton extends StatelessWidget {
  const _SubstanceButton({
    required this.substance,
    required this.count,
    required this.remainingMs,
    required this.justLogged,
    required this.onTap,
    super.key,
  });

  final Substance substance;
  final int count;
  final int? remainingMs;
  final bool justLogged;

  /// `null` while taps are ignored (an entry was just written).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final remaining = remainingMs == null
        ? null
        : formatRemaining(remainingMs!);
    final background = justLogged ? t.colors.primary : t.colors.surfaceAlt;
    final foreground = justLogged ? t.colors.onPrimary : t.colors.text;
    final minHeight = t.sizes.bigTapTarget;

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: ProtocolStrings.captureLabel(substance.name, count, remaining),
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: t.radii.mdAll,
          side: t.hairline,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: minHeight,
              minWidth: minHeight * 1.5,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.lg,
                vertical: t.space.xs,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (justLogged)
                        Icon(
                          AdaptiveIcons.check(context),
                          size: t.sizes.iconSm,
                          color: foreground,
                        )
                      else
                        ColorDot(color: Color(substance.color)),
                      SizedBox(width: t.space.sm),
                      Flexible(
                        child: Text(
                          substance.name,
                          style: t.text.headline.copyWith(color: foreground),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ProtocolStrings.timesCount(count),
                        style: t.text.label.copyWith(color: foreground),
                      ),
                      if (remaining != null) ...[
                        SizedBox(width: t.space.sm),
                        Icon(
                          ProtocolIcons.time(context),
                          size: t.sizes.iconSm,
                          color: justLogged ? foreground : t.colors.warning,
                        ),
                        SizedBox(width: t.space.xxs),
                        Flexible(
                          child: Text(
                            remaining,
                            style: t.text.label.copyWith(
                              color: justLogged
                                  ? foreground
                                  : t.colors.warning,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
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
