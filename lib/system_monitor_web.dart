/// System resource monitor stub for web platforms.
///
/// Most system-level metrics (VRAM, GPU temp, CPU %) are unavailable on the
/// web.  This implementation returns what it can (JS heap size in Chrome)
/// and reports −1 / 0 for everything else.
library;

import "dart:async";

export "resource_types.dart";

import "resource_types.dart";

/// Web implementation of [SystemMonitor].
///
/// Only JS heap metrics are available (Chrome only via `performance.memory`).
/// All GPU and system-level metrics report unavailable (−1 / 0).
class SystemMonitor {
  /// Sampling interval between snapshots.
  final Duration interval;
  final List<ResourceSnapshot> _snapshots = [];
  Timer? _timer;

  SystemMonitor({this.interval = const Duration(seconds: 1)});

  /// Most recent snapshot, or `null` if no samples yet.
  ResourceSnapshot? get latest => _snapshots.isEmpty ? null : _snapshots.last;

  /// All collected snapshots as an unmodifiable list.
  List<ResourceSnapshot> get snapshots => List.unmodifiable(_snapshots);

  /// Start periodic sampling.
  void start() {
    _snapshots.clear();
    _sample();
    _timer = Timer.periodic(interval, (_) => _sample());
  }

  /// Stop periodic sampling.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Reset all collected data.
  void reset() {
    _snapshots.clear();
  }

  /// Compute an aggregated summary from all snapshots.
  ResourceSummary get summary {
    if (_snapshots.isEmpty) return const ResourceSummary();

    double peakRss = 0, sumRss = 0;
    for (final s in _snapshots) {
      if (s.dartRssMb > peakRss) peakRss = s.dartRssMb;
      sumRss += s.dartRssMb;
    }
    final n = _snapshots.length;
    return ResourceSummary(
      peakDartRssMb: peakRss,
      avgDartRssMb: sumRss / n,
      sampleCount: n,
    );
  }

  void _sample() {
    // On web we can try to read JS heap size (Chrome only).
    double jsHeapMb = 0;
    try {
      jsHeapMb = _getJsHeapUsedMb();
    } catch (_) {}

    _snapshots.add(
      ResourceSnapshot(timestamp: DateTime.now(), dartRssMb: jsHeapMb),
    );
  }

  /// Attempts to read Chrome's `performance.memory.usedJSHeapSize`.
  ///
  /// Returns 0 because `performance.memory` is Chrome-only and non-standard.
  /// A future iteration could use `dart:js_interop` to read the value in
  /// Chromium-based browsers.
  static double _getJsHeapUsedMb() {
    return 0;
  }
}
