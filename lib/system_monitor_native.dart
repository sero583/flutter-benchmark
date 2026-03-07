/// System resource monitor for native platforms (Windows, Linux, macOS).
///
/// Periodically samples RAM, VRAM, GPU load, GPU temperature, and CPU usage
/// via platform-specific CLI tools (nvidia-smi, PowerShell, /proc, etc.).
library;

import "dart:async";
import "dart:io";
import "dart:math";

export "resource_types.dart";

import "resource_types.dart";

/// Periodically samples system resources on native platforms.
///
/// Call [start] to begin sampling, [stop] to end, and [summary] to get
/// aggregated results.  Sampling happens every [interval] without blocking
/// the UI — external process calls are run asynchronously.
class SystemMonitor {
  final Duration interval;
  Timer? _timer;
  final List<ResourceSnapshot> _snapshots = [];

  /// Whether nvidia-smi is available on this system.
  static bool? _hasNvidiaSmi;

  /// Cached system RAM total (doesn't change).
  static double? _systemRamTotalMb;

  /// Previous CPU time sample for delta calculation.
  int _prevCpuTimeUs = 0;
  DateTime _prevCpuSampleTime = DateTime.now();

  SystemMonitor({this.interval = const Duration(seconds: 1)});

  /// Most recent snapshot, or null if no samples yet.
  ResourceSnapshot? get latest => _snapshots.isEmpty ? null : _snapshots.last;

  List<ResourceSnapshot> get snapshots => List.unmodifiable(_snapshots);

  /// Start periodic sampling.
  void start() {
    _snapshots.clear();
    _prevCpuTimeUs = 0;
    // Take one sample immediately, then periodically.
    _sample();
    _timer = Timer.periodic(interval, (_) => _sample());
  }

  /// Stop sampling.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Reset all collected data.
  void reset() {
    _snapshots.clear();
    _prevCpuTimeUs = 0;
  }

  /// Compute an aggregated summary from all snapshots.
  ResourceSummary get summary {
    if (_snapshots.isEmpty) return const ResourceSummary();

    double peakRss = 0, sumRss = 0;
    double peakSysRam = 0, sysRamTotal = 0;
    double peakVram = 0, sumVram = 0, vramTotal = 0;
    double peakGpuLoad = -1, sumGpuLoad = 0;
    int gpuLoadCount = 0;
    double peakTemp = -1, sumTemp = 0;
    int tempCount = 0;
    double peakCpu = -1, sumCpu = 0;
    int cpuCount = 0;

    for (final s in _snapshots) {
      peakRss = max(peakRss, s.dartRssMb);
      sumRss += s.dartRssMb;

      peakSysRam = max(peakSysRam, s.systemRamUsedMb);
      if (s.systemRamTotalMb > 0) sysRamTotal = s.systemRamTotalMb;

      if (s.vramTotalMb > 0) vramTotal = s.vramTotalMb;
      peakVram = max(peakVram, s.vramUsedMb);
      sumVram += s.vramUsedMb;

      if (s.gpuLoadPercent >= 0) {
        peakGpuLoad = max(peakGpuLoad, s.gpuLoadPercent);
        sumGpuLoad += s.gpuLoadPercent;
        gpuLoadCount++;
      }
      if (s.gpuTempC >= 0) {
        peakTemp = max(peakTemp, s.gpuTempC);
        sumTemp += s.gpuTempC;
        tempCount++;
      }
      if (s.cpuPercent >= 0) {
        peakCpu = max(peakCpu, s.cpuPercent);
        sumCpu += s.cpuPercent;
        cpuCount++;
      }
    }

    final n = _snapshots.length;
    return ResourceSummary(
      peakDartRssMb: peakRss,
      avgDartRssMb: sumRss / n,
      peakSystemRamUsedMb: peakSysRam,
      systemRamTotalMb: sysRamTotal,
      peakVramUsedMb: peakVram,
      avgVramUsedMb: sumVram / n,
      vramTotalMb: vramTotal,
      avgGpuLoadPercent: gpuLoadCount > 0 ? sumGpuLoad / gpuLoadCount : -1,
      peakGpuLoadPercent: peakGpuLoad,
      avgGpuTempC: tempCount > 0 ? sumTemp / tempCount : -1,
      peakGpuTempC: peakTemp,
      avgCpuPercent: cpuCount > 0 ? sumCpu / cpuCount : -1,
      peakCpuPercent: peakCpu,
      sampleCount: n,
    );
  }

