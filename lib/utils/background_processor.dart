import 'package:flutter/foundation.dart';

/// Utility for running heavy computations in background isolates
class BackgroundProcessor {
  /// Process heavy computation in background isolate
  static Future<R> processInBackground<T, R>({
    required R Function(T) computation,
    required T data,
    String? debugLabel,
  }) async {
    return await compute(computation, data, debugLabel: debugLabel);
  }

  /// Process list of items in background
  static Future<List<R>> processListInBackground<T, R>({
    required List<T> items,
    required R Function(T) processor,
  }) async {
    return await compute(_processListIsolate<T, R>, {
      'items': items,
      'processor': processor,
    });
  }

  static List<R> _processListIsolate<T, R>(Map<String, dynamic> params) {
    final items = params['items'] as List<T>;
    final processor = params['processor'] as R Function(T);
    final results = <R>[];

    for (final item in items) {
      results.add(processor(item));
    }

    return results;
  }

  /// Process with progress updates (for UI feedback)
  static Future<List<R>> processWithProgress<T, R>({
    required List<T> items,
    required R Function(T) processor,
    required void Function(int processed, int total) onProgress,
  }) async {
    final results = <R>[];
    final total = items.length;

    for (var i = 0; i < items.length; i++) {
      // Process in chunks to allow progress updates
      if (i % 10 == 0) {
        onProgress(i, total);
      }
      results.add(processor(items[i]));
    }

    onProgress(total, total);
    return results;
  }
}
