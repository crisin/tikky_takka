import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A stretch without any event that the strip draws narrow ("Falte"):
/// from [from] to [to], UTC milliseconds.
@immutable
final class StripFold {
  const StripFold(this.from, this.to);

  final int from;
  final int to;

  int get lengthMs => to - from;

  @override
  bool operator ==(Object other) =>
      other is StripFold && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'StripFold($from..$to)';
}

/// The folds of a strip: every stretch of at least [minGapMs] between two
/// neighbouring instants of [times] (and from the last one up to "now"),
/// less [padMs] at both ends so the markers keep some room.
///
/// * Nothing within [keepRecentMs] before [nowMs] is folded: what just
///   happened stays readable.
/// * [times] are the moments that must stay visible: events, starts,
///   ends and pauses of sessions. A bar that simply runs is no reason to
///   keep a stretch - it is drawn through the fold.
/// * Pure; [times] in any order.
List<StripFold> computeFolds(
  Iterable<int> times, {
  required int nowMs,
  required int minGapMs,
  required int keepRecentMs,
  required int padMs,
}) {
  final sorted = times.toList()..sort();
  if (sorted.isEmpty || minGapMs <= 0) return const [];
  final limit = nowMs - keepRecentMs;
  final folds = <StripFold>[];
  // [b] is an instant to keep room before (not the edge of the recent
  // stretch).
  void gap(int a, int b, {required bool padEnd}) {
    final end = math.min(b, limit);
    if (end - a < minGapMs) return;
    final from = a + padMs;
    final to = padEnd && end == b ? b - padMs : end;
    if (to > from) folds.add(StripFold(from, to));
  }

  for (var i = 0; i + 1 < sorted.length; i++) {
    gap(sorted[i], sorted[i + 1], padEnd: true);
  }
  if (sorted.last < limit) gap(sorted.last, limit, padEnd: false);
  return List.unmodifiable(folds);
}

/// Time <-> horizontal position of the strip.
///
/// Linear at [msPerPx] from [startMs] at x = 0, except that every fold
/// that would be wider than [foldPx] is drawn exactly [foldPx] wide.
/// Before and after a fold the scale is the same. Positions are monotonic
/// in time, and [timeAt] undoes [xOf].
///
/// Works with "drawn" milliseconds: real time with each active fold
/// shrunk to `foldPx * msPerPx`.
@immutable
final class TimeScale {
  TimeScale({
    required this.startMs,
    required this.msPerPx,
    List<StripFold> folds = const [],
    this.foldPx = 0,
  }) : folds = [
         for (final f in folds)
           if (msPerPx > 0 && f.lengthMs / msPerPx > foldPx) f,
       ] {
    _startDrawn = drawnMs(startMs);
  }

  /// A plain linear scale.
  TimeScale.linear({required this.startMs, required this.msPerPx})
    : folds = const [],
      foldPx = 0 {
    _startDrawn = startMs;
  }

  final double startMs;
  final double msPerPx;

  /// The folds that are drawn narrower than they are, in time order.
  final List<StripFold> folds;
  final double foldPx;
  late final double _startDrawn;

  double get _foldDrawnMs => foldPx * msPerPx;

  /// [ms] with every fold before it shrunk.
  double drawnMs(num ms) {
    var d = ms.toDouble();
    for (final f in folds) {
      if (ms <= f.from) break;
      final inside = math.min(ms.toDouble(), f.to.toDouble()) - f.from;
      d -= inside * (1 - _foldDrawnMs / f.lengthMs);
    }
    return d;
  }

  /// The real instant of the drawn time [drawn] (undoes [drawnMs]).
  double realMs(double drawn) {
    var removed = 0.0;
    for (final f in folds) {
      final drawnFrom = f.from - removed;
      if (drawn <= drawnFrom) break;
      final drawnTo = drawnFrom + _foldDrawnMs;
      if (drawn <= drawnTo) {
        return f.from + (drawn - drawnFrom) / _foldDrawnMs * f.lengthMs;
      }
      removed += f.lengthMs - _foldDrawnMs;
    }
    return drawn + removed;
  }

  /// Horizontal position of the instant [ms].
  double xOf(num ms) => (drawnMs(ms) - _startDrawn) / msPerPx;

  /// The instant at the horizontal position [x].
  double timeAt(double x) => realMs(_startDrawn + x * msPerPx);

  /// Whether [ms] lies inside a fold.
  bool isFolded(num ms) => foldAt(ms) != null;

  /// The fold that [ms] lies in, if any.
  StripFold? foldAt(num ms) {
    for (final f in folds) {
      if (ms < f.from) return null;
      if (ms <= f.to) return f;
    }
    return null;
  }
}

