import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/domain/domain.dart';
import '../../core/repo/repo.dart';
import '../../l10n/formatters.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'protocol_strings.dart';
import 'protocol_widgets.dart';

/// The two lists managed on [ProtocolPeopleScreen].
enum ProtocolPeopleTab { persons, substances }

/// Opens the management screen for persons and substances.
Future<void> openProtocolPeople(
  BuildContext context, {
  ProtocolPeopleTab tab = ProtocolPeopleTab.persons,
}) => pushAdaptivePage<void>(
  context,
  builder: (_) => ProtocolPeopleScreen(initialTab: tab),
);

/// A settings row that opens [ProtocolPeopleScreen]. Place it inside an
/// `AdaptiveSection`.
class ProtocolPeopleTile extends StatelessWidget {
  const ProtocolPeopleTile({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return AdaptiveTile(
      title: ProtocolStrings.peopleTitle,
      leading: Icon(
        AdaptiveIcons.person(context),
        size: t.sizes.iconMd,
        color: t.colors.textMuted,
      ),
      onTap: () => openProtocolPeople(context),
    );
  }
}

/// Management of the user's own persons and substances: name, colour, and
/// for substances an optional lockout ("frühestens wieder in ...").
///
/// Both lists start empty. The lockout is only ever a value the user picked
/// here; the app has no defaults, presets or advice of any kind.
class ProtocolPeopleScreen extends ConsumerStatefulWidget {
  const ProtocolPeopleScreen({
    this.initialTab = ProtocolPeopleTab.persons,
    super.key,
  });

  final ProtocolPeopleTab initialTab;

  @override
  ConsumerState<ProtocolPeopleScreen> createState() =>
      _ProtocolPeopleScreenState();
}

class _ProtocolPeopleScreenState extends ConsumerState<ProtocolPeopleScreen> {
  late ProtocolPeopleTab _tab = widget.initialTab;

  bool get _persons => _tab == ProtocolPeopleTab.persons;

  void _add() =>
      _persons ? showPersonEditor(context) : showSubstanceEditor(context);

  // -------------------------------------------------------------- persons

  Future<void> _restorePerson(Person person) => ref
      .read(peopleRepositoryProvider)
      .setPersonArchived(person.id, archived: false);

  Future<void> _deletePerson(Person person) async {
    final people = ref.read(peopleRepositoryProvider);
    final deleted = await people.deletePerson(person.id);
    if (deleted == null || !mounted) return;
    showUndoSnackBar(
      context,
      message: ProtocolStrings.personDeleted,
      onUndo: () => people.restorePerson(deleted),
    );
  }

  // ----------------------------------------------------------- substances

  Future<void> _restoreSubstance(Substance substance) => ref
      .read(peopleRepositoryProvider)
      .setSubstanceArchived(substance.id, archived: false);

