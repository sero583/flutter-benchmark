/// Platform utilities for Flutter web (CanvasKit / Skwasm).
library;

import "dart:convert";
import "dart:js_interop";
import "dart:js_interop_unsafe";
import "dart:ui" as ui;

/// Accesses `PlatformDispatcher.renderingBackend` via dynamic dispatch so the
/// app compiles on stock Flutter SDKs that don't expose this custom getter.
/// Returns the backend name as a [String] (e.g. `'canvaskit'`, `'skwasm'`), or
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

/// Platform utilities for Flutter web targets.
///
/// Provides GPU renderer detection (via WebGL debug info), screen metrics,
/// browser identification, clipboard access, and base-64 file downloads.
class PlatformUtils {
  /// No-op on web — all data is available synchronously.
  static Future<void> init() async {
    // No async initialization needed on web.
  }

  /// GPU renderer string from `WEBGL_debug_renderer_info`.
  static String get gpuInfo => _getGPURenderer();

  /// Whether Impeller was detected.
  ///
  /// On web, Skwasm uses an Impeller-like pipeline.
  /// Returns `null` if the `renderingBackend` API is not available.
  static bool? get isImpellerEnabled {
    final name = _getRenderingBackendName();
    if (name == null) return null;
    return name == "skwasm";
  }

  /// Whether the renderer was successfully detected via the custom engine API.
  static bool get isRendererDetected => _getRenderingBackendName() != null;

  /// Returns a human-readable browser name and version.
  static String get systemDescription => _parseBrowser(_getUserAgent());

  /// Returns the screen resolution as `(width, height)` in CSS pixels.
  static (int, int) getScreenSize() {
    try {
      final s = globalContext["screen"] as JSObject;
      return (
        (s["width"] as JSNumber).toDartInt,
        (s["height"] as JSNumber).toDartInt,
      );
    } catch (_) {
      return (0, 0);
    }
  }

  /// The current `window.devicePixelRatio`.
  static double getDevicePixelRatio() {
    try {
      return (globalContext["devicePixelRatio"] as JSNumber).toDartDouble;
    } catch (_) {
      return 1.0;
    }
  }

  /// Whether `navigator.gpu` (WebGPU) is available.
  static bool get isWebGPUAvailable {
    try {
      return (globalContext["navigator"] as JSObject).has("gpu");
    } catch (_) {
      return false;
    }
  }

  /// Whether the Dart VM is running as a Wasm module.
  ///
  /// In JS, `MAX_SAFE_INTEGER + 1 == MAX_SAFE_INTEGER` due to IEEE 754
  /// double precision. In Wasm, integers are 64-bit and the addition
  /// produces the correct (larger) result.
  static bool get isWasm {
    return (9007199254740992 + 1) > 9007199254740992;
  }

  /// Always `true` — this compilation unit only runs on web.
  static const bool isWeb = true;

  /// Always `'Web'`.
  static String get platformName => "Web";

  /// Uses the authoritative `renderingBackend` API to detect the renderer.
  ///
  /// Falls back to `'Undetected'` when running on stock Flutter without
  /// the custom engine constants.
  static String detectRenderer() {
    final name = _getRenderingBackendName();
    if (name == null) return "Undetected";

    switch (name) {
      case "skwasm":
        return isWasm ? "Skwasm (WebGPU + Wasm)" : "Skwasm (WebGPU)";
      case "canvaskit":
        final glVer = _getWebGLVersion();
        return glVer > 0 ? "CanvasKit (WebGL $glVer)" : "CanvasKit";
      case "vulkan":
        return "Vulkan";
      case "metal":
        return "Metal";
      case "opengl":
        return "OpenGL";
      case "software":
        return "Software Rasterizer";
      default:
        return "Unknown ($name)";
    }
  }

