import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../adaptive/adaptive.dart';
import '../../../../core/clock.dart';
import '../../../../l10n/formatters.dart';
import '../../../../l10n/strings.dart';
import '../../../../theme/theme.dart';
import '../../../protocol/protocol_logic.dart';
import '../../tracks_strings.dart';
import '../timeline_event_sheet.dart';
import 'strip_model.dart';

/// Keys of the small sheets of the strip (for tests).
abstract final class StripDetailKeys {
  static const event = ValueKey('strip-detail');
  static const edit = ValueKey('strip-detail-edit');
  static const delete = ValueKey('strip-detail-delete');
  static const session = ValueKey('strip-session');
  static const sincePrevious = ValueKey('strip-detail-since-previous');
}

enum _DetailAction { edit, delete }

/// "frühestens wieder in ..." for an entry whose substance carries a
/// lockout the USER set, while that lockout still runs at [nowMs];
/// otherwise `null`. Nothing is added to the existing wording.
String? stripLockoutText(StripEvent event, int nowMs) {
  final until = event.lockoutUntil;
  if (until == null || until <= nowMs) return null;
  return Strings.lockoutRemaining(formatRemaining(until - nowMs));
}

/// What a tap on a marker opens: when it was, what happened (the wording
/// of the list), and the way on - "Bearbeiten" opens the editor of the
/// timeline (protocol entries: the entry sheet), "Löschen" deletes with
/// "Rückgängig".
Future<void> showStripEventDetail(
  BuildContext context,
  WidgetRef ref,
  StripEvent event,
) async {
  final nowMs = ref.read(clockProvider).nowMs();
  final action = await showAdaptiveSheet<_DetailAction>(
    context,
    builder: (context) => _EventDetail(event: event, nowMs: nowMs),
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _DetailAction.edit:
      await openTimelineEvent(context, ref, event.row);
    case _DetailAction.delete:
      await deleteTimelineEvent(context, ref, event.row.event);
  }
}

class _EventDetail extends StatelessWidget {
  const _EventDetail({required this.event, required this.nowMs});

  final StripEvent event;
  final int nowMs;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final row = event.row;
    final note = row.note;
    final lockout = stripLockoutText(event, nowMs);
    final previous = event.previousAt;
    return SingleChildScrollView(
      key: StripDetailKeys.event,
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
              Text(row.track.name, style: t.text.laneTitle),
              SizedBox(height: t.space.xs),
              Text(row.text, style: t.text.title),
              SizedBox(height: t.space.xs),
              Text(
                '${Fmt.date(row.at)}, '
                '${Fmt.time(row.at, use24h: t.prefs.use24h, seconds: true)}',
                style: t.text.digitsSmall,
              ),
              if (previous != null) ...[
                SizedBox(height: t.space.sm),
                Text(
                  TracksStrings.stripSincePrevious(
                    Fmt.compact(row.at - previous),
                  ),
                  key: StripDetailKeys.sincePrevious,
                  style: t.text.body,
                ),
              ],
              if (note != null && note.isNotEmpty) ...[
                SizedBox(height: t.space.sm),
                Text(note, style: t.text.body),
              ],
              if (lockout != null) ...[
                SizedBox(height: t.space.sm),
                Text(lockout, style: t.text.bodyMuted),
              ],
              SizedBox(height: t.space.lg),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: t.space.sm,
                children: [
                  if (isTimelineEventDeletable(row.event))
                    KeyedSubtree(
                      key: StripDetailKeys.delete,
                      child: AdaptiveTextButton(
                        label: Strings.delete,
                        destructive: true,
                        onPressed: () =>
                            Navigator.of(context).pop(_DetailAction.delete),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  KeyedSubtree(
                    key: StripDetailKeys.edit,
                    child: AdaptiveFilledButton(
                      label: Strings.edit,
                      onPressed: () =>
                          Navigator.of(context).pop(_DetailAction.edit),
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

/// What a tap on a session bar opens: start, end, net duration and the
/// sum of the pauses, as they stand at [nowMs].
Future<void> showStripSessionInfo(
  BuildContext context,
  StripSession session, {
  required int nowMs,
}) => showAdaptiveSheet<void>(
  context,
  builder: (context) => _SessionInfo(session: session, nowMs: nowMs),
);

class _SessionInfo extends StatelessWidget {
  const _SessionInfo({required this.session, required this.nowMs});

  final StripSession session;
  final int nowMs;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final use24h = t.prefs.use24h;
    String stamp(int ms) =>
        '${Fmt.date(ms)}, ${Fmt.time(ms, use24h: use24h, seconds: true)}';
    final end = session.endAt;

    Widget line(String label, String value) => Padding(
      padding: EdgeInsets.only(top: t.space.xs),
      child: MergeSemantics(
        child: Row(
          children: [
            Expanded(child: Text(label, style: t.text.bodyMuted)),
            SizedBox(width: t.space.md),
            Text(value, style: t.text.digitsSmall),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      key: StripDetailKeys.session,
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
              Text(
                session.source.track?.name ?? Strings.deletedTrack,
                style: t.text.laneTitle,
              ),
              SizedBox(height: t.space.xs),
              Text(TracksStrings.stripSessionTitle, style: t.text.title),
              SizedBox(height: t.space.sm),
              line(Strings.started, stamp(session.startAt)),
              line(
                Strings.ended,
                end == null
                    ? (session.isRunning
                          ? TracksStrings.stripRunning
                          : Strings.pausedDuration)
                    : stamp(end),
              ),
              line(Strings.netDuration, Fmt.clock(session.netMs(nowMs))),
              line(Strings.pausedDuration, Fmt.clock(session.pausedMs(nowMs))),
            ],
          ),
        ),
      ),
    );
  }
}
