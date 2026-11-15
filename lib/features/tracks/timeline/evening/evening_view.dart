import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../adaptive/adaptive.dart';
import '../../../../core/domain/domain.dart';
import '../../../../core/engine/engine.dart';
import '../../../../core/now_ticker.dart';
import '../../../../core/repo/repo.dart';
import '../../../../core/services/haptics.dart';
import '../../../../l10n/formatters.dart';
import '../../../../theme/theme.dart';
import '../../../protocol/protocol_widgets.dart';
import '../../now_selector.dart';
import '../../tracks_strings.dart';
import '../timeline_event_sheet.dart';
import '../timeline_logic.dart';
import 'evening_layout.dart';

/// Keys of the evening (for tests).
abstract final class EveningKeys {
  static const view = ValueKey('evening-view');
  static const body = ValueKey('evening-body');
  static const chain = ValueKey('evening-chain');
  static const now = ValueKey('evening-now');
  static Key column(String? personId) =>
      ValueKey('evening-column-${personId ?? ''}');
  static Key chip(String eventId) => ValueKey('evening-chip-$eventId');
}

/// "Abend" (Pult 3.2): one logical day of a set, the time running
/// downwards. A column per person with its entries as chips, on the left
/// the hours and the bars of the other tracks; "now" as a line, what is
/// still to come hatched.
///
/// A tap on a chip shows the chain of that thing (its entries with the
/// time between them); a tap on a chip of the chain shown opens the
/// entry. Chips have a tap area of 48 - where two overlap, the nearer
/// one wins.
class EveningView extends ConsumerStatefulWidget {
  const EveningView({
    required this.sessions,
    required this.fromMs,
    required this.toMs,
    required this.hiddenTracks,
    super.key,
  });

  /// What `watchSetActivity` delivered for the day.
  final List<HistorySession> sessions;
  final int fromMs;
  final int toMs;
  final Set<String> hiddenTracks;

  @override
  ConsumerState<EveningView> createState() => _EveningViewState();
}

class _EveningViewState extends ConsumerState<EveningView> {
  /// The chain shown: the person's column and the thing.
  ({String? personId, String thing})? _chain;

