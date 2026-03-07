/// Data models for benchmark results, system info, and export/import.
///
/// These classes represent the data captured during benchmark runs and
/// provide JSON serialization for export and comparison workflows.
library;

import "dart:convert";

import "fps_tracker.dart";
import "platform_utils.dart";
import "resource_types.dart";

/// Snapshot of the system environment at the time of a benchmark run.
class SystemInfo {
  /// GPU model or description string.
  final String gpu;

  /// Platform/system description (e.g. browser user-agent on web,
  /// OS version string on native).
  final String browser;

  /// Display resolution as "WxH".
  final String screenSize;

  /// Detected rendering backend name (e.g. "Impeller (Vulkan)").
  final String renderer;

  /// ISO-8601 timestamp when the info was captured.
  final String timestamp;

  /// Device pixel ratio of the primary display.
  final double dpr;

  /// Whether WebGPU is available (web-only, always `false` on native).
  final bool webgpuAvailable;

  SystemInfo({
    required this.gpu,
    required this.browser,
    required this.screenSize,
    required this.dpr,
    required this.renderer,
    required this.webgpuAvailable,
    required this.timestamp,
  });

  /// Detect current system information from the running platform.
  factory SystemInfo.detect(String renderer) {
    final (w, h) = PlatformUtils.getScreenSize();
    return SystemInfo(
      gpu: PlatformUtils.gpuInfo,
      browser: PlatformUtils.systemDescription,
      screenSize: "${w}x$h",
      dpr: PlatformUtils.getDevicePixelRatio(),
      renderer: renderer,
      webgpuAvailable: PlatformUtils.isWebGPUAvailable,
      timestamp: DateTime.now().toIso8601String(),
    );
  }

  /// Serialize to JSON-compatible map.
  Map<String, dynamic> toJson() => {
    "gpu": gpu,
    "browser": browser,
    "screen_size": screenSize,
    "dpr": dpr,
    "renderer": renderer,
    "webgpu_available": webgpuAvailable,
    "timestamp": timestamp,
  };

  /// Deserialize from a JSON map.
  factory SystemInfo.fromJson(Map<String, dynamic> j) => SystemInfo(
    gpu: j["gpu"] ?? "N/A",
    browser: j["browser"] ?? "N/A",
    screenSize: j["screen_size"] ?? "N/A",
    dpr: (j["dpr"] ?? 1.0).toDouble(),
    renderer: j["renderer"] ?? "N/A",
    webgpuAvailable: j["webgpu_available"] ?? false,
    timestamp: j["timestamp"] ?? "",
  );
}

/// Result of a single benchmark run with all recorded metrics.
class BenchmarkResult {
  final String testName, renderer;
  final double avgFps, minFps, maxFps, onePercentLow;
  final double p95FrameTimeMs, p99FrameTimeMs;
  final double avgFrameTimeMs, maxFrameTimeMs, stdDevFrameTimeMs;
  final int jankCount, totalFrames, elapsedMs;
  final double jankPercent, smoothnessScore;
  final List<double> fpsHistory;
  final ResourceSummary? resources;

  /// ISO-8601 timestamp of when this result was recorded.
  final String timestamp;

