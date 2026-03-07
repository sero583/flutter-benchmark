/// All renderer stress-test benchmark scenes for the Flutter Benchmark suite.
library;

import "dart:math";

import "package:flutter/material.dart";

// ─────────────────────────────────────────────────────────────
//  1. Particle Storm — 10 000 GPU-heavy particles
// ─────────────────────────────────────────────────────────────

/// Stress-tests the GPU with 10 000 animated particles.
///
/// Each frame updates particle positions with sinusoidal offsets and
/// repaints them via [CustomPaint] with per-particle HSV colours and
/// oscillating radii.
class ParticleStormBenchmark extends StatefulWidget {
  const ParticleStormBenchmark({super.key});
  @override
  State<ParticleStormBenchmark> createState() => _ParticleStormState();
}

class _ParticleStormState extends State<ParticleStormBenchmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Particle> _particles;
  final Random _rng = Random(42);

  @override
  void initState() {
    super.initState();
    _particles = List.generate(10000, (_) => _Particle(_rng));
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _updateParticles(double t) {
    for (final p in _particles) {
      p.x += p.vx + sin(t * 6.28 + p.hue) * 0.001;
      p.y += p.vy + cos(t * 6.28 + p.life) * 0.001;
      p.x = p.x % 1.0;
      p.y = p.y % 1.0;
      if (p.x < 0) p.x += 1;
      if (p.y < 0) p.y += 1;
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) {
      _updateParticles(_c.value);
      return CustomPaint(
        painter: _ParticlePainter(_particles, _c.value),
        size: Size.infinite,
      );
    },
  );
}

