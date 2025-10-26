import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/utils/batch_helpers.dart';

void main() {
  group('BatchHelpers Tests', () {
    group('batchList', () {
      test('should split list into batches of specified size', () {
        final items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        final batches = BatchHelpers.batchList(items, 3);

        expect(batches.length, 4);
        expect(batches[0], [1, 2, 3]);
        expect(batches[1], [4, 5, 6]);
        expect(batches[2], [7, 8, 9]);
        expect(batches[3], [10]);
      });

      test('should handle empty list', () {
        final items = <int>[];
        final batches = BatchHelpers.batchList(items, 5);

        expect(batches, isEmpty);
      });

      test('should handle single item', () {
        final items = [1];
        final batches = BatchHelpers.batchList(items, 5);

        expect(batches.length, 1);
        expect(batches[0], [1]);
      });

      test('should handle batch size larger than list', () {
        final items = [1, 2, 3];
        final batches = BatchHelpers.batchList(items, 10);

        expect(batches.length, 1);
        expect(batches[0], [1, 2, 3]);
      });

      test('should handle different types', () {
        final items = ['a', 'b', 'c', 'd', 'e'];
        final batches = BatchHelpers.batchList(items, 2);

        expect(batches.length, 3);
        expect(batches[0], ['a', 'b']);
        expect(batches[1], ['c', 'd']);
        expect(batches[2], ['e']);
      });
    });

    group('processBatched', () {
      test('should process items in batches', () async {
        final items = [1, 2, 3, 4, 5];
        final results = await BatchHelpers.processBatched(
          items: items,
          processor: (item) async => item * 2,
          batchSize: 2,
        );

        expect(results, [2, 4, 6, 8, 10]);
      });

      test('should respect batch size', () async {
        int callCount = 0;

        final items = [1, 2, 3, 4, 5, 6, 7, 8];
        final results = await BatchHelpers.processBatched(
          items: items,
          processor: (item) async {
            callCount++;
            return item;
          },
          batchSize: 3,
        );

        expect(callCount, items.length);
        expect(results.length, items.length);
      });

      test('should handle delay between batches', () async {
        final items = [1, 2, 3, 4];
        final start = DateTime.now();

        await BatchHelpers.processBatched(
          items: items,
          processor: (item) async => item,
          batchSize: 2,
          delayBetweenBatches: const Duration(milliseconds: 100),
        );

        final elapsed = DateTime.now().difference(start);
        expect(elapsed.inMilliseconds, greaterThanOrEqualTo(100));
      });

      test('should handle empty list', () async {
        final items = <int>[];
        final results = await BatchHelpers.processBatched(
          items: items,
          processor: (item) async => item * 2,
          batchSize: 5,
        );

        expect(results, isEmpty);
      });

      test('should handle errors in processing', () async {
        final items = [1, 2, 3, 4, 5];

        expect(
          () => BatchHelpers.processBatched(
            items: items,
            processor: (item) async {
              if (item == 3) throw Exception('Error on item 3');
              return item * 2;
            },
            batchSize: 2,
          ),
          throwsException,
        );
      });
    });

    group('processUntil', () {
      test('should process until condition is met', () async {
        final items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        final results = await BatchHelpers.processUntil(
          items: items,
          processor: (item) async => item * 2,
          shouldStop: (results) => results.length >= 3,
        );

        expect(results.length, 3);
        expect(results, [2, 4, 6]);
      });

      test('should process all items if condition never met', () async {
        final items = [1, 2, 3, 4, 5];
        final results = await BatchHelpers.processUntil(
          items: items,
          processor: (item) async => item,
          shouldStop: (results) => false, // Never stop
        );

        expect(results.length, items.length);
        expect(results, items);
      });

      test('should stop immediately if condition met on first item', () async {
        final items = [1, 2, 3, 4, 5];
        final results = await BatchHelpers.processUntil(
          items: items,
          processor: (item) async => item,
          shouldStop: (results) => results.isNotEmpty,
        );

        expect(results.length, 1);
        expect(results[0], 1);
      });

      test('should handle empty list', () async {
        final items = <int>[];
        final results = await BatchHelpers.processUntil(
          items: items,
          processor: (item) async => item,
          shouldStop: (results) => true,
        );

        expect(results, isEmpty);
      });

      test('should handle processing errors', () async {
        final items = [1, 2, 3, 4, 5];

        expect(
          () => BatchHelpers.processUntil(
            items: items,
            processor: (item) async {
              if (item == 3) throw Exception('Error');
              return item;
            },
            shouldStop: (results) => results.length >= 5,
          ),
          throwsException,
        );
      });
    });

    group('Edge Cases', () {
      test('should handle large batch sizes', () {
        final items = List.generate(1000, (i) => i);
        final batches = BatchHelpers.batchList(items, 100);

        expect(batches.length, 10);
        expect(batches[0].length, 100);
        expect(batches[9].length, 100);
      });

      test('should handle batch size of 1', () {
        final items = [1, 2, 3, 4, 5];
        final batches = BatchHelpers.batchList(items, 1);

        expect(batches.length, 5);
        expect(batches[0], [1]);
        expect(batches[4], [5]);
      });

      test('should handle very small lists', () {
        final items = [1];
        final batches = BatchHelpers.batchList(items, 3);

        expect(batches.length, 1);
        expect(batches[0], [1]);
      });
    });
  });
}
