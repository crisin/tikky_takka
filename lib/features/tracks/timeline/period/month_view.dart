import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/engine/engine.dart';
import '../../../../core/repo/repo.dart';
import '../../../../core/services/haptics.dart';
import '../../../../l10n/formatters.dart';
import '../../../../theme/theme.dart';
import '../../../protocol/entry_edit_sheet.dart';
import '../../now_selector.dart';
import '../../tracks_strings.dart';
import 'period_things.dart';

/// Keys of the month (for tests).
abstract final class MonthKeys {
  static const view = ValueKey('month-view');
  static const all = ValueKey('month-all');
  static const count = ValueKey('month-count');
  static const days = ValueKey('month-days');
  static const pause = ValueKey('month-pause');
  static Key thing(String key) => ValueKey('month-thing-$key');
  static Key day(LocalDay day) => ValueKey('month-day-$day');
}

/// "Monat" (Pult 3.4): a calendar of one month. A day shows how often the
/// chosen thing came ("Alles": every entry), in four steps of its colour;
/// below three figures - how often, on how many days, the longest pause.
/// A tap on a day opens its evening.
class MonthView extends ConsumerStatefulWidget {
  const MonthView({
    required this.sessions,
    required this.month,
    required this.onDay,
    required this.thing,
    required this.onThing,
    super.key,
  });

  /// What `watchSetActivity` delivered for the month (filtered already).
  final List<HistorySession> sessions;

  /// The first day of the month.
  final LocalDay month;
  final ValueChanged<LocalDay> onDay;

  /// The thing counted (`entryThingKey`); `null` = everything.
  final String? thing;
  final ValueChanged<String?> onThing;

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final s = t.strip;
    final substances = ref.watch(substancesByIdProvider);
    final dayStart = t.prefs.dayStartMinutes;
    final month = widget.month;
    final next = DateTime(month.year, month.month + 1);
    final last = logicalDayShift(LocalDay(next.year, next.month, 1), -1);
    final byDay = entriesByLogicalDay(widget.sessions, dayStart);
    final all = [
      for (final e in byDay.entries)
        if (e.key.compareTo(month) >= 0 && e.key.compareTo(last) <= 0)
          ...e.value,
    ];
    final things = thingTotals(all);
    final thing = things.any((x) => x.$1 == widget.thing) ? widget.thing : null;
    final counts = <LocalDay, int>{
      for (final e in byDay.entries)
        e.key: thing == null
            ? e.value.length
            : e.value.where((x) => entryThingKey(x) == thing).length,
    };
    var most = 0;
    for (var d = month; d.compareTo(last) <= 0; d = logicalDayShift(d, 1)) {
      final n = counts[d] ?? 0;
      if (n > most) most = n;
    }
    final roles = thing == null
        ? t.roles(t.colors.primary)
        : t.roles(
            Color(
              thingColor(thing, substances) ?? t.colors.textMuted.toARGB32(),
            ),
          );
    final label = thing == null ? null : thingLabel(thing, substances);