/// Which stretch of time the strip shows: the instant at its left edge,
/// how many milliseconds one logical pixel covers, and the folds.
///
/// The painters repaint by listening to this; nothing is rebuilt while
/// the user pans or zooms. All positions are relative to the left edge of
/// the lanes (the fixed names are not part of it).
///
/// * The zoom stays between [minSpanMs] across the width and the whole
///   range (see [setExtent]) with a little air.
/// * The middle of the view stays inside the range, so the content can
///   never be lost.
/// * While [following], "now" is pinned at [followAnchor] of the width;
///   panning ends that, [jumpToNow] starts it again.
/// * Panning and zooming work on the drawn time ([TimeScale]): a fold is
///   crossed as fast as [foldPx] pixels.
class StripViewport extends ChangeNotifier {
  StripViewport({
    this.minSpanMs = 10 * 1000,
    this.fitMinSpanMs = 60 * 1000,
    this.maxSpanFloorMs = 10 * 60 * 1000,
    this.followAnchor = 0.82,
    this.fitPadding = 0.06,
    double foldPx = 24,
    // A named parameter cannot set a private field directly.
    // ignore: prefer_initializing_formals
  }) : _foldPx = foldPx;

  /// The closest zoom: this many milliseconds across the width.
  int minSpanMs;

  /// "Alles zeigen" never shows less than this.
  int fitMinSpanMs;

  /// Zooming out always reaches at least this.
  int maxSpanFloorMs;

  /// Where "now" sits while it is followed (share of the width).
  double followAnchor;

  /// Free room on both sides of [fit] (share of the range).
  double fitPadding;

  /// Width of a fold in logical pixels.
  double get foldPx => _foldPx;
  set foldPx(double value) {
    if (value == _foldPx) return;
    _foldPx = value;
    _scale = null;
  }

  double _foldPx;

  double _startMs = 0;
  double _msPerPx = 1000;
  double _width = 0;
  int _extentStart = 0;
  int _extentEnd = 0;
  bool _live = false;
  int _nowMs = 0;
  bool _following = false;
  List<StripFold> _folds = const [];
  TimeScale? _scale;

  /// The instant at the left edge.
  double get startMs => _startMs;

  /// Milliseconds per logical pixel (outside the folds).
  double get msPerPx => _msPerPx;

  /// Width of the lanes in logical pixels.
  double get width => _width;

  /// The drawn time across the width (the real time without folds).
  double get spanMs => _width * _msPerPx;

  /// The instant at the right edge.
  double get endMs => timeAt(_width);

  bool get following => _following;

  int get nowMs => _nowMs;

  /// The stretches that are drawn narrow.
  List<StripFold> get folds => _folds;

  /// Time <-> position for the current view.
  TimeScale get scale => _scale ??= _scaleAt(_startMs, _msPerPx);

  TimeScale _scaleAt(double startMs, double msPerPx) => TimeScale(
    startMs: startMs,
    msPerPx: msPerPx,
    folds: _folds,
    foldPx: foldPx,
  );

  /// Start of the range that can be shown.
  int get extentStart => _extentStart;

  /// End of the range that can be shown: "now" is always reachable.
  int get extentEnd => math.max(_extentEnd, _nowMs);

  /// End of what "Alles zeigen" shows: "now" only while something is
  /// still going on.
  int get fitEnd => _live ? extentEnd : _extentEnd;

  double get minMsPerPx => _width <= 0 ? 1 : minSpanMs / _width;

  double get maxMsPerPx {
    if (_width <= 0) return double.maxFinite;
    final s = scale;
    final whole =
        (s.drawnMs(extentEnd) - s.drawnMs(_extentStart)) * (1 + 2 * fitPadding);
    return math.max(math.max(whole, maxSpanFloorMs.toDouble()), minSpanMs) /
        _width;
  }

  /// Horizontal position of the instant [ms].
  double xOf(num ms) => scale.xOf(ms);

  /// The instant at the horizontal position [x].
  double timeAt(double x) => scale.timeAt(x);

  /// Puts the drawn time [drawn] at the left edge (at [msPerPx]).
  void _setStartDrawn(double drawn, double msPerPx) {
    _msPerPx = msPerPx;
    _scale = null;
    _startMs = _scaleAt(0, msPerPx).realMs(drawn);
    _scale = null;
  }

  void _clamp() {
    if (_width <= 0) return;
    final mpp = _msPerPx.clamp(minMsPerPx, maxMsPerPx);
    final s = _scaleAt(0, mpp);
    final half = _width * mpp / 2;
    final lo = s.drawnMs(_extentStart) - half;
    final hi = math.max(lo, s.drawnMs(extentEnd) - half);
    _setStartDrawn(s.drawnMs(_startMs).clamp(lo, hi), mpp);
  }

