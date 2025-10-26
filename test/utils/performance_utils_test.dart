import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/utils/performance_utils.dart';

void main() {
  group('PerformanceUtils Tests', () {
    setUp(() {
      PerformanceUtils.clearCaches();
    });

    tearDown(() {
      PerformanceUtils.clearCaches();
    });

    group('Debounce', () {
      test('should debounce function calls', () {
        int callCount = 0;
        void function() {
          callCount++;
        }

        PerformanceUtils.debounce(
            'test', Duration(milliseconds: 100), function);

        // Should not be called immediately
        expect(callCount, 0);
      });

      test('should execute after delay', () async {
        int callCount = 0;
        void function() {
          callCount++;
        }

        PerformanceUtils.debounce('test', Duration(milliseconds: 50), function);

        await Future.delayed(Duration(milliseconds: 100));

        expect(callCount, 1);
      });

      test('should cancel previous debounce', () async {
        int callCount = 0;
        void function() {
          callCount++;
        }

        PerformanceUtils.debounce(
            'test', Duration(milliseconds: 100), function);
        PerformanceUtils.debounce(
            'test', Duration(milliseconds: 100), function);

        await Future.delayed(Duration(milliseconds: 150));

        expect(callCount, 1);
      });

      test('should handle multiple debounce keys', () {
        int callCount1 = 0;
        int callCount2 = 0;

        PerformanceUtils.debounce(
            'test1', Duration(milliseconds: 10), () => callCount1++);
        PerformanceUtils.debounce(
            'test2', Duration(milliseconds: 10), () => callCount2++);

        expect(callCount1, 0);
        expect(callCount2, 0);
      });
    });

    group('Throttle', () {
      test('should throttle function calls', () {
        int callCount = 0;
        void function() {
          callCount++;
        }

        PerformanceUtils.throttle(
            'test', Duration(milliseconds: 100), function);
        PerformanceUtils.throttle(
            'test', Duration(milliseconds: 100), function);

        // Should only call once immediately
        expect(callCount, 1);
      });

      test('should allow call after interval', () async {
        int callCount = 0;
        void function() {
          callCount++;
        }

        PerformanceUtils.throttle('test', Duration(milliseconds: 50), function);
        await Future.delayed(Duration(milliseconds: 60));
        PerformanceUtils.throttle('test', Duration(milliseconds: 50), function);

        expect(callCount, 2);
      });
    });

    group('Memoize', () {
      test('should memoize computation', () {
        int computationCount = 0;

        final result1 = PerformanceUtils.memoize('test', () {
          computationCount++;
          return 42;
        });

        final result2 = PerformanceUtils.memoize('test', () {
          computationCount++;
          return 42;
        });

        expect(result1, 42);
        expect(result2, 42);
        expect(computationCount, 1); // Should only compute once
      });

      test('should clear cache', () {
        PerformanceUtils.memoize('test', () => 1);
        PerformanceUtils.clearCaches();

        final stats = PerformanceUtils.getCacheStats();
        expect(stats['memoCache'], 0);
      });
    });

    group('Cache Statistics', () {
      test('should return cache statistics', () {
        PerformanceUtils.debounce('test1', Duration(milliseconds: 10), () {});
        PerformanceUtils.throttle('test2', Duration(milliseconds: 10), () {});
        PerformanceUtils.memoize('test3', () => 1);

        final stats = PerformanceUtils.getCacheStats();

        expect(stats['debounceTimers'], 1);
        expect(stats['throttleTimers'], 1);
        expect(stats['memoCache'], 1);
      });

      test('should return zero stats after clear', () {
        PerformanceUtils.debounce('test', Duration(milliseconds: 10), () {});
        PerformanceUtils.clearCaches();

        final stats = PerformanceUtils.getCacheStats();

        expect(stats['debounceTimers'], 0);
        expect(stats['throttleTimers'], 0);
        expect(stats['memoCache'], 0);
      });
    });
  });

  group('PerformanceLogger Tests', () {
    setUp(() {
      PerformanceLogger.clearMeasurements();
    });

    test('should start and end timer', () {
      PerformanceLogger.startTimer('test');
      final duration = PerformanceLogger.endTimer('test');

      expect(duration, isA<Duration>());
      expect(duration.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('should log operation', () {
      PerformanceLogger.logOperation('test', Duration(milliseconds: 100));

      final average = PerformanceLogger.getAverageTimes();
      expect(average['test'], Duration(milliseconds: 100));
    });

    test('should calculate average times', () {
      PerformanceLogger.logOperation('test', Duration(milliseconds: 100));
      PerformanceLogger.logOperation('test', Duration(milliseconds: 200));

      final average = PerformanceLogger.getAverageTimes();
      expect(average['test'], Duration(milliseconds: 150));
    });

    test('should clear measurements', () {
      PerformanceLogger.logOperation('test', Duration(milliseconds: 100));
      PerformanceLogger.clearMeasurements();

      final average = PerformanceLogger.getAverageTimes();
      expect(average, isEmpty);
    });
  });
}
