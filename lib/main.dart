/// Flutter Renderer Benchmark Suite — application entry point.
///
/// Initialises the platform utilities, checks for auto-run mode, and
/// launches either the headless auto-run app or the interactive
/// [BenchmarkApp] with the benchmark home page.
library;

import "package:flutter/foundation.dart" show defaultTargetPlatform;
import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "auto_run.dart";
import "home_page.dart";
import "platform_utils.dart";
import "theme.dart";

// Re-export split modules so that dependents (auto_run_native, tests) that
// historically imported main.dart continue to compile.
export "benchmark_defs.dart";
export "fps_tracker.dart";
export "models.dart";
export "runner_page.dart";

/// Application entry point.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force landscape on mobile platforms for optimal benchmark display.
  final platform = defaultTargetPlatform;
  if (platform == TargetPlatform.android || platform == TargetPlatform.iOS) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  await PlatformUtils.init();

  if (isAutoRunRequested) {
    runApp(buildAutoRunApp());
  } else {
    runApp(const BenchmarkApp());
  }
}

/// Root [MaterialApp] for the interactive benchmark UI.
class BenchmarkApp extends StatelessWidget {
  /// Creates the benchmark application.
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Flutter Renderer Benchmark Suite",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.dark(
          primary: kCyan,
          secondary: kPurple,
          surface: kCardDark,
        ),
        scaffoldBackgroundColor: kBgDark,
        cardColor: kCardDark,
      ),
      home: const BenchmarkHome(),
    );
  }
}