  BenchmarkResult({
    required this.testName,
    required this.renderer,
    required this.avgFps,
    required this.minFps,
    required this.maxFps,
    required this.onePercentLow,
    required this.p95FrameTimeMs,
    required this.p99FrameTimeMs,
    required this.avgFrameTimeMs,
    required this.maxFrameTimeMs,
    required this.stdDevFrameTimeMs,
    required this.jankCount,
    required this.jankPercent,
    required this.smoothnessScore,
    required this.totalFrames,
    required this.elapsedMs,
    required this.fpsHistory,
    this.resources,
    String? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toIso8601String();

  /// Create a [BenchmarkResult] by reading all metrics from a [FpsTracker].
  factory BenchmarkResult.fromTracker(
    String testName,
    String renderer,
    FpsTracker t, {
    ResourceSummary? resources,
  }) => BenchmarkResult(
    testName: testName,
    renderer: renderer,
    avgFps: t.avgFps,
    minFps: t.minFps,
    maxFps: t.maxFps,
    onePercentLow: t.onePercentLow,
    p95FrameTimeMs: t.p95FrameTimeMs,
    p99FrameTimeMs: t.p99FrameTimeMs,
    avgFrameTimeMs: t.avgFrameTimeMs,
    maxFrameTimeMs: t.maxFrameTimeMs,
    stdDevFrameTimeMs: t.stdDevFrameTimeMs,
    jankCount: t.jankCount,
    jankPercent: t.jankPercent,
    smoothnessScore: t.smoothnessScore,
    totalFrames: t.frameCount,
    elapsedMs: t.elapsed.inMilliseconds,
    fpsHistory: t.fpsHistory,
    resources: resources,
  );

  /// Round to 2 decimal places for JSON output.
  static double _r(double v) => (v * 100).roundToDouble() / 100;

  /// Serialize to JSON-compatible map. FPS history is down-sampled 4x.
  Map<String, dynamic> toJson() => {
    "test_name": testName,
    "renderer": renderer,
    "timestamp": timestamp,
    "avg_fps": _r(avgFps),
    "min_fps": _r(minFps),
    "max_fps": _r(maxFps),
    "one_percent_low": _r(onePercentLow),
    "p95_frame_time_ms": _r(p95FrameTimeMs),
    "p99_frame_time_ms": _r(p99FrameTimeMs),
    "avg_frame_time_ms": _r(avgFrameTimeMs),
    "max_frame_time_ms": _r(maxFrameTimeMs),
    "std_dev_frame_time_ms": _r(stdDevFrameTimeMs),
    "jank_count": jankCount,
    "jank_percent": _r(jankPercent),
    "smoothness_score": _r(smoothnessScore),
    "total_frames": totalFrames,
    "elapsed_ms": elapsedMs,
    "fps_history": fpsHistory
        .whereIndexed((i, _) => i % 4 == 0)
        .map((v) => _r(v))
        .toList(),
    if (resources != null) "resources": resources!.toJson(),
  };

  /// Deserialize from a JSON map.
  factory BenchmarkResult.fromJson(Map<String, dynamic> j) => BenchmarkResult(
    testName: j["test_name"] ?? "",
    renderer: j["renderer"] ?? "",
    timestamp: j["timestamp"] ?? "",
    avgFps: (j["avg_fps"] ?? 0).toDouble(),
    minFps: (j["min_fps"] ?? 0).toDouble(),
    maxFps: (j["max_fps"] ?? 0).toDouble(),
    onePercentLow: (j["one_percent_low"] ?? 0).toDouble(),
    p95FrameTimeMs: (j["p95_frame_time_ms"] ?? 0).toDouble(),
    p99FrameTimeMs: (j["p99_frame_time_ms"] ?? 0).toDouble(),
    avgFrameTimeMs: (j["avg_frame_time_ms"] ?? 0).toDouble(),
    maxFrameTimeMs: (j["max_frame_time_ms"] ?? 0).toDouble(),
    stdDevFrameTimeMs: (j["std_dev_frame_time_ms"] ?? 0).toDouble(),
    jankCount: (j["jank_count"] ?? 0).toInt(),
    jankPercent: (j["jank_percent"] ?? 0).toDouble(),
    smoothnessScore: (j["smoothness_score"] ?? 0).toDouble(),
    totalFrames: (j["total_frames"] ?? 0).toInt(),
    elapsedMs: (j["elapsed_ms"] ?? 0).toInt(),
    fpsHistory:
        (j["fps_history"] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [],
    resources: j["resources"] != null
        ? ResourceSummary.fromJson(j["resources"] as Map<String, dynamic>)
        : null,
  );
}

/// Wrapper for exporting/importing a complete benchmark session.
class ExportData {
  static const _version = "3.0";

  /// System info captured at export time.
  final SystemInfo systemInfo;

  /// All benchmark results in this export.
  final List<BenchmarkResult> results;

  ExportData({required this.systemInfo, required this.results});

  /// Encode to a pretty-printed JSON string.
  String toJsonString() {
    return const JsonEncoder.withIndent("  ").convert({
      "version": _version,
      "system_info": systemInfo.toJson(),
      "results": results.map((r) => r.toJson()).toList(),
    });
  }

  /// Decode from a JSON string previously produced by [toJsonString].
  factory ExportData.fromJsonString(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return ExportData(
      systemInfo: SystemInfo.fromJson(map["system_info"] ?? {}),
      results:
          (map["results"] as List?)
              ?.map((e) => BenchmarkResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// A labeled set of benchmark results from one "Run All" pass.
class BenchmarkRun {
  final int number;
  final String renderer;
  final DateTime timestamp;
  final List<BenchmarkResult> results;

  BenchmarkRun({
    required this.number,
    required this.renderer,
    required this.timestamp,
    required this.results,
  });

  /// Human-readable label for display in the UI.
  String get label => "Run $number — $renderer";
}

/// Adds index-aware filtering to [Iterable].
///
/// Intentionally avoids a `package:collection` dependency for this single
/// helper.
extension IterableIndexed<T> on Iterable<T> {
  /// Yields elements where [test] returns `true`, providing the index.
  Iterable<T> whereIndexed(bool Function(int index, T element) test) sync* {
    int i = 0;
    for (final e in this) {
      if (test(i, e)) yield e;
      i++;
    }
  }
}
