import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/domain.dart';
import '../../../../core/engine/engine.dart';
import '../../../../core/now_ticker.dart';
import '../../../../core/repo/repo.dart';
import '../../../../l10n/formatters.dart';
import '../../../../theme/theme.dart';
import '../../now_selector.dart';
import '../../tracks_strings.dart';
import 'period_things.dart';

/// Keys of the week (for tests).
abstract final class WeekKeys {
  static const view = ValueKey('week-view');
  static Key day(LocalDay day) => ValueKey('week-day-$day');
  static Key count(LocalDay day) => ValueKey('week-count-$day');
  static Key total(String thing) => ValueKey('week-total-$thing');
}

const int _windowMs = 12 * 60 * 60 * 1000;

/// "Woche" (Pult 3.3): seven rows, Monday to Sunday. A row shows the
/// twelve hours before the start of the next day (18:00 to 06:00 with the
/// day starting at 06:00) with a stroke per entry in the colour of its
/// thing, and how many entries the whole logical day has. Below: the
/// totals of the week per thing. A tap on a day opens its evening.
class WeekView extends ConsumerWidget {
  const WeekView({
    required this.sessions,
    required this.monday,
    required this.onDay,
    super.key,
  });

  /// What `watchSetActivity` delivered for the week (filtered already).
  final List<HistorySession> sessions;
  final LocalDay monday;
  final ValueChanged<LocalDay> onDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tikky;
    final s = t.strip;
    final substances = ref.watch(substancesByIdProvider);
    final dayStart = t.prefs.dayStartMinutes;
    final byDay = entriesByLogicalDay(sessions, dayStart);
    final days = [for (var i = 0; i < 7; i++) logicalDayShift(monday, i)];
    final week = [for (final d in days) ...?byDay[d]];
    final totals = thingTotals(week);
    final most = totals.isEmpty ? 1 : totals.first.$2;

