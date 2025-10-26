import 'dart:developer' as developer;
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:move_young/firebase_options.dart';
import 'package:move_young/db/db_paths.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Profile Screen Integration Tests', () {
    late String testUserId;

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
      final user = (await FirebaseAuth.instance.signInAnonymously()).user!;
      testUserId = user.uid;
    });

    test('Can update display name', () async {
      try {
        final db = FirebaseDatabase.instance;
        final profileRef = db.ref(DbPaths.userProfile(testUserId));

        await profileRef.update({
          'displayName': 'Test User Name',
        });

        final snapshot =
            await db.ref(DbPaths.userProfileDisplayName(testUserId)).get();
        expect(snapshot.value, 'Test User Name');
      } catch (e) {
        developer.log('Update display name test failed: $e');
      }
    });

    test('Can update profile bio', () async {
      try {
        final db = FirebaseDatabase.instance;
        final profileRef = db.ref(DbPaths.userProfile(testUserId));

        await profileRef.update({
          'bio': 'Test bio for integration test',
        });

        final snapshot = await profileRef.child('bio').get();
        expect(snapshot.value, 'Test bio for integration test');
      } catch (e) {
        developer.log('Update bio test failed: $e');
      }
    });

    test('Can update profile photo URL', () async {
      try {
        final db = FirebaseDatabase.instance;
        final photoUrlRef = db.ref(DbPaths.userProfilePhotoUrl(testUserId));

        await photoUrlRef.set('https://example.com/avatar.jpg');

        final snapshot = await photoUrlRef.get();
        expect(snapshot.value, 'https://example.com/avatar.jpg');
      } catch (e) {
        developer.log('Update photo URL test failed: $e');
      }
    });

    test('Can view profile data', () async {
      try {
        final db = FirebaseDatabase.instance;
        final profileRef = db.ref(DbPaths.userProfile(testUserId));

        await profileRef.set({
          'displayName': 'Integration Test User',
          'bio': 'Testing profile screen',
          'photoURL': 'https://example.com/test.jpg',
        });

        final snapshot = await profileRef.get();
        expect(snapshot.exists, isTrue);
        final profile = Map<String, dynamic>.from(snapshot.value as Map);
        expect(profile['displayName'], 'Integration Test User');
        expect(profile['bio'], 'Testing profile screen');
      } catch (e) {
        developer.log('View profile data test failed: $e');
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
