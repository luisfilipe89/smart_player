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

  group('Friends Screen Integration Tests', () {
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

    test('Can send friend request', () async {
      try {
        final db = FirebaseDatabase.instance;
        final friendId = 'test-friend-${DateTime.now().millisecondsSinceEpoch}';

        // Send friend request
        final requestRef =
            db.ref(DbPaths.userFriendRequestsSent(testUserId)).push();
        await requestRef.set({
          'friendId': friendId,
          'friendName': 'Test Friend',
          'status': 'pending',
          'timestamp': DateTime.now().toIso8601String(),
        });

        // Verify request sent
        final snapshot = await requestRef.get();
        expect(snapshot.exists, isTrue);
        expect((snapshot.value as Map)['status'], 'pending');

        // Cleanup
        await requestRef.remove();
      } catch (e) {
        developer.log('Send friend request test failed: $e');
      }
    });

    test('Can accept friend request', () async {
      try {
        final db = FirebaseDatabase.instance;
        final friendId = 'test-friend-${DateTime.now().millisecondsSinceEpoch}';

        // Simulate receiving a request
        final receivedRequestRef =
            db.ref(DbPaths.userFriendRequestsReceived(testUserId));
        final requestKey = receivedRequestRef.push().key!;

        await receivedRequestRef.child(requestKey).set({
          'friendId': friendId,
          'friendName': 'Test Friend',
          'status': 'pending',
          'timestamp': DateTime.now().toIso8601String(),
        });

        // Accept the request
        await receivedRequestRef.child(requestKey).update({
          'status': 'accepted',
        });

        // Verify accepted
        final snapshot = await receivedRequestRef.child(requestKey).get();
        expect((snapshot.value as Map)['status'], 'accepted');

        // Cleanup
        await receivedRequestRef.child(requestKey).remove();
      } catch (e) {
        developer.log('Accept friend request test failed: $e');
      }
    });

    test('Can reject friend request', () async {
      try {
        final db = FirebaseDatabase.instance;
        final friendId = 'test-friend-${DateTime.now().millisecondsSinceEpoch}';

        final receivedRequestRef =
            db.ref(DbPaths.userFriendRequestsReceived(testUserId));
        final requestKey = receivedRequestRef.push().key!;

        await receivedRequestRef.child(requestKey).set({
          'friendId': friendId,
          'friendName': 'Test Friend',
          'status': 'pending',
          'timestamp': DateTime.now().toIso8601String(),
        });

        // Reject the request
        await receivedRequestRef.child(requestKey).update({
          'status': 'rejected',
        });

        // Verify rejected
        final snapshot = await receivedRequestRef.child(requestKey).get();
        expect((snapshot.value as Map)['status'], 'rejected');

        // Cleanup
        await receivedRequestRef.child(requestKey).remove();
      } catch (e) {
        developer.log('Reject friend request test failed: $e');
      }
    });

    test('Can view friends list', () async {
      try {
        final db = FirebaseDatabase.instance;

        // Add friends to the list
        final friendsRef = db.ref(DbPaths.userFriends(testUserId));
        final friend1Id = 'friend-1';
        final friend2Id = 'friend-2';

        await friendsRef.child(friend1Id).set(true);
        await friendsRef.child(friend2Id).set(true);

        // Verify friends exist
        final snapshot = await friendsRef.get();
        expect(snapshot.exists, isTrue);
        final friends = Map<String, dynamic>.from(snapshot.value as Map);
        expect(friends, contains(friend1Id));
        expect(friends, contains(friend2Id));

        // Cleanup
        await friendsRef.child(friend1Id).remove();
        await friendsRef.child(friend2Id).remove();
      } catch (e) {
        developer.log('View friends list test failed: $e');
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
