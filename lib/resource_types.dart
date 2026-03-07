/// Shared data types for system resource monitoring.
///
/// Both native and web [SystemMonitor] implementations import these types
/// so that there is a single source of truth for [ResourceSnapshot] and
/// [ResourceSummary].
library;

/// A single snapshot of system resource usage.
class ResourceSnapshot {
  final DateTime timestamp;

  /// Dart process resident set size in MB.
  final double dartRssMb;

  /// System total physical RAM in MB (0 if unavailable).
  final double systemRamTotalMb;

  /// System used physical RAM in MB (0 if unavailable).
  final double systemRamUsedMb;

  /// GPU dedicated video memory used in MB (0 if unavailable).
  final double vramUsedMb;

  /// GPU total dedicated video memory in MB (0 if unavailable).
  final double vramTotalMb;

  /// GPU core utilization 0-100% (−1 if unavailable).
  final double gpuLoadPercent;

  /// GPU temperature in °C (−1 if unavailable).
  final double gpuTempC;

  /// Estimated process CPU usage 0-100% (−1 if unavailable).
  final double cpuPercent;

  const ResourceSnapshot({
    required this.timestamp,
    this.dartRssMb = 0,
    this.systemRamTotalMb = 0,
    this.systemRamUsedMb = 0,
    this.vramUsedMb = 0,
    this.vramTotalMb = 0,
    this.gpuLoadPercent = -1,
    this.gpuTempC = -1,
    this.cpuPercent = -1,
  });

  Map<String, dynamic> toJson() => {
    "dart_rss_mb": _r(dartRssMb),
    "system_ram_total_mb": _r(systemRamTotalMb),
    "system_ram_used_mb": _r(systemRamUsedMb),
    "vram_used_mb": _r(vramUsedMb),
    "vram_total_mb": _r(vramTotalMb),
    "gpu_load_percent": _r(gpuLoadPercent),
    "gpu_temp_c": _r(gpuTempC),
    "cpu_percent": _r(cpuPercent),
  };

  /// Round to 1 decimal place for JSON output.
  static double _r(double v) => (v * 10).roundToDouble() / 10;
}

/// Aggregated resource metrics over a benchmark run.
///
/// Fields that were unavailable during sampling report `0` (memory)
/// or `-1` (load / temperature percentages).
class ResourceSummary {
  /// Peak Dart resident set size in MB.
  final double peakDartRssMb;

  /// Mean Dart RSS across all samples in MB.
  final double avgDartRssMb;

  /// Peak system RAM used in MB.
  final double peakSystemRamUsedMb;

  /// Total system RAM in MB.
  final double systemRamTotalMb;

  /// Peak GPU VRAM used in MB.
  final double peakVramUsedMb;

  /// Mean GPU VRAM used in MB.
  final double avgVramUsedMb;

  /// Total GPU VRAM in MB.
  final double vramTotalMb;

  /// Mean GPU utilisation 0–100 % (−1 if unavailable).
  final double avgGpuLoadPercent;

  /// Peak GPU utilisation 0–100 % (−1 if unavailable).
  final double peakGpuLoadPercent;

  /// Mean GPU temperature in °C (−1 if unavailable).
  final double avgGpuTempC;

  /// Peak GPU temperature in °C (−1 if unavailable).
  final double peakGpuTempC;

  /// Mean process CPU usage 0–100 % (−1 if unavailable).
  final double avgCpuPercent;

  /// Peak process CPU usage 0–100 % (−1 if unavailable).
  final double peakCpuPercent;

  /// Number of snapshots aggregated.
  final int sampleCount;

  const ResourceSummary({
    this.peakDartRssMb = 0,
    this.avgDartRssMb = 0,
    this.peakSystemRamUsedMb = 0,
    this.systemRamTotalMb = 0,
    this.peakVramUsedMb = 0,
    this.avgVramUsedMb = 0,
    this.vramTotalMb = 0,
    this.avgGpuLoadPercent = -1,
    this.peakGpuLoadPercent = -1,
    this.avgGpuTempC = -1,
    this.peakGpuTempC = -1,
    this.avgCpuPercent = -1,
    this.peakCpuPercent = -1,
    this.sampleCount = 0,
  });

  /// Serialises the summary to JSON, omitting unavailable metrics.
  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      "peak_dart_rss_mb": _r(peakDartRssMb),
      "avg_dart_rss_mb": _r(avgDartRssMb),
      "system_ram_total_mb": _r(systemRamTotalMb),
      "peak_system_ram_used_mb": _r(peakSystemRamUsedMb),
      "sample_count": sampleCount,
    };
    if (vramTotalMb > 0) {
      m["vram_total_mb"] = _r(vramTotalMb);
      m["peak_vram_used_mb"] = _r(peakVramUsedMb);
      m["avg_vram_used_mb"] = _r(avgVramUsedMb);
    }
    if (avgGpuLoadPercent >= 0) {
      m["avg_gpu_load_percent"] = _r(avgGpuLoadPercent);
      m["peak_gpu_load_percent"] = _r(peakGpuLoadPercent);
    }
    if (avgGpuTempC >= 0) {
      m["avg_gpu_temp_c"] = _r(avgGpuTempC);
      m["peak_gpu_temp_c"] = _r(peakGpuTempC);
    }
    if (avgCpuPercent >= 0) {
      m["avg_cpu_percent"] = _r(avgCpuPercent);
      m["peak_cpu_percent"] = _r(peakCpuPercent);
    }
    return m;
  }

  /// Deserialises a summary from a JSON map.
  factory ResourceSummary.fromJson(Map<String, dynamic> j) => ResourceSummary(
    peakDartRssMb: (j["peak_dart_rss_mb"] ?? 0).toDouble(),
    avgDartRssMb: (j["avg_dart_rss_mb"] ?? 0).toDouble(),
    systemRamTotalMb: (j["system_ram_total_mb"] ?? 0).toDouble(),
    peakSystemRamUsedMb: (j["peak_system_ram_used_mb"] ?? 0).toDouble(),
    peakVramUsedMb: (j["peak_vram_used_mb"] ?? 0).toDouble(),
    avgVramUsedMb: (j["avg_vram_used_mb"] ?? 0).toDouble(),
    vramTotalMb: (j["vram_total_mb"] ?? 0).toDouble(),
    avgGpuLoadPercent: (j["avg_gpu_load_percent"] ?? -1).toDouble(),
    peakGpuLoadPercent: (j["peak_gpu_load_percent"] ?? -1).toDouble(),
    avgGpuTempC: (j["avg_gpu_temp_c"] ?? -1).toDouble(),
    peakGpuTempC: (j["peak_gpu_temp_c"] ?? -1).toDouble(),
    avgCpuPercent: (j["avg_cpu_percent"] ?? -1).toDouble(),
    peakCpuPercent: (j["peak_cpu_percent"] ?? -1).toDouble(),
    sampleCount: (j["sample_count"] ?? 0).toInt(),
  );

  /// Round to 1 decimal place for JSON output.
  static double _r(double v) => (v * 10).roundToDouble() / 10;
}
