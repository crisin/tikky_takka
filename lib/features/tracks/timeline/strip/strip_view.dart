import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../lane_view.dart';
import '../../now_selector.dart';
import '../../tracks_strings.dart';
import '../timeline_logic.dart';
import 'strip_detail.dart';
import 'strip_model.dart';
import 'strip_open.dart';
import 'strip_painter.dart';
import 'strip_viewport.dart';

/// Keys of the strip (for tests).
abstract final class StripKeys {
  static const view = ValueKey('strip-view');
  static const lanes = ValueKey('strip-lanes');
  static const axis = ValueKey('strip-axis');
  static const controls = ValueKey('strip-controls');
  static const fit = ValueKey('strip-fit');
  static const now = ValueKey('strip-now');
  static const tooltip = ValueKey('strip-tooltip');

  /// The name line of a lane; [rowId] is `StripRowData.id`.
  static Key lane(String rowId) => ValueKey('strip-lane-$rowId');

  /// The timer of a thing next to its name.
  static Key timer(String rowId) => ValueKey('strip-timer-$rowId');

  /// The live value of a track next to its name.
  static Key value(String rowId) => ValueKey('strip-value-$rowId');
}

/// The timer of a substance lane: time since its last entry, in the
/// warning colour while a lockout the user set is still running.
class _LaneTimer extends StatelessWidget {
  const _LaneTimer({
    required this.ticker,
    required this.from,
    required this.lockoutUntil,
    super.key,
  });

  final ValueListenable<int> ticker;
  final int from;
  final int? lockoutUntil;

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    return ValueListenableBuilder<int>(
      valueListenable: ticker,
      builder: (context, now, _) {
        final elapsed = math.max(0, now - from);
        final locked = lockoutUntil != null && lockoutUntil! > now;
        return Semantics(
          label: TracksStrings.stripTimerSemantics(Fmt.compact(elapsed)),
          excludeSemantics: true,
          child: Text(
            Fmt.clock(elapsed),
            style: locked
                ? t.text.stripDigits.copyWith(color: t.colors.warningText)
                : t.text.stripDigits,
            maxLines: 1,
          ),
        );
      },
    );
  }
}

/// Fires when the "now" line has moved far enough to be worth a frame:
/// about half a pixel, and at least once a second for the clock at the
/// line.
class _NowPulse extends ChangeNotifier {
  int _bucket = 0;

  void tick(int nowMs, double msPerPx) {
    final quantum = (msPerPx / 2).clamp(100, 1000).floor();
    final bucket = nowMs ~/ quantum;
    if (bucket == _bucket) return;
    _bucket = bucket;
    notifyListeners();
  }
}

/// "Jetzt" of the timeline (Pult 3.1): the set as a strip. Time runs from
/// left to right; every lane has a line with its name above it.
///
/// * The persons of a protocol come first, each with a line per thing
///   (a tap on the name folds it onto one line, remembered per set), then
///   the other tracks, compact.
/// * Sessions are bars in the track's colour (paused stretches hatched,
///   running ones grow up to the "now" line), events are markers on them;
///   markers that would overlap become a pill with their number.
/// * Drag to pan, pinch or Ctrl + wheel to zoom, the wheel scrolls along
///   the time. Buttons: "Alles", "Jetzt" (jumps to the "now" line and
///   follows it until the user pans).
/// * A tap on a marker opens what happened with "Bearbeiten" and
///   "Löschen"; a tap on a bar the figures of the session.
///
/// Everything is drawn by painters that listen to the viewport and the
/// shared ticker; panning, zooming and passing time rebuild no widget.
class StripView extends ConsumerStatefulWidget {
  const StripView({
    required this.setId,
    required this.scope,
    required this.tracks,
    required this.sessions,
    required this.sinceMs,
    required this.showLifecycle,
    required this.hiddenTracks,
    required this.emptyMessage,
    super.key,
  });

  final String setId;
  final TimelineScope scope;

  /// Ordered, non-archived tracks of the set.
  final List<Track> tracks;

  /// What `HistoryRepository.watchSetActivity` delivered for [scope].
  final List<HistorySession> sessions;

  /// Start of [scope]; `null` = the open sessions.
  final int? sinceMs;
  final bool showLifecycle;
  final Set<String> hiddenTracks;

