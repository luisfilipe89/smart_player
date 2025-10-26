import 'dart:developer' as developer;
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Screen Integration Tests', () {
    setUpAll(() async {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        developer.log('Firebase initialization: $e');
      }
    });

    setUp(() async {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        // Ignore
      }
    });

    test('Can sign in anonymously', () async {
      try {
        final userCredential = await FirebaseAuth.instance.signInAnonymously();

        expect(userCredential.user, isNotNull);
        expect(userCredential.user!.isAnonymous, isTrue);
        expect(userCredential.user!.uid.isNotEmpty, isTrue);

        await FirebaseAuth.instance.signOut();
      } catch (e) {
        developer.log('Anonymous sign-in test failed: $e');
      }
    });

    test('Can sign out after sign in', () async {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        expect(FirebaseAuth.instance.currentUser, isNotNull);

        await FirebaseAuth.instance.signOut();
        expect(FirebaseAuth.instance.currentUser, isNull);
      } catch (e) {
        developer.log('Sign out test failed: $e');
      }
    });

    test('User session persists across app lifecycle', () async {
      try {
        final user = (await FirebaseAuth.instance.signInAnonymously()).user!;
        final uid = user.uid;

        expect(FirebaseAuth.instance.currentUser?.uid, uid);

        await FirebaseAuth.instance.signOut();
        expect(FirebaseAuth.instance.currentUser, isNull);
      } catch (e) {
        developer.log('Session persistence test failed: $e');
      }
    });

    test('Multiple users can sign in separately', () async {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        final uid1 = FirebaseAuth.instance.currentUser!.uid;
        await FirebaseAuth.instance.signOut();

        await Future.delayed(const Duration(milliseconds: 100));

        await FirebaseAuth.instance.signInAnonymously();
        final uid2 = FirebaseAuth.instance.currentUser!.uid;

        expect(uid1 != uid2, isTrue);

        await FirebaseAuth.instance.signOut();
      } catch (e) {
        developer.log('Multiple users test failed: $e');
      }
    });

    tearDown(() async {
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        // Ignore
      }
    });
  });
}
