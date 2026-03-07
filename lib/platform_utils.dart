/// Cross-platform utilities — conditional import.
///
/// Exports [PlatformUtils]: the web version when `dart:js_interop` is
/// available, otherwise the native (`dart:io`) version.
library;

export "platform_utils_native.dart"
    if (dart.library.js_interop) "platform_utils_web.dart";