  /// Take a single sample (async — launches subprocesses if needed).
  Future<void> _sample() async {
    try {
      final dartRss = ProcessInfo.currentRss / (1024 * 1024); // bytes → MB

      double cpuPercent = -1;
      double sysRamTotal = _systemRamTotalMb ?? 0;
      double sysRamUsed = 0;

      if (Platform.isWindows) {
        // Batch RAM + CPU + VRAM into a single PowerShell invocation to avoid
        // launching multiple heavy subprocesses per sample during measurement.
        try {
          final (ramTotal, ramUsed, cpu, batchVramTotal, batchVramUsed) =
              await _windowsBatchSample();
          sysRamTotal = ramTotal;
          sysRamUsed = ramUsed;
          cpuPercent = cpu;
          _systemRamTotalMb ??= ramTotal;
          // Store batch VRAM for the GPU section below.
          if (batchVramTotal > 0) _cachedBatchVramMb ??= batchVramTotal;
          _lastBatchVramUsedMb = batchVramUsed;
        } catch (_) {}
      } else {
        // CPU usage estimate via process CPU time delta.
        try {
          if (Platform.isLinux) {
            cpuPercent = await _linuxCpuPercent();
          } else if (Platform.isMacOS) {
            cpuPercent = await _macCpuPercent();
          }
        } catch (_) {}

        // System RAM
        try {
          final (total, used) = await _getSystemRam();
          sysRamTotal = total;
          sysRamUsed = used;
          _systemRamTotalMb ??= total;
        } catch (_) {}
      }

      // GPU metrics (VRAM, load, temp) — try NVIDIA first, then AMD.
      double vramUsed = 0, vramTotal = 0, gpuLoad = -1, gpuTemp = -1;
      try {
        final gpu = await _getNvidiaGpuMetrics();
        if (gpu != null) {
          vramUsed = gpu.vramUsedMb;
          vramTotal = gpu.vramTotalMb;
          gpuLoad = gpu.loadPercent;
          gpuTemp = gpu.tempC;
        } else if (Platform.isLinux) {
          final amd = await _getAmdGpuMetrics();
          if (amd != null) {
            vramUsed = amd.vramUsedMb;
            vramTotal = amd.vramTotalMb;
            gpuLoad = amd.loadPercent;
            gpuTemp = amd.tempC;
          }
        } else if (Platform.isWindows) {
          // Use VRAM metrics from the batched PowerShell query (avoids spawning
          // a second PowerShell process with its own cold-start penalty).
          if (_cachedBatchVramMb != null && _cachedBatchVramMb! > 0) {
            vramTotal = _cachedBatchVramMb!;
          }
          if (_lastBatchVramUsedMb > 0) {
            vramUsed = _lastBatchVramUsedMb;
          }
        }
      } catch (_) {}

      _snapshots.add(
        ResourceSnapshot(
          timestamp: DateTime.now(),
          dartRssMb: dartRss,
          systemRamTotalMb: sysRamTotal,
          systemRamUsedMb: sysRamUsed,
          vramUsedMb: vramUsed,
          vramTotalMb: vramTotal,
          gpuLoadPercent: gpuLoad,
          gpuTempC: gpuTemp,
          cpuPercent: cpuPercent,
        ),
      );
    } catch (_) {
      // Never crash the app from monitoring.
    }
  }

  // ── Windows batched sample (RAM + CPU + VRAM in one PowerShell call) ──

  /// Cached VRAM total (queried once in batch — doesn't change at runtime).
  static double? _cachedBatchVramMb;

  /// Last sampled VRAM usage in MB from Windows Performance Counters.
  double _lastBatchVramUsedMb = 0;

