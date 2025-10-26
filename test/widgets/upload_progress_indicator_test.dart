import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/widgets/common/upload_progress_indicator.dart';

void main() {
  group('UploadProgressIndicator Widget Tests', () {
    testWidgets('should show progress indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadProgressIndicator(progress: 0.5),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('should show error state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadProgressIndicator(
              progress: 0.5,
              isError: true,
              message: 'Upload failed',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Upload failed'), findsOneWidget);
    });

    testWidgets('should show success state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadProgressIndicator(
              progress: 1.0,
              isSuccess: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Wait for the auto-dismiss timer to complete
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'should show retry button when onRetry is provided and isError is true',
        (tester) async {
      bool retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadProgressIndicator(
              progress: 0.5,
              isError: true,
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final retryButton = find.byIcon(Icons.refresh);
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      expect(retryCalled, isTrue);
    });

    testWidgets('should show dismiss button when onDismiss is provided',
        (tester) async {
      bool dismissCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadProgressIndicator(
              progress: 0.5,
              onDismiss: () => dismissCalled = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      final dismissButton = find.text('Dismiss');
      expect(dismissButton, findsOneWidget);

      await tester.tap(dismissButton);
      expect(dismissCalled, isTrue);
    });

    testWidgets('should not show dismiss button on success', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadProgressIndicator(
              progress: 1.0,
              isSuccess: true,
              onDismiss: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Dismiss'), findsNothing);

      // Wait for any pending timers
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('should display custom message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadProgressIndicator(
              progress: 0.75,
              message: 'Uploading file...',
            ),
          ),
        ),
      );

      expect(find.text('Uploading file...'), findsOneWidget);
    });

    testWidgets('should calculate progress percentage correctly',
        (tester) async {
      final progressValues = [0.0, 0.25, 0.5, 0.75, 1.0];

      for (final progress in progressValues) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UploadProgressIndicator(progress: progress),
            ),
          ),
        );

        final percentage = (progress * 100).toInt();
        expect(find.text('$percentage%'), findsOneWidget);
      }
    });
  });

  group('UploadProgressOverlay Widget Tests', () {
    testWidgets('should render as overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadProgressOverlay(progress: 0.5),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Just verify the key elements exist
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);

      // Ensure no pending timers
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('should show error overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadProgressOverlay(
              progress: 0.5,
              isError: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(UploadProgressIndicator), findsOneWidget);
    });

    testWidgets('should show success overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UploadProgressOverlay(
              progress: 1.0,
              isSuccess: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(UploadProgressIndicator), findsOneWidget);

      // Wait for the auto-dismiss timer to complete
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });
}
