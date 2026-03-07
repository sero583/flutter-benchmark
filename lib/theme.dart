/// Shared theme constants and color helpers for the benchmark UI.
library;

import "package:flutter/material.dart";

/// Dark background color used for scaffolds.
const kBgDark = Color(0xFF0F0F23);

/// Dark card/surface color.
const kCardDark = Color(0xFF1A1A2E);

/// Accent cyan used for primary highlights.
const kCyan = Colors.cyanAccent;

/// Accent purple used for secondary highlights.
const kPurple = Colors.purpleAccent;

/// Returns a traffic-light color for an FPS value: green >= 55, yellow >= 30,
/// red below.
Color fpsColor(double fps) {
  if (fps >= 55) return Colors.greenAccent;
  if (fps >= 30) return Colors.yellowAccent;
  return Colors.redAccent;
}

/// Returns a traffic-light color for a frame time value: green if within one
/// vsync interval, yellow up to 2x, red beyond.
Color ftColor(double ms, {double targetMs = 16.667}) {
  if (ms <= targetMs) return Colors.greenAccent;
  if (ms <= targetMs * 2) return Colors.yellowAccent;
  return Colors.redAccent;
}

/// Returns a traffic-light color for a smoothness score: green >= 80,
/// yellow >= 50, red below.
Color scoreColor(double s) {
  if (s >= 80) return Colors.greenAccent;
  if (s >= 50) return Colors.yellowAccent;
  return Colors.redAccent;
}
