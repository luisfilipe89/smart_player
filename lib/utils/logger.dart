import 'package:flutter/foundation.dart';

/// NumberedLogger overrides Flutter's global `debugPrint` to prefix
/// each printed line with an incrementing counter and optional timestamp.
class NumberedLogger {
  static int _counter = 0;
  static bool _installed = false;

  /// Installs the numbered logger by wrapping the global `debugPrint`.
  /// Call this once early in app startup.
  static void install({bool includeTimestamp = true}) {
    if (_installed) return;

    final DebugPrintCallback original = debugPrint;

    debugPrint = (String? message, {int? wrapWidth}) {
      _counter++;
      final String prefix;
      if (includeTimestamp) {
        final DateTime now = DateTime.now();
        final String hh = now.hour.toString().padLeft(2, '0');
        final String mm = now.minute.toString().padLeft(2, '0');
        final String ts = '$hh:$mm';
        prefix = '$_counter. [$ts] ';
      } else {
        prefix = '$_counter. ';
      }

      if (message == null) {
        original(null, wrapWidth: wrapWidth);
        return;
      }

      // Ensure multi-line messages are prefixed on every line
      final List<String> lines = message.split('\n');
      for (final String line in lines) {
        original('$prefix$line', wrapWidth: wrapWidth);
      }
    };

    _installed = true;
  }

  /// Resets the line counter back to zero.
  static void reset() {
    _counter = 0;
  }

  /// Convenience helpers for leveled logging
  static void i(String message) {
    debugPrint('ℹ️ $message');
  }

  static void w(String message) {
    debugPrint('⚠️ $message');
  }

  static void e(String message) {
    debugPrint('❌ $message');
  }

  static void d(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}
