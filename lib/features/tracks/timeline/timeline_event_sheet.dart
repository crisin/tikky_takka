import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../adaptive/adaptive.dart';
import '../../../core/clock.dart';
import '../../../core/domain/domain.dart';
import '../../../core/repo/repo.dart';
import '../../../core/services/haptics.dart';
import '../../../l10n/formatters.dart';
import '../../../l10n/strings.dart';
import '../../../theme/theme.dart';
import '../../protocol/protocol_entry_sheet.dart';
import '../tracks_strings.dart';
import 'timeline_logic.dart';

/// Keys of the event editor (for tests).
abstract final class EventSheetKeys {
  static const time = ValueKey('event-time');
  static const earlier = ValueKey('event-earlier');
  static const later = ValueKey('event-later');
  static const pickTime = ValueKey('event-pick-time');
  static const note = ValueKey('event-note');
  static const lapLabel = ValueKey('event-lap-label');
  static const noLabel = ValueKey('event-label-none');
  static const save = ValueKey('event-save');
  static const delete = ValueKey('event-delete');

  static Key label(String label) => ValueKey('event-label-$label');
}

sealed class _SheetResult {
  const _SheetResult();
}

final class _Save extends _SheetResult {
  const _Save(this.event);

  final TrackEvent event;
}

final class _Delete extends _SheetResult {
  const _Delete();
}

/// Opens the editor for a row of the timeline.
///
/// * Protocol entries use the protocol feature's own entry sheet (who,
///   what, amount, note, time, delete).
/// * Everything else: time, label (a tick chooses among the track's quick
///   labels, a lap takes free text), note - and "Löschen" for everything
///   but start and stop, which define the session.
///
/// Nothing asks for confirmation; every change offers "Rückgängig".
Future<void> openTimelineEvent(
  BuildContext context,
  WidgetRef ref,
  TimelineRow row,
) async {
  final history = ref.read(historyRepositoryProvider);
  final haptics = ref.read(hapticsProvider);
  final event = row.event;
  unawaited(haptics.selection());
  if (event.type == EventType.entry) {
    await showProtocolEntrySheet(context, track: row.track, existing: event);
    return;
  }
  final result = await showAdaptiveSheet<_SheetResult>(
    context,
    builder: (context) => _EventSheet(row: row),
  );
  if (result == null) return;
  switch (result) {
    case _Save(event: final edited):
      if (edited == event) return;
      final ok = await history.updateEvent(edited);
      if (!ok || !context.mounted) return;
      showUndoSnackBar(
        context,
        message: TracksStrings.eventUpdated,
        onUndo: () => unawaited(history.updateEvent(event)),
      );
    case _Delete():
      if (!context.mounted) return;
      await deleteTimelineEvent(context, ref, event);
  }
}

/// Whether an event of the timeline can be deleted: everything but start
/// and stop, which define the session.
bool isTimelineEventDeletable(TrackEvent event) =>
    event.type != EventType.start && event.type != EventType.stop;

/// Deletes [event] without asking and offers "Rückgängig".
Future<void> deleteTimelineEvent(
  BuildContext context,
  WidgetRef ref,
  TrackEvent event,
) async {
  final history = ref.read(historyRepositoryProvider);
  unawaited(ref.read(hapticsProvider).heavy());
  final deleted = await history.deleteEvent(event.id);
  if (deleted == null || !context.mounted) return;
  showUndoSnackBar(
    context,
    message: Strings.eventDeleted,
    onUndo: () => unawaited(history.restoreEvent(deleted)),
  );
}

class _EventSheet extends ConsumerStatefulWidget {
  const _EventSheet({required this.row});

  final TimelineRow row;

