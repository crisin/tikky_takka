import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Which stretch of time the strip shows: the instant at its left edge
/// and how many milliseconds one logical pixel covers.
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
class StripViewport extends ChangeNotifier {
  StripViewport({
    this.minSpanMs = 10 * 1000,
    this.fitMinSpanMs = 60 * 1000,
    this.maxSpanFloorMs = 10 * 60 * 1000,
    this.followAnchor = 0.82,
    this.fitPadding = 0.06,
  });

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

  double _startMs = 0;
  double _msPerPx = 1000;
  double _width = 0;
  int _extentStart = 0;
  int _extentEnd = 0;
  bool _live = false;
  int _nowMs = 0;
  bool _following = false;

  /// The instant at the left edge.
  double get startMs => _startMs;

  /// Milliseconds per logical pixel.
  double get msPerPx => _msPerPx;

  /// Width of the lanes in logical pixels.
  double get width => _width;

  /// The time across the width.
  double get spanMs => _width * _msPerPx;

  /// The instant at the right edge.
  double get endMs => _startMs + spanMs;

  bool get following => _following;

  int get nowMs => _nowMs;

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
    final whole = (extentEnd - _extentStart) * (1 + 2 * fitPadding);
    return math.max(math.max(whole, maxSpanFloorMs.toDouble()), minSpanMs) /
        _width;
  }

  /// Horizontal position of the instant [ms].
  double xOf(num ms) => (ms - _startMs) / _msPerPx;

  /// The instant at the horizontal position [x].
  double timeAt(double x) => _startMs + x * _msPerPx;

  void _clamp() {
    if (_width <= 0) return;
    _msPerPx = _msPerPx.clamp(minMsPerPx, maxMsPerPx);
    final half = spanMs / 2;
    final lo = _extentStart - half;
    final hi = math.max(lo, extentEnd - half);
    _startMs = _startMs.clamp(lo, hi);
  }

  void _pinNow() {
    _startMs = _nowMs - followAnchor * spanMs;
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
    _startMs -= dx * _msPerPx;
    _clamp();
    _changed(notify);
  }

  /// Zooms by [factor] (> 1 = closer) so that the instant under [x] stays
  /// where it is. While following, "now" stays where it is instead.
  void zoomAround(double x, double factor, {bool notify = true}) {
    if (_width <= 0 || factor <= 0 || factor == 1) return;
    final anchorX = _following ? xOf(_nowMs) : x;
    final anchorMs = timeAt(anchorX);
    _msPerPx = (_msPerPx / factor).clamp(minMsPerPx, maxMsPerPx);
    _startMs = anchorMs - anchorX * _msPerPx;
    _clamp();
    _changed(notify);
  }

  /// Zooms around the middle (the zoom buttons and keys).
  void zoomBy(double factor, {bool notify = true}) =>
      zoomAround(_width / 2, factor, notify: notify);

  /// Shows [from] to [to] with a little air on both sides. Ends following.
  void showRange(num from, num to, {bool notify = true}) {
    if (_width <= 0) return;
    _following = false;
    final length = math.max(0, to - from) * (1 + 2 * fitPadding);
    _msPerPx = (math.max(length, minSpanMs) / _width).clamp(
      minMsPerPx,
      maxMsPerPx,
    );
    _startMs = (from + to) / 2 - spanMs / 2;
    _clamp();
    _changed(notify);
  }

  /// "Alles zeigen": the whole range. Ends following.
  void fit({bool notify = true}) {
    if (_width <= 0) return;
    _following = false;
    final from = _extentStart;
    final to = math.max(from, fitEnd);
    final length = math.max(
      (to - from) * (1 + 2 * fitPadding),
      fitMinSpanMs.toDouble(),
    );
    _msPerPx = (length / _width).clamp(minMsPerPx, maxMsPerPx);
    _startMs = (from + to) / 2 - spanMs / 2;
    _clamp();
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
