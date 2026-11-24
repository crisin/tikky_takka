import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../adaptive/adaptive.dart';
import '../../core/domain/domain.dart';
import '../../core/repo/providers.dart';
import '../../core/services/haptics.dart';
import '../../l10n/formatters.dart';
import '../../l10n/strings.dart';
import '../../theme/theme.dart';
import 'color_picker.dart';
import 'track_undo.dart';
import 'protocol_start.dart';
import 'tracks_strings.dart';

/// Keys of the editor's controls (for tests).
abstract final class TrackEditorKeys {
  static const name = ValueKey('track-editor-name');
  static const save = ValueKey('track-editor-save');
  static const mode = ValueKey('track-editor-mode');
  static const customColor = ValueKey('track-editor-custom-color');
  static const addLabel = ValueKey('track-editor-add-label');
  static const delete = ValueKey('track-editor-delete');
  static const archive = ValueKey('track-editor-archive');
  static const duplicate = ValueKey('track-editor-duplicate');
  static const move = ValueKey('track-editor-move');
  static const stop = ValueKey('track-editor-stop');
  static Key swatch(int index) => ValueKey('track-editor-swatch-$index');
}

/// What the editor did besides plain saving; the caller shows it as a
/// snackbar with "Rückgängig" once the sheet is closed.
class _EditorOutcome {
  const _EditorOutcome(this.message, this.undo);

  final String message;
  final Future<void> Function() undo;
}

/// Opens the track editor as a modal bottom sheet.
///
/// With [track] it edits that track (name, colour, mode, mode options,
/// alarm sound / vibration) and offers move, duplicate, archive and delete
/// - all without confirmation, each with an undo snackbar on [context].
/// Without [track] it creates a new one in the set [setId].
Future<void> showTrackEditorSheet(
  BuildContext context, {
  required String setId,
  Track? track,
}) async {
  final outcome = await showAdaptiveSheet<_EditorOutcome>(
    context,
    builder: (_) => TrackEditorSheet(setId: setId, track: track),
  );
  if (outcome == null || !context.mounted) return;
  showUndoSnackBar(
    context,
    message: outcome.message,
    onUndo: () => outcome.undo(),
  );
}

class TrackEditorSheet extends ConsumerStatefulWidget {
  const TrackEditorSheet({required this.setId, this.track, super.key});

  final String setId;
  final Track? track;

  @override
  ConsumerState<TrackEditorSheet> createState() => _TrackEditorSheetState();
}

class _TrackEditorSheetState extends ConsumerState<TrackEditorSheet> {
  static const int _second = 1000;
  static const int _minRounds = 1;
  static const int _maxRounds = 99;

  late final TextEditingController _name;
  late TrackMode _mode;

  /// One draft per mode, so switching back and forth keeps the values.
  late final Map<TrackMode, TrackConfig> _configs;
  late int _colorIndex;
  int? _customColor;
  late bool _alarmSound;
  late bool _vibration;
  bool _busy = false;

  bool get _isNew => widget.track == null;

  @override
  void initState() {
    super.initState();
    final track = widget.track;
    _name = TextEditingController(text: track?.name ?? '');
    _mode = track?.mode ?? TrackMode.stopwatch;
    _configs = {
      for (final mode in TrackMode.values) mode: TrackConfig.defaultFor(mode),
      if (track != null) track.mode: track.config,
    };
    _colorIndex =
        track?.colorIndex ??
        (ref.read(tracksInSetProvider(widget.setId)).value?.length ?? 0);
    _customColor = track?.customColor;
    _alarmSound = track?.alarmSound ?? true;
    _vibration = track?.vibration ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  T _config<T extends TrackConfig>() => _configs[_mode]! as T;

  void _setConfig(TrackConfig config) =>
      setState(() => _configs[config.mode] = config);

  String get _effectiveName {
    final name = _name.text.trim();
    return name.isEmpty ? Strings.modeName(_mode) : name;
  }

  // ----------------------------------------------------------- persistence

  /// Writes the draft. Returns the stored track.
  Future<Track?> _persist() async {
    final repo = ref.read(trackRepositoryProvider);
    final commands = ref.read(trackCommandsProvider);
    final config = _configs[_mode]!;
    final original = widget.track;
    if (original == null) {
      return repo.createTrack(
        setId: widget.setId,
        name: _effectiveName,
        config: config,
        colorIndex: _colorIndex,
        customColor: _customColor,
        alarmSound: _alarmSound,
        vibration: _vibration,
      );
    }
    final current = await repo.getTrack(original.id);
    if (current == null) return null;
    final custom = _customColor;
    final updated = current.copyWith(
      name: _effectiveName,
      config: config,
      colorIndex: _colorIndex,
      customColor: () => custom,
      alarmSound: _alarmSound,
      vibration: _vibration,
    );
    if (updated == current) return current;
    if (current.mode != updated.mode) {
      // A session cannot change its mode: the running one ends here and
      // stays in the history.
      await commands.stopTrack(current.id);
    }
    await repo.updateTrack(updated);
    return updated;
  }

  Future<void> _run(Future<_EditorOutcome?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final outcome = await action();
      if (mounted) Navigator.of(context).pop(outcome);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    await _persist();
    ref.read(hapticsProvider).selection();
    return null;
  });

