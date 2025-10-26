import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Retry Helpers Tests', () {
    test('should retry on failure and eventually succeed', () async {
      int attempts = 0;
      final result = await _retry(
        () async {
          attempts++;
          if (attempts < 3) {
            throw Exception('Temporary failure');
          }
          return 'success';
        },
        maxAttempts: 3,
      );

      expect(result, 'success');
      expect(attempts, 3);
    });

    test('should fail after max attempts', () async {
      int attempts = 0;
      expect(
        () async => await _retry(
          () async {
            attempts++;
            throw Exception('Always fails');
          },
          maxAttempts: 3,
        ),
        throwsA(isA<Exception>()),
      );
      expect(attempts, 3);
    });

    test('should succeed on first attempt', () async {
      int attempts = 0;
      final result = await _retry(
        () async {
          attempts++;
          return 'success';
        },
        maxAttempts: 3,
      );

      expect(result, 'success');
      expect(attempts, 1);
    });

    test('should use custom shouldRetry function', () async {
      int attempts = 0;
      final result = await _retry(
        () async {
          attempts++;
          if (attempts < 2) {
            throw Exception('Retry this');
          }
          return 'success';
        },
        shouldRetry: (error) => error.toString().contains('Retry this'),
        maxAttempts: 3,
      );

      expect(result, 'success');
      expect(attempts, 2);
    });

    test('should not retry when shouldRetry returns false', () async {
      int attempts = 0;
      expect(
        () async => await _retry(
          () async {
            attempts++;
            throw Exception('Do not retry');
          },
          shouldRetry: (error) => false,
          maxAttempts: 3,
        ),
        throwsA(isA<Exception>()),
      );
      expect(attempts, 1);
    });
  });
}

// Mock retry helper function for testing
Future<T> _retry<T>(
  Future<T> Function() computation, {
  int maxAttempts = 3,
  bool Function(dynamic error)? shouldRetry,
}) async {
  int attempts = 0;
  while (attempts < maxAttempts) {
    try {
      return await computation();
    } catch (error) {
      attempts++;
      if (attempts >= maxAttempts ||
          (shouldRetry != null && !shouldRetry(error))) {
        rethrow;
      }
      // Wait before retrying
      await Future.delayed(Duration(milliseconds: 10 * attempts));
    }
  }
  throw Exception('Max attempts reached');
}
