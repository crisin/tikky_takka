import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/clock.dart';
import '../../core/domain/domain.dart';
import '../../core/repo/providers.dart';
import '../../l10n/formatters.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'protocol_logic.dart';
import 'protocol_people_screen.dart';
import 'protocol_strings.dart';
import 'protocol_widgets.dart';

/// Opens the quick entry sheet of a protocol track: who (person), what
/// (substance), amount (free text), optional note, optional time.
///
/// * [existing] `null`: a new entry is created with
///   `trackCommandsProvider.addEntry(track.id, ...)`.
/// * [existing] set: that entry is edited (including its time) and saved
///   with `historyRepositoryProvider.updateEvent(...)`; the sheet also
///   offers to delete it.
/// * [initialPersonId] preselects a person for a new entry. Nothing else
///   is filled in: substance and amount are picked by the user each time
///   (repeat entries are one tap on the lane's substance buttons).
///
/// Returns the saved entry, or `null` when the sheet was dismissed or the
/// entry was deleted.
///
/// There are no confirmation dialogs: after saving, editing or deleting a
/// "Rückgängig" snackbar is shown on the scaffold of [context]. The app
/// never fills in or suggests amounts or intervals of its own; the amount
/// shortcuts are the user's own earlier inputs.
Future<TrackEvent?> showProtocolEntrySheet(
  BuildContext context, {
  required Track track,
  TrackEvent? existing,
  String? initialPersonId,
  bool quiet = false,
}) async {
  // Fetched up front: undo may run long after the calling widget is gone.
  final actions = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(protocolActionsProvider);

  final result = await showAdaptiveSheet<_SheetResult>(
    context,
    builder: (context) => _EntrySheet(
      track: track,
      existing: existing,
      initialPersonId: initialPersonId,
    ),
  );
  if (result == null) return null;

  switch (result) {
    case _Added(:final added):
      // [quiet]: the caller shows the new entry (and its undo) itself.
      if (!quiet && context.mounted) {
        showUndoSnackBar(
          context,
          message: Strings.protocolSaved,
          onUndo: () => actions.undoAdd(added),
        );
      }
      return added.event;
    case _Updated(:final before, :final after):
      if (context.mounted) {
        showUndoSnackBar(
          context,
          message: ProtocolStrings.entryUpdated,
          onUndo: () => actions.updateEntry(before),
        );
      }
      return after;
    case _Deleted(:final entry):
      if (context.mounted) {
        showUndoSnackBar(
          context,
          message: Strings.protocolDeleted,
          onUndo: () => actions.restoreEntry(entry),
        );
      }
      return null;
  }
}

sealed class _SheetResult {
  const _SheetResult();
}

final class _Added extends _SheetResult {
  const _Added(this.added);
  final AddedEntry added;
}

final class _Updated extends _SheetResult {
  const _Updated({required this.before, required this.after});
  final TrackEvent before;
  final TrackEvent after;
}

final class _Deleted extends _SheetResult {
  const _Deleted(this.entry);
  final TrackEvent entry;
}

class _EntrySheet extends ConsumerStatefulWidget {
  const _EntrySheet({
    required this.track,
    required this.existing,
    required this.initialPersonId,
  });

  final Track track;
  final TrackEvent? existing;
  final String? initialPersonId;

  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _newPerson = TextEditingController();
  final _newSubstance = TextEditingController();

  String? _personId;
  String? _substanceId;

  /// Entry time in UTC ms; `null` = "now" at the moment of saving.
  int? _at;