  @override
  ConsumerState<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<_EventSheet> {
  static const int _minuteMs = 60 * 1000;

  late int _at = widget.row.event.at;
  late String? _label = widget.row.event.label;
  late final TextEditingController _note = TextEditingController(
    text: widget.row.event.note ?? '',
  );
  late final TextEditingController _lapLabel = TextEditingController(
    text: widget.row.event.label ?? '',
  );

  TrackEvent get _event => widget.row.event;

  bool get _isTick => _event.type == EventType.tick;
  bool get _isLap => _event.type == EventType.lap;

  /// Start and stop define the session and stay.
  bool get _deletable => isTimelineEventDeletable(_event);

  @override
  void dispose() {
    _note.dispose();
    _lapLabel.dispose();
    super.dispose();
  }

  static String? _blankToNull(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _save() {
    final label = _isLap ? _blankToNull(_lapLabel.text) : _label;
    Navigator.of(context).pop(
      _Save(
        _event.copyWith(
          at: _at,
          label: () => label,
          note: () => _blankToNull(_note.text),
        ),
      ),
    );
  }

  Future<void> _pickTime(bool use24h) async {
    final now = ref.read(clockProvider).nowMs();
    final current = DateTime.fromMillisecondsSinceEpoch(_at);
    final picked = await showAdaptiveDateTimePicker(
      context,
      initial: current,
      first: DateTime.fromMillisecondsSinceEpoch(
        now - 366 * 24 * 60 * _minuteMs,
      ),
      last: DateTime.fromMillisecondsSinceEpoch(now + 24 * 60 * _minuteMs),
      use24h: use24h,
      title: TracksStrings.eventPickTime,
    );
    if (picked == null || !mounted) return;
    setState(() {
      // The pickers know minutes; the seconds stay as they were.
      _at = DateTime(
        picked.year,
        picked.month,
        picked.day,
        picked.hour,
        picked.minute,
        current.second,
        current.millisecond,
      ).millisecondsSinceEpoch;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final row = widget.row;
    final use24h = t.prefs.use24h;
    final choices = _isTick
        ? tickLabelChoices(row.track, _label)
        : const <String>[];

    Widget section(String title) => Padding(
      padding: EdgeInsets.only(top: t.space.lg, bottom: t.space.xs),
      child: Semantics(
        header: true,
        child: Text(title, style: t.text.laneTitle),
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        t.space.page,
        t.space.sm,
        t.space.page,
        t.space.lg,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: t.sizes.sheetMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(TracksStrings.eventEditTitle, style: t.text.title),
              SizedBox(height: t.space.xs),
              Text(
                '${row.track.name}${TracksStrings.separator}${row.text}',
                style: t.text.bodyMuted,
              ),
              section(TracksStrings.eventTime),
              Text(
                '${Fmt.date(_at)}, '
                '${Fmt.time(_at, use24h: use24h, seconds: true)}',
                key: EventSheetKeys.time,
                style: t.text.digitsMedium,
              ),
              Wrap(
                spacing: t.space.sm,
                children: [
                  KeyedSubtree(
                    key: EventSheetKeys.earlier,
                    child: AdaptiveTextButton(
                      label: TracksStrings.eventMinuteEarlier,
                      onPressed: () => setState(() => _at -= _minuteMs),
                    ),
                  ),
                  KeyedSubtree(
                    key: EventSheetKeys.later,
                    child: AdaptiveTextButton(
                      label: TracksStrings.eventMinuteLater,
                      onPressed: () => setState(() => _at += _minuteMs),
                    ),
                  ),
                  KeyedSubtree(
                    key: EventSheetKeys.pickTime,
                    child: AdaptiveTextButton(
                      label: TracksStrings.eventPickTime,
                      onPressed: () => _pickTime(use24h),
                    ),
                  ),
                ],
              ),
              if (choices.isNotEmpty) ...[
                section(TracksStrings.eventLabel),
                Wrap(
                  spacing: t.space.sm,
                  runSpacing: t.space.xs,
                  children: [
                    for (final label in choices)
                      ChoiceChip(
                        key: EventSheetKeys.label(label),
                        label: Text(label),
                        selected: _label == label,
                        onSelected: (_) => setState(() => _label = label),
                      ),
                    ChoiceChip(
                      key: EventSheetKeys.noLabel,
                      label: const Text(TracksStrings.eventNoLabel),
                      selected: _label == null || _label!.isEmpty,
                      onSelected: (_) => setState(() => _label = null),
                    ),
                  ],
                ),
              ],
              if (_isLap) ...[
                section(TracksStrings.eventLabel),
                TextField(
                  key: EventSheetKeys.lapLabel,
                  controller: _lapLabel,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: TracksStrings.eventLabelHint,
                  ),
                ),
              ],
              section(Strings.note),
              TextField(
                key: EventSheetKeys.note,
                controller: _note,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: TracksStrings.eventNoteHint,
                ),
              ),
              SizedBox(height: t.space.lg),
              Row(
                children: [
                  if (_deletable)
                    KeyedSubtree(
                      key: EventSheetKeys.delete,
                      child: AdaptiveTextButton(
                        label: Strings.delete,
                        destructive: true,
                        onPressed: () =>
                            Navigator.of(context).pop(const _Delete()),
                      ),
                    ),
                  const Spacer(),
                  KeyedSubtree(
                    key: EventSheetKeys.save,
                    child: AdaptiveFilledButton(
                      label: Strings.save,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
