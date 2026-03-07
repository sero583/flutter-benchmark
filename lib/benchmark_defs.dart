/// Benchmark definitions that wire scene widgets to metadata.
///
/// Each [BenchmarkDef] provides a name, description, icon, color, builder
/// function, and optional duration. The [benchmarks] list defines the full
/// set of stress-test scenes available in the suite.
library;

import "package:flutter/material.dart";

import "benchmark_scenes.dart";

/// Definition of a single benchmark scene.
class BenchmarkDef {
  /// Display name shown in the benchmark list.
  final String name;

  /// Short description of what this benchmark stresses.
  final String description;

  /// Icon for the benchmark card.
  final IconData icon;

  /// Accent color for the benchmark card.
  final Color color;

  /// Factory that creates the benchmark scene widget.
  final Widget Function() builder;

  /// How long the measured phase runs (after warmup completes).
  final Duration duration;

  const BenchmarkDef({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.builder,
    this.duration = const Duration(seconds: 15),
  });
}

/// The nine benchmark scenes available in the suite.
final benchmarks = List<BenchmarkDef>.unmodifiable([
  BenchmarkDef(
    name: "Particle Storm",
    description: "10 000 particles with physics, blending & color transitions",
    icon: Icons.grain,
    color: Colors.orangeAccent,
    builder: () => const ParticleStormBenchmark(),
  ),
  BenchmarkDef(
    name: "Widget Cascade",
    description: "500 animated, nested, clipped, shadowed widgets",
    icon: Icons.widgets,
    color: Colors.blueAccent,
    builder: () => const WidgetCascadeBenchmark(),
  ),
  BenchmarkDef(
    name: "Custom Painter Heavy",
    description: "2 000 bézier curves with gradient fills per frame",
    icon: Icons.brush,
    color: Colors.greenAccent,
    builder: () => const CustomPainterBenchmark(),
  ),
  BenchmarkDef(
    name: "Image Composition",
    description: "200 overlapping gradient orbs with opacity animations",
    icon: Icons.layers,
    color: Colors.purpleAccent,
    builder: () => const ImageCompositionBenchmark(),
  ),
  BenchmarkDef(
    name: "Text Rendering Stress",
    description: "1 000 text spans with varying sizes, weights & shadows",
    icon: Icons.text_fields,
    color: Colors.redAccent,
    builder: () => const TextRenderingBenchmark(),
  ),
  BenchmarkDef(
    name: "Transform & Clip",
    description: "300 rotated, scaled, clipped containers every frame",
    icon: Icons.transform,
    color: Colors.tealAccent,
    builder: () => const TransformClipBenchmark(),
  ),
  BenchmarkDef(
    name: "Shader Mask Matrix",
    description: "8×8 grid of shader-masked animated gradients",
    icon: Icons.gradient,
    color: Colors.amberAccent,
    builder: () => const ShaderMaskBenchmark(),
  ),
  BenchmarkDef(
    name: "Opacity Tree",
    description: "Deep nesting of animated opacity + color filter layers",
    icon: Icons.opacity,
    color: Colors.pinkAccent,
    builder: () => const OpacityTreeBenchmark(),
  ),
  BenchmarkDef(
    name: "Text Scale Test",
    description: "Non-uniform Transform.scale text rendering (Issue #182143)",
    icon: Icons.text_rotation_angleup,
    color: Colors.redAccent,
    builder: () => const TextScaleTestBenchmark(),
    duration: const Duration(seconds: 20),
  ),
]);
