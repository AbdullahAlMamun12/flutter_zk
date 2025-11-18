import 'package:flutter/foundation.dart';

/// A custom logging function that only prints messages in debug mode.
///
/// This function wraps `debugPrint` and ensures that log messages are
/// only emitted when `kDebugMode` is true, preventing debug logs
/// from appearing in release builds.
void debugLog(
  String message, {
  String? name,
  Object? error,
  StackTrace? stackTrace,
}) {
  if (kDebugMode) {
    debugPrint(message);
    if (error != null) {
      debugPrint('Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('StackTrace: $stackTrace');
    }
  }
}