  /// Second line of the empty state.
  final String emptyMessage;

  @override
  ConsumerState<StripView> createState() => StripViewState();
}

class StripViewState extends ConsumerState<StripView> {
  final StripViewport _viewport = StripViewport();
  final _NowPulse _pulse = _NowPulse();
  final ValueNotifier<({Offset at, String text})?> _hover = ValueNotifier(null);
  final ValueNotifier<bool> _following = ValueNotifier(false);
  final FocusNode _focus = FocusNode(debugLabel: 'strip');
  late final Listenable _repaint = Listenable.merge([_viewport, _pulse]);

  NowTicker? _ticker;
  StripData _data = StripData.empty;

  /// The data and the minute the folds were computed for.
  StripData? _foldedData;
  int _foldedMinute = -1;
  StripStyle? _style;
  bool _needsFit = true;
  bool _lanesOverflow = false;

  int _semanticsEpoch = 0;
  bool _semanticsScheduled = false;
  double _semanticsStartMs = 0;
  double _semanticsMsPerPx = 0;

  Offset _lastFocal = Offset.zero;
  double _lastScale = 1;

  /// The viewport (for tests).
  @visibleForTesting
  StripViewport get viewport => _viewport;

  /// The primitives that are on screen right now (for tests).
  @visibleForTesting
  StripLayout get layout => _layout();

  @override
  void initState() {
    super.initState();
    _viewport.addListener(_onViewport);
  }