    return NowSelector<int>(
      selector: (now) => now ~/ Duration.millisecondsPerMinute,
      builder: (context, _) {
        final now = ref.read(nowTickerProvider).value;
        final today = logicalDayOf(now, dayStart);
        // The hours above the rows: from the start of the window every
        // three hours.
        final windowStart = DateTime.fromMillisecondsSinceEpoch(
          logicalDayEndMs(monday, dayStart) - _windowMs,
        );
        return ListView(
          key: WeekKeys.view,
          padding: EdgeInsets.fromLTRB(
            t.space.pageLanes,
            0,
            t.space.pageLanes,
            t.space.lg,
          ),
          children: [
            Row(
              children: [
                SizedBox(width: s.weekLabel),
                Expanded(
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var k = 0; k <= 4; k++)
                          Text(
                            DateTime(
                              windowStart.year,
                              windowStart.month,
                              windowStart.day,
                              windowStart.hour + 3 * k,
                            ).hour.toString().padLeft(2, '0'),
                            style: t.text.stripDigits.copyWith(
                              color: t.colors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: s.weekCount),
              ],
            ),
            SizedBox(height: t.space.xs),
            for (final day in days) ...[
              _DayRow(
                day: day,
                entries: byDay[day] ?? const [],
                windowTo: logicalDayEndMs(day, dayStart),
                isToday: day == today,
                isFuture: day.compareTo(today) > 0,
                nowMs: now,
                substances: substances,
                onTap: () => onDay(day),
              ),
              SizedBox(height: s.weekGap),
            ],
            SizedBox(height: t.space.md),
            Text(TracksStrings.weekTotal(week.length), style: t.text.caption),
            SizedBox(height: t.space.sm),
            for (final (thing, n) in totals)
              Padding(
                key: WeekKeys.total(thing),
                padding: EdgeInsets.only(bottom: t.space.sm),
                child: MergeSemantics(
                  child: Row(
                    children: [
                      SizedBox(
                        width: s.weekLabel * 2,
                        child: Text(
                          thingLabel(thing, substances),
                          style: t.text.stripName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) => Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              width: math.max(
                                s.weekSumBar,
                                c.maxWidth * n / most,
                              ),
                              height: s.weekSumBar,
                              decoration: BoxDecoration(
                                color: _solid(t, thing, substances),
                                borderRadius: t.radii.pillAll,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: s.weekCount,
                        child: Text(
                          '$n',
                          style: t.text.laneLabelCount,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

Color _solid(TikkyTokens t, String thing, Map<String, Substance> substances) {
  final argb = thingColor(thing, substances);
  return argb == null ? t.colors.textMuted : t.roles(Color(argb)).solid;
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.entries,
    required this.windowTo,
    required this.isToday,
    required this.isFuture,
    required this.nowMs,
    required this.substances,
    required this.onTap,
  });

  final LocalDay day;
  final List<TrackEvent> entries;
  final int windowTo;
  final bool isToday;
  final bool isFuture;
  final int nowMs;
  final Map<String, Substance> substances;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final s = t.strip;
    final from = windowTo - _windowMs;
    final weekday = Fmt.weekdayPlain(day);
    final date = Fmt.dayMonth(day);
    return Semantics(
      button: true,
      label: TracksStrings.daySemantics(weekday, date, entries.length),
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: isFuture ? 0.5 : 1,
        child: InkWell(
          key: WeekKeys.day(day),
          onTap: onTap,
          borderRadius: BorderRadius.circular(t.radii.small),
          child: SizedBox(
            height: s.weekRow,
            child: Row(
              children: [
                SizedBox(
                  width: s.weekLabel,
                  // Large text: smaller rather than cut off.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(weekday, style: t.text.headline, maxLines: 1),
                        Text(date, style: t.text.stripWord, maxLines: 1),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: t.colors.surface,
                      borderRadius: BorderRadius.circular(t.radii.small),
                      border: isToday
                          ? Border.all(color: t.colors.text, width: s.nowLine)
                          : null,
                    ),
                    child: CustomPaint(
                      painter: _TicksPainter(
                        tokens: t,
                        entries: entries,
                        from: from,
                        nowMs: isToday ? nowMs : null,
                        substances: substances,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                SizedBox(
                  width: s.weekCount,
                  child: Text(
                    isFuture
                        ? ''
                        : entries.isEmpty
                        ? TracksStrings.noCount
                        : '${entries.length}',
                    key: WeekKeys.count(day),
                    style: t.text.laneLabelCount,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TicksPainter extends CustomPainter {
  _TicksPainter({
    required this.tokens,
    required this.entries,
    required this.from,
    required this.nowMs,
    required this.substances,
  });

  final TikkyTokens tokens;
  final List<TrackEvent> entries;
  final int from;
  final int? nowMs;
  final Map<String, Substance> substances;

  @override
  void paint(Canvas canvas, Size size) {
    final s = tokens.strip;
    final inset = s.weekTick * 2;
    final width = size.width - 2 * inset;
    double? xOf(int at) {
      final f = (at - from) / _windowMs;
      if (f < 0 || f > 1) return null;
      return inset + f * width;
    }

    final top = (size.height - s.weekTickHeight) / 2;
    for (final e in entries) {
      final x = xOf(e.at);
      if (x == null) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - s.weekTick / 2, top, s.weekTick, s.weekTickHeight),
          Radius.circular(s.weekTick / 2),
        ),
        Paint()..color = _solid(tokens, entryThingKey(e), substances),
      );
    }
    final now = nowMs;
    final x = now == null ? null : xOf(now);
    if (x != null) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = tokens.colors.text
          ..strokeWidth = s.nowLine,
      );
    }
  }

  @override
  bool shouldRepaint(_TicksPainter old) =>
      old.entries != entries ||
      old.nowMs != nowMs ||
      old.from != from ||
      old.tokens != tokens;
}