  Future<void> _duplicate() => _run(() async {
    final repo = ref.read(trackRepositoryProvider);
    final saved = await _persist();
    if (saved == null) return null;
    final copy = await repo.duplicateTrack(
      saved.id,
      name: Strings.themeCopyName(saved.name),
    );
    if (copy == null) return null;
    return _EditorOutcome(
      TracksStrings.trackDuplicated,
      () => repo.deleteTrack(copy.id),
    );
  });

  Future<void> _archive() => _run(() async {
    final repo = ref.read(trackRepositoryProvider);
    final haptics = ref.read(hapticsProvider);
    final saved = await _persist();
    if (saved == null) return null;
    final commands = ref.read(trackCommandsProvider);
    // Archiving ends a running session; undo brings both back.
    final stoppedSessionId = await repo.setArchived(saved.id, archived: true);
    haptics.heavy();
    return _EditorOutcome(Strings.trackArchived, () async {
      await repo.setArchived(saved.id, archived: false);
      if (stoppedSessionId != null) {
        await commands.reopenSession(stoppedSessionId);
      }
    });
  });

  Future<void> _delete() => _run(() async {
    final track = widget.track;
    if (track == null) return null;
    final haptics = ref.read(hapticsProvider);
    final restore = await ref.read(trackUndoProvider).deleteTrack(track);
    haptics.heavy();
    return _EditorOutcome(Strings.trackDeleted, restore);
  });

  /// Ends the open run (E2: the way to stop a counter with labels, which
  /// has no primary button); "Rückgängig" brings it back.
  Future<void> _stopSession() => _run(() async {
    final track = widget.track;
    if (track == null) return null;
    final commands = ref.read(trackCommandsProvider);
    final before = await commands.resetTrack(track.id);
    if (before == null) return null;
    ref.read(hapticsProvider).heavy();
    return _EditorOutcome(
      Strings.sessionStopped,
      () => commands.reopenSession(before.session.id),
    );
  });

  Future<void> _move(List<TrackSet> others) async {
    final target = await showAdaptiveActionSheet<TrackSet>(
      context,
      title: Strings.moveToSet,
      actions: [
        for (final set in others)
          AdaptiveSheetAction(value: set, label: set.name),
      ],
    );
    if (target == null || !mounted) return;
    await _run(() async {
      final repo = ref.read(trackRepositoryProvider);
      final saved = await _persist();
      if (saved == null) return null;
      final oldSetId = saved.setId;
      final oldOrder = [
        for (final t in await repo.getTracks(oldSetId, includeArchived: true))
          t.id,
      ];
      await repo.moveTrackToSet(saved.id, target.id);
      return _EditorOutcome(TracksStrings.trackMovedTo(target.name), () async {
        await repo.moveTrackToSet(saved.id, oldSetId);
        await repo.reorderTracks(oldSetId, oldOrder);
      });
    });
  }

  // --------------------------------------------------------------- pickers

  Future<void> _pickMode() async {
    final mode = await showAdaptiveActionSheet<TrackMode>(
      context,
      title: Strings.trackMode,
      actions: [
        for (final m in TrackMode.values)
          // The protocol is not a track. Where a track is added it is
          // offered as the way to set it up.
          if (m != TrackMode.protocol || _isNew)
            AdaptiveSheetAction(
              value: m,
              label: Strings.modeName(m),
              selected: m == _mode,
            ),
      ],
    );
    if (mode == null || !mounted) return;
    if (mode == TrackMode.protocol) {
      final navigator = Navigator.of(context);
      navigator.pop();
      unawaited(startProtocol(navigator.context, setId: widget.setId));
      return;
    }
    ref.read(hapticsProvider).selection();
    setState(() => _mode = mode);
  }

