import 'dart:async';

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
import 'protocol_strings.dart';
import 'protocol_widgets.dart';

/// Keys of the sheet "Ändern" for tests.
abstract final class EntrySheetKeys {
  static const timeNow = ValueKey('time-now');
  static ValueKey<String> timeBack(int minutes) => ValueKey('time-$minutes');
  static ValueKey<String> timeStep(int minutes) =>
      ValueKey('time-step-$minutes');
  static const timePick = ValueKey('time-pick');
  static ValueKey<String> amount(String amount) => ValueKey('amount-$amount');
  static const amountOther = ValueKey('amount-other');
  static const amountField = ValueKey('amount');
  static const rowPerson = ValueKey('row-person');
  static const rowSubstance = ValueKey('row-substance');
  static const rowNote = ValueKey('row-note');
  static const note = ValueKey('note');
  static const delete = ValueKey('delete-entry');
  static const again = ValueKey('again-now');
  static const done = ValueKey('save-entry');
  static const close = ValueKey('close-entry');
}

/// The sheet "Ändern" of an entry that exists (Pult 2.4, 2.5 and 3.5).
///
/// Every change is written right away; "Fertig" only closes. Afterwards a
/// snackbar offers "Rückgängig" for the whole edit (unless [quiet]: the
/// caller shows the entry itself), for "Löschen" and for "Nochmal jetzt".
///
/// * [fresh]: the entry was just written (opened from an undo bar).
///   "Wann?" moves it back from the time it was written: Jetzt, −5, −10,
///   −30 min, or a time of its own.
/// * otherwise (timeline, history, entry list): "Wann?" shows the time
///   with −5 / −1 / +1 / +5, the head names the gap to the person's
///   previous entry of the same substance, and "Nochmal jetzt" logs the
///   same entry once more with the time of now.
///
/// Returns the entry as it is after the sheet, or `null` when it was
/// deleted.
Future<TrackEvent?> showEntryEditSheet(
  BuildContext context, {
  required Track track,
  required TrackEvent entry,
  bool fresh = false,
  bool quiet = false,
}) async {
  // Fetched up front: undo may run long after the calling widget is gone.
  final actions = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(protocolActionsProvider);
  final edit = _Edit(entry, actions);

  await showAdaptiveSheet<void>(
    context,
    builder: (context) => _EditSheet(track: track, edit: edit, fresh: fresh),
  );
  await edit.writes;

  final deleted = edit.deleted;
  if (deleted != null) {
    if (context.mounted) {
      showUndoSnackBar(
        context,
        message: Strings.protocolDeleted,
        onUndo: () => actions.restoreEntry(deleted),
      );
    }
    return null;
  }
  final again = edit.again;
  if (again != null) {
    if (context.mounted) {
      showUndoSnackBar(
        context,
        message: Strings.protocolSaved,
        onUndo: () => actions.undoAdd(again),
      );
    }
  } else if (edit.changed && !quiet && context.mounted) {
    showUndoSnackBar(
      context,
      message: ProtocolStrings.entryUpdated,
      onUndo: () => actions.updateEntry(entry),
    );
  }
  return edit.current;
}

/// What happened to the entry while the sheet was open.
final class _Edit {
  _Edit(this.before, this.actions) : current = before;

  final TrackEvent before;
  final ProtocolActions actions;
  TrackEvent current;
  bool changed = false;
  TrackEvent? deleted;
  AddedEntry? again;

  /// The writes, strictly one after the other.
  Future<void> writes = Future<void>.value();

  void write(TrackEvent next) {
    current = next;
    changed = true;
    writes = writes.then((_) async {
      try {
        await actions.updateEntry(next);
      } catch (_) {
        // The next change or the close writes again.
      }
    });
  }
}

