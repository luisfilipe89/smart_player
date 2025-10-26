import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

void main() {
  group('Timeout Helpers Tests', () {
    test('should complete within timeout', () async {
      final result = await _withTimeout(
        () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'success';
        },
        const Duration(seconds: 1),
      );

      expect(result, 'success');
    });

    test('should throw timeout exception when exceeded', () async {
      expect(
        () async => await _withTimeout(
          () async {
            await Future.delayed(const Duration(seconds: 2));
            return 'success';
          },
          const Duration(milliseconds: 100),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('should use quick timeout', () async {
      final result = await _withQuickTimeout(
        () async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'quick success';
        },
      );

      expect(result, 'quick success');
    });

    test('should use long timeout', () async {
      final result = await _withLongTimeout(
        () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'long success';
        },
      );

      expect(result, 'long success');
    });

    test('should handle errors in timeout', () async {
      expect(
        () async => await _withTimeout(
          () async {
            throw Exception('Test error');
          },
          const Duration(seconds: 1),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

// Mock timeout helper functions for testing
Future<T> _withTimeout<T>(
  Future<T> Function() computation,
  Duration timeout,
) async {
  return await computation().timeout(timeout);
}

Future<T> _withQuickTimeout<T>(
  Future<T> Function() computation,
) async {
  return await _withTimeout(computation, const Duration(seconds: 1));
}

Future<T> _withLongTimeout<T>(
  Future<T> Function() computation,
) async {
  return await _withTimeout(computation, const Duration(seconds: 30));
}
