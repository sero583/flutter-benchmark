/// Platform utilities for native (Android, iOS, Windows, Linux, macOS).
library;

import "dart:io";
import "dart:ui" as ui;

import "package:file_picker/file_picker.dart";
import "package:flutter/services.dart";

/// Accesses `PlatformDispatcher.renderingBackend` via dynamic dispatch so the
/// app compiles on stock Flutter SDKs that don't expose this custom getter.
/// Returns the backend name as a [String] (e.g. `'vulkan'`, `'metal'`), or
/// `null` if the getter doesn't exist.
String? _getRenderingBackendName() {
  try {
    // ignore: avoid_dynamic_calls
    final dynamic dispatcher = ui.PlatformDispatcher.instance;
    final dynamic backend = dispatcher.renderingBackend;
    return backend.toString().split(".").last;
  } catch (_) {
    return null;
  }
}

/// Platform utilities for native (non-web) Flutter targets.
///
/// Provides GPU detection, renderer identification, screen metrics,
/// file save/export, and clipboard access using `dart:io` APIs.
class PlatformUtils {
  static String _gpuInfo = "Detecting...";

  /// Initialises platform-specific resources (GPU name detection).
  ///
  /// Must be called before accessing [gpuInfo].
  static Future<void> init() async {
    _gpuInfo = await _detectGPU();
  }

  // System info.

  /// Human-readable GPU model name (e.g. `'NVIDIA RTX 4070'`).
  static String get gpuInfo => _gpuInfo;

  /// Whether Impeller is in use (Vulkan or Metal backend).
  ///
  /// Returns `null` if the `renderingBackend` API is not available
  /// (stock Flutter SDK without custom engine constants).
  static bool? get isImpellerEnabled {
    final name = _getRenderingBackendName();
    if (name == null) return null;
    return name == "vulkan" || name == "metal";
  }

  /// A short description of the OS name and version.
  static String get systemDescription {
    return "${Platform.operatingSystem} ${Platform.operatingSystemVersion}";
  }

  /// Returns the logical screen size as `(width, height)` in device-
  /// independent pixels.
  static (int, int) getScreenSize() {
    try {
      final view = ui.PlatformDispatcher.instance.views.firstOrNull;
      if (view == null) return (0, 0);
      final size = view.physicalSize / view.devicePixelRatio;
      return (size.width.toInt(), size.height.toInt());
    } catch (_) {
      return (0, 0);
    }
  }

  /// The current device pixel ratio (physical pixels per logical pixel).
  static double getDevicePixelRatio() {
    try {
      return ui
              .PlatformDispatcher
              .instance
              .views
              .firstOrNull
              ?.devicePixelRatio ??
          1.0;
    } catch (_) {
      return 1.0;
    }
  }

  // Capability detection.

  /// Always `false` on native platforms.
  static bool get isWebGPUAvailable => false;

  /// Always `false` on native platforms.
  static bool get isWasm => false;

  /// Always `false` — this compilation unit only runs on native.
  static const bool isWeb = false;

  /// Short human-readable platform label (e.g. `'Windows'`, `'Android'`).
  static String get platformName {
    if (Platform.isAndroid) return "Android";
    if (Platform.isIOS) return "iOS";
    if (Platform.isLinux) return "Linux";
    if (Platform.isWindows) return "Windows";
    if (Platform.isMacOS) return "macOS";
    return Platform.operatingSystem;
  }

  /// Maps a [ui.RenderingBackend] value to a human-readable renderer string.
  ///
  /// Uses the authoritative engine API instead of fragile environment variable
  /// heuristics.  Returns `'Undetected'` if the custom `renderingBackend`
  /// getter is not available in the current Flutter build.
  static String detectRenderer() {
    // 1. Explicit --dart-define override (escape hatch for testing).
    const envRenderer = String.fromEnvironment("RENDERER");
    if (envRenderer.isNotEmpty) return envRenderer;

    // 2. Use the authoritative rendering backend from the engine.
    final name = _getRenderingBackendName();
    if (name == null) return "Undetected";

    switch (name) {
      case "vulkan":
        return "Impeller (Vulkan)";
      case "metal":
        return "Impeller (Metal)";
      case "opengl":
        if (Platform.isWindows) return "Skia (ANGLE)";
        if (Platform.isAndroid) return "Skia (OpenGL ES)";
        return "Skia (OpenGL)";
      case "software":
        return "Software Rasterizer";
      case "canvaskit":
        return "CanvasKit (WebGL)";
      case "skwasm":
        return "Skwasm (WebGPU)";
      default:
        return "Unknown ($name)";
    }
  }

  /// Whether the custom `renderingBackend` API is available.
  static bool get isRendererDetected => detectRenderer() != "Undetected";

  /// Returns a map of runtime diagnostic info about the rendering backend.
  static Map<String, String> getRenderingInfo() {
    final info = <String, String>{};

    final backendName = _getRenderingBackendName();
    info["Rendering Backend"] = backendName ?? "Unavailable (stock Flutter)";
    info["Detected Renderer"] = detectRenderer();
    info["GPU"] = _gpuInfo;
    info["Platform"] = platformName;
    info["OS Version"] = Platform.operatingSystemVersion;
    info["Dart Version"] = Platform.version.split(" ").first;
    info["Impeller Active"] = (isImpellerEnabled ?? false).toString();

    // Screen / window info
    try {
      final view = ui.PlatformDispatcher.instance.views.firstOrNull;
      if (view != null) {
        final physSize = view.physicalSize;
        final dpr = view.devicePixelRatio;
        info["Window Size (physical px)"] =
            "${physSize.width.toInt()} × ${physSize.height.toInt()}";
        info["DPR"] = dpr.toStringAsFixed(2);
        final logical = physSize / dpr;
        info["Window Size (logical)"] =
            "${logical.width.toInt()} × ${logical.height.toInt()}";
      }

      // Full display resolution from PlatformDispatcher.displays.
      final displays = ui.PlatformDispatcher.instance.displays;
      if (displays.isNotEmpty) {
        final d = displays.first;
        info["Display Resolution"] =
            "${d.size.width.toInt()} × ${d.size.height.toInt()} px";
        info["Display Refresh Rate"] = "${d.refreshRate.toStringAsFixed(1)} Hz";
      }
    } catch (_) {}

    return info;
  }

