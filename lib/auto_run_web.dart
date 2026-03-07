/// Auto-run detection and app — web stub.
///
/// On web, auto-run mode is not supported; the flag is always `false`.
library;

import "package:flutter/material.dart";

/// Always `false` on web.
bool get isAutoRunRequested => false;

/// Returns an empty placeholder (never actually shown).
Widget buildAutoRunApp() => const SizedBox.shrink();