  /// Combines RAM, CPU, and VRAM queries into a single PowerShell invocation
  /// to minimise subprocess overhead during measurement.
  /// Returns (ramTotalMb, ramUsedMb, cpuPercent, vramTotalMb, vramUsedMb).
  Future<(double, double, double, double, double)> _windowsBatchSample() async {
    final processPid = pid;

    // Build optional VRAM-total snippet — only on first call (result is
    // constant).
    final vramSnippet = _cachedBatchVramMb == null
        ? r"$vram = 0; "
              r"$gpuPaths = Get-ChildItem 'HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue; "
              r"foreach ($gp in $gpuPaths) { "
              r"$qw = (Get-ItemProperty -Path $gp.PSPath -Name 'HardwareInformation.qwMemorySize' -ErrorAction SilentlyContinue).'HardwareInformation.qwMemorySize'; "
              r"if ($qw -gt 0) { $vram = $qw; break } } "
              r"if ($vram -eq 0) { "
              r"$ar = (Get-CimInstance Win32_VideoController | Where-Object { $_.AdapterRAM -gt 0 } | Select-Object -First 1).AdapterRAM; "
              r"if ($ar -gt 0) { $vram = $ar } } "
              'Write-Output "VRAM=\$vram"; '
        : "";

    // GPU dedicated-memory usage via Windows Performance Counters.
    // `Get-Counter` returns bytes; we pick the largest adapter (ignoring
    // virtual / zero adapters).
    const gpuUsageSnippet =
        r"try { $gc = (Get-Counter '\GPU Adapter Memory(*)\Dedicated Usage' -ErrorAction SilentlyContinue).CounterSamples | "
        r"Sort-Object CookedValue -Descending | Select-Object -First 1; "
        r'if ($gc) { Write-Output "VRAM_USED=$($gc.CookedValue)" } } catch {} ';

    final r =
        await Process.run("powershell", [
          "-NoProfile",
          "-Command",
          "\$os = Get-CimInstance Win32_OperatingSystem; "
              "\$cpu = (Get-Process -Id $processPid).CPU; "
              'Write-Output "RAM_FREE=\$(\$os.FreePhysicalMemory)"; '
              'Write-Output "RAM_TOTAL=\$(\$os.TotalVisibleMemorySize)"; '
              'Write-Output "CPU=\$cpu"; '
              "$vramSnippet"
              "$gpuUsageSnippet",
        ]).timeout(
          const Duration(seconds: 10),
          onTimeout: () => ProcessResult(0, 1, "", "timeout"),
        );
    final out = r.stdout.toString();

    final free = _extractNumber(out, r"RAM_FREE=(\d+)") / 1024; // KB → MB
    final total = _extractNumber(out, r"RAM_TOTAL=(\d+)") / 1024;

    // Parse VRAM total (bytes → MB), cache on first successful read.
    if (_cachedBatchVramMb == null) {
      final vramBytes = _extractNumber(out, r"VRAM=(\d+)");
      if (vramBytes > 0) {
        _cachedBatchVramMb = vramBytes / (1024 * 1024);
      }
    }

    // Parse VRAM usage (bytes → MB) from performance counters.
    double vramUsedMb = 0;
    final vramUsedBytes = _extractNumber(out, r"VRAM_USED=([\d.]+)");
    if (vramUsedBytes > 0) {
      vramUsedMb = vramUsedBytes / (1024 * 1024);
    }

    double cpuPercent = -1;
    // CPU time returned by Get-Process is in seconds of CPU time summed
    // across all cores.  Divide by core count to match Task Manager's
    // per-process percentage.
    final cpuMatch = RegExp(r"CPU=([\d.]+)").firstMatch(out);
    if (cpuMatch != null) {
      final totalSec = double.tryParse(cpuMatch.group(1)!) ?? 0;
      final totalUs = (totalSec * 1e6).round();
      final now = DateTime.now();
      if (_prevCpuTimeUs > 0) {
        final deltaCpu = totalUs - _prevCpuTimeUs;
        final deltaWall = now.difference(_prevCpuSampleTime).inMicroseconds;
        _prevCpuTimeUs = totalUs;
        _prevCpuSampleTime = now;
        if (deltaWall > 0) {
          final cores = Platform.numberOfProcessors.clamp(1, 1024);
          cpuPercent = (deltaCpu / deltaWall / cores * 100).clamp(0.0, 100.0);
        }
      } else {
        _prevCpuTimeUs = totalUs;
        _prevCpuSampleTime = now;
      }
    }

    return (
      total,
      total - free,
      cpuPercent,
      _cachedBatchVramMb ?? 0,
      vramUsedMb,
    );
  }

  // ── System RAM ──────────────────────────────────

  static Future<(double total, double used)> _getSystemRam() async {
    if (Platform.isWindows) {
      return _windowsRam();
    } else if (Platform.isLinux) {
      return _linuxRam();
    } else if (Platform.isMacOS) {
      return _macRam();
    }
    return (0.0, 0.0);
  }

  static Future<(double, double)> _windowsRam() async {
    // Use PowerShell Get-CimInstance instead of deprecated wmic.
    final r = await _timedRun("powershell", [
      "-NoProfile",
      "-Command",
      "Get-CimInstance Win32_OperatingSystem | "
          "Select-Object -Property FreePhysicalMemory,TotalVisibleMemorySize | "
          "Format-List",
    ]);
    final out = r.stdout.toString();
    final free =
        _extractNumber(out, r"FreePhysicalMemory\s*:\s*(\d+)") / 1024; // KB→MB
    final total =
        _extractNumber(out, r"TotalVisibleMemorySize\s*:\s*(\d+)") / 1024;
    return (total, total - free);
  }

