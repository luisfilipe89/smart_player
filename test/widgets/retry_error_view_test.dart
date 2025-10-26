import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/widgets/common/retry_error_view.dart';

void main() {
  group('RetryErrorView Widget Tests', () {
    testWidgets('should render error view with default message',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetryErrorView(
              message: 'Something went wrong',
            ),
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('should show retry button when onRetry is provided',
        (tester) async {
      bool retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetryErrorView(
              message: 'Error occurred',
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );

      final retryButton = find.byIcon(Icons.refresh);
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      expect(retryCalled, isTrue);
    });

    testWidgets('should not show retry button when onRetry is null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetryErrorView(
              message: 'Error occurred',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.refresh), findsNothing);
    });

    testWidgets('should use custom icon when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetryErrorView(
              message: 'Error',
              icon: Icons.warning,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.warning), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('should use custom retry text when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetryErrorView(
              message: 'Error',
              onRetry: () {},
              retryText: 'Try Again',
            ),
          ),
        ),
      );

      expect(find.text('Try Again'), findsOneWidget);
    });

    testWidgets('should have proper layout structure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetryErrorView(
              message: 'Error',
              onRetry: () {},
            ),
          ),
        ),
      );

      // Verify key elements exist
      expect(find.byType(Icon), findsAtLeastNWidgets(1)); // Error icon
      expect(find.byIcon(Icons.refresh), findsOneWidget); // Retry button
    });

    testWidgets('should display message correctly', (tester) async {
      const errorMessages = [
        'Network error',
        'Permission denied',
        'Operation failed',
      ];

      for (final message in errorMessages) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RetryErrorView(message: message),
            ),
          ),
        );

        expect(find.text(message), findsOneWidget);
      }
    });

    testWidgets('should render with minimal props', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RetryErrorView(),
          ),
        ),
      );

      expect(find.byType(RetryErrorView), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
