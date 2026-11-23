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
import '../tracks/tracks_view.dart';
import 'protocol_entry_sheet.dart';
import 'protocol_logic.dart';
import 'protocol_scene_sheet.dart';
import 'protocol_session_screen.dart';
import 'protocol_strings.dart';
import 'protocol_widgets.dart';

/// The lane of a protocol-mode track. The tracks screen uses this instead
/// of its regular lane whenever `track.mode == TrackMode.protocol`.
///
/// "Wer bist du?": one card per person (name, colour, last entry, time
/// since and, while one of the user's own lockouts is still running,
/// "frühestens wieder in ..."). With a scene on the track's set only the
/// scene's persons are shown, the rest waits behind "Andere"; without a
/// scene everybody is listed.
///
/// A card opens the page "Was?" of that person on the tap pad, where one
/// tap writes the entry (Pult 2.2). The lane itself captures nothing any
/// more. The card of entries without a person, and the round "+", open
/// the full entry sheet. Secondary buttons: the entry list of the session,
/// and "Sitzung beenden" (undoable, no confirmation).
///
/// Narrow lanes (phones, tiles) stack the cards above the buttons; wide
/// ones put them side by side. Works in a list row (height follows the
/// content) and in a box of fixed height (the cards scroll). Long-press is
/// left to the surrounding screen (track editor / reordering).
///
/// The app never shows or suggests dosing or interval values of its own:
/// a card shows a remaining time only for a substance the user gave a
/// lockout.
class ProtocolLane extends ConsumerStatefulWidget {
  const ProtocolLane({required this.track, super.key});

  final Track track;

  @override
  ConsumerState<ProtocolLane> createState() => _ProtocolLaneState();
}

class _ProtocolLaneState extends ConsumerState<ProtocolLane> {
  /// "Andere" was tapped: persons outside the scene are listed too.
  bool _showOthers = false;

  Track get _track => widget.track;