  static Future<(double, double)> _linuxRam() async {
    final content = await File("/proc/meminfo").readAsString();
    final total = _extractNumber(content, r"MemTotal:\s+(\d+)") / 1024;
    final available = _extractNumber(content, r"MemAvailable:\s+(\d+)") / 1024;
    return (total, total - available);
  }

  static Future<(double, double)> _macRam() async {
    // Total RAM via sysctl
    final sysctl = await _timedRun("sysctl", ["-n", "hw.memsize"]);
    final totalBytes = double.tryParse(sysctl.stdout.toString().trim()) ?? 0;
    final totalMb = totalBytes / (1024 * 1024);

    // Used RAM approximation via vm_stat
    final vmStat = await _timedRun("vm_stat", []);
    final out = vmStat.stdout.toString();
    // Pages are 4096 bytes each on macOS.
    final active = _extractNumber(out, r"Pages active:\s+(\d+)");
    final wired = _extractNumber(out, r"Pages wired down:\s+(\d+)");
    final compressed = _extractNumber(
      out,
      r"Pages occupied by compressor:\s+(\d+)",
    );
    final usedMb = (active + wired + compressed) * 4096 / (1024 * 1024);
    return (totalMb, usedMb);
  }

  // ── GPU metrics (nvidia-smi) ────────────────────

  static Future<_GpuMetrics?> _getNvidiaGpuMetrics() async {
    // Check availability once.
    if (_hasNvidiaSmi == false) return null;

    try {
      final r = await _timedRun("nvidia-smi", [
        "--query-gpu=memory.used,memory.total,utilization.gpu,temperature.gpu",
        "--format=csv,noheader,nounits",
      ]);
      if (r.exitCode != 0) {
        _hasNvidiaSmi = false;
        return null;
      }
      _hasNvidiaSmi = true;
      final parts = r.stdout.toString().trim().split(",");
      if (parts.length < 4) return null;
      return _GpuMetrics(
        vramUsedMb: double.tryParse(parts[0].trim()) ?? 0,
        vramTotalMb: double.tryParse(parts[1].trim()) ?? 0,
        loadPercent: double.tryParse(parts[2].trim()) ?? -1,
        tempC: double.tryParse(parts[3].trim()) ?? -1,
      );
    } catch (_) {
      _hasNvidiaSmi = false;
      return null;
    }
  }

  // ── GPU metrics (AMD on Linux via sysfs) ────────

  /// Whether AMD GPU sysfs entries exist.
  static bool? _hasAmdGpu;

  /// Detected AMD GPU card path (e.g. `/sys/class/drm/card0/device`).
  static String? _amdCardPath;

  static Future<_GpuMetrics?> _getAmdGpuMetrics() async {
    if (_hasAmdGpu == false) return null;

    try {
      // Auto-detect the AMD GPU card path on first call.
      if (_amdCardPath == null) {
        for (int i = 0; i < 8; i++) {
          final base = "/sys/class/drm/card$i/device";
          final gpuBusy = File("$base/gpu_busy_percent");
          if (await gpuBusy.exists()) {
            _amdCardPath = base;
            break;
          }
        }
        if (_amdCardPath == null) {
          _hasAmdGpu = false;
          return null;
        }
      }
      _hasAmdGpu = true;
      final base = _amdCardPath!;

      double loadPercent = -1;
      double vramUsed = 0, vramTotal = 0, tempC = -1;

      // GPU utilization.
      try {
        final load = await File("$base/gpu_busy_percent").readAsString();
        loadPercent = double.tryParse(load.trim()) ?? -1;
      } catch (_) {}

      // VRAM usage (amdgpu driver exposes these in bytes).
      try {
        final used = await File("$base/mem_info_vram_used").readAsString();
        final total = await File("$base/mem_info_vram_total").readAsString();
        vramUsed = (double.tryParse(used.trim()) ?? 0) / (1024 * 1024);
        vramTotal = (double.tryParse(total.trim()) ?? 0) / (1024 * 1024);
      } catch (_) {}

      // Temperature via hwmon (edge temperature).
      try {
        final hwmonDir = Directory("$base/hwmon");
        if (await hwmonDir.exists()) {
          final entries = await hwmonDir.list().toList();
          for (final entry in entries) {
            final tempFile = File("${entry.path}/temp1_input");
            if (await tempFile.exists()) {
              final raw = await tempFile.readAsString();
              final milliC = double.tryParse(raw.trim()) ?? 0;
              tempC = milliC / 1000.0; // millidegrees → °C
              break;
            }
          }
        }
      } catch (_) {}

      return _GpuMetrics(
        vramUsedMb: vramUsed,
        vramTotalMb: vramTotal,
        loadPercent: loadPercent,
        tempC: tempC,
      );
    } catch (_) {
      _hasAmdGpu = false;
      return null;
    }
  }

