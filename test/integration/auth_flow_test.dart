import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/firebase_test_helpers.dart';

void main() {
  bool hasEmulators = false;

  group('Auth Flow Integration Tests', () {
    setUpAll(() async {
      // Initialize Flutter binding before Firebase
      TestWidgetsFlutterBinding.ensureInitialized();
      try {
        await FirebaseTestHelpers.initializeFirebaseEmulators();
        hasEmulators = true;
      } catch (e) {
        // Skip tests if emulators not running
        print(
            '⚠️ Firebase emulators not available, skipping integration tests');
        hasEmulators = false;
      }
    });

    tearDownAll(() async {
      if (hasEmulators) {
        // Clean up test data
        await FirebaseTestHelpers.cleanup();
      }
    });

    test('should handle complete authentication flow', () async {
      if (!hasEmulators) {
        return; // Skip if emulators not available
      }
      // 1) Anonymous sign-in
      final cred = await FirebaseAuth.instance.signInAnonymously();
      expect(cred.user, isNotNull);
      final uid = cred.user!.uid;

      // 2) User state persistence
      expect(FirebaseAuth.instance.currentUser?.uid, uid);

      // 3) Sign-out
      await FirebaseAuth.instance.signOut();
      expect(FirebaseAuth.instance.currentUser, isNull);
    });

    test('should handle authentication state changes', () async {
      if (!hasEmulators) return;
      final states = <User?>[];
      final sub = FirebaseAuth.instance.userChanges().listen(states.add);

      // Trigger a state change
      await FirebaseAuth.instance.signInAnonymously();
      await FirebaseAuth.instance.signOut();

      await Future.delayed(const Duration(milliseconds: 200));
      await sub.cancel();

      expect(states.isNotEmpty, isTrue);
    });

    test('should handle user profile updates', () async {
      if (!hasEmulators) return;
      final user = (await FirebaseAuth.instance.signInAnonymously()).user!;
      await user.updateDisplayName('Tester');
      await user.reload();
      expect(FirebaseAuth.instance.currentUser?.displayName, 'Tester');
      await FirebaseAuth.instance.signOut();
    });

    test('should connect to Firebase emulators', () async {
      if (!hasEmulators) return;
      final app = FirebaseTestHelpers.app;
      expect(app, isNotNull);
      expect(app.name, isNotEmpty);
    });
  });
}
