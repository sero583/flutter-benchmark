/// Benchmark runner page — executes a single benchmark with live FPS tracking.
///
/// Shows the benchmark scene full-screen with a HUD overlay displaying
/// real-time metrics, a warmup indicator, and a completion card when done.
library;

import "dart:async";
import "dart:math";
import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";

import "benchmark_defs.dart";
import "fps_tracker.dart";
import "models.dart";
import "system_monitor.dart";
import "theme.dart";

/// Page that runs a single [BenchmarkDef] and reports a [BenchmarkResult].
class BenchmarkRunnerPage extends StatefulWidget {
  /// The benchmark to execute.
  final BenchmarkDef benchmark;

  /// The detected renderer name (e.g. "Impeller (Vulkan)").
  final String renderer;

  /// Called with the final result when the benchmark completes.
  final void Function(BenchmarkResult) onComplete;

  const BenchmarkRunnerPage({
    super.key,
    required this.benchmark,
    required this.renderer,
    required this.onComplete,
  });

  @override
  State<BenchmarkRunnerPage> createState() => _BenchmarkRunnerPageState();
}

class _BenchmarkRunnerPageState extends State<BenchmarkRunnerPage>
    with SingleTickerProviderStateMixin {
  final FpsTracker _tracker = FpsTracker();
  final SystemMonitor _monitor = SystemMonitor();
  late final Ticker _ticker;
  bool _running = true;
  bool _warmingUp = true;
  Timer? _timer;
  Timer? _hudTimer;
  BenchmarkResult? _cachedResult;
  ResourceSnapshot? _latestSnapshot;

  // Adaptive warmup: minimum 1 s, maximum 5 s.
  // Ends early when FPS variance stabilizes (stddev of last N frames
  // drops below 10% of the mean).
  static const _warmupMin = Duration(seconds: 1);
  static const _warmupMax = Duration(seconds: 5);

  /// HUD refresh interval in milliseconds (4 Hz).
  static const _hudIntervalMs = 250;

  /// Delay before auto-popping the page after completion.
  static const _completionDelay = Duration(seconds: 2);

  final List<double> _warmupFps = [];
  Timer? _warmupMaxTimer;
  bool _warmupMinPassed = false;

  @override
  void initState() {
    super.initState();

    // Detect the display refresh rate and configure the tracker.
    try {
      final displays = ui.PlatformDispatcher.instance.displays;
      if (displays.isNotEmpty) {
        final hz = displays.first.refreshRate;
        if (hz > 0) _tracker.setDisplayRefreshRate(hz);
      }
    } catch (_) {
      // Fallback: keep default 60 Hz.
    }

    _ticker = createTicker(_onTick)..start();
    _monitor.start();

    Timer(_warmupMin, () {
      if (mounted) _warmupMinPassed = true;
    });
    _warmupMaxTimer = Timer(_warmupMax, _endWarmup);

    // Update HUD at 4 Hz instead of every frame to reduce overhead.
    _hudTimer = Timer.periodic(const Duration(milliseconds: _hudIntervalMs), (
      _,
    ) {
      if (_running && mounted) {
        setState(() {
          _latestSnapshot = _monitor.latest;
          if (!_warmingUp) {
            _cachedResult = BenchmarkResult.fromTracker(
              widget.benchmark.name,
              widget.renderer,
              _tracker,
              resources: _monitor.summary,
            );
          }
        });
      }
    });
  }

  void _endWarmup() {
    if (!mounted || !_warmingUp) return;
    _warmupMaxTimer?.cancel();
    _warmupMaxTimer = null;
    _tracker.reset();
    _monitor.reset();
    _warmupFps.clear();
    setState(() => _warmingUp = false);
    _timer = Timer(widget.benchmark.duration, _finish);
  }

  void _onTick(Duration elapsed) {
    if (!_running) return;
    _tracker.onFrame(elapsed);

    if (_warmingUp) {
      if (_tracker.currentFps > 0) _warmupFps.add(_tracker.currentFps);
      final windowSize = max(30, _tracker.targetFps.round());
      if (_warmupMinPassed && _warmupFps.length >= windowSize) {
        final recent = _warmupFps.sublist(_warmupFps.length - windowSize);
        final mean = recent.reduce((a, b) => a + b) / recent.length;
        if (mean > 0) {
          final sumSq = recent.fold(0.0, (s, v) => s + (v - mean) * (v - mean));
          final stdDev = sqrt(sumSq / recent.length);
          if (stdDev / mean < 0.10) _endWarmup();
        }
      }
    }
  }

  void _finish() {
    if (!mounted) return;
    _monitor.stop();
    setState(() => _running = false);
    _ticker.stop();
    final r = BenchmarkResult.fromTracker(
      widget.benchmark.name,
      widget.renderer,
      _tracker,
      resources: _monitor.summary,
    );
    widget.onComplete(r);
    Future.delayed(_completionDelay, () {
      if (mounted) Navigator.pop(context, r);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _timer?.cancel();
    _hudTimer?.cancel();
    _warmupMaxTimer?.cancel();
    _monitor.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r =
        _cachedResult ??
        BenchmarkResult.fromTracker(
          widget.benchmark.name,
          widget.renderer,
          _tracker,
        );
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(child: widget.benchmark.builder()),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _HudPanel(
              r: r,
              running: _running,
              warmingUp: _warmingUp,
              snapshot: _latestSnapshot,
              fpsHistory: _tracker.fpsHistory,
              targetFps: _tracker.targetFps,
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: _InfoBadge(
              name: widget.benchmark.name,
              renderer: widget.renderer,
              running: _running,
              warmingUp: _warmingUp,
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            child: FloatingActionButton.small(
              onPressed: () {
                _ticker.stop();
                _timer?.cancel();
                _monitor.stop();
                Navigator.pop(context);
              },
              backgroundColor: Colors.redAccent.withValues(alpha: 0.85),
              child: const Icon(
                Icons.arrow_back,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
          if (!_running) Center(child: _CompletionCard(result: r)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HUD panel — live metrics overlay
// ---------------------------------------------------------------------------

class _HudPanel extends StatelessWidget {
  final BenchmarkResult r;
  final bool running;
  final bool warmingUp;
  final ResourceSnapshot? snapshot;
  final List<double> fpsHistory;
  final double targetFps;

  const _HudPanel({
    required this.r,
    required this.running,
    required this.warmingUp,
    this.snapshot,
    this.fpsHistory = const [],
    this.targetFps = 60.0,
  });

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: warmingUp
              ? Colors.orangeAccent.withValues(alpha: 0.4)
              : running
              ? kCyan.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (warmingUp) ...[
            const Text(
              "WARMING UP",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent,
                fontFamily: "monospace",
              ),
            ),
            Text(
              "Shaders compiling…",
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 120,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.grey[800],
                  color: Colors.orangeAccent,
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            "${r.avgFps.toStringAsFixed(0)} FPS",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              fontFamily: "monospace",
              color: warmingUp ? Colors.grey : fpsColor(r.avgFps),
            ),
          ),
          if (fpsHistory.length > 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: SizedBox(
                width: 120,
                height: 30,
                child: CustomPaint(painter: _FpsSparklinePainter(fpsHistory)),
              ),
            ),
          const SizedBox(height: 4),
          _row("AVG", r.avgFps, true),
          _row("MIN", r.minFps, true),
          _row("1% LOW", r.onePercentLow, true),
          const Divider(height: 10, color: Colors.grey),
          _row("p95 ft", r.p95FrameTimeMs, false, "ms"),
          _row("p99 ft", r.p99FrameTimeMs, false, "ms"),
          _row("σ ft", r.stdDevFrameTimeMs, false, "ms"),
          _row("JANK", r.jankPercent, false, "%"),
          const Divider(height: 10, color: Colors.grey),
          _row("SCORE", r.smoothnessScore, true, ""),
          const SizedBox(height: 2),
          Text(
            "${r.totalFrames} frames",
            style: const TextStyle(
              fontSize: 9,
              color: Colors.grey,
              fontFamily: "monospace",
            ),
          ),
          if (s != null) ...[
            const Divider(height: 10, color: Colors.grey),
            Text(
              "RESOURCES",
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
                fontFamily: "monospace",
              ),
            ),
            const SizedBox(height: 2),
            _resRow("RAM", "${s.dartRssMb.toStringAsFixed(0)} MB"),
            if (s.systemRamTotalMb > 0)
              _resRow(
                "SYS RAM",
                "${s.systemRamUsedMb.toStringAsFixed(0)} / ${s.systemRamTotalMb.toStringAsFixed(0)} MB",
              ),
            if (s.vramTotalMb > 0)
              _resRow(
                "VRAM",
                "${s.vramUsedMb.toStringAsFixed(0)} / ${s.vramTotalMb.toStringAsFixed(0)} MB",
              ),
            if (s.gpuLoadPercent >= 0)
              _resRow("GPU", "${s.gpuLoadPercent.toStringAsFixed(0)}%"),
            if (s.gpuTempC >= 0)
              _resRow("TEMP", "${s.gpuTempC.toStringAsFixed(0)}°C"),
            if (s.cpuPercent >= 0)
              _resRow("CPU", "${s.cpuPercent.toStringAsFixed(0)}%"),
          ],
        ],
      ),
    );
  }

  Widget _row(
    String label,
    double value,
    bool higherBetter, [
    String suffix = "",
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[500],
                fontFamily: "monospace",
              ),
            ),
          ),
          Text(
            "${value.toStringAsFixed(1)}$suffix",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: "monospace",
              color: higherBetter
                  ? fpsColor(value)
                  : ftColor(value, targetMs: 1000.0 / targetFps),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[500],
                fontFamily: "monospace",
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: "monospace",
              color: Colors.lightBlueAccent,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FPS sparkline mini-graph
// ---------------------------------------------------------------------------

class _FpsSparklinePainter extends CustomPainter {
  final List<double> data;
  _FpsSparklinePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    // Keep at most 120 points (2 s at 60 Hz) for a readable sparkline.
    const maxPoints = 120;
    final points = data.length > maxPoints
        ? data.sublist(data.length - maxPoints)
        : data;
    if (points.length < 2) return;

    final minV = points.reduce(min);
    final maxV = points.reduce(max);
    final range = maxV - minV;
    if (range <= 0) return;

    final linePaint = Paint()
      ..color = kCyan.withValues(alpha: 0.8)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
        kCyan.withValues(alpha: 0.25),
        kCyan.withValues(alpha: 0.0),
      ]);

    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < points.length; i++) {
      final x = i / (points.length - 1) * size.width;
      final y = size.height - ((points[i] - minV) / range * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _FpsSparklinePainter old) =>
      data.length != old.data.length ||
      (data.isNotEmpty && old.data.isNotEmpty && data.last != old.data.last);
}

// ---------------------------------------------------------------------------
// Info badge — top-left benchmark name and status dot
// ---------------------------------------------------------------------------

class _InfoBadge extends StatelessWidget {
  final String name, renderer;
  final bool running, warmingUp;

  const _InfoBadge({
    required this.name,
    required this.renderer,
    required this.running,
    required this.warmingUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: warmingUp
                  ? Colors.orangeAccent
                  : running
                  ? Colors.redAccent
                  : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                warmingUp ? "$renderer — warming up…" : renderer,
                style: TextStyle(fontSize: 9, color: Colors.grey[400]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Completion card — shown when the benchmark finishes
// ---------------------------------------------------------------------------

class _CompletionCard extends StatelessWidget {
  final BenchmarkResult result;
  const _CompletionCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kCardDark.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 44),
            const SizedBox(height: 10),
            Text(
              "${result.avgFps.toStringAsFixed(1)} FPS avg",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: fpsColor(result.avgFps),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Min ${result.minFps.toStringAsFixed(1)} · 1% Low ${result.onePercentLow.toStringAsFixed(1)}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Text(
              "Jank ${result.jankPercent.toStringAsFixed(1)}% · Score ${result.smoothnessScore.toStringAsFixed(0)} · "
              "${result.totalFrames}f / ${(result.elapsedMs / 1000).toStringAsFixed(1)}s",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (result.resources != null) ...[
              const SizedBox(height: 8),
              _resourceSummaryRow(result.resources!),
            ],
            const SizedBox(height: 14),
            const Text(
              "Returning to menu…",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resourceSummaryRow(ResourceSummary res) {
    final parts = <String>[
      "RAM ${res.peakDartRssMb.toStringAsFixed(0)} MB peak",
    ];
    if (res.vramTotalMb > 0) {
      parts.add(
        "VRAM ${res.peakVramUsedMb.toStringAsFixed(0)}/${res.vramTotalMb.toStringAsFixed(0)} MB",
      );
    }
    if (res.peakGpuLoadPercent >= 0) {
      parts.add("GPU ${res.peakGpuLoadPercent.toStringAsFixed(0)}% peak");
    }
    if (res.peakGpuTempC >= 0) {
      parts.add("${res.peakGpuTempC.toStringAsFixed(0)}°C peak");
    }
    return Text(
      parts.join(" · "),
      style: const TextStyle(fontSize: 10, color: Colors.lightBlueAccent),
    );
  }
}
