/// Auto-run conditional export.
///
/// Selects the native or web implementation based on the platform.
library;

export "auto_run_native.dart" if (dart.library.js_interop) "auto_run_web.dart";