  bool _addingPerson = false;
  bool _addingSubstance = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _prefill();
    // Keeps the "selected" mark of the amount shortcuts in sync.
    _amount.addListener(_onAmountChanged);
  }

  void _prefill() {
    final existing = widget.existing;
    if (existing != null) {
      _personId = existing.personId;
      _substanceId = existing.substanceId;
      _amount.text = existing.amount ?? '';
      _note.text = existing.note ?? '';
      _at = existing.at;
      return;
    }
    // Only the person is preselected. Substance and amount are never
    // carried over from an earlier entry: the user picks them each time.
    _personId = widget.initialPersonId;
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amount
      ..removeListener(_onAmountChanged)
      ..dispose();
    _note.dispose();
    _newPerson.dispose();
    _newSubstance.dispose();
    super.dispose();
  }

  int get _nowMs => ref.read(clockProvider).nowMs();

  // ------------------------------------------------------------ inline add

  /// Creates the person typed into the inline field (if any) and selects
  /// it. An existing person with the same name is selected instead.
  Future<void> _commitNewPerson() async {
    final name = _newPerson.text.trim();
    if (name.isNotEmpty) {
      final all = ref.read(allPersonsProvider).value ?? const <Person>[];
      final people = ref.read(peopleRepositoryProvider);
      final color = context.tikky.paletteColor(all.length).toARGB32();
      Person? match;
      for (final p in all) {
        if (p.name.toLowerCase() == name.toLowerCase()) match = p;
      }
      if (match == null) {
        match = await people.createPerson(name: name, color: color);
      } else if (match.archived) {
        await people.setPersonArchived(match.id, archived: false);
      }
      _personId = match.id;
    }
    _newPerson.clear();
    if (mounted) setState(() => _addingPerson = false);
  }

  /// Like [_commitNewPerson], for substances. A new substance never gets a
  /// lockout here; that is set by the user in the substance list.
  Future<void> _commitNewSubstance() async {
    final name = _newSubstance.text.trim();
    if (name.isNotEmpty) {
      final all = ref.read(allSubstancesProvider).value ?? const <Substance>[];
      final people = ref.read(peopleRepositoryProvider);
      final color = context.tikky.paletteColor(all.length).toARGB32();
      Substance? match;
      for (final s in all) {
        if (s.name.toLowerCase() == name.toLowerCase()) match = s;
      }
      if (match == null) {
        match = await people.createSubstance(name: name, color: color);
      } else if (match.archived) {
        await people.setSubstanceArchived(match.id, archived: false);
      }
      _substanceId = match.id;
    }
    _newSubstance.clear();
    if (mounted) setState(() => _addingSubstance = false);
  }

  // ------------------------------------------------------------------ time

  void _stepEarlier() {
    const step = ProtocolStrings.timeStepMinutes * 60 * 1000;
    setState(() => _at = (_at ?? _nowMs) - step);
  }

  Future<void> _pickTime() async {
    final clock = ref.read(clockProvider);
    final now = clock.nowLocal();
    final current = _at == null
        ? now
        : DateTime.fromMillisecondsSinceEpoch(_at!);
    final picked = await showAdaptiveDateTimePicker(
      context,
      initial: current,
      first: DateTime(now.year - 1, now.month, now.day),
      last: now,
      use24h: context.tikky.prefs.use24h,
      title: Strings.protocolTime,
    );
    if (picked == null || !mounted) return;
    setState(() => _at = picked.millisecondsSinceEpoch);
  }

  // ------------------------------------------------------------------ save

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final actions = ref.read(protocolActionsProvider);
    final navigator = Navigator.of(context);
    try {
      // A name that was typed but not confirmed still counts.
      if (_addingPerson) await _commitNewPerson();
      if (_addingSubstance) await _commitNewSubstance();

      final now = _nowMs;
      // Entries are never logged in the future.
      final at = _at == null ? null : (_at! > now ? now : _at!);
      final amount = _amount.text.trim();
      final note = _note.text.trim();

      _SheetResult? result;
      final existing = widget.existing;
      if (existing == null) {
        final added = await actions.addEntry(
          widget.track.id,
          personId: _personId,
          substanceId: _substanceId,
          amount: amount,
          note: note,
          at: at,
        );
        if (added != null) result = _Added(added);
      } else {
        final updated = existing.copyWith(
          personId: () => _personId,
          substanceId: () => _substanceId,
          amount: () => amount.isEmpty ? null : amount,
          note: () => note.isEmpty ? null : note,
          at: at ?? now,
        );
        if (await actions.updateEntry(updated)) {
          result = _Updated(before: existing, after: updated);
        }
      }
      if (result != null) await actions.haptics.tick();
      if (navigator.mounted) navigator.pop(result);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showInfoSnackBar(context, Strings.errorGeneric);
      }
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null || _saving) return;
    setState(() => _saving = true);
    final actions = ref.read(protocolActionsProvider);
    final navigator = Navigator.of(context);
    final deleted = await actions.deleteEntry(existing.id);
    await actions.haptics.heavy();
    if (navigator.mounted) {
      navigator.pop(deleted == null ? null : _Deleted(deleted));
    }
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final byPerson = ref.watch(personsByIdProvider);
    final bySubstance = ref.watch(substancesByIdProvider);
    final persons = [
      ...ref.watch(personsProvider).value ?? const <Person>[],
    ];
    final substances = [
      ...ref.watch(substancesProvider).value ?? const <Substance>[],
    ];
    // An edited entry may refer to someone who was removed from the list.
    if (_personId != null &&
        persons.every((p) => p.id != _personId) &&
        byPerson[_personId] != null) {
      persons.add(byPerson[_personId]!);
    }
    if (_substanceId != null &&
        substances.every((s) => s.id != _substanceId) &&
        bySubstance[_substanceId] != null) {
      substances.add(bySubstance[_substanceId]!);
    }

    final history =
        ref.watch(protocolEntryHistoryProvider(widget.track.id)).value ??
        const <TrackEvent>[];
    final suggestions = recentAmounts(history, substanceId: _substanceId);

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: t.sizes.sheetMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: t.space.page),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        _isEdit
                            ? Strings.protocolEditEntry
                            : Strings.protocolNewEntry,
                        style: t.text.title,
                      ),
                    ),
                    Text(widget.track.name, style: t.text.laneTitle),

                    // ---------------------------------------------- who
                    const ProtocolSectionLabel(Strings.protocolWho),
                    Wrap(
                      spacing: t.space.sm,
                      runSpacing: t.space.sm,
                      children: [
                        for (final p in persons)
                          ProtocolChoice(
                            key: ValueKey('person-${p.id}'),
                            label: p.name,
                            color: Color(p.color),
                            selected: p.id == _personId,
                            onTap: () => setState(
                              () =>
                                  _personId = p.id == _personId ? null : p.id,
                            ),
                          ),
                        if (!_addingPerson)
                          ProtocolChoice(
                            key: const ValueKey('add-person'),
                            label: ProtocolStrings.addPersonShort,
                            semanticLabel: Strings.protocolAddPerson,
                            icon: AdaptiveIcons.add(context),
                            onTap: () => setState(() => _addingPerson = true),
                          ),
                      ],
                    ),
                    if (_addingPerson)
                      ProtocolInlineAdd(
                        key: const ValueKey('new-person'),
                        controller: _newPerson,
                        hint: ProtocolStrings.newPersonHint,
                        onSubmit: _commitNewPerson,
                        onCancel: () => setState(() {
                          _newPerson.clear();
                          _addingPerson = false;
                        }),
                      ),

                    // --------------------------------------------- what
                    const ProtocolSectionLabel(Strings.protocolWhat),
                    Wrap(
                      spacing: t.space.sm,
                      runSpacing: t.space.sm,
                      children: [
                        for (final s in substances)
                          ProtocolChoice(
                            key: ValueKey('substance-${s.id}'),
                            label: s.name,
                            color: Color(s.color),
                            selected: s.id == _substanceId,
                            onTap: () => setState(
                              () => _substanceId = s.id == _substanceId
                                  ? null
                                  : s.id,
                            ),
                          ),
                        if (!_addingSubstance)
                          ProtocolChoice(
                            key: const ValueKey('add-substance'),
                            label: ProtocolStrings.addSubstanceShort,
                            semanticLabel: Strings.protocolAddSubstance,
                            icon: AdaptiveIcons.add(context),
                            onTap: () =>
                                setState(() => _addingSubstance = true),
                          ),
                      ],
                    ),
                    if (_addingSubstance)
                      ProtocolInlineAdd(
                        key: const ValueKey('new-substance'),
                        controller: _newSubstance,
                        hint: ProtocolStrings.newSubstanceHint,
                        onSubmit: _commitNewSubstance,
                        onCancel: () => setState(() {
                          _newSubstance.clear();
                          _addingSubstance = false;
                        }),
                      ),
                    if (!_isEdit)
                      _LockoutLine(
                        track: widget.track,
                        personId: _personId,
                        substanceId: _substanceId,
                      ),

                    // ------------------------------------------- amount
                    const ProtocolSectionLabel(Strings.protocolAmount),
                    TextField(
                      key: const ValueKey('amount'),
                      controller: _amount,
                      style: t.text.headline,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(
                        hintText: Strings.protocolAmountHint,
                      ),
                    ),
                    if (suggestions.isNotEmpty) ...[
                      SizedBox(height: t.space.sm),
                      Text(
                        ProtocolStrings.recentAmounts,
                        style: t.text.caption,
                      ),
                      SizedBox(height: t.space.xs),
                      Wrap(
                        spacing: t.space.sm,
                        runSpacing: t.space.sm,
                        children: [
                          for (final amount in suggestions)
                            ProtocolChoice(
                              key: ValueKey('amount-$amount'),
                              label: amount,
                              big: false,
                              selected: _amount.text.trim() == amount,
                              onTap: () => setState(() {
                                _amount.text = amount;
                                _amount.selection = TextSelection.collapsed(
                                  offset: amount.length,
                                );
                              }),
                            ),
                        ],
                      ),
                    ],

                    // --------------------------------------------- time
                    const ProtocolSectionLabel(Strings.protocolTime),
                    _TimeRow(
                      at: _at,
                      onNow: () => setState(() => _at = null),
                      onEarlier: _stepEarlier,
                      onPick: _pickTime,
                    ),

                    // --------------------------------------------- note
                    const ProtocolSectionLabel(
                      Strings.protocolNote,
                      trailing: ProtocolStrings.optional,
                    ),
                    TextField(
                      key: const ValueKey('note'),
                      controller: _note,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: ProtocolStrings.noteHint,
                      ),
                    ),
                    SizedBox(height: t.space.sm),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        if (_isEdit)
                          AdaptiveTextButton(
                            label: ProtocolStrings.deleteEntry,
                            destructive: true,
                            onPressed: _saving ? null : _delete,
                          ),
                        AdaptiveTextButton(
                          label: ProtocolStrings.manage,
                          onPressed: () => openProtocolPeople(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // The save button stays visible above the keyboard.
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
                  key: const ValueKey('save-entry'),
                  label: Strings.save,
                  icon: AdaptiveIcons.check(context),
                  onPressed: _saving ? null : _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the user's own lockout for the chosen person and substance while
/// it is still running. Purely informational: saving is never blocked.
///
/// Counted from the person's last entry of that substance on this track
/// in ANY session - also after "Sitzung beenden", when the track has no
/// open session.
class _LockoutLine extends ConsumerWidget {
  const _LockoutLine({
    required this.track,
    required this.personId,
    required this.substanceId,
  });

  final Track track;
  final String? personId;
  final String? substanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final substanceId = this.substanceId;
    if (substanceId == null) return const SizedBox.shrink();
    final lockouts = ref.watch(lockoutsProvider);
    if (!lockouts.containsKey(substanceId)) return const SizedBox.shrink();
    // Until the track-wide facts have loaded, the open session's entries.
    final facts =
        ref.watch(protocolLastEntriesProvider(track.id)).value ??
        lastEntriesOfSession(ref.watch(openSessionProvider(track.id)));
    if (facts.isEmpty) return const SizedBox.shrink();
    final persons = ref.watch(personsByIdProvider);

    return CoarseNowBuilder(
      builder: (context, nowMs) {
        final t = context.tikky;
        final remaining = lockoutRemainingFor(
          facts,
          personId: personId,
          substanceId: substanceId,
          nowMs: nowMs,
          lockouts: lockouts,
        );
        if (remaining == null) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(top: t.space.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                ProtocolIcons.time(context),
                size: t.sizes.iconSm,
                color: t.colors.warning,
              ),
              SizedBox(width: t.space.sm),
              Expanded(
                child: Text(
                  '${personLabel(personId, persons)} · '
                  '${Strings.lockoutRemaining(formatRemaining(remaining))}',
                  style: t.text.label,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "Zeitpunkt": the chosen time plus the shortcuts to change it.
class _TimeRow extends ConsumerWidget {
  const _TimeRow({
    required this.at,
    required this.onNow,
    required this.onEarlier,
    required this.onPick,
  });

  final int? at;
  final VoidCallback onNow;
  final VoidCallback onEarlier;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final at = this.at;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (at != null)
          Padding(
            padding: EdgeInsets.only(bottom: t.space.sm),
            child: CoarseNowBuilder(
              builder: (context, nowMs) => Text(
                ProtocolStrings.timeWithAgo(
                  entryTimeLabel(at, nowMs: nowMs, use24h: t.prefs.use24h),
                  Fmt.ago(nowMs - at),
                ),
                key: const ValueKey('entry-time'),
                style: t.text.headline,
              ),
            ),
          ),
        Wrap(
          spacing: t.space.sm,
          runSpacing: t.space.sm,
          children: [
            ProtocolChoice(
              key: const ValueKey('time-now'),
              label: ProtocolStrings.timeNow,
              big: false,
              selected: at == null,
              onTap: onNow,
            ),
            ProtocolChoice(
              key: const ValueKey('time-earlier'),
              label: ProtocolStrings.timeEarlier,
              big: false,
              onTap: onEarlier,
            ),
            ProtocolChoice(
              key: const ValueKey('time-pick'),
              label: ProtocolStrings.timePick,
              icon: ProtocolIcons.time(context),
              big: false,
              onTap: onPick,
            ),
          ],
        ),
      ],
    );
  }
}