  Future<void> _pickDuration({
    required String title,
    required int currentMs,
    required int minMs,
    required ValueChanged<int> onPicked,
  }) async {
    final picked = await showAdaptiveDurationPicker(
      context,
      initial: Duration(milliseconds: currentMs),
      title: title,
    );
    if (picked == null || !mounted) return;
    final ms = picked.inMilliseconds;
    onPicked(ms < minMs ? minMs : ms);
  }

  Future<void> _pickCustomColor(Color current) async {
    final color = await showCustomColorSheet(context, initial: current);
    if (color == null || !mounted) return;
    setState(() => _customColor = color.toARGB32());
  }

  Future<void> _addLabel() async {
    final label = await showAdaptiveTextPrompt(
      context,
      title: Strings.optAddLabel,
      hint: TracksStrings.labelName,
    );
    if (label == null || label.isEmpty || !mounted) return;
    final config = _config<CounterConfig>();
    if (config.labels.contains(label)) return;
    _setConfig(config.copyWith(labels: [...config.labels, label]));
  }

  // ----------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final palette = ref.watch(themeForSetProvider(widget.setId));
    final original = widget.track;
    final modeChanged = original != null && original.mode != _mode;
    final hasOpenSession =
        original != null && ref.watch(openSessionProvider(original.id)) != null;

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: t.sizes.sheetMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.sm),
              child: Row(
                children: [
                  AdaptiveTextButton(
                    label: Strings.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        _isNew ? Strings.newTrack : Strings.editTrack,
                        style: t.text.headline,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  AdaptiveFilledButton(
                    key: TrackEditorKeys.save,
                    label: _isNew ? TracksStrings.createTrack : Strings.save,
                    onPressed: _busy ? null : _save,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: t.space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        t.space.page,
                        t.space.md,
                        t.space.page,
                        0,
                      ),
                      child: _nameField(context),
                    ),
                    AdaptiveSection(
                      footer: modeChanged && hasOpenSession
                          ? TracksStrings.modeChangeStopsSession
                          : Strings.modeDescription(_mode),
                      children: [
                        AdaptiveTile(
                          key: TrackEditorKeys.mode,
                          title: Strings.trackMode,
                          value: Strings.modeName(_mode),
                          onTap: _pickMode,
                        ),
                      ],
                    ),
                    AdaptiveSection(
                      header: Strings.trackColor,
                      children: [_colorRow(context, palette)],
                    ),
                    ..._modeSections(context),
                    if (_mode.hasAlarms)
                      AdaptiveSection(
                        header: TracksStrings.sectionAlarm,
                        children: [
                          AdaptiveSwitchTile(
                            title: Strings.alarmSound,
                            value: _alarmSound,
                            onChanged: (v) => setState(() => _alarmSound = v),
                          ),
                          AdaptiveSwitchTile(
                            title: Strings.vibration,
                            value: _vibration,
                            onChanged: (v) => setState(() => _vibration = v),
                          ),
                        ],
                      ),
                    if (original != null) _manageSection(context, original),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nameField(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoTextField(
        key: TrackEditorKeys.name,
        controller: _name,
        placeholder: Strings.trackName,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        clearButtonMode: OverlayVisibilityMode.editing,
      );
    }
    return TextField(
      key: TrackEditorKeys.name,
      controller: _name,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        labelText: Strings.trackName,
        hintText: TracksStrings.trackNameHint,
      ),
    );
  }

  Widget _colorRow(BuildContext context, TikkyTheme theme) {
    final t = context.tikky;
    final colors = theme.trackPalette;
    final custom = _customColor;
    final selectedIndex = colors.isEmpty ? 0 : _colorIndex % colors.length;
    final current = custom != null
        ? Color(custom)
        : theme.paletteColor(_colorIndex);
    return Padding(
      padding: EdgeInsets.all(t.space.sm),
      child: Wrap(
        children: [
          for (var i = 0; i < colors.length; i++)
            _Swatch(
              key: TrackEditorKeys.swatch(i),
              color: colors[i],
              selected: custom == null && i == selectedIndex,
              label: TracksStrings.paletteColorN(i + 1),
              onTap: () => setState(() {
                _colorIndex = i;
                _customColor = null;
              }),
            ),
          _Swatch(
            key: TrackEditorKeys.customColor,
            color: custom == null ? null : Color(custom),
            selected: custom != null,
            label: Strings.customColor,
            icon: AdaptiveIcons.palette(context),
            onTap: () => _pickCustomColor(current),
          ),
        ],
      ),
    );
  }

  List<Widget> _modeSections(BuildContext context) {
    switch (_mode) {
      case TrackMode.stopwatch:
        final config = _config<StopwatchConfig>();
        return [
          AdaptiveSection(
            header: TracksStrings.sectionMode,
            footer: Strings.optExclusiveHint,
            children: [
              AdaptiveSwitchTile(
                title: Strings.optExclusive,
                value: config.exclusive,
                onChanged: (v) => _setConfig(config.copyWith(exclusive: v)),
              ),
            ],
          ),
        ];
      case TrackMode.countdown:
        final config = _config<CountdownConfig>();
        return [
          AdaptiveSection(
            header: TracksStrings.sectionMode,
            children: [
              AdaptiveTile(
                title: Strings.optDuration,
                value: Fmt.clock(config.durationMs),
                onTap: () => _pickDuration(
                  title: Strings.optDuration,
                  currentMs: config.durationMs,
                  minMs: _second,
                  onPicked: (ms) => _setConfig(config.copyWith(durationMs: ms)),
                ),
              ),
              AdaptiveSwitchTile(
                title: Strings.optAutoRestart,
                value: config.autoRestart,
                onChanged: (v) => _setConfig(config.copyWith(autoRestart: v)),
              ),
            ],
          ),
        ];
      case TrackMode.interval:
        final config = _config<IntervalConfig>();
        return [
          AdaptiveSection(
            header: TracksStrings.sectionMode,
            children: [
              AdaptiveTile(
                title: Strings.optWork,
                value: Fmt.clock(config.workMs),
                onTap: () => _pickDuration(
                  title: Strings.optWork,
                  currentMs: config.workMs,
                  minMs: _second,
                  onPicked: (ms) => _setConfig(config.copyWith(workMs: ms)),
                ),
              ),
              AdaptiveTile(
                title: Strings.optRest,
                value: config.restMs <= 0
                    ? TracksStrings.restOff
                    : Fmt.clock(config.restMs),
                onTap: () => _pickDuration(
                  title: Strings.optRest,
                  currentMs: config.restMs,
                  minMs: 0,
                  onPicked: (ms) => _setConfig(config.copyWith(restMs: ms)),
                ),
              ),
              _RoundsTile(
                rounds: config.rounds,
                onChanged: (rounds) => _setConfig(
                  config.copyWith(rounds: rounds.clamp(_minRounds, _maxRounds)),
                ),
                min: _minRounds,
                max: _maxRounds,
              ),
            ],
          ),
        ];
      case TrackMode.counter:
        final config = _config<CounterConfig>();
        return [
          AdaptiveSection(
            header: Strings.optLabels,
            footer: config.labels.isEmpty
                ? TracksStrings.noLabels
                : Strings.optLabelsHint,
            children: [
              _LabelsEditor(
                labels: config.labels,
                onAdd: _addLabel,
                onRemove: (label) => _setConfig(
                  config.copyWith(
                    labels: [
                      for (final l in config.labels)
                        if (l != label) l,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ];
      case TrackMode.reminder:
        final config = _config<ReminderConfig>();
        return [
          AdaptiveSection(
            header: TracksStrings.sectionMode,
            children: [
              AdaptiveTile(
                title: Strings.optInterval,
                value: Fmt.clock(config.intervalMs),
                onTap: () => _pickDuration(
                  title: Strings.optInterval,
                  currentMs: config.intervalMs,
                  minMs: _second,
                  onPicked: (ms) => _setConfig(config.copyWith(intervalMs: ms)),
                ),
              ),
              AdaptiveTile(
                title: Strings.optNagEvery,
                value: config.nagEveryMs <= 0
                    ? Strings.off
                    : Fmt.clock(config.nagEveryMs),
                onTap: () => _pickDuration(
                  title: Strings.optNagEvery,
                  currentMs: config.nagEveryMs,
                  minMs: 0,
                  onPicked: (ms) => _setConfig(config.copyWith(nagEveryMs: ms)),
                ),
              ),
            ],
          ),
        ];
      case TrackMode.protocol:
        return const [];
    }
  }

  Widget _manageSection(BuildContext context, Track track) {
    final others = [
      for (final set in ref.watch(setsProvider).value ?? const <TrackSet>[])
        if (set.id != track.setId) set,
    ];
    final running =
        track.mode != TrackMode.protocol &&
        ref.watch(openSessionProvider(track.id)) != null;
    return AdaptiveSection(
      header: TracksStrings.sectionManage,
      children: [
        if (running)
          AdaptiveTile(
            key: TrackEditorKeys.stop,
            title: TracksStrings.actionStopSession,
            leading: Icon(AdaptiveIcons.stop(context)),
            trailing: const SizedBox.shrink(),
            onTap: _busy ? null : _stopSession,
          ),
        AdaptiveTile(
          key: TrackEditorKeys.move,
          title: Strings.moveToSet,
          subtitle: others.isEmpty ? TracksStrings.noOtherSet : null,
          onTap: others.isEmpty || _busy ? null : () => _move(others),
        ),
        AdaptiveTile(
          key: TrackEditorKeys.duplicate,
          title: TracksStrings.duplicateTrack,
          leading: Icon(AdaptiveIcons.copy(context)),
          trailing: const SizedBox.shrink(),
          onTap: _busy ? null : _duplicate,
        ),
        AdaptiveTile(
          key: TrackEditorKeys.archive,
          title: Strings.archiveTrack,
          leading: Icon(AdaptiveIcons.archive(context)),
          trailing: const SizedBox.shrink(),
          onTap: _busy ? null : _archive,
        ),
        AdaptiveTile(
          key: TrackEditorKeys.delete,
          title: Strings.deleteTrack,
          destructive: true,
          onTap: _busy ? null : _delete,
        ),
      ],
    );
  }
}

/// A round colour swatch with a tap target of at least the minimum size.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.label,
    required this.onTap,
    this.icon,
    super.key,
  });

  /// `null` shows an empty swatch (no custom colour chosen yet).
  final Color? color;
  final bool selected;
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final fill = color ?? t.colors.surfaceAlt;
    final onFill = color == null ? t.colors.textMuted : t.onColor(fill);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: t.sizes.swatch,
          child: SizedBox.square(
            dimension: t.sizes.minTapTarget,
            child: Center(
              child: Container(
                width: t.sizes.swatch,
                height: t.sizes.swatch,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? t.colors.text : t.colors.border,
                    width: selected ? t.sizes.progressBar : t.sizes.hairline,
                  ),
                ),
                child: selected || icon != null
                    ? Icon(
                        selected ? AdaptiveIcons.check(context) : icon,
                        size: t.sizes.iconSm,
                        color: onFill,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Runden" with a minus / plus stepper.
class _RoundsTile extends StatelessWidget {
  const _RoundsTile({
    required this.rounds,
    required this.onChanged,
    required this.min,
    required this.max,
  });

  final int rounds;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return AdaptiveTile(
      title: Strings.optRounds,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AdaptiveIconButton(
            icon: Icons.remove_rounded,
            semanticLabel: TracksStrings.roundsFewer,
            onPressed: rounds > min ? () => onChanged(rounds - 1) : null,
          ),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: t.space.xl),
            child: Text(
              '$rounds',
              style: t.text.digitsMedium,
              textAlign: TextAlign.center,
            ),
          ),
          AdaptiveIconButton(
            icon: Icons.add_rounded,
            semanticLabel: TracksStrings.roundsMore,
            onPressed: rounds < max ? () => onChanged(rounds + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// Quick labels of a counter as removable chips plus an "add" chip.
class _LabelsEditor extends StatelessWidget {
  const _LabelsEditor({
    required this.labels,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> labels;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Padding(
      padding: EdgeInsets.all(t.space.md),
      child: Wrap(
        spacing: t.space.sm,
        runSpacing: t.space.sm,
        children: [
          for (final label in labels)
            InputChip(
              label: Text(label),
              onDeleted: () => onRemove(label),
              deleteIcon: Icon(
                AdaptiveIcons.close(context),
                size: t.sizes.iconSm,
              ),
              deleteButtonTooltipMessage: TracksStrings.removeLabel(label),
            ),
          ActionChip(
            key: TrackEditorKeys.addLabel,
            avatar: Icon(AdaptiveIcons.add(context), size: t.sizes.iconSm),
            label: const Text(Strings.optAddLabel),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