  /// A person card: "Was?" of that person on the tap pad; entries without
  /// a person go through the full sheet.
  void _choose(String? personId) {
    if (personId == null) {
      unawaited(_openSheet(null));
      return;
    }
    ref.read(hapticsProvider).selection();
    ref
        .read(padPageRequestProvider.notifier)
        .open(_track.setId, trackId: _track.id, personId: personId);
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

  /// The full entry sheet, for anything the tap pad does not cover.
  Future<void> _openSheet(String? personId) async {
    ref.read(hapticsProvider).primary();
    final saved = await showProtocolEntrySheet(
      context,
      track: _track,
      initialPersonId: personId,
    );
    if (saved != null && mounted) setState(() => _showOthers = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final track = _track;
    final open = ref.watch(openSessionProvider(track.id));
    final set = ref.watch(setProvider(track.setId));
    final active = ref.watch(personsProvider).value ?? const <Person>[];
    final entryCount =
        open?.events.where((e) => e.type == EventType.entry).length ?? 0;

    // The scene's persons that are still on the user's list, in its order.
    final scenePersonIds = [
      for (final id in set?.scenePersonIds ?? const <String>[])
        if (active.any((p) => p.id == id)) id,
    ];

    final roles = t.trackRoles(track);
    // With persons to choose from the head line asks; otherwise it names
    // the mode.
    final asks = active.isNotEmpty;
    final title = Row(
      children: [
        ExcludeSemantics(
          child: SizedBox.square(
            dimension: t.sizes.lamp,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: open == null ? null : roles.solid,
                borderRadius: t.radii.pillAll,
                border: open == null
                    ? Border.all(
                        color: roles.solid,
                        width: t.sizes.laneButtonOutline,
                      )
                    : null,
              ),
            ),
          ),
        ),
        SizedBox(width: t.space.sm),
        Flexible(
          child: Text(
            track.name,
            style: t.text.laneName.copyWith(
              color: open == null ? t.colors.text : roles.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: t.space.sm),
        Expanded(
          child: Semantics(
            header: asks,
            child: Text(
              asks ? ProtocolStrings.whoAreYou : Strings.modeProtocol,
              style: t.text.laneMode.copyWith(color: roles.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (entryCount > 0)
          Flexible(
            child: Text(
              ProtocolStrings.entryCount(entryCount),
              style: t.text.laneSub.copyWith(color: roles.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );

    final cards = _PersonCards(
      track: track,
      open: open,
      scenePersonIds: scenePersonIds,
      showOthers: _showOthers,
      onChoose: _choose,
      onShowOthers: () => setState(() => _showOthers = true),
      onEditScene: () => showSceneEditor(context, setId: track.setId),
    );

    final primary = _PrimaryButton(
      roles: roles,
      onPressed: () => _openSheet(null),
    );

    final secondary = open == null
        ? const <Widget>[]
        : [
            AdaptiveIconButton(
              icon: ProtocolIcons.entries(context),
              semanticLabel: ProtocolStrings.showEntries,
              size: t.sizes.secondaryIcon,
              color: roles.ink,
              onPressed: () => openProtocolSession(context, track: track),
            ),
            AdaptiveIconButton(
              icon: AdaptiveIcons.stop(context),
              semanticLabel: ProtocolStrings.finishSession,
              size: t.sizes.secondaryIcon,
              color: roles.ink,
              onPressed: _finish,
            ),
          ];

    final info = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        title,
        SizedBox(height: t.space.xs),
        cards,
      ],
    );
    final direction = t.prefs.leftHanded
        ? TextDirection.rtl
        : TextDirection.ltr;

    // A surface in the track colour while a session is open, otherwise
    // the thin outline of a ready lane.
    return Semantics(
      container: true,
      label: track.name,
      child: Material(
        color: open == null ? t.colors.background : roles.tint,
        shape: RoundedRectangleBorder(
          borderRadius: t.radii.laneAll,
          side: open == null
              ? BorderSide(
                  color: t.colors.border,
                  width: t.sizes.laneOutlineIdle,
                )
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: t.sizes.laneHeightIdle),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              t.space.lg,
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
  const _PrimaryButton({required this.roles, required this.onPressed});

  final TrackRoles roles;
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
          color: roles.solid,
          shape: RoundedRectangleBorder(borderRadius: t.radii.pillAll),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('protocol-add'),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(
                AdaptiveIcons.add(context),
                size: t.sizes.primaryIcon,
                color: roles.on,
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

  static const int _tilesPerRow = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final roles = t.trackRoles(track);
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
            if (!scenePersonIds.contains(p.id) && !info.containsKey(p.id)) p.id,
        ];
        final shown = <String?>[
          ...scenePersonIds,
          if (!hasScene || showOthers) ...rest,
        ];

        final cards = [
          for (final id in shown)
            _PersonCard(
              key: ValueKey('person-card-${id ?? 'none'}'),
              personId: id,
              info: info[id],
              persons: persons,
              substances: substances,
              roles: roles,
              onTap: () => onChoose(id),
            ),
        ];
        // Two tiles side by side where they fit; a row is as high as its
        // taller tile, so every tile of a row is the same size.
        List<Widget> rowsFor(int perRow) => [
          for (var i = 0; i < cards.length; i += perRow)
            Padding(
              padding: EdgeInsets.only(bottom: t.space.sm),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < perRow; j++) ...[
                      if (j > 0) SizedBox(width: t.space.sm),
                      Expanded(
                        child: i + j < cards.length
                            ? cards[i + j]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
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
                roles: roles,
                onTap: onShowOthers,
              ),
            _FooterButton(
              key: const ValueKey('scene-edit'),
              label: ProtocolStrings.scene,
              semanticLabel: ProtocolStrings.sceneEdit,
              icon: ProtocolIcons.scene(context),
              minHeight: t.sizes.minTapTarget,
              roles: roles,
              onTap: onEditScene,
            ),
          ],
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.isEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: t.space.xs),
                child: _EmptyStatus(
                  // Nobody on the list yet: the "+" is the way in.
                  showHint: cards.isEmpty && t.prefs.showSubLine,
                  prominent: cards.isEmpty,
                ),
              ),
            // In a fixed order: a tile never changes its place.
            LayoutBuilder(
              builder: (context, constraints) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rowsFor(
                  constraints.maxWidth >=
                          _tilesPerRow * t.sizes.personTileMinWidth
                      ? _tilesPerRow
                      : 1,
                ),
              ),
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
    required this.roles,
    required this.onTap,
    super.key,
  });

  final String label;
  final String semanticLabel;
  final IconData icon;
  final double minHeight;
  final TrackRoles roles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: roles.strong,
        shape: RoundedRectangleBorder(borderRadius: t.radii.smallAll),
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
                  Icon(icon, size: t.sizes.iconSm, color: roles.ink),
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

/// One person of step 1: a tile with the initial, the name and the last
/// entry; the whole of it is the button.
class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.personId,
    required this.info,
    required this.persons,
    required this.substances,
    required this.roles,
    required this.onTap,
    super.key,
  });

  final String? personId;

  /// `null` for a person without entries (just the name).
  final _PersonInfo? info;
  final Map<String, Person> persons;
  final Map<String, Substance> substances;

  /// The roles of the lane's colour.
  final TrackRoles roles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final person = personId == null ? null : persons[personId];
    final name = personLabel(personId, persons);
    final info = this.info;
    final lastEntry = info?.lastEntry;
    final String headline;
    if (info == null) {
      headline = name;
    } else if (info.sinceMs < 60000) {
      headline = ProtocolStrings.personJustNow(name);
    } else {
      headline = Strings.protocolPersonSince(name, Fmt.coarse(info.sinceMs));
    }
    final detail = lastEntry == null ? '' : entrySummary(lastEntry, substances);
    final personRoles = person == null ? null : t.roles(Color(person.color));
    final initial = name.isEmpty ? '' : name.characters.first.toUpperCase();

    return Semantics(
      button: true,
      hint: ProtocolStrings.choosePerson(name),
      child: Material(
        color: roles.strong,
        shape: RoundedRectangleBorder(borderRadius: t.radii.smallAll),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: t.sizes.personTile),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.sm,
                vertical: t.space.xs,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: t.sizes.personAvatar,
                      height: t.sizes.personAvatar,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: personRoles?.solid ?? t.colors.textMuted,
                        borderRadius: t.radii.pillAll,
                      ),
                      child: Text(
                        initial,
                        style: t.text.laneLabel.copyWith(
                          color:
                              personRoles?.on ?? t.onColor(t.colors.textMuted),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: t.space.sm),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: t.text.laneLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (t.prefs.showSubLine && detail.isNotEmpty)
                          Text(
                            detail,
                            style: t.text.laneSub.copyWith(color: roles.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                            style: t.text.laneSub.copyWith(
                              color: t.colors.warningText,
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
