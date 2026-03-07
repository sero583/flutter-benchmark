/// Home page — benchmark list, run management, and system info.
///
/// Displays the list of available benchmarks, a header bar with actions
/// (Run All, Info, Export, Import, Compare), and a side panel showing
/// completed and in-progress runs.
library;

import "dart:async";
import "dart:convert";

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";

import "benchmark_defs.dart";
import "comparison_page.dart";
import "export_dialog.dart";
import "models.dart";
import "platform_utils.dart";
import "runner_page.dart";
import "system_monitor.dart";
import "theme.dart";

/// The main benchmark list and run management page.
class BenchmarkHome extends StatefulWidget {
  const BenchmarkHome({super.key});
  @override
  State<BenchmarkHome> createState() => _BenchmarkHomeState();
}

class _BenchmarkHomeState extends State<BenchmarkHome> {
  final List<BenchmarkRun> _runs = [];
  final List<BenchmarkResult> _currentRunResults = [];
  late String _renderer;

  @override
  void initState() {
    super.initState();
    _renderer = PlatformUtils.detectRenderer();
  }

  void _addResult(BenchmarkResult r) {
    setState(() => _currentRunResults.add(r));
  }

  /// Finalize the current in-progress run into the runs list.
  void _finalizeRun() {
    if (_currentRunResults.isEmpty) return;
    setState(() {
      _runs.add(
        BenchmarkRun(
          number: _runs.length + 1,
          renderer: _renderer,
          timestamp: DateTime.now(),
          results: List.of(_currentRunResults),
        ),
      );
      _currentRunResults.clear();
    });
  }

