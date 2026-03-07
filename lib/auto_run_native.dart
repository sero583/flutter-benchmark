/// Auto-run detection and app — native implementation.
///
/// Runs all benchmarks sequentially, exports JSON results, then exits.
/// Triggered by `--dart-define=AUTO_RUN=true` or `AUTO_BENCH_OUTPUT` env var.
library;

import "dart:io" show File, Platform, exit;

import "package:flutter/material.dart";
import "package:flutter/scheduler.dart";

import "benchmark_defs.dart";
import "models.dart";
import "platform_utils.dart";
import "runner_page.dart";
import "theme.dart" show kBgDark, kCyan;

/// Whether auto-run mode was requested.
bool get isAutoRunRequested {
  const autoRunDefine = bool.fromEnvironment("AUTO_RUN");
  if (autoRunDefine) return true;
  return Platform.environment.containsKey("AUTO_BENCH_OUTPUT");
}

/// The auto-run app widget.
Widget buildAutoRunApp() => const _AutoRunApp();

class _AutoRunApp extends StatelessWidget {
  const _AutoRunApp();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(
        useMaterial3: true,
      ).copyWith(scaffoldBackgroundColor: kBgDark),
      home: const _AutoRunPage(),
    );
  }
}

class _AutoRunPage extends StatefulWidget {
  const _AutoRunPage();
  @override
  State<_AutoRunPage> createState() => _AutoRunPageState();
}

class _AutoRunPageState extends State<_AutoRunPage> {
  String _status = "Starting auto-run…";
  int _current = 0;
  final List<BenchmarkResult> _results = [];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) => _runAll());
  }

  Future<void> _runAll() async {
    final renderer = PlatformUtils.detectRenderer();
    for (int i = 0; i < benchmarks.length; i++) {
      if (!mounted) return;
      setState(() {
        _current = i + 1;
        _status =
            "Running ${benchmarks[i].name} ($_current/${benchmarks.length})";
      });
      final result = await Navigator.push<BenchmarkResult>(
        context,
        MaterialPageRoute(
          builder: (_) => BenchmarkRunnerPage(
            benchmark: benchmarks[i],
            renderer: renderer,
            // No-op: result is captured from Navigator.pop return value.
            onComplete: (r) {},
          ),
        ),
      );
      if (result != null) _results.add(result);
      // Brief pause between benchmarks to let the GC and GPU settle.
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (!mounted) return;
    setState(() {
      _status = "All benchmarks complete. Exporting…";
      _done = true;
    });
    final data = ExportData(
      systemInfo: SystemInfo.detect(renderer),
      results: _results,
    );
    final outputPath = Platform.environment["AUTO_BENCH_OUTPUT"] ?? "";
    if (outputPath.isNotEmpty) {
      try {
        final file = File(outputPath);
        await file.writeAsString(data.toJsonString());
        setState(() => _status = "Saved to ${file.path}");
      } catch (e) {
        setState(() => _status = "Export error: $e");
      }
    } else {
      final msg = PlatformUtils.downloadFile(
        data.toJsonString(),
        'auto_bench_${renderer.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      setState(() => _status = msg);
    }
    // Give the user a moment to read the final status before exiting.
    await Future.delayed(const Duration(seconds: 3));
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _done ? Icons.check_circle : Icons.speed,
                color: _done ? Colors.greenAccent : kCyan,
                size: 60,
              ),
              const SizedBox(height: 16),
              const Text(
                "Auto-Run Benchmark",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: kCyan,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                PlatformUtils.detectRenderer(),
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
              const SizedBox(height: 20),
              if (!_done)
                LinearProgressIndicator(
                  value: benchmarks.isEmpty ? 0 : _current / benchmarks.length,
                  backgroundColor: Colors.grey[800],
                  color: kCyan,
                ),
              const SizedBox(height: 12),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