class _Particle {
  double x, y, vx, vy, size, hue, life;
  _Particle(Random r)
    : x = r.nextDouble(),
      y = r.nextDouble(),
      vx = (r.nextDouble() - 0.5) * 0.01,
      vy = (r.nextDouble() - 0.5) * 0.01,
      size = r.nextDouble() * 3 + 0.5,
      hue = r.nextDouble() * 360,
      life = r.nextDouble();
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;
  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final hue = (p.hue + t * 120) % 360;
      paint.color = HSVColor.fromAHSV(
        (0.4 + 0.6 * sin(t * 3.14 + p.life * 6.28)).clamp(0.1, 0.9),
        hue,
        0.9,
        1.0,
      ).toColor();
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size * (1 + 0.5 * sin(t * 10 + p.hue)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────
//  2. Widget Cascade — 500 animated widgets
// ─────────────────────────────────────────────────────────────

/// Stress-tests the widget layer with 500 simultaneously animated widgets.
///
/// Each widget moves, rotates, and resizes every frame via sinusoidal
/// functions, exercising the compositor's transform and layout pipelines.
class WidgetCascadeBenchmark extends StatefulWidget {
  const WidgetCascadeBenchmark({super.key});
  @override
  State<WidgetCascadeBenchmark> createState() => _WidgetCascadeState();
}

class _WidgetCascadeState extends State<WidgetCascadeBenchmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 30))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final screenSize = MediaQuery.of(context).size;
        return Stack(
          children: List.generate(500, (i) {
            final phase = i * 0.002;
            final x = (sin(t * 6.28 * 2 + phase * 20) + 1) / 2;
            final y = (cos(t * 6.28 * 3 + phase * 15) + 1) / 2;
            final sz = 20.0 + 30.0 * sin(t * 6.28 + phase * 10).abs();
            final hue = ((i * 7.3 + t * 360) % 360);
            return Positioned(
              left: x * (screenSize.width - sz),
              top: y * (screenSize.height - sz),
              child: Transform.rotate(
                angle: t * 6.28 + phase,
                child: Container(
                  width: sz,
                  height: sz,
                  decoration: BoxDecoration(
                    color: HSVColor.fromAHSV(0.7, hue, 0.8, 0.9).toColor(),
                    borderRadius: BorderRadius.circular(sz * 0.2),
                    boxShadow: [
                      BoxShadow(
                        color: HSVColor.fromAHSV(0.4, hue, 1.0, 1.0).toColor(),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  3. Custom Painter Heavy — 2 000 bézier curves
// ─────────────────────────────────────────────────────────────

/// Draws 2 000 animated quadratic Bézier curves per frame.
///
/// Measures raw [Canvas] path-drawing throughput — a good indicator
/// of tessellation and stroke performance in the GPU backend.
class CustomPainterBenchmark extends StatefulWidget {
  const CustomPainterBenchmark({super.key});
  @override
  State<CustomPainterBenchmark> createState() => _CustomPainterState();
}

class _CustomPainterState extends State<CustomPainterBenchmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) =>
        CustomPaint(painter: _BezierPainter(_c.value), size: Size.infinite),
  );
}

class _BezierPainter extends CustomPainter {
  final double t;
  _BezierPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (int i = 0; i < 2000; i++) {
      final phase = i * 0.003;
      final hue = (i * 0.18 + t * 200) % 360;
      paint.color = HSVColor.fromAHSV(0.5, hue, 0.9, 1.0).toColor();
      path.reset();
      path
        ..moveTo(
          size.width * ((sin(t * 4 + phase) + 1) / 2),
          size.height * ((cos(t * 3 + phase * 2) + 1) / 2),
        )
        ..quadraticBezierTo(
          size.width * ((sin(t * 7 + phase * 5) + 1) / 2),
          size.height * ((cos(t * 8 + phase * 6) + 1) / 2),
          size.width * ((sin(t * 5 + phase * 3) + 1) / 2),
          size.height * ((cos(t * 6 + phase * 4) + 1) / 2),
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────
//  4. Image Composition — 200 blurred layered images
// ─────────────────────────────────────────────────────────────

/// Composites 200 overlapping gradient circles with animated opacity.
///
/// Exercises alpha-blending and radial-gradient fill throughput,
/// stressing the fragment shader and compositing pipeline.
class ImageCompositionBenchmark extends StatefulWidget {
  const ImageCompositionBenchmark({super.key});
  @override
  State<ImageCompositionBenchmark> createState() => _ImageCompositionState();
}

class _ImageCompositionState extends State<ImageCompositionBenchmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 30))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final screenSize = MediaQuery.of(context).size;
        return Stack(
          children: List.generate(200, (i) {
            final phase = i * 0.005;
            final x = sin(t * 6.28 + phase * 10) * 0.5 + 0.5;
            final y = cos(t * 6.28 * 1.3 + phase * 8) * 0.5 + 0.5;
            final sz = 60.0 + 80.0 * sin(t * 6.28 * 2 + phase * 5).abs();
            final opacity = (0.3 + 0.5 * sin(t * 10 + phase * 20)).clamp(
              0.1,
              0.8,
            );
            final hue = ((i * 5.7 + t * 180) % 360);
            return Positioned(
              left: x * (screenSize.width - sz),
              top: y * (screenSize.height - sz),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: sz,
                  height: sz,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        HSVColor.fromAHSV(1, hue, 0.9, 1.0).toColor(),
                        HSVColor.fromAHSV(
                          1,
                          (hue + 60) % 360,
                          0.9,
                          0.5,
                        ).toColor(),
                        Colors.transparent,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  5. Text Rendering Stress — 1 000 text spans
// ─────────────────────────────────────────────────────────────

/// Paints 1 000 independently-styled text spans per frame.
///
/// Exercises the glyph atlas, font rasterizer, and text layout engine.
/// Font sizes are quantised to a narrow integer range (12–24 px) with
/// only two weights to keep atlas pressure bounded.
class TextRenderingBenchmark extends StatefulWidget {
  const TextRenderingBenchmark({super.key});
  @override
  State<TextRenderingBenchmark> createState() => _TextRenderingState();
}

class _TextRenderingState extends State<TextRenderingBenchmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 60))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) =>
        CustomPaint(painter: _TextStressPainter(_c.value), size: Size.infinite),
  );
}

class _TextStressPainter extends CustomPainter {
  final double t;
  _TextStressPainter(this.t);

  static const _words = [
    "Flutter",
    "Impeller",
    "Benchmark",
    "Performance",
    "Rendering",
    "GPU",
    "Shader",
    "Pipeline",
    "Canvas",
    "CanvasKit",
    "Skia",
    "WASM",
    "WebGL",
    "Vulkan",
    "Metal",
    "OpenGL",
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 1000; i++) {
      final phase = i * 0.00628;
      final x = (sin(t * 4 + phase * 7) + 1) / 2 * (size.width - 100);
      final y = (cos(t * 3 + phase * 11) + 1) / 2 * (size.height - 20);
      // Quantize to integer sizes in a narrow range (12-24) and limit weight
      // variants to keep glyph atlas entries bounded.  The atlas has a fixed
      // capacity and WILL crash (Fatal error in Impeller) if too many unique
      // font-size × weight combinations are requested simultaneously.
      final fontSize = (12.0 + 12.0 * sin(t * 5 + phase * 3).abs())
          .roundToDouble();
      final hue = (i * 0.36 + t * 200) % 360;
      // Use only 2 weights (normal + bold) instead of 3 to halve atlas pressure.
      final weight = i % 2 == 0 ? FontWeight.bold : FontWeight.normal;
      final tp = TextPainter(
        text: TextSpan(
          text: _words[i % _words.length],
          style: TextStyle(
            fontSize: fontSize,
            color: HSVColor.fromAHSV(0.9, hue, 0.8, 1.0).toColor(),
            fontWeight: weight,
            shadows: [
              Shadow(
                color: HSVColor.fromAHSV(0.5, hue, 1, 1).toColor(),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x, y));
      tp.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────
//  6. Transform & Clip Gauntlet
// ─────────────────────────────────────────────────────────────

/// Renders 300 widgets with animated rotation, scale, and oval clipping.
///
/// Heavily exercises the transform matrix stack and clip-path generation,
/// which are performance-sensitive in both Impeller and Skia backends.
class TransformClipBenchmark extends StatefulWidget {
  const TransformClipBenchmark({super.key});
  @override
  State<TransformClipBenchmark> createState() => _TransformClipState();
}

class _TransformClipState extends State<TransformClipBenchmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 30))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final ss = MediaQuery.of(context).size;
        return Stack(
          children: List.generate(300, (i) {
            final phase = i * 0.0033;
            final x = (sin(t * 6 + phase * 12) + 1) / 2;
            final y = (cos(t * 5 + phase * 10) + 1) / 2;
            final sz = 30.0 + 40.0 * sin(t * 8 + phase * 6).abs();
            final angle = t * 6.28 * 2 + phase * 20;
            final scale = 0.5 + 0.5 * sin(t * 10 + phase * 8).abs();
            final hue = ((i * 1.2 + t * 300) % 360);
            return Positioned(
              left: x * (ss.width - sz),
              top: y * (ss.height - sz),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..rotateZ(angle)
                  ..scaleByDouble(scale, scale, scale, 1.0),
                child: ClipOval(
                  child: Container(
                    width: sz,
                    height: sz,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          HSVColor.fromAHSV(0.8, hue, 0.9, 1.0).toColor(),
                          HSVColor.fromAHSV(
                            0.8,
                            (hue + 180) % 360,
                            0.9,
                            1.0,
                          ).toColor(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  7. Shader Mask Matrix — 8×8 animated shader masks
// ─────────────────────────────────────────────────────────────

/// Fills an 8×8 grid of rotating [ShaderMask] tiles.
///
/// Each tile applies an animated tri-colour linear gradient mask,
/// stressing fragment-shader switching and gradient interpolation.
class ShaderMaskBenchmark extends StatefulWidget {
  const ShaderMaskBenchmark({super.key});
  @override
  State<ShaderMaskBenchmark> createState() => _ShaderMaskState();
}

class _ShaderMaskState extends State<ShaderMaskBenchmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 30))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        return LayoutBuilder(
          builder: (context, constraints) {
            const cols = 8, rows = 8;
            final cellW = constraints.maxWidth / cols;
            final cellH = constraints.maxHeight / rows;
            return Stack(
              children: List.generate(cols * rows, (idx) {
                final col = idx % cols, row = idx ~/ cols;
                final phase = (col + row * cols) * 0.015;
                final hue = ((col * 45 + row * 45 + t * 360) % 360);
                final angle = sin(t * 6.28 * 2 + phase * 5) * 0.3;
                return Positioned(
                  left: col * cellW,
                  top: row * cellH,
                  width: cellW,
                  height: cellH,
                  child: Transform.rotate(
                    angle: angle,
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        begin: Alignment(
                          cos(t * 6.28 * 3 + phase),
                          sin(t * 6.28 * 3 + phase),
                        ),
                        end: Alignment(
                          -cos(t * 6.28 * 3 + phase),
                          -sin(t * 6.28 * 3 + phase),
                        ),
                        colors: [
                          HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                          HSVColor.fromAHSV(
                            1,
                            (hue + 120) % 360,
                            1,
                            1,
                          ).toColor(),
                          HSVColor.fromAHSV(
                            1,
                            (hue + 240) % 360,
                            1,
                            1,
                          ).toColor(),
                        ],
                      ).createShader(bounds),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            "${(t * 100 + idx).toInt() % 100}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  8. Opacity Tree — deep nested opacity + color filter layers
// ─────────────────────────────────────────────────────────────

/// Builds a 20-level deep tree of nested [Opacity] and [ColorFiltered] widgets.
///
/// Forces the engine to allocate and composite many off-screen render targets,
/// measuring save-layer overhead and intermediate texture throughput.
class OpacityTreeBenchmark extends StatefulWidget {
  const OpacityTreeBenchmark({super.key});
  @override
  State<OpacityTreeBenchmark> createState() => _OpacityTreeState();
}

class _OpacityTreeState extends State<OpacityTreeBenchmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 30))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) => _buildLayer(_c.value, 0, 20),
  );

  Widget _buildLayer(double t, int depth, int maxDepth) {
    if (depth >= maxDepth) {
      return Container(
        decoration: BoxDecoration(
          gradient: SweepGradient(
            startAngle: t * 6.28,
            colors: const [
              Colors.cyanAccent,
              Colors.purpleAccent,
              Colors.orangeAccent,
              Colors.cyanAccent,
            ],
          ),
        ),
      );
    }
    final opacity = (0.5 + 0.5 * sin(t * 8 + depth * 0.5)).clamp(0.3, 0.95);
    final hue = ((depth * 18 + t * 200) % 360);
    return Opacity(
      opacity: opacity,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          HSVColor.fromAHSV(0.1, hue, 0.5, 1).toColor(),
          BlendMode.overlay,
        ),
        child: Padding(
          padding: EdgeInsets.all(4.0 + 2.0 * sin(t * 12 + depth).abs()),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: HSVColor.fromAHSV(0.5, hue, 0.8, 1.0).toColor(),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildLayer(t, depth + 1, maxDepth),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  9. Text Scale Test — non-uniform Transform.scale text
//     Reproduces flutter/flutter#182143: jagged diagonals &
//     varying stroke weights when scaleY != scaleX.
// ─────────────────────────────────────────────────────────────

/// Reproduces [flutter/flutter#182143](https://github.com/flutter/flutter/issues/182143):
/// non-uniform `Transform.scale` causes jagged diagonals and uneven
/// stroke weights in Impeller's text rasteriser.
///
/// Displays static and animated scale comparisons across font weights,
/// diagonal-heavy characters, and large letterforms so the artefact is
/// clearly visible.
class TextScaleTestBenchmark extends StatefulWidget {
  const TextScaleTestBenchmark({super.key});
  @override
  State<TextScaleTestBenchmark> createState() => _TextScaleTestState();
}

class _TextScaleTestState extends State<TextScaleTestBenchmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 30))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = _c.value;
        return Container(
          color: const Color(0xFF1A1A2E),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  "Text Scale Test — Issue #182143",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Non-uniform Transform.scale causes jagged text in Impeller.\n"
                  "Look for varying stroke weights and jagged diagonal strokes.",
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),

                // Row 1: Static comparisons
                _sectionHeader("Static Comparisons"),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _testCase("No scale", 1.0, 1.0)),
                    const SizedBox(width: 12),
                    Expanded(child: _testCase("scaleY: 2", 1.0, 2.0)),
                    const SizedBox(width: 12),
                    Expanded(child: _testCase("scaleX: 2", 2.0, 1.0)),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _testCase("scaleY: 1.5", 1.0, 1.5)),
                    const SizedBox(width: 12),
                    Expanded(child: _testCase("scaleY: 3", 1.0, 3.0)),
                    const SizedBox(width: 12),
                    Expanded(child: _testCase("scale: 2 (uniform)", 2.0, 2.0)),
                  ],
                ),
                const SizedBox(height: 20),

                // Row 2: Animated scale
                _sectionHeader("Animated Non-Uniform Scale"),
                const SizedBox(height: 8),
                _animatedScaleRow(t),
                const SizedBox(height: 20),

                // Row 3: Various fonts and weights
                _sectionHeader("Different Fonts & Weights"),
                const SizedBox(height: 8),
                _fontWeightRow(),
                const SizedBox(height: 20),

                // Row 4: Side-by-side "before fix / after fix" demo
                _sectionHeader("Diagonal Stroke Quality"),
                const SizedBox(height: 8),
                _diagonalStrokeRow(),
                const SizedBox(height: 20),

                // Row 5: Animated cycling through various ratios
                _sectionHeader("Scale Ratio Sweep (animated)"),
                const SizedBox(height: 8),
                _scaleSweep(t),
                const SizedBox(height: 20),

                // Row 6: Large text demonstrating the issue clearly
                _sectionHeader("Large Text Showcase"),
                const SizedBox(height: 8),
                _largeTextShowcase(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.2)),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.cyanAccent,
        ),
      ),
    );
  }

  Widget _testCase(String label, double sx, double sy) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
          Text(
            "scaleX=$sx, scaleY=$sy",
            style: TextStyle(fontSize: 9, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          ClipRect(
            child: SizedBox(
              height: 60,
              child: Transform.scale(
                scaleX: sx,
                scaleY: sy,
                alignment: Alignment.topLeft,
                child: const Text(
                  "AaBbWwMm\nHello Vulkan!",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _animatedScaleRow(double t) {
    // Animate scaleY from 1.0 to 3.0 and back
    final scaleY = 1.0 + 2.0 * (0.5 + 0.5 * sin(t * 2 * pi));
    final scaleX = 1.0 + 1.5 * (0.5 + 0.5 * cos(t * 2 * pi * 0.7));
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "scaleY: ${scaleY.toStringAsFixed(2)} (animated)",
                  style: TextStyle(fontSize: 10, color: Colors.orangeAccent),
                ),
                const SizedBox(height: 4),
                ClipRect(
                  child: SizedBox(
                    height: 70,
                    child: Transform.scale(
                      scaleX: 1.0,
                      scaleY: scaleY,
                      alignment: Alignment.topLeft,
                      child: const Text(
                        "Quick brown fox\njumps over lazy dog",
                        style: TextStyle(fontSize: 13, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "scaleX: ${scaleX.toStringAsFixed(2)} (animated)",
                  style: TextStyle(fontSize: 10, color: Colors.purpleAccent),
                ),
                const SizedBox(height: 4),
                ClipRect(
                  child: SizedBox(
                    height: 70,
                    child: Transform.scale(
                      scaleX: scaleX,
                      scaleY: 1.0,
                      alignment: Alignment.topLeft,
                      child: const Text(
                        "Quick brown fox\njumps over lazy dog",
                        style: TextStyle(fontSize: 13, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Both: sx=${scaleX.toStringAsFixed(1)} sy=${scaleY.toStringAsFixed(1)}",
                  style: TextStyle(fontSize: 10, color: Colors.greenAccent),
                ),
                const SizedBox(height: 4),
                ClipRect(
                  child: SizedBox(
                    height: 70,
                    child: Transform.scale(
                      scaleX: scaleX,
                      scaleY: scaleY,
                      alignment: Alignment.topLeft,
                      child: const Text(
                        "Quick brown fox\njumps over lazy dog",
                        style: TextStyle(fontSize: 13, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fontWeightRow() {
    const weights = [
      ("Thin", FontWeight.w100),
      ("Light", FontWeight.w300),
      ("Regular", FontWeight.w400),
      ("Medium", FontWeight.w500),
      ("Bold", FontWeight.w700),
      ("Black", FontWeight.w900),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: weights.map((w) {
        return Container(
          width: 140,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                w.$1,
                style: TextStyle(fontSize: 9, color: Colors.grey[500]),
              ),
              const SizedBox(height: 4),
              ClipRect(
                child: SizedBox(
                  height: 45,
                  child: Transform.scale(
                    scaleX: 1.0,
                    scaleY: 2.0,
                    alignment: Alignment.topLeft,
                    child: Text(
                      "AaWwMm",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: w.$2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _diagonalStrokeRow() {
    // Characters with lots of diagonals that show the issue most clearly
    const diagText = "AVWXYZ avwxyz /\\|{}";
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.greenAccent.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Uniform scale (OK)",
                  style: TextStyle(fontSize: 10, color: Colors.greenAccent),
                ),
                const SizedBox(height: 6),
                Transform.scale(
                  scale: 2.0,
                  alignment: Alignment.topLeft,
                  child: const Text(
                    diagText,
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Non-uniform scaleY:2 (BUG #182143)",
                  style: TextStyle(fontSize: 10, color: Colors.redAccent),
                ),
                const SizedBox(height: 6),
                ClipRect(
                  child: SizedBox(
                    height: 50,
                    child: Transform.scale(
                      scaleX: 1.0,
                      scaleY: 2.0,
                      alignment: Alignment.topLeft,
                      child: const Text(
                        diagText,
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _scaleSweep(double t) {
    // Sweep through different scale ratios
    final ratios = <double>[1.0, 1.2, 1.5, 2.0, 2.5, 3.0];
    final idx = (t * ratios.length * 2).floor() % ratios.length;
    final currentRatio = ratios[idx];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (int i = 0; i < ratios.length; i++) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: i == idx
                        ? Colors.cyanAccent.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: i == idx
                          ? Colors.cyanAccent
                          : Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    "Y:${ratios[i]}",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: i == idx
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: i == idx ? Colors.cyanAccent : Colors.grey[600],
                    ),
                  ),
                ),
                if (i < ratios.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ClipRect(
            child: SizedBox(
              height: 60,
              child: Transform.scale(
                scaleX: 1.0,
                scaleY: currentRatio,
                alignment: Alignment.topLeft,
                child: const Text(
                  "The quick brown fox jumps over the lazy dog. AVWXYZ 0123456789",
                  style: TextStyle(fontSize: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _largeTextShowcase() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.greenAccent.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Normal",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Hg",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "scaleY: 2 (bug)",
                  style: const TextStyle(fontSize: 10, color: Colors.redAccent),
                ),
                const SizedBox(height: 4),
                ClipRect(
                  child: SizedBox(
                    height: 120,
                    child: Transform.scale(
                      scaleX: 1.0,
                      scaleY: 2.0,
                      alignment: Alignment.topLeft,
                      child: const Text(
                        "Hg",
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "scale: 2 (uniform, OK)",
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRect(
                  child: SizedBox(
                    height: 120,
                    child: Transform.scale(
                      scale: 2.0,
                      alignment: Alignment.topLeft,
                      child: const Text(
                        "Hg",
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
