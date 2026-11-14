import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/domain/domain.dart';
import '../../core/repo/providers.dart';
import '../../core/services/haptics.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'protocol_logic.dart';
import 'protocol_strings.dart';
import 'protocol_widgets.dart';

/// Opens the scene editor of a set: "Wer ist dabei?" and "Was ist heute
/// dran?".
///
/// A scene is not an entity of its own; it is two lists of ids on the set
/// (`TrackSet.scenePersonIds` / `sceneSubstanceIds`). Every tap is stored
/// right away, there is no save button. The substances keep the order in
/// which they were chosen; that is the order of the one-tap buttons.
///
/// The scene only decides what is shown first on the protocol lanes of the
/// set. It carries no amounts, intervals or rules of any kind.
Future<void> showSceneEditor(BuildContext context, {required String setId}) {
  return showAdaptiveSheet<void>(
    context,
    builder: (_) => _SceneSheet(setId: setId),
  );
}

class _SceneSheet extends StatelessWidget {
  const _SceneSheet({required this.setId});

  final String setId;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
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
                child: SceneEditor(setId: setId),
              ),
            ),
            SceneDoneButton(onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

/// The "Fertig" button at the bottom of a scene sheet.
class SceneDoneButton extends StatelessWidget {
  const SceneDoneButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.page,
        t.space.sm,
        t.space.page,
        t.space.lg,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: t.sizes.bigTapTarget),
        child: AdaptiveFilledButton(
          key: const ValueKey('scene-done'),
          label: Strings.done,
          icon: AdaptiveIcons.check(context),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// The scene of a set: "Wer ist dabei?" and "Was ist dran?" as chips. Used
/// in its own sheet and in "Sets und Szene".
class SceneEditor extends ConsumerStatefulWidget {
  const SceneEditor({required this.setId, super.key});

  final String setId;

  @override
  ConsumerState<SceneEditor> createState() => _SceneEditorState();
}

class _SceneEditorState extends ConsumerState<SceneEditor> {
  final _newPerson = TextEditingController();
  final _newSubstance = TextEditingController();

  /// Working copy: changed synchronously, stored right after. `null` until
  /// the set has loaded.
  List<String>? _personIds;
  List<String>? _substanceIds;

  bool _addingPerson = false;
  bool _addingSubstance = false;

  /// Writes are chained so they reach the database in the order of the
  /// taps.
  Future<void> _writes = Future.value();

  @override
  void dispose() {
    _newPerson.dispose();
    _newSubstance.dispose();
    super.dispose();
  }

  void _store() {
    final sets = ref.read(setRepositoryProvider);
    final persons = [...?_personIds];
    final substances = [...?_substanceIds];
    _writes = _writes.then(
      (_) => sets.updateScene(
        widget.setId,
        personIds: persons,
        substanceIds: substances,
      ),
    );
  }

  void _toggle(List<String> ids, String id) {
    ref.read(hapticsProvider).selection();
    setState(() {
      if (!ids.remove(id)) ids.add(id);
    });
    _store();
  }

  void _clear() {
    ref.read(hapticsProvider).heavy();
    setState(() {
      _personIds = [];
      _substanceIds = [];
    });
    _store();
  }

  Future<void> _commitNewPerson() async {
    final actions = ref.read(protocolActionsProvider);
    final count = ref.read(allPersonsProvider).value?.length ?? 0;
    final color = context.tikky.paletteColor(count).toARGB32();
    final person = await actions.ensurePerson(_newPerson.text, color: color);
    _newPerson.clear();
    if (!mounted) return;
    setState(() {
      _addingPerson = false;
      final ids = _personIds;
      if (person != null && ids != null && !ids.contains(person.id)) {
        ids.add(person.id);
      }
    });
    if (person != null) _store();
  }

  Future<void> _commitNewSubstance() async {
    final actions = ref.read(protocolActionsProvider);
    final count = ref.read(allSubstancesProvider).value?.length ?? 0;
    final color = context.tikky.paletteColor(count).toARGB32();
    final substance = await actions.ensureSubstance(
      _newSubstance.text,
      color: color,
    );
    _newSubstance.clear();
    if (!mounted) return;
    setState(() {
      _addingSubstance = false;
      final ids = _substanceIds;
      if (substance != null && ids != null && !ids.contains(substance.id)) {
        ids.add(substance.id);
      }
    });
    if (substance != null) _store();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final set = ref.watch(setProvider(widget.setId));
    if (set != null) {
      _personIds ??= [...set.scenePersonIds];
      _substanceIds ??= [...set.sceneSubstanceIds];
    }
    final personIds = _personIds;
    final substanceIds = _substanceIds;
    final persons = ref.watch(personsProvider).value ?? const <Person>[];
    final substances =
        ref.watch(substancesProvider).value ?? const <Substance>[];
    final ready = personIds != null && substanceIds != null;
    // Ids of removed persons / substances stay stored but do not count.
    final shownSubstances = !ready
        ? const <String>[]
        : [
            for (final id in substanceIds)
              if (substances.any((s) => s.id == id)) id,
          ];
    final hasScene = ready && (personIds.isNotEmpty || substanceIds.isNotEmpty);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            set == null
                ? ProtocolStrings.scene
                : ProtocolStrings.sceneOf(set.name),
            style: t.text.title,
          ),
        ),
        SizedBox(height: t.space.xs),
        Text(ProtocolStrings.sceneHint, style: t.text.caption),

        // ---------------------------------------------- who
        const ProtocolSectionLabel(ProtocolStrings.sceneWho),
        Wrap(
          spacing: t.space.sm,
          runSpacing: t.space.sm,
          children: [
            if (ready)
              for (final p in persons)
                ProtocolChoice(
                  key: ValueKey('scene-person-${p.id}'),
                  label: p.name,
                  color: Color(p.color),
                  selected: personIds.contains(p.id),
                  onTap: () => _toggle(personIds, p.id),
                ),
            if (ready && !_addingPerson)
              ProtocolChoice(
                key: const ValueKey('scene-add-person'),
                label: ProtocolStrings.addPersonShort,
                semanticLabel: Strings.protocolAddPerson,
                icon: AdaptiveIcons.add(context),
                onTap: () => setState(() => _addingPerson = true),
              ),
          ],
        ),
        if (_addingPerson)
          ProtocolInlineAdd(
            key: const ValueKey('scene-new-person'),
            controller: _newPerson,
            hint: ProtocolStrings.newPersonHint,
            onSubmit: _commitNewPerson,
            onCancel: () => setState(() {
              _newPerson.clear();
              _addingPerson = false;
            }),
          ),

        // --------------------------------------------- what
        const ProtocolSectionLabel(ProtocolStrings.sceneWhat),
        Wrap(
          spacing: t.space.sm,
          runSpacing: t.space.sm,
          children: [
            if (ready)
              for (final s in substances)
                ProtocolChoice(
                  key: ValueKey('scene-substance-${s.id}'),
                  label: shownSubstances.contains(s.id)
                      ? ProtocolStrings.sceneOrdered(
                          shownSubstances.indexOf(s.id) + 1,
                          s.name,
                        )
                      : s.name,
                  color: Color(s.color),
                  selected: substanceIds.contains(s.id),
                  onTap: () => _toggle(substanceIds, s.id),
                ),
            if (ready && !_addingSubstance)
              ProtocolChoice(
                key: const ValueKey('scene-add-substance'),
                label: ProtocolStrings.addSubstanceShort,
                semanticLabel: Strings.protocolAddSubstance,
                icon: AdaptiveIcons.add(context),
                onTap: () => setState(() => _addingSubstance = true),
              ),
          ],
        ),
        if (_addingSubstance)
          ProtocolInlineAdd(
            key: const ValueKey('scene-new-substance'),
            controller: _newSubstance,
            hint: ProtocolStrings.newSubstanceHint,
            onSubmit: _commitNewSubstance,
            onCancel: () => setState(() {
              _newSubstance.clear();
              _addingSubstance = false;
            }),
          ),
        SizedBox(height: t.space.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AdaptiveTextButton(
            key: const ValueKey('scene-clear'),
            label: ProtocolStrings.sceneClear,
            destructive: true,
            onPressed: hasScene ? _clear : null,
          ),
        ),
      ],
    );
  }
}