  // ── CPU usage (Linux /proc/self/stat) ───────────

  Future<double> _linuxCpuPercent() async {
    final stat = await File("/proc/self/stat").readAsString();
    final fields = stat.split(" ");
    // Fields 13 (utime) and 14 (stime) are in clock ticks.
    if (fields.length < 15) return -1;
    final utime = int.tryParse(fields[13]) ?? 0;
    final stime = int.tryParse(fields[14]) ?? 0;
    final totalTicks = utime + stime;
    // Convert ticks to microseconds (assuming 100 Hz tick rate = 10000 µs/tick).
    final totalUs = totalTicks * 10000;

    final now = DateTime.now();
    if (_prevCpuTimeUs > 0) {
      final deltaCpu = totalUs - _prevCpuTimeUs;
      final deltaWall = now.difference(_prevCpuSampleTime).inMicroseconds;
      _prevCpuTimeUs = totalUs;
      _prevCpuSampleTime = now;
      if (deltaWall > 0) {
        final cores = Platform.numberOfProcessors.clamp(1, 1024);
        return (deltaCpu / deltaWall / cores * 100).clamp(0.0, 100.0);
      }
    }
    _prevCpuTimeUs = totalUs;
    _prevCpuSampleTime = now;
    return -1; // First sample — need two to compute delta.
  }

  // ── CPU usage (macOS via /usr/bin/ps) ───────────

  Future<double> _macCpuPercent() async {
    try {
      final r = await _timedRun("ps", ["-o", "cputime=", "-p", "$pid"]);
      // Output format: "HH:MM:SS" or "M:SS.CC" — parse total seconds.
      final raw = r.stdout.toString().trim();
      final totalUs = _parsePsCpuTime(raw);
      if (totalUs < 0) return -1;

      final now = DateTime.now();
      if (_prevCpuTimeUs > 0) {
        final deltaCpu = totalUs - _prevCpuTimeUs;
        final deltaWall = now.difference(_prevCpuSampleTime).inMicroseconds;
        _prevCpuTimeUs = totalUs;
        _prevCpuSampleTime = now;
        if (deltaWall > 0) {
          final cores = Platform.numberOfProcessors.clamp(1, 1024);
          return (deltaCpu / deltaWall / cores * 100).clamp(0.0, 100.0);
        }
      }
      _prevCpuTimeUs = totalUs;
      _prevCpuSampleTime = now;
    } catch (_) {}
    return -1;
  }

  /// Parse `ps -o cputime=` output (e.g. "0:02.45" or "01:23:45") into µs.
  static int _parsePsCpuTime(String raw) {
    final parts = raw.split(":");
    if (parts.isEmpty) return -1;
    try {
      double seconds = 0;
      if (parts.length == 3) {
        seconds =
            int.parse(parts[0]) * 3600 +
            int.parse(parts[1]) * 60 +
            double.parse(parts[2]);
      } else if (parts.length == 2) {
        seconds = int.parse(parts[0]) * 60 + double.parse(parts[1]);
      } else {
        seconds = double.parse(parts[0]);
      }
      return (seconds * 1e6).round();
    } catch (_) {
      return -1;
    }
  }

  // ── Helpers ─────────────────────────────────────

  static const Duration _procTimeout = Duration(seconds: 3);

  static Future<ProcessResult> _timedRun(String exe, List<String> args) async {
    return Process.run(exe, args).timeout(
      _procTimeout,
      onTimeout: () => ProcessResult(0, 1, "", "timeout"),
    );
  }

  static double _extractNumber(String text, String pattern) {
    final m = RegExp(pattern).firstMatch(text);
    if (m == null) return 0;
    return double.tryParse(m.group(1)!) ?? 0;
  }
}

class _GpuMetrics {
  final double vramUsedMb, vramTotalMb, loadPercent, tempC;
  _GpuMetrics({
    required this.vramUsedMb,
    required this.vramTotalMb,
    required this.loadPercent,
    required this.tempC,
  });
}
