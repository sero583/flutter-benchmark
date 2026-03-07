/// Cross-platform system resource monitor — conditional import.
///
/// Exports [SystemMonitor], [ResourceSnapshot], and [ResourceSummary]:
/// the web version when `dart:js_interop` is available, otherwise the
/// native (`dart:io`) version.  Data types are shared via
/// `resource_types.dart`.
library;

export "system_monitor_native.dart"
    if (dart.library.js_interop) "system_monitor_web.dart";
