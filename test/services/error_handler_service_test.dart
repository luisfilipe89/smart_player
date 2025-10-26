import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/services/error_handler/error_handler_service_instance.dart';

void main() {
  group('ErrorHandlerServiceInstance Tests', () {
    late ErrorHandlerServiceInstance errorHandler;

    setUp(() {
      errorHandler = ErrorHandlerServiceInstance();
    });

    test('should log error without throwing', () {
      expect(() => errorHandler.logError('Test error', null), returnsNormally);
    });

    test('should log error with stack trace', () {
      final stackTrace = StackTrace.current;
      expect(
        () => errorHandler.logError('Test error', stackTrace),
        returnsNormally,
      );
    });

    test('should log exception', () {
      expect(
        () => errorHandler.logError(Exception('Test exception'), null),
        returnsNormally,
      );
    });

    test('should handle null error gracefully', () {
      expect(() => errorHandler.logError(null, null), returnsNormally);
    });

    test('should handle empty error message', () {
      expect(() => errorHandler.logError('', null), returnsNormally);
    });

    test('should log different error types', () {
      expect(
          () => errorHandler.logError('String error', null), returnsNormally);

      expect(
        () => errorHandler.logError(Exception('Exception error'), null),
        returnsNormally,
      );

      expect(() => errorHandler.logError(42, null), returnsNormally);
      expect(
          () => errorHandler.logError({'key': 'value'}, null), returnsNormally);
    });

    test('should provide error handler instance', () {
      expect(errorHandler, isNotNull);
      expect(errorHandler, isA<ErrorHandlerServiceInstance>());
    });

    test('should handle multiple consecutive errors', () {
      for (int i = 0; i < 10; i++) {
        expect(
          () => errorHandler.logError('Error $i', StackTrace.current),
          returnsNormally,
        );
      }
    });
  });
}