/// The folded rows of the sheet; one at most is open.
enum _Row { person, substance, note }

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({
    required this.track,
    required this.edit,
    required this.fresh,
  });

  final Track track;
  final _Edit edit;
  final bool fresh;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  /// The shortcuts of a just written entry, in minutes back.
  static const _backMinutes = [5, 10, 30];

  /// The steps of the time of an older entry, in minutes.
  static const _steps = [-5, -1, 1, 5];

  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _newPerson = TextEditingController();
  final _newSubstance = TextEditingController();

  _Row? _open;
  bool _customAmount = false;
  bool _addingPerson = false;
  bool _addingSubstance = false;
  bool _busy = false;

  /// The time the shortcuts of a just written entry count back from.
  late final int _base = widget.edit.before.at;

  TrackEvent get _e => widget.edit.current;

  @override
  void initState() {
    super.initState();
    _amount.text = _e.amount ?? '';
    _note.text = _e.note ?? '';
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _newPerson.dispose();
    _newSubstance.dispose();
    super.dispose();
  }

  int get _nowMs => ref.read(clockProvider).nowMs();

  void _apply(TrackEvent next) {
    setState(() => widget.edit.write(next));
  }

  void _tick() => unawaited(widget.edit.actions.haptics.selection());

  // ------------------------------------------------------------------ time

  /// Entries are never logged in the future.
  void _setAt(int at) {
    final now = _nowMs;
    final clamped = at > now ? now : at;
    if (clamped == _e.at) return;
    _tick();
    _apply(_e.copyWith(at: clamped));
  }

  Future<void> _pickTime() async {
    final now = ref.read(clockProvider).nowLocal();
    final picked = await showAdaptiveDateTimePicker(
      context,
      initial: DateTime.fromMillisecondsSinceEpoch(_e.at),
      first: DateTime(now.year - 1, now.month, now.day),
      last: now,
      use24h: context.tikky.prefs.use24h,
      title: Strings.protocolTime,
    );
    if (picked == null || !mounted) return;
    _setAt(picked.millisecondsSinceEpoch);
  }

  // ---------------------------------------------------------------- amount

  void _chooseAmount(String amount) {
    _tick();
    final same = _e.amount == amount;
    _amount.text = same ? '' : amount;
    _customAmount = false;
    _apply(_e.copyWith(amount: () => same ? null : amount));
  }

  void _typeAmount(String text) {
    final amount = text.trim();
    _apply(_e.copyWith(amount: () => amount.isEmpty ? null : amount));
  }

  void _typeNote(String text) {
    final note = text.trim();
    _apply(_e.copyWith(note: () => note.isEmpty ? null : note));
  }

  // ------------------------------------------------------------ who / what

  void _toggle(_Row row) {
    _tick();
    setState(() {
      _open = _open == row ? null : row;
      _addingPerson = false;
      _addingSubstance = false;
    });
  }

  void _choosePerson(String id) {
    _tick();
    _apply(_e.copyWith(personId: () => _e.personId == id ? null : id));
  }

  void _chooseSubstance(String id) {
    _tick();
    _apply(_e.copyWith(substanceId: () => _e.substanceId == id ? null : id));
  }

  /// Creates the person typed into the inline field (an existing one of
  /// that name is taken instead) and puts it on the entry.
  Future<void> _commitNewPerson() async {
    final name = _newPerson.text.trim();
    _newPerson.clear();
    setState(() => _addingPerson = false);
    if (name.isEmpty) return;
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
    if (!mounted) return;
    _apply(_e.copyWith(personId: () => match!.id));
  }

  /// Like [_commitNewPerson]. A new substance never gets a lockout here.
  Future<void> _commitNewSubstance() async {
    final name = _newSubstance.text.trim();
    _newSubstance.clear();
    setState(() => _addingSubstance = false);
    if (name.isEmpty) return;
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
    if (!mounted) return;
    _apply(_e.copyWith(substanceId: () => match!.id));
  }

  // --------------------------------------------------------------- actions

  Future<void> _delete() async {
    if (_busy) return;
    setState(() => _busy = true);
    final edit = widget.edit;
    final navigator = Navigator.of(context);
    await edit.writes;
    edit.deleted = await edit.actions.deleteEntry(_e.id);
    await edit.actions.haptics.heavy();
    if (navigator.mounted) navigator.pop();
  }

  Future<void> _again() async {
    if (_busy) return;
    setState(() => _busy = true);
    final edit = widget.edit;
    final navigator = Navigator.of(context);
    await edit.writes;
    final e = _e;
    edit.again = await edit.actions.addEntry(
      widget.track.id,
      personId: e.personId,
      substanceId: e.substanceId,
      amount: e.amount ?? '',
      note: e.note ?? '',
    );
    if (edit.again != null) await edit.actions.haptics.tick();
    if (navigator.mounted) navigator.pop();
  }

  void _close() => Navigator.of(context).pop();

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final e = _e;
    final byPerson = ref.watch(personsByIdProvider);
    final bySubstance = ref.watch(substancesByIdProvider);
    final history =
        ref.watch(protocolEntryHistoryProvider(widget.track.id)).value ??
        const <TrackEvent>[];
    // The entry itself never suggests an amount (it is being typed).
    final others = [
      for (final h in history)
        if (h.id != e.id) h,
    ];
    final suggestions = recentAmounts(others, substanceId: e.substanceId);
    final amount = e.amount;
    final custom =
        _customAmount || (amount != null && !suggestions.contains(amount));

    final what = substanceLabel(e.substanceId, bySubstance);
    final who = personLabel(e.personId, byPerson);
    final title = what == null ? who : ProtocolStrings.editTitle(what, who);

    final gap = SizedBox(height: t.space.md);
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: t.sizes.sheetMaxWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            t.space.page,
            0,
            t.space.page,
            t.space.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ------------------------------------------------- head
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(title, style: t.text.sheetTitle),
                        ),
                        SizedBox(height: t.space.xxs),
                        _Subtitle(
                          entry: e,
                          fresh: widget.fresh,
                          history: others,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: t.space.sm),
                  HeaderRoundButton(
                    key: EntrySheetKeys.close,
                    icon: AdaptiveIcons.close(context),
                    label: Strings.close,
                    color: t.colors.background,
                    onPressed: _close,
                  ),
                ],
              ),
              gap,

              // ------------------------------------------------- when
              _Label(ProtocolStrings.when),
              if (widget.fresh) _freshTime(t, e) else _olderTime(t, e),
              gap,

              // --------------------------------------------- how much
              _Label(ProtocolStrings.howMuch),
              Wrap(
                spacing: t.space.xs,
                runSpacing: t.space.xs,
                children: [
                  for (final s in suggestions)
                    SheetChip(
                      key: EntrySheetKeys.amount(s),
                      label: s,
                      selected: amount == s && !_customAmount,
                      onTap: () => _chooseAmount(s),
                    ),
                  SheetChip(
                    key: EntrySheetKeys.amountOther,
                    label: ProtocolStrings.otherAmount,
                    selected: custom,
                    onTap: () {
                      _tick();
                      setState(() => _customAmount = !custom);
                    },
                  ),
                ],
              ),
              if (custom) ...[
                SizedBox(height: t.space.sm),
                TextField(
                  key: EntrySheetKeys.amountField,
                  controller: _amount,
                  autofocus: _customAmount,
                  style: t.text.headline,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: ProtocolStrings.otherAmountHint,
                  ),
                  onChanged: _typeAmount,
                ),
              ],
              gap,

              // ------------------------------------- who, what, note
              _Rows(
                children: [
                  _FoldRow(
                    key: EntrySheetKeys.rowPerson,
                    label: Strings.protocolWho,
                    value: who,
                    open: _open == _Row.person,
                    onToggle: () => _toggle(_Row.person),
                    child: _personChoices(t, e, byPerson),
                  ),
                  _FoldRow(
                    key: EntrySheetKeys.rowSubstance,
                    label: Strings.protocolWhat,
                    value: what ?? Strings.unknown,
                    open: _open == _Row.substance,
                    onToggle: () => _toggle(_Row.substance),
                    child: _substanceChoices(t, e, bySubstance),
                  ),
                  _FoldRow(
                    key: EntrySheetKeys.rowNote,
                    label: Strings.protocolNote,
                    value: e.note ?? ProtocolStrings.noNote,
                    open: _open == _Row.note,
                    onToggle: () => _toggle(_Row.note),
                    child: TextField(
                      key: EntrySheetKeys.note,
                      controller: _note,
                      autofocus: true,
                      minLines: 1,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: ProtocolStrings.noteHint,
                      ),
                      onChanged: _typeNote,
                    ),
                  ),
                ],
              ),
              gap,

              // ----------------------------------------------- bottom
              Row(
                children: [
                  _DeleteButton(onPressed: _busy ? null : _delete),
                  // The rest of the row; "Nochmal jetzt" sits at its end.
                  Expanded(
                    child: widget.fresh
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: PillButton(
                              key: EntrySheetKeys.again,
                              label: ProtocolStrings.againNow,
                              semanticLabel: ProtocolStrings.againNowSemantics,
                              outlined: true,
                              onPressed: _busy ? null : _again,
                            ),
                          ),
                  ),
                  SizedBox(width: t.space.sm),
                  PillButton(
                    key: EntrySheetKeys.done,
                    label: Strings.done,
                    onPressed: _close,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Jetzt · −5 · −10 · −30 min · a time of its own.
  Widget _freshTime(TikkyTokens t, TrackEvent e) {
    final back = _base - e.at;
    final picked = back != 0 && !_backMinutes.any((m) => back == m * 60 * 1000);
    return Semantics(
      container: true,
      label: Strings.protocolTime,
      child: Row(
        children: [
          Expanded(
            child: SheetChip(
              key: EntrySheetKeys.timeNow,
              tight: true,
              label: ProtocolStrings.timeNow,
              selected: back == 0,
              onTap: () => _setAt(_base),
            ),
          ),
          for (final m in _backMinutes) ...[
            SizedBox(width: t.space.xs),
            Expanded(
              child: SheetChip(
                key: EntrySheetKeys.timeBack(m),
                tight: true,
                label: ProtocolStrings.minutesBack(m),
                semanticLabel: ProtocolStrings.minutesBackSemantics(m),
                selected: back == m * 60 * 1000,
                onTap: () => _setAt(_base - m * 60 * 1000),
              ),
            ),
          ],
          SizedBox(width: t.space.xs),
          SheetChip(
            key: EntrySheetKeys.timePick,
            icon: ProtocolIcons.time(context),
            semanticLabel: ProtocolStrings.timePick,
            selected: picked,
            onTap: _pickTime,
          ),
        ],
      ),
    );
  }

  /// −5 · −1 · the time · +1 · +5.
  Widget _olderTime(TikkyTokens t, TrackEvent e) {
    Widget step(int m) => SizedBox(
      width: t.sizes.timeStep,
      child: SheetChip(
        key: EntrySheetKeys.timeStep(m),
        tight: true,
        label: ProtocolStrings.timeStep(m),
        semanticLabel: ProtocolStrings.timeStepSemantics(m),
        onTap: () => _setAt(_e.at + m * 60 * 1000),
      ),
    );
    final time = Fmt.time(e.at, use24h: t.prefs.use24h);
    return Row(
      children: [
        step(_steps[0]),
        SizedBox(width: t.space.xs),
        step(_steps[1]),
        Expanded(
          child: Semantics(
            button: true,
            label: '${ProtocolStrings.timePick}, $time',
            excludeSemantics: true,
            child: InkWell(
              key: EntrySheetKeys.timePick,
              borderRadius: t.radii.pillAll,
              onTap: _pickTime,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: t.sizes.minTapTarget),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(time, style: t.text.digitsLarge),
                  ),
                ),
              ),
            ),
          ),
        ),
        step(_steps[2]),
        SizedBox(width: t.space.xs),
        step(_steps[3]),
      ],
    );
  }

  Widget _personChoices(
    TikkyTokens t,
    TrackEvent e,
    Map<String, Person> byPerson,
  ) {
    final persons = [...ref.watch(personsProvider).value ?? const <Person>[]];
    // The entry may name someone who was removed from the list.
    final current = e.personId == null ? null : byPerson[e.personId];
    if (current != null && persons.every((p) => p.id != current.id)) {
      persons.add(current);
    }
    return _Choices(
      adding: _addingPerson,
      addKey: const ValueKey('add-person'),
      addLabel: ProtocolStrings.newPerson,
      field: ProtocolInlineAdd(
        key: const ValueKey('new-person'),
        controller: _newPerson,
        hint: ProtocolStrings.newPersonHint,
        onSubmit: _commitNewPerson,
        onCancel: () => setState(() {
          _newPerson.clear();
          _addingPerson = false;
        }),
      ),
      onAdd: () => setState(() => _addingPerson = true),
      chips: [
        for (final p in persons)
          SheetChip(
            key: ValueKey('person-${p.id}'),
            label: p.name,
            roles: t.roles(Color(p.color)),
            selected: p.id == e.personId,
            onTap: () => _choosePerson(p.id),
          ),
      ],
    );
  }

  Widget _substanceChoices(
    TikkyTokens t,
    TrackEvent e,
    Map<String, Substance> bySubstance,
  ) {
    final substances = [
      ...ref.watch(substancesProvider).value ?? const <Substance>[],
    ];
    final current = e.substanceId == null ? null : bySubstance[e.substanceId];
    if (current != null && substances.every((s) => s.id != current.id)) {
      substances.add(current);
    }
    return _Choices(
      adding: _addingSubstance,
      addKey: const ValueKey('add-substance'),
      addLabel: ProtocolStrings.newSubstance,
      field: ProtocolInlineAdd(
        key: const ValueKey('new-substance'),
        controller: _newSubstance,
        hint: ProtocolStrings.newSubstanceHint,
        onSubmit: _commitNewSubstance,
        onCancel: () => setState(() {
          _newSubstance.clear();
          _addingSubstance = false;
        }),
      ),
      onAdd: () => setState(() => _addingSubstance = true),
      chips: [
        for (final s in substances)
          SheetChip(
            key: ValueKey('substance-${s.id}'),
            label: s.name,
            roles: t.roles(Color(s.color)),
            selected: s.id == e.substanceId,
            onTap: () => _chooseSubstance(s.id),
          ),
      ],
    );
  }
}

