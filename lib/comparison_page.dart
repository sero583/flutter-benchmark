/// Comparison page — side-by-side analysis of two benchmark runs.
///
/// Users can load runs from the current session or from exported JSON files.
/// Displays system info comparison, an overview table with per-test FPS
/// deltas, and detailed per-test cards with dual FPS graphs.
library;

import "dart:convert";
import "dart:math";

import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";

import "models.dart";
import "theme.dart";

/// Page for comparing two benchmark runs (A = baseline, B = current).
class ComparisonPage extends StatefulWidget {
  /// Runs from the current session available for quick selection.
  final List<BenchmarkRun> runs;

  const ComparisonPage({super.key, required this.runs});

  @override
  State<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends State<ComparisonPage> {
  ExportData? _dataA;
  ExportData? _dataB;
  String _labelA = "Not loaded";
  String _labelB = "Not loaded";

  Future<ExportData?> _pickJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["json"],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return null;
    final content = utf8.decode(result.files.single.bytes!);
    return ExportData.fromJsonString(content);
  }

  void _useRun(bool isA, BenchmarkRun run) {
    final data = ExportData(
      systemInfo: SystemInfo.detect(run.renderer),
      results: run.results,
    );
    setState(() {
      if (isA) {
        _dataA = data;
        _labelA = run.label;
      } else {
        _dataB = data;
        _labelB = run.label;
      }
    });
  }

