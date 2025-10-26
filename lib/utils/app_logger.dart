import 'package:flutter/foundation.dart';

/// Comprehensive logging utility that provides different log levels
/// and automatically handles production vs debug environments.
class AppLogger {
  /// Log a debug message (only in debug mode)
  static void debug(String message, {String? category}) {
    if (kDebugMode) {
      final prefix = _buildPrefix('DEBUG', category);
      debugPrint('$prefix$message');
    }
  }

  /// Log an info message (only in debug mode)
  static void info(String message, {String? category}) {
    if (kDebugMode) {
      final prefix = _buildPrefix('INFO', category);
      debugPrint('$prefix$message');
    }
  }

  /// Log a warning message (always shown)
  static void warning(String message, {String? category}) {
    final prefix = _buildPrefix('WARNING', category);
    debugPrint('$prefix$message');
  }

  /// Log an error message (always shown)
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? category,
  }) {
    final prefix = _buildPrefix('ERROR', category);
    debugPrint('$prefix$message');

    if (error != null) {
      final errorPrefix = _buildPrefix('ERROR', category);
      debugPrint('$errorPrefix Error: $error');
    }

    if (stackTrace != null && kDebugMode) {
      debugPrint('$prefix$stackTrace');
    }
  }

  static String _buildPrefix(String level, String? category) {
    final timestamp = DateTime.now().toString().substring(11, 19); // HH:MM:SS
    final categoryStr = category != null ? '[$category] ' : '';
    return '[$timestamp] [$level] $categoryStr';
  }
}