  @override
  void didUpdateWidget(EveningView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fromMs != widget.fromMs) _chain = null;
  }

  EveningMetrics _metrics(TikkyTokens t) {
    final s = t.strip;
    return EveningMetrics(
      axisWidth: s.eveningAxis,
      trackBar: s.eveningTrackBar,
      trackGap: s.eveningTrackGap,
      minTracksWidth: s.eveningTracks,
      chipHeight: s.eveningChip,
      chipInset: s.eveningChipInset,
      slotGap: s.eveningSlotGap,
      minPxPerHour: s.eveningMinPxPerHour,
      minColumnWidth: s.eveningMinColumn,
    );
  }

  double _chipWidth(TikkyTokens t, String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: t.text.eveningChip),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width + 2 * t.space.sm;
    painter.dispose();
    return width;
  }

  void _tapChip(EveningColumn column, EveningChip chip) {
    final chain = (personId: column.personId, thing: chip.thing);
    if (_chain == chain) {
      _open(chip.event);
      return;
    }
    ref.read(hapticsProvider).selection();
    setState(() => _chain = chain);
  }

  void _open(TrackEvent event) {
    final rows = buildTimelineRows(
      sessions: widget.sessions,
      personNames: {
        for (final p in ref.read(personsByIdProvider).values) p.id: p.name,
      },
      substanceNames: {
        for (final s in ref.read(substancesByIdProvider).values) s.id: s.name,
      },
    );
    for (final row in rows) {
      if (row.event.id == event.id) {
        openTimelineEvent(context, ref, row);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final persons = ref.watch(personsByIdProvider);
    final substances = ref.watch(substancesByIdProvider);
    // "Now" moves the line, the end of the scale and the open gap.
    return NowSelector<int>(
      selector: (now) => now ~/ Duration.millisecondsPerMinute,
      builder: (context, minute) {
        final now = ref.read(nowTickerProvider).value;
        return LayoutBuilder(
          builder: (context, outer) {
            // Low (a phone held sideways): the whole evening scrolls.
            final low = outer.maxHeight < t.strip.eveningMinHeight;
            final constraints = low
                ? outer.copyWith(maxHeight: t.strip.eveningMinHeight)
                : outer;
            final chainHeight = _chain == null ? 0.0 : t.strip.eveningChain;
            final layout = layoutEvening(
              sessions: widget.sessions,
              fromMs: widget.fromMs,
              toMs: widget.toMs,
              nowMs: now,
              width: constraints.maxWidth,
              // The head takes about a tap target and a line.
              height: math.max(
                0,
                constraints.maxHeight -
                    chainHeight -
                    2 * t.sizes.minTapTarget -
                    t.sizes.minTapTarget,
              ),
              metrics: _metrics(t),
              persons: persons,
              substances: substances,
              hiddenTrackIds: widget.hiddenTracks,
            );
            if (layout.isEmpty) {
              return AdaptiveEmptyState(
                icon: AdaptiveIcons.history(context),
                title: TracksStrings.timelineEmptyTitle,
                message: TracksStrings.eveningEmpty,
              );
            }
            EveningColumn? chainColumn;
            for (final c in layout.columns) {
              if (_chain != null && c.personId == _chain!.personId) {
                chainColumn = c;
              }
            }
            final chain = chainColumn == null
                ? null
                : eveningChain(
                    chainColumn,
                    _chain!.thing,
                    substances: substances,
                  );
            final live = now >= widget.fromMs && now < widget.toMs;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Head(layout: layout),
                if (chainColumn != null && chain!.entries.isNotEmpty)
                  _ChainLine(
                    column: chainColumn,
                    entries: chain.entries,
                    lockoutUntil: chain.lockoutUntil,
                    nowMs: live ? now : null,
                  ),
                Expanded(
                  child: _Body(
                    layout: layout,
                    nowMs: now,
                    live: live,
                    chain: _chain,
                    chainColumn: chainColumn,
                    chainEntries: chain?.entries ?? const [],
                    lockoutUntil: chain?.lockoutUntil,
                    chipWidth: (label) => _chipWidth(t, label),
                    onChip: _tapChip,
                    onEmpty: () {
                      if (_chain != null) setState(() => _chain = null);
                    },
                  ),
                ),
              ],
            );
            final wide = layout.width > constraints.maxWidth
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: layout.width, child: content),
                  )
                : content;
            return KeyedSubtree(
              key: EveningKeys.view,
              child: low
                  ? SingleChildScrollView(
                      child: SizedBox(
                        height: constraints.maxHeight,
                        child: wide,
                      ),
                    )
                  : wide,
            );
          },
        );
      },
    );
  }
}

/// The column heads: "Spuren" over the bars, then per person the initial,
/// the name and how often each thing came.
class _Head extends StatelessWidget {
  const _Head({required this.layout});

