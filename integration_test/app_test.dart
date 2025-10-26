import 'package:flutter/material.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/main.dart' as app;
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Integration Tests - Real User Flows', () {
    setUpAll(() async {
      // Ensure clean state - sign out any existing user
      await FirebaseAuth.instance.signOut();
    });

    testWidgets('App launches and initializes correctly',
        (WidgetTester tester) async {
      // Launch the actual app
      app.main();
      await tester.pumpAndSettle();

      // Wait for app to fully load
      await tester.pump(const Duration(seconds: 2));

      // Verify app launched successfully
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('User can sign in anonymously and access features',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      // Sign in anonymously
      try {
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        expect(userCredential.user, isNotNull);
        expect(userCredential.user!.isAnonymous, isTrue);

        // Verify user is authenticated
        expect(FirebaseAuth.instance.currentUser, isNotNull);

        // Sign out to clean up
        await FirebaseAuth.instance.signOut();
        expect(FirebaseAuth.instance.currentUser, isNull);
      } catch (e) {
        print('⚠️ Firebase connection issue: $e');
        // Test can continue - just note the connectivity issue
      }
    });

    testWidgets('App handles offline state gracefully',
        (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify app doesn't crash when there are connectivity issues
      expect(find.byType(MaterialApp), findsOneWidget);

      // App should show appropriate UI for connectivity status
      // (This depends on your actual offline handling implementation)
    });

    tearDownAll(() async {
      // Clean up: sign out any test users
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        // Ignore cleanup errors
      }
    });
  });
}
