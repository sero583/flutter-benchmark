/// High-precision FPS tracker for benchmark measurement.
///
/// Collects per-frame timing data from a [Ticker] and computes statistics
/// including average/min/max FPS, percentile frame times, jank detection,
/// and a composite smoothness score. Adapts automatically to the display
/// refresh rate.
library;

import "dart:math";

/// Tracks frame timing and computes benchmark metrics.
///
/// Usage:
/// ```dart
/// final tracker = FpsTracker();
/// tracker.setDisplayRefreshRate(120.0); // optional
/// // Inside a Ticker callback:
/// tracker.onFrame(elapsed);
/// print(tracker.avgFps);
/// ```
class FpsTracker {
  final List<double> _frameTimes = [];
  final List<double> _fpsHistory = [];
  int _frameCount = 0;
  double _lastTimestamp = 0;
  double _totalFrameTimeMs = 0;
  double _minFps = double.infinity;
  double _maxFps = 0;
  double _currentFps = 0;
  Duration _totalElapsed = Duration.zero;

  /// Offset captured on the first frame after reset, so that elapsed
  /// time does not include warmup or prior phases.
  Duration? _resetTimestamp;

  /// Cached sorted frame times — invalidated on each new frame.
  List<double>? _sortedFrameTimes;

  /// Target frame time based on display refresh rate (default 60 Hz).
  double _targetFrameTimeMs = 16.667;

  /// Target FPS derived from display refresh rate.
  double _targetFps = 60.0;

  /// The target FPS for external callers (e.g. warmup window sizing).
  double get targetFps => _targetFps;

  /// Instantaneous FPS of the most recent frame.
  double get currentFps => _currentFps;

  /// Average FPS computed as totalFrames / totalSeconds — the correct
  /// harmonic-mean equivalent that avoids the upward bias of averaging
  /// instantaneous per-frame FPS values.
  double get avgFps => _totalFrameTimeMs > 0
      ? _frameTimes.length * 1000.0 / _totalFrameTimeMs
      : 0;

  /// Lowest instantaneous FPS recorded.
  double get minFps => _minFps == double.infinity ? 0 : _minFps;

  /// Highest instantaneous FPS recorded.
  double get maxFps => _maxFps;

  /// Total number of frames recorded (including the first partial frame).
  int get frameCount => _frameCount;

  /// Wall-clock time elapsed since the last [reset].
  Duration get elapsed => _totalElapsed;

  /// Unmodifiable copy of the FPS history (one entry per frame).
  List<double> get fpsHistory => List.unmodifiable(_fpsHistory);

  /// Unmodifiable copy of per-frame durations in milliseconds.
  List<double> get frameTimes => List.unmodifiable(_frameTimes);

  /// Lazily compute and cache sorted frame times.
  List<double> get _sorted {
    _sortedFrameTimes ??= List<double>.from(_frameTimes)..sort();
    return _sortedFrameTimes!;
  }

  /// The average FPS of the slowest 1 % of frames.
  double get onePercentLow {
    if (_frameTimes.length < 100) return 0;
    final sorted = _sorted;
    final n = max(1, (sorted.length * 0.01).ceil());
    final worst = sorted.reversed.take(n).fold(0.0, (a, b) => a + b);
    return 1000.0 / (worst / n);
  }

  /// Mean frame time in milliseconds.
  double get avgFrameTimeMs =>
      _frameTimes.isEmpty ? 0 : _totalFrameTimeMs / _frameTimes.length;

  /// Longest single frame time in milliseconds.
  double get maxFrameTimeMs =>
      _frameTimes.isEmpty ? 0 : _frameTimes.reduce(max);

  /// 95th-percentile frame time in milliseconds.
  double get p95FrameTimeMs => _percentile(0.95);

  /// 99th-percentile frame time in milliseconds.
  double get p99FrameTimeMs => _percentile(0.99);

  /// Standard deviation of frame times.
  double get stdDevFrameTimeMs {
    if (_frameTimes.length < 2) return 0;
    final mean = avgFrameTimeMs;
    final sumSq = _frameTimes.fold(0.0, (s, v) => s + (v - mean) * (v - mean));
    return sqrt(sumSq / (_frameTimes.length - 1));
  }

  /// Number of frames that exceeded the target vsync interval.
  int get jankCount => _frameTimes.where((t) => t > _targetFrameTimeMs).length;

  /// Percentage of frames that were janky.
  double get jankPercent =>
      _frameTimes.isEmpty ? 0 : jankCount / _frameTimes.length * 100;

  /// Composite smoothness score (0–100) combining jank rate and FPS ratio.
  ///
  /// Uses exponential decay to avoid the hard cliff at 20 % jank that a
  /// linear formula would produce.
  double get smoothnessScore {
    if (_frameTimes.isEmpty) return 0;
    final jankPenalty = exp(-0.05 * jankPercent) * 100;
    final fpsFactor = (avgFps / _targetFps).clamp(0.0, 1.0);
    return (jankPenalty * fpsFactor).toDouble();
  }

  double _percentile(double p) {
    if (_frameTimes.isEmpty) return 0;
    final sorted = _sorted;
    final idx = (sorted.length * p).floor().clamp(0, sorted.length - 1);
    return sorted[idx];
  }

  /// Set the display refresh rate so that jank and smoothness computations
  /// adapt automatically. Call this once when the benchmark starts.
  void setDisplayRefreshRate(double hz) {
    if (hz > 0) {
      _targetFps = hz;
      _targetFrameTimeMs = 1000.0 / hz;
    }
  }

  /// Record a frame from a [Ticker] callback.
  void onFrame(Duration timestamp) {
    final double ms = timestamp.inMicroseconds / 1000.0;
    if (_lastTimestamp > 0) {
      final double delta = ms - _lastTimestamp;
      if (delta > 0) {
        final double fps = 1000.0 / delta;
        _frameTimes.add(delta);
        _fpsHistory.add(fps);
        _totalFrameTimeMs += delta;
        _currentFps = fps;
        if (fps < _minFps) _minFps = fps;
        if (fps > _maxFps) _maxFps = fps;
        _sortedFrameTimes = null;
      }
    }
    _lastTimestamp = ms;
    _frameCount++;
    _resetTimestamp ??= timestamp;
    _totalElapsed = timestamp - _resetTimestamp!;
  }

  /// Discard all recorded data and start fresh.
  void reset() {
    _frameTimes.clear();
    _fpsHistory.clear();
    _frameCount = 0;
    _lastTimestamp = 0;
    _totalFrameTimeMs = 0;
    _minFps = double.infinity;
    _maxFps = 0;
    _currentFps = 0;
    _totalElapsed = Duration.zero;
    _resetTimestamp = null;
    _sortedFrameTimes = null;
  }
}