  // File operations.

  /// Writes [content] to a file named [filename] in the user's Documents
  /// directory (or temp on mobile). Returns a status message.
  static String downloadFile(String content, String filename) {
    try {
      String dirPath;
      if (Platform.isAndroid || Platform.isIOS) {
        dirPath = Directory.systemTemp.path;
      } else {
        final home =
            Platform.environment["HOME"] ??
            Platform.environment["USERPROFILE"] ??
            ".";
        dirPath = "$home${Platform.pathSeparator}Documents";
      }
      final dir = Directory(dirPath);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File("$dirPath${Platform.pathSeparator}$filename");
      file.writeAsStringSync(content);
      return "Saved to: ${file.path}";
    } catch (e) {
      return "Save failed: $e";
    }
  }

  /// Copies [text] to the system clipboard.
  static void copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
  }

  /// Save JSON via native file dialog.
  static Future<String> saveJsonFile(
    String content,
    String suggestedName,
  ) async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: "Save Benchmark Results",
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: ["json"],
      );
      if (result == null) return "Cancelled";
      final file = File(result);
      await file.writeAsString(content);
      return "Saved successfully";
    } catch (e) {
      return downloadFile(content, suggestedName);
    }
  }

  // GPU detection (async, run once at init).

  static Future<String> _detectGPU() async {
    try {
      if (Platform.isWindows) {
        // Use PowerShell Get-CimInstance instead of deprecated wmic.
        final r =
            await Process.run("powershell", [
              "-NoProfile",
              "-Command",
              "(Get-CimInstance Win32_VideoController).Name",
            ]).timeout(
              const Duration(seconds: 5),
              onTimeout: () => ProcessResult(0, 1, "", "timeout"),
            );
        final names = r.stdout
            .toString()
            .split("\n")
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (names.isNotEmpty) {
          const virtualKeywords = [
            "parsec",
            "virtual",
            "remote",
            "rdp",
            "microsoft basic",
            "basic display",
          ];
          for (final name in names) {
            final lower = name.toLowerCase();
            if (!virtualKeywords.any((kw) => lower.contains(kw))) {
              return name;
            }
          }
          return names.first;
        }
      } else if (Platform.isLinux) {
        // Try lspci first (works on native Linux).
        final r =
            await Process.run("bash", [
              "-c",
              r'lspci | grep -iE "vga|3d|display"',
            ]).timeout(
              const Duration(seconds: 3),
              onTimeout: () => ProcessResult(0, 1, "", "timeout"),
            );
        final output = r.stdout.toString().trim();
        if (output.isNotEmpty) {
          final match = RegExp(
            r":\s+(.+)$",
            multiLine: true,
          ).firstMatch(output);
          return match?.group(1)?.trim() ?? output.split("\n").first.trim();
        }
        // Fallback: vulkaninfo (works on WSL and systems without lspci).
        final vi =
            await Process.run("bash", [
              "-c",
              r"vulkaninfo --summary 2>/dev/null | grep deviceName",
            ]).timeout(
              const Duration(seconds: 5),
              onTimeout: () => ProcessResult(0, 1, "", "timeout"),
            );
        final viOut = vi.stdout.toString().trim();
        if (viOut.isNotEmpty) {
          final match = RegExp(r"deviceName\s*=\s*(.+)").firstMatch(viOut);
          if (match != null) return match.group(1)!.trim();
        }
      } else if (Platform.isMacOS) {
        final r = await Process.run("system_profiler", ["SPDisplaysDataType"]);
        final match = RegExp(
          r"Chipset Model:\s*(.+)",
        ).firstMatch(r.stdout.toString());
        return match?.group(1)?.trim() ?? "Apple Silicon GPU";
      } else if (Platform.isAndroid) {
        // Try getprop for GPU model (available without root).
        final r = await Process.run("getprop", ["ro.hardware.chipname"])
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => ProcessResult(0, 1, "", "timeout"),
            );
        final chipname = r.stdout.toString().trim();
        if (chipname.isNotEmpty) return chipname;
        // Fallback: SoC-level identifier.
        final soc = await Process.run("getprop", ["ro.board.platform"]).timeout(
          const Duration(seconds: 3),
          onTimeout: () => ProcessResult(0, 1, "", "timeout"),
        );
        final socName = soc.stdout.toString().trim();
        if (socName.isNotEmpty) return "Android GPU ($socName)";
        return "Android GPU";
      } else if (Platform.isIOS) {
        // On iOS, uname gives the device model (e.g. iPhone15,2).
        final r = await Process.run("uname", ["-m"]).timeout(
          const Duration(seconds: 3),
          onTimeout: () => ProcessResult(0, 1, "", "timeout"),
        );
        final machine = r.stdout.toString().trim();
        if (machine.isNotEmpty) return "Apple GPU ($machine)";
        return "Apple GPU";
      }
    } catch (_) {}
    return "Unknown GPU (${Platform.operatingSystem})";
  }
}