  /// Returns a map of runtime diagnostic info about the rendering backend.
  static Map<String, String> getRenderingInfo() {
    final backendName =
        _getRenderingBackendName() ?? "Unavailable (stock Flutter)";
    return {
      "Rendering Backend": backendName,
      "Detected Renderer": detectRenderer(),
      "GPU": gpuInfo,
      "Platform": "Web",
      "Browser": systemDescription,
      "WebGPU Available": isWebGPUAvailable.toString(),
      "Wasm": isWasm.toString(),
      "Screen": "${getScreenSize().$1} × ${getScreenSize().$2}",
      "DPR": getDevicePixelRatio().toStringAsFixed(2),
    };
  }

  static int _getWebGLVersion() {
    try {
      final doc = globalContext["document"] as JSObject;
      final canvas =
          doc.callMethod("createElement".toJS, "canvas".toJS) as JSObject;
      if (canvas.callMethod("getContext".toJS, "webgl2".toJS) != null) return 2;
      if (canvas.callMethod("getContext".toJS, "webgl".toJS) != null) return 1;
    } catch (_) {}
    return 0;
  }

  /// Triggers a browser download of [content] as a file named [filename].
  static String downloadFile(String content, String filename) {
    try {
      final bytes = utf8.encode(content);
      final b64 = base64Encode(bytes);
      final uri = "data:application/json;base64,$b64".toJS;
      final doc = globalContext["document"] as JSObject;
      final body = doc["body"] as JSObject;
      final a = doc.callMethod("createElement".toJS, "a".toJS) as JSObject;
      a["href"] = uri;
      a["download"] = filename.toJS;
      body.callMethod("appendChild".toJS, a);
      a.callMethod("click".toJS);
      body.callMethod("removeChild".toJS, a);
      return "Download started";
    } catch (e) {
      return "Download failed: $e";
    }
  }

  /// Copies [text] to the clipboard via `navigator.clipboard.writeText`.
  static void copyToClipboard(String text) {
    try {
      final nav = globalContext["navigator"] as JSObject;
      final cb = nav["clipboard"] as JSObject;
      cb.callMethod("writeText".toJS, text.toJS);
    } catch (_) {}
  }

  /// Save JSON via file picker (web: browser download).
  static Future<String> saveJsonFile(
    String content,
    String suggestedName,
  ) async {
    downloadFile(content, suggestedName);
    return "Download started";
  }

  static String _getGPURenderer() {
    try {
      final doc = globalContext["document"] as JSObject;
      final canvas =
          doc.callMethod("createElement".toJS, "canvas".toJS) as JSObject;
      var gl = canvas.callMethod("getContext".toJS, "webgl2".toJS);
      gl ??= canvas.callMethod("getContext".toJS, "webgl".toJS);
      if (gl == null) return "WebGL unavailable";
      final glObj = gl as JSObject;
      final ext = glObj.callMethod(
        "getExtension".toJS,
        "WEBGL_debug_renderer_info".toJS,
      );
      if (ext == null) return "Renderer info N/A";
      // UNMASKED_RENDERER_WEBGL = 0x9246.
      final r = glObj.callMethod("getParameter".toJS, (0x9246).toJS);
      return r == null ? "Unknown" : (r as JSString).toDart;
    } catch (e) {
      return "Error: $e";
    }
  }

  static String _getUserAgent() {
    try {
      final nav = globalContext["navigator"] as JSObject;
      return (nav["userAgent"] as JSString).toDart;
    } catch (_) {
      return "Unknown";
    }
  }

  static String _parseBrowser(String ua) {
    if (ua.contains("Edg/")) return 'Edge ${_extract(ua, 'Edg/')}';
    if (ua.contains("Chrome/")) return 'Chrome ${_extract(ua, 'Chrome/')}';
    if (ua.contains("Firefox/")) return 'Firefox ${_extract(ua, 'Firefox/')}';
    if (ua.contains("Safari/") && !ua.contains("Chrome")) return "Safari";
    return ua.length > 60 ? "${ua.substring(0, 60)}…" : ua;
  }

  static String _extract(String ua, String token) {
    final i = ua.indexOf(token);
    if (i < 0) return "";
    final sub = ua.substring(i + token.length);
    final end = sub.indexOf(" ");
    return end < 0 ? sub : sub.substring(0, end);
  }
}