  Future<void> _deleteSubstance(Substance substance) async {
    final people = ref.read(peopleRepositoryProvider);
    final deleted = await people.deleteSubstance(substance.id);
    if (deleted == null || !mounted) return;
    showUndoSnackBar(
      context,
      message: ProtocolStrings.substanceDeleted,
      onUndo: () => people.restoreSubstance(deleted),
    );
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final persons = ref.watch(allPersonsProvider).value ?? const <Person>[];
    final substances =
        ref.watch(allSubstancesProvider).value ?? const <Substance>[];

    final List<Widget> active;
    final List<Widget> removed;
    if (_persons) {
      active = [
        for (final p in persons)
          if (!p.archived)
            AdaptiveTile(
              key: ValueKey('person-${p.id}'),
              title: p.name,
              subtitle: p.note,
              leading: ColorDot(color: Color(p.color), size: t.sizes.swatch),
              onTap: () => showPersonEditor(context, person: p),
            ),
      ];
      removed = [
        for (final p in persons)
          if (p.archived)
            _RemovedTile(
              key: ValueKey('removed-person-${p.id}'),
              name: p.name,
              color: Color(p.color),
              onRestore: () => _restorePerson(p),
              onDelete: () => _deletePerson(p),
            ),
      ];
    } else {
      active = [
        for (final s in substances)
          if (!s.archived)
            AdaptiveTile(
              key: ValueKey('substance-${s.id}'),
              title: s.name,
              subtitle: s.lockoutMs == null
                  ? s.note
                  : '${Strings.lockout} ${Fmt.compact(s.lockoutMs!)}',
              leading: ColorDot(color: Color(s.color), size: t.sizes.swatch),
              onTap: () => showSubstanceEditor(context, substance: s),
            ),
      ];
      removed = [
        for (final s in substances)
          if (s.archived)
            _RemovedTile(
              key: ValueKey('removed-substance-${s.id}'),
              name: s.name,
              color: Color(s.color),
              onRestore: () => _restoreSubstance(s),
              onDelete: () => _deleteSubstance(s),
            ),
      ];
    }

    final addLabel = _persons
        ? ProtocolStrings.newPerson
        : ProtocolStrings.newSubstance;

    return AdaptivePageScaffold(
      title: const Text(ProtocolStrings.peopleTitle),
      actions: [
        AdaptiveIconButton(
          icon: AdaptiveIcons.add(context),
          semanticLabel: addLabel,
          onPressed: _add,
        ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: t.sizes.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space.page,
                  t.space.md,
                  t.space.page,
                  t.space.xs,
                ),
                child: AdaptiveSegmented<ProtocolPeopleTab>(
                  segments: const {
                    ProtocolPeopleTab.persons: Strings.persons,
                    ProtocolPeopleTab.substances: Strings.substances,
                  },
                  selected: _tab,
                  onChanged: (tab) => setState(() => _tab = tab),
                ),
              ),
              Expanded(
                child: active.isEmpty && removed.isEmpty
                    ? AdaptiveEmptyState(
                        icon: _persons
                            ? AdaptiveIcons.person(context)
                            : ProtocolIcons.substance(context),
                        title: _persons
                            ? ProtocolStrings.personsEmptyTitle
                            : ProtocolStrings.substancesEmptyTitle,
                        message: _persons
                            ? ProtocolStrings.personsEmptyBody
                            : ProtocolStrings.substancesEmptyBody,
                        action: AdaptiveFilledButton(
                          label: addLabel,
                          icon: AdaptiveIcons.add(context),
                          onPressed: _add,
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.only(bottom: t.space.xl),
                        children: [
                          AdaptiveSection(
                            children: [
                              ...active,
                              AdaptiveTile(
                                key: const ValueKey('add-row'),
                                title: addLabel,
                                leading: Icon(
                                  AdaptiveIcons.add(context),
                                  size: t.sizes.iconMd,
                                  color: t.colors.primary,
                                ),
                                trailing: const SizedBox.shrink(),
                                onTap: _add,
                              ),
                            ],
                          ),
                          if (removed.isNotEmpty)
                            AdaptiveSection(
                              header: ProtocolStrings.removedSection,
                              footer: ProtocolStrings.removedHint,
                              children: removed,
                            ),
                        ],
                      ),
              ),
              const ProtocolNeutralNote(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A person or substance that was removed from the pick lists.
class _RemovedTile extends StatelessWidget {
  const _RemovedTile({
    required this.name,
    required this.color,
    required this.onRestore,
    required this.onDelete,
    super.key,
  });

  final String name;
  final Color color;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return AdaptiveTile(
      title: name,
      leading: ColorDot(color: color, size: t.sizes.swatch),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdaptiveIconButton(
            icon: AdaptiveIcons.undo(context),
            semanticLabel: Strings.restore,
            onPressed: onRestore,
          ),
          AdaptiveIconButton(
            icon: AdaptiveIcons.delete(context),
            semanticLabel: ProtocolStrings.deleteForever,
            color: t.colors.danger,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ editors

/// Opens the editor sheet for a new ([person] `null`) or existing person.
/// Returns the saved person, or `null` when dismissed or removed.
Future<Person?> showPersonEditor(BuildContext context, {Person? person}) async {
  final people = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(peopleRepositoryProvider);
  final result = await showAdaptiveSheet<_EditorResult>(
    context,
    builder: (_) => _EditorSheet(
      isSubstance: false,
      id: person?.id,
      name: person?.name ?? '',
      color: person?.color,
      note: person?.note,
    ),
  );
  if (result == null) return null;
  if (result.removed) {
    final id = person!.id;
    await people.setPersonArchived(id, archived: true);
    if (context.mounted) {
      showUndoSnackBar(
        context,
        message: ProtocolStrings.personRemoved,
        onUndo: () => people.setPersonArchived(id, archived: false),
      );
    }
    return null;
  }
  if (person == null) {
    return people.createPerson(
      name: result.name,
      color: result.color,
      note: result.note,
    );
  }
  final updated = person.copyWith(
    name: result.name,
    color: result.color,
    note: () => result.note,
  );
  await people.updatePerson(updated);
  return updated;
}

/// Opens the editor sheet for a new ([substance] `null`) or existing
/// substance. The lockout starts empty and is only what the user picks.
Future<Substance?> showSubstanceEditor(
  BuildContext context, {
  Substance? substance,
}) async {
  final people = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(peopleRepositoryProvider);
  final result = await showAdaptiveSheet<_EditorResult>(
    context,
    builder: (_) => _EditorSheet(
      isSubstance: true,
      id: substance?.id,
      name: substance?.name ?? '',
      color: substance?.color,
      note: substance?.note,
      lockoutMs: substance?.lockoutMs,
    ),
  );
  if (result == null) return null;
  if (result.removed) {
    final id = substance!.id;
    await people.setSubstanceArchived(id, archived: true);
    if (context.mounted) {
      showUndoSnackBar(
        context,
        message: ProtocolStrings.substanceRemoved,
        onUndo: () => people.setSubstanceArchived(id, archived: false),
      );
    }
    return null;
  }
  if (substance == null) {
    return people.createSubstance(
      name: result.name,
      color: result.color,
      lockoutMs: result.lockoutMs,
      note: result.note,
    );
  }
  final updated = substance.copyWith(
    name: result.name,
    color: result.color,
    lockoutMs: () => result.lockoutMs,
    note: () => result.note,
  );
  await people.updateSubstance(updated);
  return updated;
}

final class _EditorResult {
  const _EditorResult({
    required this.name,
    required this.color,
    this.note,
    this.lockoutMs,
  }) : removed = false;

  const _EditorResult.removed()
    : name = '',
      color = 0,
      note = null,
      lockoutMs = null,
      removed = true;

  final String name;
  final int color;
  final String? note;
  final int? lockoutMs;
  final bool removed;
}

class _EditorSheet extends ConsumerStatefulWidget {
  const _EditorSheet({
    required this.isSubstance,
    required this.id,
    required this.name,
    required this.color,
    required this.note,
    this.lockoutMs,
  });

  final bool isSubstance;

  /// `null` for a new person / substance.
  final String? id;
  final String name;
  final int? color;
  final String? note;
  final int? lockoutMs;

  @override
  ConsumerState<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends ConsumerState<_EditorSheet> {
  late final _name = TextEditingController(text: widget.name);
  late final _note = TextEditingController(text: widget.note ?? '');
  int? _color;
  late int? _lockoutMs = widget.lockoutMs;

  @override
  void initState() {
    super.initState();
    _color = widget.color;
    _name.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _name
      ..removeListener(_onChanged)
      ..dispose();
    _note.dispose();
    super.dispose();
  }

  /// A new entry gets the next palette colour until the user picks one.
  int _effectiveColor(BuildContext context) {
    final picked = _color;
    if (picked != null) return picked;
    final count = widget.isSubstance
        ? (ref.read(allSubstancesProvider).value ?? const []).length
        : (ref.read(allPersonsProvider).value ?? const []).length;
    return context.tikky.paletteColor(count).toARGB32();
  }

  Future<void> _pickLockout() async {
    final picked = await showAdaptiveDurationPicker(
      context,
      // Starts at zero: the app has no value of its own to offer.
      initial: Duration(milliseconds: _lockoutMs ?? 0),
      title: Strings.lockout,
      showSeconds: false,
    );
    if (picked == null || !mounted) return;
    setState(
      () =>
          _lockoutMs = picked.inMilliseconds > 0 ? picked.inMilliseconds : null,
    );
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final note = _note.text.trim();
    Navigator.of(context).pop(
      _EditorResult(
        name: name,
        color: _effectiveColor(context),
        note: note.isEmpty ? null : note,
        lockoutMs: widget.isSubstance ? _lockoutMs : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final isNew = widget.id == null;
    final title = widget.isSubstance
        ? (isNew ? ProtocolStrings.newSubstance : ProtocolStrings.editSubstance)
        : (isNew ? ProtocolStrings.newPerson : ProtocolStrings.editPerson);
    final lockoutMs = _lockoutMs;

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
              Semantics(header: true, child: Text(title, style: t.text.title)),
              ProtocolSectionLabel(
                widget.isSubstance ? Strings.substanceName : Strings.personName,
              ),
              TextField(
                key: const ValueKey('editor-name'),
                controller: _name,
                autofocus: isNew,
                style: t.text.headline,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const ProtocolSectionLabel(Strings.color),
              ProtocolColorPicker(
                selected: _effectiveColor(context),
                onChanged: (color) => setState(() => _color = color),
              ),
              if (widget.isSubstance) ...[
                const ProtocolSectionLabel(
                  Strings.lockout,
                  trailing: ProtocolStrings.optional,
                ),
                Wrap(
                  spacing: t.space.sm,
                  runSpacing: t.space.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ProtocolChoice(
                      key: const ValueKey('lockout-pick'),
                      label: lockoutMs == null
                          ? Strings.lockoutNone
                          : Fmt.compact(lockoutMs),
                      semanticLabel: ProtocolStrings.lockoutSet,
                      icon: ProtocolIcons.time(context),
                      big: false,
                      onTap: _pickLockout,
                    ),
                    if (lockoutMs != null)
                      AdaptiveTextButton(
                        label: ProtocolStrings.lockoutClear,
                        onPressed: () => setState(() => _lockoutMs = null),
                      ),
                  ],
                ),
                SizedBox(height: t.space.sm),
                Text(Strings.lockoutHint, style: t.text.caption),
              ],
              const ProtocolSectionLabel(
                Strings.note,
                trailing: ProtocolStrings.optional,
              ),
              TextField(
                key: const ValueKey('editor-note'),
                controller: _note,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: ProtocolStrings.noteHint,
                ),
              ),
              SizedBox(height: t.space.lg),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: t.sizes.bigTapTarget),
                child: AdaptiveFilledButton(
                  key: const ValueKey('editor-save'),
                  label: Strings.save,
                  icon: AdaptiveIcons.check(context),
                  onPressed: _name.text.trim().isEmpty ? null : _save,
                ),
              ),
              if (!isNew) ...[
                SizedBox(height: t.space.xs),
                AdaptiveTextButton(
                  label: ProtocolStrings.remove,
                  destructive: true,
                  onPressed: () =>
                      Navigator.of(context).pop(const _EditorResult.removed()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