  void _pinNow() {
    final s = _scaleAt(0, _msPerPx);
    _setStartDrawn(s.drawnMs(_nowMs) - followAnchor * spanMs, _msPerPx);
  }

  void _changed(bool notify) {
    if (notify) notifyListeners();
  }

  /// The width of the lanes changed (layout). The left edge and the zoom
  /// stay as they are.
  void setWidth(double width, {bool notify = true}) {
    if (width == _width) return;
    _width = width;
    if (_following) _pinNow();
    _clamp();
    _changed(notify);
  }

  /// The range of the content: from [start] to [end]; with [live] it
  /// reaches up to "now" (something is still going on).
  void setExtent(int start, int end, {required bool live, bool notify = true}) {
    final to = math.max(start, end);
    if (start == _extentStart && to == _extentEnd && live == _live) return;
    _extentStart = start;
    _extentEnd = to;
    _live = live;
    _clamp();
    _changed(notify);
  }

  /// The stretches to draw narrow (see [computeFolds]). What is at the
  /// left edge stays there; while following, "now" stays in its place.
  void setFolds(List<StripFold> folds, {bool notify = true}) {
    if (listEquals(folds, _folds)) return;
    _folds = List.unmodifiable(folds);
    _scale = null;
    if (_following) _pinNow();
    _clamp();
    _changed(notify);
  }

  /// Time passed. Only moves the view (and notifies) while following.
  void setNow(int nowMs, {bool notify = true}) {
    if (nowMs == _nowMs) return;
    _nowMs = nowMs;
    if (!_following) return;
    final before = _startMs;
    _pinNow();
    _clamp();
    if (_startMs != before) _changed(notify);
  }

  /// Drags the content by [dx] pixels (positive = to the right, towards
  /// earlier times). Ends following.
  void panBy(double dx, {bool notify = true}) {
    if (dx == 0) return;
    _following = false;
    final s = _scaleAt(0, _msPerPx);
    _setStartDrawn(s.drawnMs(_startMs) - dx * _msPerPx, _msPerPx);
    _clamp();
    _changed(notify);
  }

  /// Zooms by [factor] (> 1 = closer) so that the instant under [x] stays
  /// where it is. While following, "now" stays where it is instead.
  void zoomAround(double x, double factor, {bool notify = true}) {
    if (_width <= 0 || factor <= 0 || factor == 1) return;
    final anchorX = _following ? xOf(_nowMs) : x;
    final anchorMs = timeAt(anchorX);
    final mpp = (_msPerPx / factor).clamp(minMsPerPx, maxMsPerPx);
    final s = _scaleAt(0, mpp);
    _setStartDrawn(s.drawnMs(anchorMs) - anchorX * mpp, mpp);
    _clamp();
    _changed(notify);
  }

  /// Zooms around the middle (the zoom buttons and keys).
  void zoomBy(double factor, {bool notify = true}) =>
      zoomAround(_width / 2, factor, notify: notify);

  /// Puts [from] to [to] (drawn) in the middle, at least [minLength]
  /// across, with a little air on both sides.
  void _show(num from, num to, double minLength) {
    // Which folds are active depends on the zoom: settle it in two steps.
    var mpp = _msPerPx;
    for (var i = 0; i < 2; i++) {
      final s = _scaleAt(0, mpp);
      final length =
          math.max(0.0, s.drawnMs(to) - s.drawnMs(from)) * (1 + 2 * fitPadding);
      mpp = (math.max(length, minLength) / _width).clamp(
        minMsPerPx,
        maxMsPerPx,
      );
    }
    final s = _scaleAt(0, mpp);
    final middle = (s.drawnMs(from) + s.drawnMs(to)) / 2;
    _setStartDrawn(middle - _width * mpp / 2, mpp);
    _clamp();
  }

  /// Shows [from] to [to] with a little air on both sides. Ends following.
  void showRange(num from, num to, {bool notify = true}) {
    if (_width <= 0) return;
    _following = false;
    _show(from, to, minSpanMs.toDouble());
    _changed(notify);
  }

  /// "Alles zeigen": the whole range. Ends following.
  void fit({bool notify = true}) {
    if (_width <= 0) return;
    _following = false;
    final from = _extentStart;
    _show(from, math.max(from, fitEnd), fitMinSpanMs.toDouble());
    _changed(notify);
  }

  /// "Jetzt": jumps to the "now" line and follows it.
  void jumpToNow({bool notify = true}) {
    _following = true;
    _pinNow();
    _clamp();
    _changed(notify);
  }
}