  /// Latest result for a given test name (across all runs).
  BenchmarkResult? _latestFor(String testName) {
    for (final run in _runs.reversed) {
      for (final r in run.results.reversed) {
        if (r.testName == testName) return r;
      }
    }
    for (final r in _currentRunResults.reversed) {
      if (r.testName == testName) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Row(
                children: [
                  Expanded(flex: 3, child: _buildList(context)),
                  if (_runs.isNotEmpty || _currentRunResults.isNotEmpty)
                    Expanded(flex: 2, child: _buildRunsPanel()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Header bar
  // -----------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final isNarrow = MediaQuery.sizeOf(context).width < 600;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 10 : 20,
        vertical: isNarrow ? 8 : 14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kCyan.withValues(alpha: 0.12),
            kPurple.withValues(alpha: 0.12),
          ],
        ),
        border: Border(bottom: BorderSide(color: kCyan.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Icon(Icons.speed, color: kCyan, size: isNarrow ? 22 : 30),
          SizedBox(width: isNarrow ? 6 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNarrow
                      ? "Benchmark Suite"
                      : "Flutter Renderer Benchmark Suite",
                  style: TextStyle(
                    fontSize: isNarrow ? 14 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _renderer == "Undetected"
                    ? Tooltip(
                        message:
                            "Renderer detection requires the custom Flutter "
                            "engine build with RenderingBackend constants.\n"
                            "Using stock Flutter — detection unavailable.",
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${PlatformUtils.platformName} • $_renderer",
                              style: TextStyle(
                                fontSize: isNarrow ? 10 : 12,
                                color: Colors.orange.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.help_outline,
                              size: 12,
                              color: Colors.orange.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        "${PlatformUtils.platformName} • $_renderer",
                        style: TextStyle(
                          fontSize: isNarrow ? 10 : 12,
                          color: kCyan.withValues(alpha: 0.8),
                        ),
                      ),
              ],
            ),
          ),
          _iconBtn(
            Icons.play_arrow,
            "Run All",
            kCyan,
            _runAll,
            compact: isNarrow,
          ),
          SizedBox(width: isNarrow ? 4 : 8),
          _iconBtn(
            Icons.info_outline,
            "Info",
            Colors.lightBlueAccent,
            _showSystemInfo,
            compact: isNarrow,
          ),
          SizedBox(width: isNarrow ? 4 : 8),
          _iconBtn(
            Icons.file_download,
            "Export",
            Colors.greenAccent,
            _runs.isEmpty ? null : _export,
            compact: isNarrow,
          ),
          SizedBox(width: isNarrow ? 4 : 8),
          _iconBtn(
            Icons.file_upload,
            "Import",
            Colors.amberAccent,
            _import,
            compact: isNarrow,
          ),
          SizedBox(width: isNarrow ? 4 : 8),
          _iconBtn(
            Icons.compare_arrows,
            "Compare",
            kPurple,
            _compare,
            compact: isNarrow,
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback? onTap, {
    bool compact = false,
  }) {
    return Tooltip(
      message: label,
      child: Material(
        color: onTap != null
            ? color.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: compact ? 16 : 18,
                  color: onTap != null ? color : Colors.grey,
                ),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: onTap != null ? color : Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Actions
  // -----------------------------------------------------------------------

  Future<void> _runAll() async {
    _currentRunResults.clear();
    for (final b in benchmarks) {
      if (!mounted) break;
      final r = await Navigator.push<BenchmarkResult>(
        context,
        MaterialPageRoute(
          builder: (_) => BenchmarkRunnerPage(
            benchmark: b,
            renderer: _renderer,
            onComplete: _addResult,
          ),
        ),
      );
      if (r == null && mounted) break;
      // Brief pause between benchmarks to let the GC and GPU settle.
      await Future.delayed(const Duration(milliseconds: 300));
    }
    _finalizeRun();
  }

  void _showSystemInfo() async {
    final info = PlatformUtils.getRenderingInfo();
    StateSetter dialogSetState = (_) {};
    bool loading = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          dialogSetState = setDialogState;
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.info_outline, color: kCyan, size: 22),
                const SizedBox(width: 8),
                const Text(
                  "System & Rendering Info",
                  style: TextStyle(fontSize: 16),
                ),
                if (loading) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kCyan,
                    ),
                  ),
                ],
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...info.entries.map((e) {
                      final isRenderer = e.key == "Detected Renderer";
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 180,
                              child: Text(
                                e.key,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                e.value,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: "monospace",
                                  fontWeight: isRenderer
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isRenderer
                                      ? (e.value.contains("Vulkan")
                                            ? Colors.greenAccent
                                            : kCyan)
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (loading) ...[
                      const SizedBox(height: 12),
                      _buildSkeleton(),
                      _buildSkeleton(),
                      _buildSkeleton(),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  PlatformUtils.copyToClipboard(
                    info.entries.map((e) => "${e.key}: ${e.value}").join("\n"),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Copied to clipboard"),
                      backgroundColor: Colors.greenAccent,
                    ),
                  );
                },
                child: const Text("Copy"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Close"),
              ),
            ],
          );
        },
      ),
    );

    // Fetch resource data asynchronously.
    final monitor = SystemMonitor();
    monitor.start();
    // Sample system resources for about 1.2 s so counters stabilize.
    await Future.delayed(const Duration(milliseconds: 1200));
    monitor.stop();
    final snap = monitor.latest;
    if (snap != null) {
      if (snap.systemRamTotalMb > 0) {
        info["System RAM"] =
            "${snap.systemRamUsedMb.toStringAsFixed(0)} / ${snap.systemRamTotalMb.toStringAsFixed(0)} MB";
      }
      info["Process RSS"] = "${snap.dartRssMb.toStringAsFixed(1)} MB";
      if (snap.vramTotalMb > 0) {
        info["VRAM"] =
            "${snap.vramUsedMb.toStringAsFixed(0)} / ${snap.vramTotalMb.toStringAsFixed(0)} MB";
      }
      if (snap.gpuTempC >= 0) {
        info["GPU Temperature"] = "${snap.gpuTempC.toStringAsFixed(0)} °C";
      }
      if (snap.gpuLoadPercent >= 0) {
        info["GPU Utilization"] = "${snap.gpuLoadPercent.toStringAsFixed(0)} %";
      }
    }
    if (mounted) {
      try {
        dialogSetState(() => loading = false);
      } catch (_) {
        // Dialog may have been dismissed.
      }
    }
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _export() {
    final run = _runs.last;
    final data = ExportData(
      systemInfo: SystemInfo.detect(_renderer),
      results: run.results,
    );
    final json = data.toJsonString();
    showDialog(
      context: context,
      builder: (_) => ExportDialog(json: json),
    );
  }

  Future<void> _import() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["json"],
        withData: true,
      );
      if (result == null) return;
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Could not read file data"),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
        return;
      }
      final content = utf8.decode(bytes);
      final data = ExportData.fromJsonString(content);
      if (data.results.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No results found in file"),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
        return;
      }
      setState(() {
        _runs.add(
          BenchmarkRun(
            number: _runs.length + 1,
            renderer: data.systemInfo.renderer,
            timestamp:
                DateTime.tryParse(data.systemInfo.timestamp) ?? DateTime.now(),
            results: data.results,
          ),
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Imported Run ${_runs.length}: ${data.results.length} tests "
              "from ${data.systemInfo.renderer}",
            ),
            backgroundColor: Colors.greenAccent.withValues(alpha: 0.8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Import error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _compare() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ComparisonPage(runs: _runs)),
    );
  }

  // -----------------------------------------------------------------------
  // Benchmark list
  // -----------------------------------------------------------------------

  Widget _buildList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: benchmarks.length,
      itemBuilder: (context, i) {
        final b = benchmarks[i];
        return _BenchmarkCard(
          benchmark: b,
          renderer: _renderer,
          onComplete: _addResult,
          lastResult: _latestFor(b.name),
        );
      },
    );
  }

  // -----------------------------------------------------------------------
  // Runs panel
  // -----------------------------------------------------------------------

  Widget _buildRunsPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kCyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.analytics, color: kCyan, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${_runs.length} Run${_runs.length == 1 ? "" : "s"}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() {
                    _runs.clear();
                    _currentRunResults.clear();
                  }),
                  tooltip: "Clear all",
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                if (_currentRunResults.isNotEmpty) ...[
                  _runHeader(
                    "In Progress",
                    Colors.orangeAccent,
                    _currentRunResults.length,
                  ),
                  for (int i = 0; i < _currentRunResults.length; i++)
                    _ResultTile(result: _currentRunResults[i], index: i + 1),
                  const SizedBox(height: 10),
                ],
                for (final run in _runs.reversed) ...[
                  _runHeader(run.label, kCyan, run.results.length),
                  for (int i = 0; i < run.results.length; i++)
                    _ResultTile(result: run.results[i], index: i + 1),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _runHeader(String label, Color color, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.flag, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Text(
            "$count tests",
            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Benchmark card — list item for a single benchmark
// ---------------------------------------------------------------------------

class _BenchmarkCard extends StatelessWidget {
  final BenchmarkDef benchmark;
  final String renderer;
  final void Function(BenchmarkResult) onComplete;
  final BenchmarkResult? lastResult;

  const _BenchmarkCard({
    required this.benchmark,
    required this.renderer,
    required this.onComplete,
    this.lastResult,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BenchmarkRunnerPage(
              benchmark: benchmark,
              renderer: renderer,
              onComplete: onComplete,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: benchmark.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(benchmark.icon, color: benchmark.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      benchmark.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      benchmark.description,
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              if (lastResult != null) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${lastResult!.avgFps.toStringAsFixed(1)} FPS",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: fpsColor(lastResult!.avgFps),
                        ),
                      ),
                      Text(
                        "Score: ${lastResult!.smoothnessScore.toStringAsFixed(0)}",
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
              Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result tile — compact row in the runs panel
// ---------------------------------------------------------------------------

class _ResultTile extends StatelessWidget {
  final BenchmarkResult result;
  final int index;
  const _ResultTile({required this.result, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              "$index",
              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              result.testName,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            result.avgFps.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: "monospace",
              color: fpsColor(result.avgFps),
            ),
          ),
          const SizedBox(width: 4),
          Text("FPS", style: TextStyle(fontSize: 8, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
