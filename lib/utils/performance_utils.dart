import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Performance utilities for optimizing app performance
class PerformanceUtils {
  static final Map<String, Timer> _debounceTimers = {};
  static final Map<String, DateTime> _throttleTimers = {};
  static final Map<String, dynamic> _memoCache = {};

  /// Debounce function calls to prevent excessive execution
  static void debounce(
    String key,
    Duration delay,
    VoidCallback callback, {
    bool cancelPrevious = true,
  }) {
    if (cancelPrevious) {
      _debounceTimers[key]?.cancel();
    }

    _debounceTimers[key] = Timer(delay, () {
      callback();
      _debounceTimers.remove(key);
    });
  }

  /// Throttle function calls to limit execution frequency
  static void throttle(
    String key,
    Duration interval,
    VoidCallback callback,
  ) {
    final now = DateTime.now();
    final lastCall = _throttleTimers[key];

    if (lastCall == null || now.difference(lastCall) >= interval) {
      _throttleTimers[key] = now;
      callback();
    }
  }

  /// Memoize expensive computations
  static T memoize<T>(
    String key,
    T Function() computation, {
    Duration? ttl,
  }) {
    final cacheKey = ttl != null
        ? '${key}_${DateTime.now().millisecondsSinceEpoch ~/ ttl.inMilliseconds}'
        : key;

    if (_memoCache.containsKey(cacheKey)) {
      return _memoCache[cacheKey] as T;
    }

    final result = computation();
    _memoCache[cacheKey] = result;

    // Clean up old entries if TTL is specified
    if (ttl != null) {
      Timer(ttl, () {
        _memoCache.removeWhere((k, v) => k.startsWith(key) && k != cacheKey);
      });
    }

    return result;
  }

  /// Run expensive computation in isolate
  static Future<R> computeInIsolate<T, R>(
    ComputeCallback<T, R> callback,
    T message, {
    String? debugLabel,
  }) async {
    return await compute(callback, message, debugLabel: debugLabel);
  }

  /// Clear all caches
  static void clearCaches() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _throttleTimers.clear();
    _memoCache.clear();
  }

  /// Get cache statistics
  static Map<String, int> getCacheStats() {
    return {
      'debounceTimers': _debounceTimers.length,
      'throttleTimers': _throttleTimers.length,
      'memoCache': _memoCache.length,
    };
  }
}

/// Debounced text field controller
class DebouncedTextController extends TextEditingController {
  final Duration delay;
  final ValueChanged<String>? onChanged;
  Timer? _debounceTimer;

  DebouncedTextController({
    super.text,
    this.delay = const Duration(milliseconds: 500),
    this.onChanged,
  }) {
    addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      onChanged?.call(text);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Throttled scroll controller
class ThrottledScrollController extends ScrollController {
  final Duration throttleDelay;
  final ValueChanged<double>? onScrollChanged;
  DateTime? _lastScrollTime;

  ThrottledScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    this.throttleDelay = const Duration(milliseconds: 16), // 60fps
    this.onScrollChanged,
  }) {
    addListener(_onScroll);
  }

  void _onScroll() {
    final now = DateTime.now();
    if (_lastScrollTime == null ||
        now.difference(_lastScrollTime!) >= throttleDelay) {
      _lastScrollTime = now;
      if (hasClients) {
        onScrollChanged?.call(position.pixels);
      }
    }
  }
}

/// Performance logger for debugging
class PerformanceLogger {
  static final Map<String, DateTime> _startTimes = {};
  static final Map<String, List<Duration>> _measurements = {};

  static void startTimer(String operation) {
    _startTimes[operation] = DateTime.now();
  }

  static Duration endTimer(String operation) {
    final startTime = _startTimes.remove(operation);
    if (startTime == null) return Duration.zero;

    final duration = DateTime.now().difference(startTime);
    _measurements.putIfAbsent(operation, () => []).add(duration);
    return duration;
  }

  static void logOperation(String operation, Duration duration) {
    _measurements.putIfAbsent(operation, () => []).add(duration);
  }

  static Map<String, Duration> getAverageTimes() {
    final averages = <String, Duration>{};
    for (final entry in _measurements.entries) {
      final durations = entry.value;
      if (durations.isNotEmpty) {
        final totalMs =
            durations.fold<int>(0, (sum, d) => sum + d.inMilliseconds);
        averages[entry.key] =
            Duration(milliseconds: totalMs ~/ durations.length);
      }
    }
    return averages;
  }

  static void clearMeasurements() {
    _startTimes.clear();
    _measurements.clear();
  }
}
