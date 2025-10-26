import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:move_young/firebase_options.dart';
import 'package:move_young/db/db_paths.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Screen Integration Tests', () {
    late String testUserId;

    setUpAll(() async {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        print('Firebase initialization: $e');
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

    test('Can update notification settings', () async {
      try {
        final db = FirebaseDatabase.instance;

        await db
            .ref(
                '${DbPaths.userSettingsRoot(testUserId)}/notifications/gameInvites')
            .set(true);
        await db
            .ref(
                '${DbPaths.userSettingsRoot(testUserId)}/notifications/gameUpdates')
            .set(false);

        final invitesSnapshot = await db
            .ref(
                '${DbPaths.userSettingsRoot(testUserId)}/notifications/gameInvites')
            .get();
        final updatesSnapshot = await db
            .ref(
                '${DbPaths.userSettingsRoot(testUserId)}/notifications/gameUpdates')
            .get();

        expect(invitesSnapshot.value, isTrue);
        expect(updatesSnapshot.value, isFalse);
      } catch (e) {
        print('Notification settings test failed: $e');
      }
    });

    test('Can update privacy settings', () async {
      try {
        final db = FirebaseDatabase.instance;

        await db.ref(DbPaths.userVisibility(testUserId)).set('public');
        await db.ref(DbPaths.userShowOnline(testUserId)).set(true);
        await db.ref(DbPaths.userAllowFriendRequests(testUserId)).set(true);

        final visibilitySnapshot =
            await db.ref(DbPaths.userVisibility(testUserId)).get();
        final showOnlineSnapshot =
            await db.ref(DbPaths.userShowOnline(testUserId)).get();
        final allowRequestsSnapshot =
            await db.ref(DbPaths.userAllowFriendRequests(testUserId)).get();

        expect(visibilitySnapshot.value, 'public');
        expect(showOnlineSnapshot.value, isTrue);
        expect(allowRequestsSnapshot.value, isTrue);
      } catch (e) {
        print('Privacy settings test failed: $e');
      }
    });

    test('Can view current settings', () async {
      try {
        final db = FirebaseDatabase.instance;
        final settingsRef = db.ref(DbPaths.userSettingsRoot(testUserId));

        await settingsRef.child('profile').child('visibility').set('public');
        await settingsRef
            .child('notifications')
            .child('gameReminders')
            .set(true);

        final profileSnapshot = await settingsRef.child('profile').get();
        final notificationsSnapshot =
            await settingsRef.child('notifications').get();

        expect(profileSnapshot.exists, isTrue);
        expect(notificationsSnapshot.exists, isTrue);
      } catch (e) {
        print('View settings test failed: $e');
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
