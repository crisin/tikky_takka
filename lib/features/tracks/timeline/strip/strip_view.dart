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
import '../../tracks_strings.dart';
import '../timeline_logic.dart';
import 'strip_detail.dart';
import 'strip_model.dart';
import 'strip_painter.dart';
import 'strip_viewport.dart';

/// Keys of the strip (for tests).
abstract final class StripKeys {
  static const view = ValueKey('strip-view');
  static const lanes = ValueKey('strip-lanes');
  static const axis = ValueKey('strip-axis');
  static const gutter = ValueKey('strip-gutter');
  static const controls = ValueKey('strip-controls');
  static const zoomIn = ValueKey('strip-zoom-in');
  static const zoomOut = ValueKey('strip-zoom-out');
  static const fit = ValueKey('strip-fit');
  static const now = ValueKey('strip-now');
  static const tooltip = ValueKey('strip-tooltip');

  /// The name of a lane in the gutter; [rowId] is `StripRowData.id`.
  static Key lane(String rowId) => ValueKey('strip-lane-$rowId');

  /// The timer of a lane in the gutter.
  static Key timer(String rowId) => ValueKey('strip-timer-$rowId');
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
            style: t.text.digitsSmall.copyWith(
              color: locked ? t.colors.warning : t.colors.text,
              fontWeight: FontWeight.w600,
            ),
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

/// "Streifen": the timeline of a set as a strip. Time runs from left to
/// right, every track has its lane, the names stay put on the left.
///
/// * Sessions are bars in the track's colour (paused stretches hatched,
///   running ones grow up to the "now" line), events are markers on them;
///   markers that would overlap become a pill with their number.
/// * Drag to pan, pinch or Ctrl + wheel to zoom, the wheel scrolls along
///   the time. Buttons: closer, further, "Alles zeigen", "Jetzt" (jumps
///   to the "now" line and follows it until the user pans).
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

  StripLayout _layout() {
    final style = _style ?? StripStyle.of(context);
    return layoutStrip(
      data: _data,
      startMs: _viewport.startMs,
      msPerPx: _viewport.msPerPx,
      width: _viewport.width,
      nowMs: _now,
      metrics: style.metrics,
    );
  }

  StripHit? _hit(Offset position) =>
      _layout().hitTest(position, slop: context.tikky.strip.hitSlop);

  // ------------------------------------------------------------ actions

  void _zoomButton(double factor) {
    ref.read(hapticsProvider).selection();
    _viewport.zoomBy(factor);
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

  Widget _gutterRow(
    TikkyTokens t,
    StripRowData row,
    double height,
    NowTicker ticker,
  ) {
    final color = row.dotArgb == null
        ? t.trackColor(row.track)
        : Color(row.dotArgb!);
    final indent = row.indent > 0 ? row.indent : (row.isSub ? 1 : 0);
    final title = Text(
      row.title,
      style: row.isSub
          ? t.text.caption.copyWith(color: t.colors.text)
          : t.text.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final from = row.timerFrom;
    return SizedBox(
      key: StripKeys.lane(row.id),
      height: height,
      child: Padding(
        padding: EdgeInsets.only(
          left: t.space.sm + indent * t.strip.subIndent,
          right: t.space.xs,
        ),
        child: Semantics(
          label: row.isSub
              ? TracksStrings.stripSubLane(row.track.name, row.title)
              : row.title,
          excludeSemantics: from == null,
          child: Row(
            children: [
              ColorDot(color: color),
              SizedBox(width: t.space.xs),
              Expanded(
                child: from == null
                    ? title
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ExcludeSemantics(child: title),
                          _LaneTimer(
                            key: StripKeys.timer(row.id),
                            ticker: ticker,
                            from: from,
                            lockoutUntil: row.lockoutUntil,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Closer, further, "Alles zeigen", "Jetzt". On a phone the last two
  /// are icons as well (their names are the tooltips), so the bar fits.
  Widget _controls(TikkyTokens t, {required bool narrow}) => Semantics(
    container: true,
    label: TracksStrings.stripControls,
    child: DecoratedBox(
      key: StripKeys.controls,
      decoration: t.surfaceDecoration(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdaptiveIconButton(
              key: StripKeys.zoomOut,
              icon: Icons.remove_rounded,
              semanticLabel: TracksStrings.stripZoomOut,
              onPressed: () => _zoomButton(1 / t.strip.zoomStep),
            ),
            AdaptiveIconButton(
              key: StripKeys.zoomIn,
              icon: Icons.add_rounded,
              semanticLabel: TracksStrings.stripZoomIn,
              onPressed: () => _zoomButton(t.strip.zoomStep),
            ),
            KeyedSubtree(
              key: StripKeys.fit,
              child: narrow
                  ? AdaptiveIconButton(
                      icon: Icons.fit_screen_outlined,
                      semanticLabel: TracksStrings.stripFit,
                      onPressed: _fit,
                    )
                  : AdaptiveTextButton(
                      label: TracksStrings.stripFit,
                      onPressed: _fit,
                    ),
            ),
            // Following already: nothing to jump to.
            ValueListenableBuilder<bool>(
              valueListenable: _following,
              builder: (context, following, _) => KeyedSubtree(
                key: StripKeys.now,
                child: narrow
                    ? AdaptiveIconButton(
                        icon: Icons.keyboard_tab_rounded,
                        semanticLabel: TracksStrings.stripNow,
                        onPressed: following ? null : _jumpToNow,
                      )
                    : AdaptiveTextButton(
                        label: TracksStrings.stripNow,
                        onPressed: following ? null : _jumpToNow,
                      ),
              ),
            ),
          ],
        ),
      ),
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
    // Names and colours of persons and substances may change.
    ref
      ..watch(personsByIdProvider)
      ..watch(substancesByIdProvider);
    _viewport
      ..minSpanMs = s.minSpanMs
      ..fitMinSpanMs = s.fitMinSpanMs
      ..maxSpanFloorMs = s.maxSpanFloorMs
      ..followAnchor = s.followAnchor
      ..fitPadding = s.fitPadding;

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

        final narrow = constraints.maxWidth < s.narrowBreakpoint;
        final gutter = narrow ? s.gutterNarrow : s.gutter;
        final width = math.max(0.0, constraints.maxWidth - gutter);
        final extent = stripExtent(data)!;
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
          startMs: _viewport.startMs,
          msPerPx: _viewport.msPerPx,
          width: width,
          nowMs: ticker.value,
          metrics: style.metrics,
        );

        final axis = SizedBox(
          height: axisHeight,
          child: Row(
            children: [
              SizedBox(
                width: gutter,
                height: axisHeight,
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: StripCornerPainter(
                      viewport: _viewport,
                      style: style,
                    ),
                  ),
                ),
              ),
              Expanded(
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
              ),
            ],
          ),
        );

        final lanes = SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                key: StripKeys.gutter,
                width: gutter,
                height: paintHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border(right: t.hairline)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < data.rows.length; i++)
                        _gutterRow(
                          t,
                          data.rows[i],
                          layout.rowHeights[i],
                          ticker,
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
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
                      _tooltip(t, Size(width, paintHeight)),
                    ],
                  ),
                ),
              ),
            ],
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
                    child: _controls(t, narrow: narrow),
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