  final EveningLayout layout;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final s = t.strip;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: s.eveningAxis),
          SizedBox(
            width: layout.tracksWidth,
            child: layout.tracksWidth == 0
                ? null
                : Text(
                    TracksStrings.eveningTracks,
                    style: t.text.stripWord,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
          ),
          for (final c in layout.columns)
            SizedBox(
              key: EveningKeys.column(c.personId),
              width: c.width,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: t.space.xs),
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          PersonInitial(
                            name: c.name,
                            color: c.colorArgb == null
                                ? null
                                : Color(c.colorArgb!),
                            size: s.eveningAvatar,
                            style: t.text.stripName,
                          ),
                          SizedBox(width: s.nameGap),
                          Expanded(
                            child: Text(
                              c.name,
                              style: t.text.laneName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: t.space.xxs),
                      Text(
                        [for (final (thing, n) in c.counts) '$thing $n']
                            .join(TracksStrings.separator),
                        style: t.text.stripWord,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The chain of the chosen thing in one line: "Bier 21:20 55 min 22:15
/// 1 h 23:15 26 min jetzt". The time still open is in the warning colour
/// while the lockout the user set runs.
class _ChainLine extends StatelessWidget {
  const _ChainLine({
    required this.column,
    required this.entries,
    required this.lockoutUntil,
    required this.nowMs,
  });

  final EveningColumn column;
  final List<TrackEvent> entries;
  final int? lockoutUntil;

  /// `null` when the evening is over.
  final int? nowMs;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final use24h = t.prefs.use24h;
    final chip = column.chips.firstWhere((c) => c.event.id == entries.first.id);
    final roles = chip.colorArgb == null
        ? t.roles(t.colors.textMuted)
        : t.roles(Color(chip.colorArgb!));
    final gap = t.text.stripName;
    final time = t.text.stripDigits.copyWith(color: t.colors.textMuted);
    final name = DecoratedBox(
      decoration: BoxDecoration(
        color: roles.solid,
        borderRadius: t.radii.pillAll,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: t.space.sm),
        child: Text(
          chip.label,
          style: t.text.eveningChip.copyWith(color: roles.on),
        ),
      ),
    );
    final children = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      children.add(Text(Fmt.time(entries[i].at, use24h: use24h), style: time));
      if (i + 1 < entries.length) {
        children.add(
          Text(Fmt.coarse(entries[i + 1].at - entries[i].at), style: gap),
        );
      }
    }
    final now = nowMs;
    if (now != null) {
      final locked = lockoutUntil != null && lockoutUntil! > now;
      children
        ..add(
          Text(
            Fmt.coarse(math.max(0, now - entries.last.at)),
            style: locked ? gap.copyWith(color: t.colors.warningText) : gap,
          ),
        )
        ..add(Text(TracksStrings.eveningNow, style: t.text.stripWord));
    }
    return Semantics(
      container: true,
      label: TracksStrings.eveningChainSemantics(chip.label, column.name),
      child: Container(
        key: EveningKeys.chain,
        height: t.strip.eveningChain,
        decoration: BoxDecoration(
          border: Border(top: t.hairline, bottom: t.hairline),
        ),
        padding: EdgeInsets.symmetric(horizontal: t.space.md),
        // The name stays; the times scroll, the latest in view.
        child: Row(
          children: [
            name,
            SizedBox(width: t.space.sm),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) SizedBox(width: t.space.sm),
                      children[i],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.layout,
    required this.nowMs,
    required this.live,
    required this.chain,
    required this.chainColumn,
    required this.chainEntries,
    required this.lockoutUntil,
    required this.chipWidth,
    required this.onChip,
    required this.onEmpty,
  });

  final EveningLayout layout;
  final int nowMs;
  final bool live;
  final ({String? personId, String thing})? chain;
  final EveningColumn? chainColumn;
  final List<TrackEvent> chainEntries;
  final int? lockoutUntil;
  final double Function(String label) chipWidth;
  final void Function(EveningColumn column, EveningChip chip) onChip;
  final VoidCallback onEmpty;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final s = t.strip;
    final use24h = t.prefs.use24h;
    final target = t.sizes.minTapTarget;
    // Room below the scale for "Abstand bis" and the last chip.
    final height = layout.height + target;
    final nowY = live ? layout.yOf(nowMs) : null;
    final chips = <(EveningColumn, EveningChip, Rect)>[
      for (final c in layout.columns)
        for (final chip in c.chips)
          (
            c,
            chip,
            Rect.fromLTWH(
              chip.x,
              chip.y - s.eveningChip / 2,
              math.min(chipWidth(chip.label), c.left + c.width - chip.x),
              s.eveningChip,
            ),
          ),
    ];

    void tapAt(Offset at) {
      // A tap area of 48 around every chip; the nearest one wins.
      (EveningColumn, EveningChip)? best;
      var bestDistance = double.infinity;
      for (final (column, chip, rect) in chips) {
        final area = Rect.fromLTRB(
          rect.left - t.space.xs,
          rect.center.dy - target / 2,
          rect.right + t.space.xs,
          rect.center.dy + target / 2,
        );
        if (!area.contains(at)) continue;
        final distance = (rect.center - at).distance;
        if (distance < bestDistance) {
          bestDistance = distance;
          best = (column, chip);
        }
      }
      if (best == null) {
        onEmpty();
      } else {
        onChip(best.$1, best.$2);
      }
    }

    final lockout = lockoutUntil;
    final showLockout =
        nowY != null &&
        chainColumn != null &&
        lockout != null &&
        lockout > nowMs;

    return SingleChildScrollView(
      key: EveningKeys.body,
      // While the evening goes on, "now" at the bottom is in view.
      reverse: live,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => tapAt(d.localPosition),
        child: SizedBox(
          width: layout.width,
          height: height,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _EveningPainter(
                    layout: layout,
                    tokens: t,
                    nowY: nowY,
                    chainColumn: chainColumn,
                    chainEntries: chainEntries,
                    chainColorArgb: _chainColor(),
                  ),
                ),
              ),
              for (final hour in layout.hours)
                Positioned(
                  left: 0,
                  width: s.eveningAxis - t.space.xs,
                  top: hour.y - s.eveningChip / 2,
                  height: s.eveningChip,
                  child: ExcludeSemantics(
                    child: Align(
                      alignment: Alignment.centerRight,
                      // Narrow column: smaller rather than cut off.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Fmt.time(hour.ms, use24h: use24h),
                          style: t.text.stripDigits.copyWith(
                            color: t.colors.textMuted,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              for (final (column, chip, rect) in chips)
                Positioned.fromRect(
                  rect: rect,
                  child: _Chip(
                    key: EveningKeys.chip(chip.event.id),
                    chip: chip,
                    selected:
                        chain != null &&
                        chain!.personId == column.personId &&
                        chain!.thing == chip.thing,
                    semanticLabel: TracksStrings.eveningChipSemantics(
                      column.name,
                      chip.label,
                      Fmt.time(chip.event.at, use24h: use24h),
                    ),
                    onTap: () => onChip(column, chip),
                  ),
                ),
              if (nowY != null)
                Positioned(
                  key: EveningKeys.now,
                  left: 0,
                  width: s.eveningAxis,
                  top: nowY - s.eveningChip / 2,
                  height: s.eveningChip,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: t.colors.text,
                        borderRadius: t.radii.pillAll,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: t.space.xxs),
                        child: Text(
                          Fmt.time(nowMs, use24h: use24h),
                          style: t.text.stripDigits.copyWith(
                            color: t.colors.background,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              if (showLockout)
                Positioned(
                  left: chainColumn!.left + s.eveningChipInset,
                  top: nowY + t.space.sm,
                  child: Text(
                    TracksStrings.eveningLockoutUntil(
                      Fmt.time(lockout, use24h: use24h),
                    ),
                    style: t.text.stripName.copyWith(
                      color: t.colors.warningText,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int? _chainColor() {
    final column = chainColumn;
    if (column == null || chainEntries.isEmpty) return null;
    for (final c in column.chips) {
      if (c.event.id == chainEntries.first.id) return c.colorArgb;
    }
    return null;
  }
}

/// An entry chip: in the tint of its thing, solid while its chain is
/// shown.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.chip,
    required this.selected,
    required this.semanticLabel,
    required this.onTap,
    super.key,
  });

  final EveningChip chip;
  final bool selected;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final roles = t.roles(
      chip.colorArgb == null ? t.colors.textMuted : Color(chip.colorArgb!),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      // The taps go to the body, which picks the nearest chip.
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? roles.solid : roles.tint,
            borderRadius: t.radii.pillAll,
          ),
          child: Center(
            child: Text(
              chip.label,
              style: t.text.eveningChip.copyWith(
                color: selected ? roles.on : roles.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.clip,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hour lines, column lines, the bars of the tracks, the line of the
/// chain, the "now" line and the hatched rest of the evening.
class _EveningPainter extends CustomPainter {
  _EveningPainter({
    required this.layout,
    required this.tokens,
    required this.nowY,
    required this.chainColumn,
    required this.chainEntries,
    required this.chainColorArgb,
  });

  final EveningLayout layout;
  final TikkyTokens tokens;
  final double? nowY;
  final EveningColumn? chainColumn;
  final List<TrackEvent> chainEntries;
  final int? chainColorArgb;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tokens;
    final s = t.strip;
    final line = Paint()
      ..color = t.colors.border
      ..strokeWidth = math.max(t.sizes.hairline, 1);
    final left = s.eveningAxis;
    for (final hour in layout.hours) {
      canvas.drawLine(Offset(left, hour.y), Offset(size.width, hour.y), line);
    }
    final columnsLeft = s.eveningAxis + layout.tracksWidth;
    for (final c in layout.columns) {
      if (c.left <= columnsLeft && layout.tracksWidth == 0) continue;
      canvas.drawLine(Offset(c.left, 0), Offset(c.left, size.height), line);
    }

    // What is still to come.
    final now = nowY;
    if (now != null) {
      final rest = Rect.fromLTRB(left, now, size.width, layout.height);
      if (rest.height > 0) {
        canvas
          ..save()
          ..clipRect(rest);
        final step = s.foldHatchSpacing;
        for (var x = rest.left - rest.height; x < rest.right; x += step) {
          canvas.drawLine(
            Offset(x, rest.bottom),
            Offset(x + rest.height, rest.top),
            line,
          );
        }
        canvas.restore();
      }
    }

    // The bars of the tracks.
    final radius = Radius.circular(s.eveningTrackBar / 2);
    final gapPaint = Paint()
      ..color = t.colors.background
      ..strokeWidth = math.max(t.sizes.hairline, 1.5);
    for (final bar in layout.trackBars) {
      final paint = Paint()..color = t.roles(t.trackColor(bar.track)).solid;
      for (final (top, bottom) in bar.spans) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              bar.x,
              top,
              bar.x + s.eveningTrackBar,
              math.max(bottom, top + 2),
            ),
            radius,
          ),
          paint,
        );
      }
      for (final y in bar.marks) {
        canvas.drawLine(
          Offset(bar.x, y),
          Offset(bar.x + s.eveningTrackBar, y),
          gapPaint,
        );
      }
    }

    // The chain: a line from its first entry on, a dot at every entry.
    final column = chainColumn;
    if (column != null && chainEntries.isNotEmpty) {
      final color = chainColorArgb == null
          ? t.colors.textMuted
          : t.roles(Color(chainColorArgb!)).solid;
      final x = column.left + s.eveningChipInset / 2;
      final top = layout.yOf(chainEntries.first.at);
      final bottom = now ?? layout.yOf(chainEntries.last.at);
      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        Paint()
          ..color = color
          ..strokeWidth = s.eveningChainLine,
      );
      for (final e in chainEntries) {
        canvas.drawCircle(
          Offset(x, layout.yOf(e.at)),
          s.eveningChainDot / 2,
          Paint()..color = color,
        );
      }
    }

    if (now != null) {
      canvas.drawLine(
        Offset(left, now),
        Offset(size.width, now),
        Paint()
          ..color = t.colors.text
          ..strokeWidth = s.nowLine,
      );
    }
  }

  @override
  bool shouldRepaint(_EveningPainter old) =>
      !identical(old.layout, layout) ||
      old.nowY != nowY ||
      old.chainColumn != chainColumn ||
      old.chainEntries != chainEntries ||
      old.tokens != tokens;
}