  Future<void> _loadFile(bool isA) async {
    try {
      final data = await _pickJsonFile();
      if (data == null) return;
      final label =
          "${data.systemInfo.renderer} — ${data.results.length} tests";
      setState(() {
        if (isA) {
          _dataA = data;
          _labelA = label;
        } else {
          _dataB = data;
          _labelB = label;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error reading file: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  bool get _ready => _dataA != null && _dataB != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Compare Results"),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildLoaderRow(),
          if (_ready) ...[
            const SizedBox(height: 16),
            _buildSystemInfo(),
            const SizedBox(height: 16),
            _buildOverviewTable(),
            const SizedBox(height: 16),
            ..._buildPerTestCards(),
          ] else ...[
            const SizedBox(height: 80),
            Center(
              child: Column(
                children: [
                  Icon(Icons.compare_arrows, size: 60, color: Colors.grey[700]),
                  const SizedBox(height: 12),
                  Text(
                    "Pick two runs or files above to compare",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoaderRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _slotCard("A", "Baseline", _labelA, _dataA != null, true),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _slotCard("B", "Current", _labelB, _dataB != null, false),
        ),
      ],
    );
  }

  Widget _slotCard(
    String letter,
    String title,
    String label,
    bool loaded,
    bool isA,
  ) {
    final color = isA ? kCyan : kPurple;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: loaded
              ? color.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (loaded)
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Colors.greenAccent,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            _actionChip(
              Icons.folder_open,
              "Pick File",
              color,
              () => _loadFile(isA),
            ),
            if (widget.runs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "Session Runs:",
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final run in widget.runs)
                    _actionChip(
                      Icons.flag,
                      run.label,
                      Colors.amberAccent,
                      () => _useRun(isA, run),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionChip(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(fontSize: 10, color: color)),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.08),
      onPressed: onTap,
    );
  }

  // -----------------------------------------------------------------------
  // System info comparison
  // -----------------------------------------------------------------------

  Widget _buildSystemInfo() {
    final a = _dataA!.systemInfo;
    final b = _dataB!.systemInfo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "System Info",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _sysRow("Renderer", a.renderer, b.renderer),
            _sysRow("GPU", a.gpu, b.gpu),
            _sysRow("System", a.browser, b.browser),
            _sysRow("Screen", a.screenSize, b.screenSize),
            _sysRow("DPR", a.dpr.toStringAsFixed(1), b.dpr.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }

  Widget _sysRow(String label, String a, String b) {
    final same = a == b;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
          Expanded(
            child: Text(
              a,
              style: const TextStyle(
                fontSize: 11,
                color: kCyan,
                fontFamily: "monospace",
              ),
            ),
          ),
          if (!same)
            const Text(
              " vs ",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          Expanded(
            child: Text(
              same ? "(same)" : b,
              style: TextStyle(
                fontSize: 11,
                color: same ? Colors.grey[600] : kPurple,
                fontFamily: "monospace",
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Overview table
  // -----------------------------------------------------------------------

  Widget _buildOverviewTable() {
    final pairs = _matchTests();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Overview — $_labelA vs $_labelB",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingTextStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[400],
                ),
                dataTextStyle: const TextStyle(fontSize: 11),
                columns: const [
                  DataColumn(label: Text("Test")),
                  DataColumn(label: Text("A FPS"), numeric: true),
                  DataColumn(label: Text("B FPS"), numeric: true),
                  DataColumn(label: Text("Δ FPS"), numeric: true),
                  DataColumn(label: Text("A Score"), numeric: true),
                  DataColumn(label: Text("B Score"), numeric: true),
                  DataColumn(label: Text("Verdict")),
                ],
                rows: pairs.map((p) {
                  final diff = p.a.avgFps != 0
                      ? ((p.b.avgFps - p.a.avgFps) / p.a.avgFps * 100)
                      : 0.0;
                  final better = diff > 0.5;
                  final worse = diff < -0.5;
                  final color = better
                      ? Colors.greenAccent
                      : worse
                      ? Colors.redAccent
                      : Colors.grey;
                  return DataRow(
                    cells: [
                      DataCell(Text(p.name)),
                      DataCell(
                        Text(
                          p.a.avgFps.toStringAsFixed(1),
                          style: const TextStyle(color: kCyan),
                        ),
                      ),
                      DataCell(
                        Text(
                          p.b.avgFps.toStringAsFixed(1),
                          style: const TextStyle(color: kPurple),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          p.a.smoothnessScore.toStringAsFixed(0),
                          style: TextStyle(
                            color: scoreColor(p.a.smoothnessScore),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          p.b.smoothnessScore.toStringAsFixed(0),
                          style: TextStyle(
                            color: scoreColor(p.b.smoothnessScore),
                          ),
                        ),
                      ),
                      DataCell(_verdictBadge(better, worse)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verdictBadge(bool better, bool worse) {
    if (!better && !worse) {
      return Text(
        "SAME",
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey[500],
        ),
      );
    }
    final color = better ? Colors.greenAccent : Colors.redAccent;
    final text = better ? "B WINS" : "A WINS";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Per-test detail cards
  // -----------------------------------------------------------------------

  List<Widget> _buildPerTestCards() {
    return _matchTests()
        .map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _testDetailCard(p),
          ),
        )
        .toList();
  }

  Widget _testDetailCard(_TestPair p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: CustomPaint(
                painter: _DualFpsGraphPainter(p.a.fpsHistory, p.b.fpsHistory),
                size: Size.infinite,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(width: 12, height: 3, color: kCyan),
                const SizedBox(width: 4),
                Text(
                  "A: ${p.a.avgFps.toStringAsFixed(1)} FPS",
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
                const SizedBox(width: 16),
                Container(width: 12, height: 3, color: kPurple),
                const SizedBox(width: 4),
                Text(
                  "B: ${p.b.avgFps.toStringAsFixed(1)} FPS",
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _diffTable(p.a, p.b),
          ],
        ),
      ),
    );
  }

  Widget _diffTable(BenchmarkResult a, BenchmarkResult b) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "A → B Metric Comparison",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 6),
          _diffRow("Avg FPS", a.avgFps, b.avgFps, true),
          _diffRow("Min FPS", a.minFps, b.minFps, true),
          _diffRow("1% Low FPS", a.onePercentLow, b.onePercentLow, true),
          _diffRow(
            "Avg Frame Time",
            a.avgFrameTimeMs,
            b.avgFrameTimeMs,
            false,
            "ms",
          ),
          _diffRow(
            "p95 Frame Time",
            a.p95FrameTimeMs,
            b.p95FrameTimeMs,
            false,
            "ms",
          ),
          _diffRow(
            "p99 Frame Time",
            a.p99FrameTimeMs,
            b.p99FrameTimeMs,
            false,
            "ms",
          ),
          _diffRow("Jank %", a.jankPercent, b.jankPercent, false, "%"),
          _diffRow("Smoothness", a.smoothnessScore, b.smoothnessScore, true),
        ],
      ),
    );
  }

  Widget _diffRow(
    String label,
    double valA,
    double valB,
    bool higherBetter, [
    String suffix = "",
  ]) {
    final diff = valA != 0 ? ((valB - valA) / valA) * 100 : 0.0;
    final bool isBetter = higherBetter ? diff > 0.5 : diff < -0.5;
    final bool isWorse = higherBetter ? diff < -0.5 : diff > 0.5;
    final color = isBetter
        ? Colors.greenAccent
        : isWorse
        ? Colors.redAccent
        : Colors.grey;
    final arrow = diff > 0.5
        ? "↑"
        : diff < -0.5
        ? "↓"
        : "–";
    final diffStr = diff.abs() < 0.5
        ? "same"
        : '${diff > 0 ? "+" : ""}${diff.toStringAsFixed(1)}% $arrow';
    final tag = isBetter
        ? "BETTER"
        : isWorse
        ? "WORSE"
        : "";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              "${valA.toStringAsFixed(1)}$suffix",
              style: const TextStyle(
                fontSize: 10,
                fontFamily: "monospace",
                color: kCyan,
              ),
            ),
          ),
          const Text(" → ", style: TextStyle(fontSize: 10, color: Colors.grey)),
          SizedBox(
            width: 60,
            child: Text(
              "${valB.toStringAsFixed(1)}$suffix",
              style: const TextStyle(
                fontSize: 10,
                fontFamily: "monospace",
                color: kPurple,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            diffStr,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: "monospace",
            ),
          ),
          if (tag.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_TestPair> _matchTests() {
    if (_dataA == null || _dataB == null) return [];
    final aMap = <String, BenchmarkResult>{};
    for (final r in _dataA!.results) {
      aMap[r.testName] = r;
    }
    final pairs = <_TestPair>[];
    for (final r in _dataB!.results) {
      final a = aMap[r.testName];
      if (a != null) pairs.add(_TestPair(name: r.testName, a: a, b: r));
    }
    return pairs;
  }
}

/// A matched pair of benchmark results for the same test.
class _TestPair {
  final String name;
  final BenchmarkResult a, b;
  _TestPair({required this.name, required this.a, required this.b});
}

// ---------------------------------------------------------------------------
// Dual FPS graph painter — overlays two FPS history lines
// ---------------------------------------------------------------------------

class _DualFpsGraphPainter extends CustomPainter {
  final List<double> historyA, historyB;
  _DualFpsGraphPainter(this.historyA, this.historyB);

  @override
  void paint(Canvas canvas, Size size) {
    if (historyA.isEmpty && historyB.isEmpty) return;
    double maxFps = 0;
    if (historyA.isNotEmpty) maxFps = historyA.reduce(max);
    if (historyB.isNotEmpty) maxFps = max(maxFps, historyB.reduce(max));
    final targetMax = max(maxFps, 70.0);

    final y60 = size.height * (1 - 60 / targetMax);
    canvas.drawLine(
      Offset(0, y60),
      Offset(size.width, y60),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 1,
    );

    void drawLine(List<double> h, Color c) {
      if (h.isEmpty) return;
      final paint = Paint()
        ..color = c.withValues(alpha: 0.8)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (int i = 0; i < h.length; i++) {
        final x = i / h.length * size.width;
        final y = size.height * (1 - h[i] / targetMax);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }

    drawLine(historyA, kCyan);
    drawLine(historyB, kPurple);
  }

  @override
  bool shouldRepaint(covariant _DualFpsGraphPainter old) =>
      historyA.length != old.historyA.length ||
      historyB.length != old.historyB.length;
}