/// "eben eingetragen · 23:41", or "Sa. 14.11. · 1 h nach dem vorherigen ·
/// vor 26 min".
class _Subtitle extends StatelessWidget {
  const _Subtitle({
    required this.entry,
    required this.fresh,
    required this.history,
  });

  final TrackEvent entry;
  final bool fresh;

  /// The other entries of the track, newest first.
  final List<TrackEvent> history;

  /// The person's entry of the same substance right before [entry].
  TrackEvent? get _previous {
    for (final h in history) {
      if (h.type != EventType.entry) continue;
      if (h.personId != entry.personId || h.substanceId != entry.substanceId) {
        continue;
      }
      if (h.at < entry.at) return h;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    if (fresh) {
      return Text(
        ProtocolStrings.justEntered(Fmt.time(entry.at, use24h: t.prefs.use24h)),
        style: t.text.caption,
      );
    }
    final previous = _previous;
    return CoarseNowBuilder(
      builder: (context, nowMs) => Text(
        [
          Fmt.dayShort(entry.at),
          if (previous != null)
            ProtocolStrings.afterPrevious(Fmt.coarse(entry.at - previous.at)),
          Fmt.ago(nowMs - entry.at),
        ].join(' · '),
        style: t.text.caption,
      ),
    );
  }
}

/// "Wann?", "Wie viel?"
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.sm),
      child: Text(text, style: t.text.caption),
    );
  }
}