  @override
  void didUpdateWidget(StripView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.setId != widget.setId || oldWidget.scope != widget.scope) {
      _needsFit = true;
    }
  }

  @override
  void dispose() {
    _ticker?.removeListener(_onTick);
    _ticker = null;
    _viewport
      ..removeListener(_onViewport)
      ..dispose();
    _pulse.dispose();
    _hover.dispose();
    _following.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _subscribe(NowTicker? ticker) {
    if (identical(ticker, _ticker)) return;
    _ticker?.removeListener(_onTick);
    _ticker = ticker;
    ticker?.addListener(_onTick);
  }

  void _onTick() {
    final ticker = _ticker;
    if (ticker == null || !mounted) return;
    final now = ticker.value;
    _updateFolds(now);
    // While following this moves the view (and repaints through it).
    _viewport.setNow(now);
    _pulse.tick(now, _viewport.msPerPx);
  }

  void _onViewport() {
    _following.value = _viewport.following;
    if (_hover.value != null) _hover.value = null;
    // A screen reader needs the nodes of the markers where they are now.
    if (!WidgetsBinding.instance.semanticsEnabled || _semanticsScheduled) {
      return;
    }
    final moved =
        (_viewport.startMs - _semanticsStartMs).abs() / _viewport.msPerPx;
    if (moved < 4 && _viewport.msPerPx == _semanticsMsPerPx) return;
    _semanticsScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _semanticsScheduled = false;
      if (!mounted) return;
      setState(() {
        _semanticsEpoch++;
        _semanticsStartMs = _viewport.startMs;
        _semanticsMsPerPx = _viewport.msPerPx;
      });
    });
  }

  int get _now => ref.read(nowTickerProvider).value;

  /// The stretches without events are drawn narrow. Only the fold up to
  /// "now" grows with time: once a minute is enough.
  void _updateFolds(int nowMs, {bool notify = true}) {
    final minute = nowMs ~/ Duration.millisecondsPerMinute;
    if (identical(_foldedData, _data) && minute == _foldedMinute) return;
    _foldedData = _data;
    _foldedMinute = minute;
    final s = context.tikky.strip;
    _viewport.setFolds(
      computeFolds(
        stripKeepTimes(_data),
        nowMs: minute * Duration.millisecondsPerMinute,
        minGapMs: s.foldMinGapMs,
        keepRecentMs: s.foldKeepRecentMs,
        padMs: s.foldPadMs,
      ),
      notify: notify,
    );
  }

  StripLayout _layout() {
    final style = _style ?? StripStyle.of(context);
    return layoutStrip(
      data: _data,
      scale: _viewport.scale,
      width: _viewport.width,
      nowMs: _now,
      metrics: style.metrics,
    );
  }

  StripHit? _hit(Offset position) =>
      _layout().hitTest(position, slop: context.tikky.strip.hitSlop);

  // ------------------------------------------------------------ actions

  void _togglePerson(String laneId) {
    ref.read(hapticsProvider).selection();
    ref
        .read(stripOpenProvider.notifier)
        .toggle(
          widget.setId,
          laneId,
          shownIds: [
            for (final row in _data.rows)
              if (row.isPerson) row.id,
          ],
        );
  }

  void _fit() {
    ref.read(hapticsProvider).selection();
    _viewport.fit();
  }

  void _jumpToNow() {
    ref.read(hapticsProvider).selection();
    _viewport
      ..setNow(_now, notify: false)
      ..jumpToNow();
  }

  void _openEvent(StripEvent event) =>
      showStripEventDetail(context, ref, event);

  /// A tap on a cluster zooms into it. Where zooming cannot take it apart
  /// (the closest zoom, or events of the same instant) its events are
  /// offered as a list.
  Future<void> _openCluster(StripCluster cluster, {double? x}) async {
    final v = _viewport;
    final step = context.tikky.strip.zoomStep;
    final atLimit = v.msPerPx <= v.minMsPerPx * 1.001;
    if (cluster.toMs > cluster.fromMs && !atLimit) {
      final fitted =
          (cluster.toMs - cluster.fromMs) * (1 + 2 * v.fitPadding) / v.width;
      if (fitted < v.msPerPx / step) {
        v.showRange(cluster.fromMs, cluster.toMs);
      } else {
        // Wider than the view: closer around where the tap was.
        final center = cluster.rect.center.dx.clamp(0.0, v.width);
        v.zoomAround(x ?? center, step * step);
      }
      return;
    }
    final use24h = context.tikky.prefs.use24h;
    final picked = await showAdaptiveActionSheet<StripEvent>(
      context,
      title: TracksStrings.stripCluster(cluster.count),
      actions: [
        for (final e in cluster.events)
          AdaptiveSheetAction(
            value: e,
            label: TracksStrings.stripMarkerTip(
              Fmt.time(e.at, use24h: use24h, seconds: true),
              e.row.text,
            ),
          ),
      ],
    );
    if (picked == null || !mounted) return;
    _openEvent(picked);
  }

  void _openSession(StripSession session) =>
      showStripSessionInfo(context, session, nowMs: _now);

  void _onTapUp(TapUpDetails details) {
    _focus.requestFocus();
    switch (_hit(details.localPosition)) {
      case null:
        break;
      case StripMarkerHit(:final marker):
        ref.read(hapticsProvider).selection();
        if (marker.event case final event?) {
          _openEvent(event);
        } else if (marker.session case final session?) {
          _openSession(session);
        }
      case StripClusterHit(:final cluster):
        ref.read(hapticsProvider).selection();
        _openCluster(cluster, x: details.localPosition.dx);
      case StripBarHit(:final bar):
        ref.read(hapticsProvider).selection();
        _openSession(bar.session);
    }
  }

  String? _tipFor(StripHit hit) {
    final use24h = context.tikky.prefs.use24h;
    String time(int ms, {bool seconds = false}) =>
        Fmt.time(ms, use24h: use24h, seconds: seconds);
    switch (hit) {
      case StripMarkerHit(:final marker):
        final event = marker.event;
        if (event == null) return null;
        final lockout = stripLockoutText(event, _now);
        final note = event.row.note;
        return [
          TracksStrings.stripMarkerTip(
            time(event.at, seconds: true),
            event.row.text,
          ),
          if (note != null && note.isNotEmpty) note,
          ?lockout,
        ].join('\n');
      case StripClusterHit(:final cluster):
        return TracksStrings.stripClusterSemantics(
          cluster.count,
          time(cluster.fromMs, seconds: true),
          time(cluster.toMs, seconds: true),
        );
      case StripBarHit(:final bar):
        final s = bar.session;
        final end = s.endAt;
        return TracksStrings.stripBarTip(
          s.source.track?.name ?? '',
          time(s.startAt),
          end == null ? TracksStrings.stripRunning : time(end),
        );
    }
  }

  void _onHover(PointerHoverEvent event) {
    final hit = _hit(event.localPosition);
    final text = hit == null ? null : _tipFor(hit);
    _hover.value = text == null ? null : (at: event.localPosition, text: text);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _focus.requestFocus();
    _lastFocal = details.localFocalPoint;
    _lastScale = 1;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final scale = details.horizontalScale;
    if (details.pointerCount > 1 && scale > 0 && scale != _lastScale) {
      _viewport.zoomAround(details.localFocalPoint.dx, scale / _lastScale);
      _lastScale = scale;
    }
    final dx = details.localFocalPoint.dx - _lastFocal.dx;
    _lastFocal = details.localFocalPoint;
    if (dx != 0) _viewport.panBy(dx);
  }

  void _onSignal(PointerSignalEvent event) {
    final s = context.tikky.strip;
    if (event is PointerScaleEvent) {
      GestureBinding.instance.pointerSignalResolver.register(
        event,
        (e) => _viewport.zoomAround(
          event.localPosition.dx,
          (e as PointerScaleEvent).scale,
        ),
      );
      return;
    }
    if (event is! PointerScrollEvent) return;
    final keyboard = HardwareKeyboard.instance;
    final zoom = keyboard.isControlPressed || keyboard.isMetaPressed;
    final delta = event.scrollDelta;
    final sideways = delta.dx != 0 || keyboard.isShiftPressed;
    // A plain wheel scrolls along the time - unless the lanes do not fit,
    // then it scrolls them (the scroll view takes the event).
    if (!zoom && !sideways && _lanesOverflow) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (zoom) {
        _viewport.zoomAround(
          event.localPosition.dx,
          math.pow(2, -delta.dy / s.wheelZoomDistance).toDouble(),
        );
      } else {
        _viewport.panBy(-(delta.dx != 0 ? delta.dx : delta.dy));
      }
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final s = context.tikky.strip;
    final key = event.logicalKey;
    final v = _viewport;
    if (key == LogicalKeyboardKey.arrowLeft) {
      v.panBy(v.width * s.keyPanShare);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      v.panBy(-v.width * s.keyPanShare);
    } else if (key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd ||
        event.character == '+') {
      v.zoomBy(s.zoomStep);
    } else if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract ||
        event.character == '-') {
      v.zoomBy(1 / s.zoomStep);
    } else if (key == LogicalKeyboardKey.home) {
      v.fit();
    } else if (key == LogicalKeyboardKey.end) {
      v
        ..setNow(_now, notify: false)
        ..jumpToNow();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // -------------------------------------------------------------- build

  StripData _build({required bool expand}) => buildStripData(
    tracks: widget.tracks,
    sessions: widget.sessions,
    nowMs: _now,
    sinceMs: widget.sinceMs,
    persons: ref.read(personsByIdProvider),
    substances: ref.read(substancesByIdProvider),
    showLifecycle: widget.showLifecycle,
    hiddenTrackIds: widget.hiddenTracks,
    expandCounterLabels: expand,
    openPersons: ref.read(stripOpenProvider)[widget.setId],
  );

  Widget _interactive({required Widget child, required bool lanes}) => Listener(
    onPointerSignal: _onSignal,
    child: MouseRegion(
      onHover: lanes ? _onHover : null,
      onExit: lanes ? (_) => _hover.value = null : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onTapUp: lanes ? _onTapUp : null,
        child: child,
      ),
    ),
  );

  /// The line above a lane: the colour dot and the name; a thing with the
  /// time since its last entry, a track with its live value, a person with
  /// whether it is open (a tap folds or opens it).
  Widget _nameLine(
    TikkyTokens t,
    StripRowData row, {
    required double top,
    required double height,
    required double width,
    required NowTicker ticker,
    required Map<String, OpenSession> open,
  }) {
    final s = t.strip;
    final left = s.nameInset + row.indent * s.subIndent;
    final color = row.dotArgb == null
        ? t.trackColor(row.track)
        : Color(row.dotArgb!);
    final name = Text(
      row.title,
      style: row.kind == StripRowKind.thing
          ? t.text.stripThing
          : t.text.stripName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final gap = SizedBox(width: s.nameGap);

    if (row.isPerson) {
      final isOpen = !row.folded;
      final line = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ColorDot(color: color, size: s.nameDot),
          gap,
          Flexible(child: name),
          gap,
          Flexible(
            child: Text(
              isOpen
                  ? TracksStrings.stripPersonOpen
                  : TracksStrings.stripPersonFolded(row.events.length),
              style: t.text.stripWord,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
      // A tap target of full height around the short name line.
      final target = t.sizes.minTapTarget;
      return Positioned(
        key: StripKeys.lane(row.id),
        left: 0,
        top: top + height / 2 - target / 2,
        height: target,
        child: Semantics(
          button: true,
          label: TracksStrings.stripPersonSemantics(row.title, open: isOpen),
          onTapHint: isOpen
              ? TracksStrings.stripPersonFold
              : TracksStrings.stripPersonUnfold,
          excludeSemantics: true,
          onTap: () => _togglePerson(row.id),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _togglePerson(row.id),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: left),
                child: Center(widthFactor: 1, child: line),
              ),
            ),
          ),
        ),
      );
    }

    Widget? extra;
    final from = row.timerFrom;
    if (from != null) {
      extra = _LaneTimer(
        key: StripKeys.timer(row.id),
        ticker: ticker,
        from: from,
        lockoutUntil: row.lockoutUntil,
      );
    } else if (row.kind == StripRowKind.track &&
        row.track.mode != TrackMode.protocol) {
      final session = open[row.track.id];
      if (session != null) {
        final prefs = t.prefs;
        extra = NowSelector<String>(
          key: StripKeys.value(row.id),
          selector: (now) => buildLaneView(
            track: row.track,
            open: session,
            nowMs: now,
            prefs: prefs,
          ).time.digits,
          builder: (context, digits) =>
              Text(digits, style: t.text.stripDigits, maxLines: 1),
        );
      }
    }
    return Positioned(
      key: StripKeys.lane(row.id),
      left: left,
      right: s.nameInset,
      top: top,
      height: height,
      child: IgnorePointer(
        child: Semantics(
          label: row.isSub
              ? TracksStrings.stripSubLane(row.track.name, row.title)
              : row.title,
          excludeSemantics: extra == null,
          child: Row(
            children: [
              if (row.kind != StripRowKind.thing) ...[
                ColorDot(color: color, size: s.nameDot),
                gap,
              ],
              Flexible(
                child: extra == null ? name : ExcludeSemantics(child: name),
              ),
              if (extra != null) ...[gap, extra],
            ],
          ),
        ),
      ),
    );
  }

  /// "Alles" and "Jetzt" at the bottom right.
  Widget _controls(TikkyTokens t) => Semantics(
    container: true,
    label: TracksStrings.stripControls,
    child: Row(
      key: StripKeys.controls,
      mainAxisSize: MainAxisSize.min,
      children: [
        PillButton(
          key: StripKeys.fit,
          label: TracksStrings.stripAll,
          semanticLabel: TracksStrings.stripFit,
          outlined: true,
          onPressed: _fit,
        ),
        SizedBox(width: t.space.sm),
        // Following already: nothing to jump to.
        ValueListenableBuilder<bool>(
          valueListenable: _following,
          builder: (context, following, _) => PillButton(
            key: StripKeys.now,
            label: TracksStrings.stripNow,
            semanticLabel: TracksStrings.stripToNow,
            outlined: true,
            onPressed: following ? null : _jumpToNow,
          ),
        ),
      ],
    ),
  );

  Widget _tooltip(TikkyTokens t, Size area) =>
      ValueListenableBuilder<({Offset at, String text})?>(
        valueListenable: _hover,
        builder: (context, hover, _) {
          if (hover == null) return const SizedBox.shrink();
          final maxWidth = math.min(t.strip.tooltipMaxWidth, area.width);
          final left = (hover.at.dx + t.space.md)
              .clamp(0.0, math.max(0.0, area.width - maxWidth))
              .toDouble();
          // Below the pointer; above it near the bottom edge.
          final below = hover.at.dy < area.height / 2;
          return Positioned(
            left: left,
            top: below ? hover.at.dy + t.space.lg : null,
            bottom: below ? null : area.height - hover.at.dy + t.space.sm,
            child: IgnorePointer(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: DecoratedBox(
                  key: StripKeys.tooltip,
                  decoration: t.surfaceDecoration(color: t.colors.surfaceAlt),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.space.sm,
                      vertical: t.space.xs,
                    ),
                    child: Text(
                      hover.text,
                      style: t.text.caption.copyWith(color: t.colors.text),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final t = context.tikky;
    final s = t.strip;
    final style = StripStyle.of(context);
    _style = style;
    final ticker = ref.watch(nowTickerProvider);
    // Offstage (another destination is shown): no ticks, no frames.
    _subscribe(TickerMode.valuesOf(context).enabled ? ticker : null);
    // Names and colours of persons and substances may change, and which
    // persons are open.
    ref
      ..watch(personsByIdProvider)
      ..watch(substancesByIdProvider)
      ..watch(stripOpenProvider.select((m) => m[widget.setId]));
    final open =
        ref.watch(openSessionsProvider).value ?? const <String, OpenSession>{};
    _viewport
      ..minSpanMs = s.minSpanMs
      ..fitMinSpanMs = s.fitMinSpanMs
      ..maxSpanFloorMs = s.maxSpanFloorMs
      ..followAnchor = s.followAnchor
      ..fitPadding = s.fitPadding
      ..foldPx = s.fold;

    return LayoutBuilder(
      builder: (context, constraints) {
        final axisHeight = style.axisHeight;
        final lanesHeight = math.max(0.0, constraints.maxHeight - axisHeight);
        // One lane per label only while everything fits.
        var data = _build(expand: true);
        if (data.contentHeight(style.metrics) > lanesHeight) {
          data = _build(expand: false);
        }
        _data = data;

        if (data.isEmpty) {
          _needsFit = true;
          return AdaptiveEmptyState(
            icon: AdaptiveIcons.history(context),
            title: TracksStrings.timelineEmptyTitle,
            message: data.hasActivity
                ? TracksStrings.timelineAllHidden
                : widget.emptyMessage,
          );
        }

        final width = math.max(0.0, constraints.maxWidth);
        final extent = stripExtent(data)!;
        _updateFolds(ticker.value, notify: false);
        _viewport
          ..setNow(ticker.value, notify: false)
          ..setExtent(extent.start, extent.end, live: data.live, notify: false)
          ..setWidth(width, notify: false);
        if (_needsFit && width > 0) {
          _viewport.fit(notify: false);
          _needsFit = false;
          // Quietly, because this is a build; "Jetzt" hears of it after.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _following.value = _viewport.following;
          });
        }

        final content = data.contentHeight(style.metrics);
        _lanesOverflow = content > lanesHeight;
        // Room below the last lane, so the buttons never hide a marker
        // for good.
        final reserve = t.sizes.minTapTarget + 2 * t.space.sm;
        final paintHeight = math.max(lanesHeight, content + reserve);
        final layout = layoutStrip(
          data: data,
          scale: _viewport.scale,
          width: width,
          nowMs: ticker.value,
          metrics: style.metrics,
        );

        final axis = SizedBox(
          height: axisHeight,
          child: _interactive(
            lanes: false,
            child: ExcludeSemantics(
              child: CustomPaint(
                key: StripKeys.axis,
                size: Size.infinite,
                painter: StripAxisPainter(
                  viewport: _viewport,
                  now: ticker,
                  style: style,
                  repaint: _repaint,
                ),
              ),
            ),
          ),
        );

        final lanes = SingleChildScrollView(
          child: SizedBox(
            height: paintHeight,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: _interactive(
                    lanes: true,
                    child: CustomPaint(
                      key: StripKeys.lanes,
                      painter: StripLanesPainter(
                        data: data,
                        viewport: _viewport,
                        now: ticker,
                        style: style,
                        semanticsEpoch: _semanticsEpoch,
                        onEvent: _openEvent,
                        onCluster: _openCluster,
                        repaint: _repaint,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                for (var i = 0; i < data.rows.length; i++)
                  _nameLine(
                    t,
                    data.rows[i],
                    top: layout.rowTops[i],
                    height: style.metrics.labelHeight,
                    width: width,
                    ticker: ticker,
                    open: open,
                  ),
                _tooltip(t, Size(width, paintHeight)),
              ],
            ),
          ),
        );

        return Focus(
          focusNode: _focus,
          autofocus: true,
          onKeyEvent: _onKey,
          child: Semantics(
            key: StripKeys.view,
            container: true,
            explicitChildNodes: true,
            label: TracksStrings.stripSemantics(
              data.rows.length,
              data.eventCount,
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    axis,
                    Expanded(child: lanes),
                  ],
                ),
                Positioned(
                  left: t.space.sm,
                  right: t.space.sm,
                  bottom: t.space.sm,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: _controls(t),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
