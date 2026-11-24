import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Figures over the frames a [FrameStats] holds.
@immutable
final class FrameSummary {
  const FrameSummary({
    required this.frames,
    required this.avgBuildMs,
    required this.avgRasterMs,
    required this.worstMs,
    required this.slow,
  });

  static const empty = FrameSummary(
    frames: 0,
    avgBuildMs: 0,
    avgRasterMs: 0,
    worstMs: 0,
    slow: 0,
  );

  final int frames;
  final double avgBuildMs;
  final double avgRasterMs;

  /// The longest frame (build + raster).
  final double worstMs;

  /// Frames that took longer than the budget of one display refresh.
  final int slow;
}

/// Build and raster times of the last frames, in memory only. Shown on the
/// developer page in the settings; measures the app's drawing, never
/// anything about the tracks.
class FrameStats {
  FrameStats({this.capacity = 600});

  /// The stats of the running app.
  static final instance = FrameStats();

  final int capacity;
  final ListQueue<(int buildUs, int rasterUs)> _frames = ListQueue();
  bool _attached = false;

  /// Time from start to the first frame, set once by `main.dart`.
  int? startupMs;

  /// Starts collecting from the engine. Safe to call more than once.
  void attach() {
    if (_attached) return;
    _attached = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      add(t.buildDuration, t.rasterDuration);
    }
  }

  void add(Duration build, Duration raster) {
    _frames.addLast((build.inMicroseconds, raster.inMicroseconds));
    while (_frames.length > capacity) {
      _frames.removeFirst();
    }
  }

  void clear() => _frames.clear();

  /// [budgetMs]: the time one frame may take (1000 / refresh rate).
  FrameSummary summary({double budgetMs = 1000 / 60}) {
    if (_frames.isEmpty) return FrameSummary.empty;
    var build = 0;
    var raster = 0;
    var worst = 0;
    var slow = 0;
    final budgetUs = budgetMs * 1000;
    for (final (b, r) in _frames) {
      build += b;
      raster += r;
      if (b + r > worst) worst = b + r;
      if (b + r > budgetUs) slow++;
    }
    final n = _frames.length;
    return FrameSummary(
      frames: n,
      avgBuildMs: build / n / 1000,
      avgRasterMs: raster / n / 1000,
      worstMs: worst / 1000,
      slow: slow,
    );
  }
}

/// The app's [FrameStats]; tests override it with a fresh one.
final frameStatsProvider = Provider<FrameStats>((ref) => FrameStats.instance);