    return NowSelector<LocalDay>(
      selector: (now) => logicalDayOf(now, dayStart),
      builder: (context, today) {
        final until = today.compareTo(last) < 0 ? today : last;
        final figures = monthFigures(counts, month, until);
        final firstMonday = month.weekStart;
        final rows = <List<LocalDay>>[];
        for (
          var d = firstMonday;
          d.compareTo(last) <= 0;
          d = logicalDayShift(d, 7)
        ) {
          rows.add([for (var i = 0; i < 7; i++) logicalDayShift(d, i)]);
        }

        Widget chip(String? key, String text) {
          final argb = key == null ? null : thingColor(key, substances);
          final chipRoles = argb == null ? null : t.roles(Color(argb));
          return Padding(
            padding: EdgeInsets.only(right: t.space.sm),
            child: SheetChip(
              key: key == null ? MonthKeys.all : MonthKeys.thing(key),
              label: text,
              roles: chipRoles,
              selected: key == thing,
              onTap: () {
                ref.read(hapticsProvider).selection();
                widget.onThing(key);
              },
            ),
          );
        }

        return ListView(
          key: MonthKeys.view,
          padding: EdgeInsets.fromLTRB(
            t.space.pageLanes,
            0,
            t.space.pageLanes,
            t.space.lg,
          ),
          children: [
            Semantics(
              container: true,
              label: TracksStrings.monthWhat,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    chip(null, TracksStrings.monthAll),
                    for (final (key, _) in things)
                      chip(key, thingLabel(key, substances)),
                  ],
                ),
              ),
            ),
            SizedBox(height: t.space.sm),
            ExcludeSemantics(
              child: Row(
                children: [
                  for (final name in Fmt.weekdaysPlain)
                    Expanded(
                      child: Text(
                        name,
                        style: t.text.stripWord,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: t.space.xs),
            for (final row in rows)
              Padding(
                padding: EdgeInsets.only(bottom: s.monthGap),
                child: Row(
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      if (i > 0) SizedBox(width: s.monthGap),
                      Expanded(
                        child: _Day(
                          day: row[i],
                          inMonth: row[i].month == month.month,
                          isToday: row[i] == today,
                          isFuture: row[i].compareTo(today) > 0,
                          count: counts[row[i]] ?? 0,
                          level: countLevel(counts[row[i]] ?? 0, most),
                          roles: roles,
                          onTap: () => widget.onDay(row[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            SizedBox(height: t.space.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Figure(
                    key: MonthKeys.count,
                    value: '${figures.count}',
                    label: TracksStrings.monthCountLabel(label),
                  ),
                  SizedBox(width: t.space.sm),
                  _Figure(
                    key: MonthKeys.days,
                    value: '${figures.daysWithEntry}',
                    label: TracksStrings.monthDays,
                  ),
                  SizedBox(width: t.space.sm),
                  _Figure(
                    key: MonthKeys.pause,
                    value: TracksStrings.days(figures.longestPauseDays),
                    label: TracksStrings.monthPause,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A day of the calendar: its number, and how often - in one of four
/// steps of the colour (none, tint, strong, solid).
class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isFuture,
    required this.count,
    required this.level,
    required this.roles,
    required this.onTap,
  });

  final LocalDay day;
  final bool inMonth;
  final bool isToday;
  final bool isFuture;
  final int count;
  final int level;
  final TrackRoles roles;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final s = t.strip;
    final number = Text(
      '${day.day}',
      style: t.text.stripWord.copyWith(
        color: inMonth && !isFuture ? null : t.colors.textMuted,
      ),
    );
    if (!inMonth) {
      // Days of the months around: only their number, quiet.
      return ExcludeSemantics(
        child: SizedBox(
          height: s.monthCell,
          child: Opacity(
            opacity: 0.5,
            child: Padding(
              padding: EdgeInsets.all(t.space.xs),
              child: Align(alignment: Alignment.topLeft, child: number),
            ),
          ),
        ),
      );
    }
    final (fill, ink) = switch (level) {
      1 => (roles.tint, roles.ink),
      2 => (roles.strong, roles.ink),
      3 => (roles.solid, roles.on),
      _ => (isFuture ? t.colors.background : t.colors.surface, t.colors.text),
    };
    final weekday = Fmt.weekdayPlain(day);
    return Semantics(
      button: !isFuture,
      label: TracksStrings.daySemantics(weekday, Fmt.dayMonth(day), count),
      excludeSemantics: true,
      onTap: isFuture ? null : onTap,
      child: Material(
        key: MonthKeys.day(day),
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radii.small),
          side: isToday
              ? BorderSide(color: t.colors.text, width: s.nowLine * 1.5)
              : isFuture
              ? t.hairline
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isFuture ? null : onTap,
          child: SizedBox(
            height: s.monthCell,
            child: Padding(
              padding: EdgeInsets.all(t.space.xs),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: DefaultTextStyle.merge(
                      style: TextStyle(color: level > 0 ? ink : null),
                      child: number,
                    ),
                  ),
                  if (count > 0)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        '$count',
                        style: t.text.laneLabelCount.copyWith(color: ink),
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

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label, super.key});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return Expanded(
      child: MergeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.colors.surface,
            borderRadius: BorderRadius.circular(t.radii.small),
            border: Border.fromBorderSide(t.hairline),
          ),
          child: Padding(
            padding: EdgeInsets.all(t.space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: t.text.cardDigits, maxLines: 1),
                ),
                Text(label, style: t.text.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
