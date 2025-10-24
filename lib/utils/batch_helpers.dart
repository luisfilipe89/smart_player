/// Performance utilities for batch processing operations
class BatchHelpers {
  /// Split list into batches for processing
  static List<List<T>> batchList<T>(List<T> items, int batchSize) {
    final batches = <List<T>>[];
    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize).clamp(0, items.length);
      batches.add(items.sublist(i, end));
    }
    return batches;
  }

  /// Process items in batches with delay between batches
  static Future<List<R>> processBatched<T, R>({
    required List<T> items,
    required Future<R> Function(T) processor,
    int batchSize = 10,
    Duration? delayBetweenBatches,
  }) async {
    final results = <R>[];
    final batches = batchList(items, batchSize);

    for (final batch in batches) {
      final batchResults = await Future.wait(
        batch.map((item) => processor(item)),
      );
      results.addAll(batchResults);

      if (delayBetweenBatches != null && batch != batches.last) {
        await Future.delayed(delayBetweenBatches);
      }
    }

    return results;
  }

  /// Process items with early exit on condition
  static Future<List<R>> processUntil<T, R>({
    required List<T> items,
    required Future<R> Function(T) processor,
    required bool Function(List<R>) shouldStop,
  }) async {
    final results = <R>[];

    for (final item in items) {
      final result = await processor(item);
      results.add(result);

      if (shouldStop(results)) break;
    }

    return results;
  }
}

