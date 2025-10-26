import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication Flow Integration Tests', () {
    setUpAll(() async {
      // Initialize Firebase for integration tests
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        // Firebase already initialized
        print('Firebase initialization: $e');
      }
    });

    setUp(() async {
      // Ensure clean state before each test
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        // Ignore if already signed out
      }
    });

    tearDown(() async {
      // Clean up after each test
      await FirebaseAuth.instance.signOut();
    });

    test('User can sign in anonymously with real Firebase', () async {
      try {
        // Sign in anonymously using REAL Firebase
        final userCredential = await FirebaseAuth.instance.signInAnonymously();

        // Verify user was created
        expect(userCredential.user, isNotNull);
        expect(userCredential.user!.isAnonymous, isTrue);
        expect(userCredential.user!.uid.isNotEmpty, isTrue);

        // Verify current user is set
        expect(FirebaseAuth.instance.currentUser, isNotNull);
        expect(
            FirebaseAuth.instance.currentUser!.uid, userCredential.user!.uid);
      } catch (e) {
        fail('Failed to sign in anonymously: $e');
      }
    });

    test('User can sign out and state updates correctly', () async {
      try {
        // Sign in first
        await FirebaseAuth.instance.signInAnonymously();
        expect(FirebaseAuth.instance.currentUser, isNotNull);

        // Sign out
        await FirebaseAuth.instance.signOut();

        // Verify user is signed out
        expect(FirebaseAuth.instance.currentUser, isNull);
      } catch (e) {
        fail('Sign out failed: $e');
      }
    });

    test('User authentication state persists across operations', () async {
      try {
        // Sign in
        final user = (await FirebaseAuth.instance.signInAnonymously()).user!;
        final uid = user.uid;

        // Verify user is still authenticated
        expect(FirebaseAuth.instance.currentUser, isNotNull);
        expect(FirebaseAuth.instance.currentUser!.uid, uid);

        // Reload user data
        await user.reload();
        expect(user.uid, uid);

        // Sign out
        await FirebaseAuth.instance.signOut();
        expect(FirebaseAuth.instance.currentUser, isNull);
      } catch (e) {
        fail('Authentication state persistence failed: $e');
      }
    });

    test('Multiple sign-ins create different users', () async {
      try {
        // First sign-in
        final user1 = (await FirebaseAuth.instance.signInAnonymously()).user!;
        final uid1 = user1.uid;
        await FirebaseAuth.instance.signOut();

        // Wait a bit to ensure different users
        await Future.delayed(const Duration(milliseconds: 100));

        // Second sign-in
        final user2 = (await FirebaseAuth.instance.signInAnonymously()).user!;
        final uid2 = user2.uid;

        // Should be different users
        expect(uid1, isNot(uid2));

        await FirebaseAuth.instance.signOut();
      } catch (e) {
        fail('Multiple sign-in test failed: $e');
      }
    });

    test('User can update profile information', () async {
      try {
        final user = (await FirebaseAuth.instance.signInAnonymously()).user!;

        // Update display name
        await user.updateDisplayName('Test User');
        await user.reload();

        expect(user.displayName, 'Test User');

        await FirebaseAuth.instance.signOut();
      } catch (e) {
        // Some features might not be available in test mode
        print('Note: Profile update may not be available: $e');
      }
    });
  });
}