/// A pill of 48 of a sheet: a time, an amount, a person, a substance.
///
/// Plain: the background with a hairline; chosen: the primary colour. With
/// [roles] the pill takes that colour: its tint, chosen its solid.
class SheetChip extends StatelessWidget {
  const SheetChip({
    required this.onTap,
    this.label,
    this.icon,
    this.selected = false,
    this.roles,
    this.semanticLabel,
    this.tight = false,
    super.key,
  }) : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final bool selected;
  final TrackRoles? roles;
  final String? semanticLabel;
  final VoidCallback? onTap;

  /// No padding at the sides: for chips of a given width (a row of times).
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final roles = this.roles;
    final Color fill;
    final Color foreground;
    final BorderSide side;
    if (roles != null) {
      fill = selected ? roles.solid : roles.tint;
      foreground = selected ? roles.on : t.colors.text;
      side = BorderSide.none;
    } else if (selected) {
      fill = t.colors.primary;
      foreground = t.colors.onPrimary;
      side = BorderSide.none;
    } else {
      fill = t.colors.background;
      foreground = t.colors.text;
      side = t.hairline;
    }
    final label = this.label;
    final icon = this.icon;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: t.radii.pillAll,
          side: side,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          splashFactory: isCupertino(context) ? NoSplash.splashFactory : null,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: t.sizes.minTapTarget,
              minWidth: t.sizes.minTapTarget,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: label == null || tight ? 0 : t.space.md,
              ),
              child: Center(
                widthFactor: 1,
                child: label == null
                    ? Icon(icon, size: t.sizes.iconSm, color: foreground)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          style: t.text.chip.copyWith(color: foreground),
                          maxLines: 1,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The box around the folded rows, with hairlines between them.
class _Rows extends StatelessWidget {
  const _Rows({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.colors.background,
        borderRadius: t.radii.smallAll,
        border: t.sizes.hairline > 0
            ? Border.all(color: t.colors.border, width: t.sizes.hairline)
            : null,
      ),
      child: ClipRRect(
        borderRadius: t.radii.smallAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: t.sizes.hairline,
                  thickness: t.sizes.hairline,
                  color: t.colors.border,
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// "Wer  Krille  ⌄": a row of 56 that unfolds into its [child].
class _FoldRow extends StatelessWidget {
  const _FoldRow({
    required this.label,
    required this.value,
    required this.open,
    required this.onToggle,
    required this.child,
    super.key,
  });

  final String label;
  final String value;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final chevron = Icon(
      AdaptiveIcons.chevronDown(context),
      size: t.sizes.iconSm,
      color: t.colors.text,
    );
    final head = Semantics(
      button: true,
      expanded: open,
      label: ProtocolStrings.rowSemantics(label, value, open: open),
      excludeSemantics: true,
      onTap: onToggle,
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: t.sizes.sheetRow),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.md),
            child: Row(
              children: [
                SizedBox(
                  width: t.sizes.minTapTarget,
                  child: Text(label, style: t.text.caption),
                ),
                SizedBox(width: t.space.md),
                Expanded(
                  child: Text(
                    value,
                    style: t.text.rowValue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (open)
                  RotatedBox(quarterTurns: 2, child: chevron)
                else
                  chevron,
              ],
            ),
          ),
        ),
      ),
    );
    if (!open) return head;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        Padding(
          padding: EdgeInsets.fromLTRB(t.space.md, 0, t.space.md, t.space.md),
          child: child,
        ),
      ],
    );
  }
}

/// The chips of an open row "Wer" / "Was" and a "+" for a new one.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.chips,
    required this.adding,
    required this.addKey,
    required this.addLabel,
    required this.field,
    required this.onAdd,
  });

  final List<Widget> chips;
  final bool adding;
  final Key addKey;
  final String addLabel;
  final Widget field;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: t.space.xs,
          runSpacing: t.space.xs,
          children: [
            ...chips,
            if (!adding)
              SheetChip(
                key: addKey,
                icon: AdaptiveIcons.add(context),
                semanticLabel: addLabel,
                onTap: onAdd,
              ),
          ],
        ),
        if (adding) field,
      ],
    );
  }
}

/// "Löschen" in the danger colour, as text.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Semantics(
      button: true,
      label: ProtocolStrings.deleteEntry,
      excludeSemantics: true,
      onTap: onPressed,
      child: InkWell(
        key: EntrySheetKeys.delete,
        borderRadius: t.radii.pillAll,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: t.sizes.minTapTarget,
            minWidth: t.sizes.minTapTarget,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.sm),
            child: Center(
              widthFactor: 1,
              child: Text(
                ProtocolStrings.delete,
                style: t.text.labelStrong.copyWith(color: t.colors.danger),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
