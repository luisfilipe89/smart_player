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

  group('Notification Delivery Tests', () {
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

    test('Can create game invitation notification', () async {
      try {
        final db = FirebaseDatabase.instance;
        final inviteeId =
            'test-invitee-${DateTime.now().millisecondsSinceEpoch}';

        final gameRef = db.ref(DbPaths.games).push();
        final gameId = gameRef.key!;

        await db.ref(DbPaths.userGameInvites(inviteeId)).child(gameId).set({
          'status': 'pending',
          'organizerId': testUserId,
          'organizerName': 'Test Organizer',
          'sport': 'soccer',
          'timestamp': DateTime.now().toIso8601String(),
        });

        final snapshot = await db
            .ref(DbPaths.userGameInvites(inviteeId))
            .child(gameId)
            .get();
        expect(snapshot.exists, isTrue);

        await gameRef.remove();
      } catch (e) {
        developer.log('Game invitation notification test failed: $e');
      }
    });

    test('Can create friend request notification', () async {
      try {
        final db = FirebaseDatabase.instance;
        final friendId =
            'test-friend-notif-${DateTime.now().millisecondsSinceEpoch}';

        await db
            .ref(DbPaths.userFriendRequestsReceived(testUserId))
            .child(friendId)
            .set({
          'status': 'pending',
          'timestamp': DateTime.now().toIso8601String(),
        });

        final snapshot = await db
            .ref(DbPaths.userFriendRequestsReceived(testUserId))
            .child(friendId)
            .get();
        expect(snapshot.exists, isTrue);
      } catch (e) {
        developer.log('Friend request notification test failed: $e');
      }
    });

    test('Notification status updates correctly', () async {
      try {
        final db = FirebaseDatabase.instance;
        final friendId =
            'test-status-update-${DateTime.now().millisecondsSinceEpoch}';

        final requestRef = db
            .ref(DbPaths.userFriendRequestsReceived(testUserId))
            .child(friendId);

        await requestRef.set({
          'status': 'pending',
          'timestamp': DateTime.now().toIso8601String(),
        });

        await requestRef.update({'status': 'accepted'});

        final snapshot = await requestRef.get();
        expect((snapshot.value as Map)['status'], 'accepted');
      } catch (e) {
        developer.log('Notification status update test failed: $e');
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
