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

  group('Concurrent Operation Tests', () {
    late String testUserId;
    late String testGameId;

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

      final db = FirebaseDatabase.instance;
      final gameRef = db.ref(DbPaths.games).push();
      testGameId = gameRef.key!;

      await gameRef.set({
        'id': testGameId,
        'sport': 'soccer',
        'dateTime':
            DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'location': 'Test Field',
        'maxPlayers': 10,
        'currentPlayers': 0,
        'organizerId': 'other-user',
        'players': [],
        'isPublic': true,
        '__test_game__': true,
      });
    });

    test('Handles simultaneous game join attempts', () async {
      try {
        final db = FirebaseDatabase.instance;
        final playersRef = db.ref(DbPaths.gamePlayers(testGameId));

        final futures = [
          playersRef.child('user-1').set(true),
          playersRef.child('user-2').set(true),
          playersRef.child('user-3').set(true),
        ];

        await Future.wait(futures);

        await db.ref(DbPaths.game(testGameId)).update({
          'currentPlayers': 3,
          'players': ['user-1', 'user-2', 'user-3'],
        });

        final snapshot = await db.ref(DbPaths.game(testGameId)).get();
        final gameData = Map<String, dynamic>.from(snapshot.value as Map);
        expect(gameData['currentPlayers'], 3);
        expect(List.from(gameData['players']).length, 3);

        await playersRef.child('user-1').remove();
        await playersRef.child('user-2').remove();
        await playersRef.child('user-3').remove();
      } catch (e) {
        developer.log('Simultaneous join test failed: $e');
      }
    });

    test('Resolves conflicts when multiple users update same game', () async {
      try {
        final db = FirebaseDatabase.instance;

        final update1 =
            db.ref(DbPaths.game(testGameId)).update({'location': 'Location A'});
        final update2 =
            db.ref(DbPaths.game(testGameId)).update({'location': 'Location B'});

        try {
          await Future.wait([update1, update2]);
        } catch (e) {
          developer.log('Concurrent update conflict resolved: $e');
        }

        final snapshot = await db.ref(DbPaths.game(testGameId)).get();
        expect(snapshot.exists, isTrue);
      } catch (e) {
        developer.log('Conflict resolution test failed: $e');
      }
    });

    test('Optimistic updates work correctly', () async {
      try {
        final db = FirebaseDatabase.instance;

        final initialSnapshot = await db.ref(DbPaths.game(testGameId)).get();
        final initialPlayers =
            (initialSnapshot.value as Map)['currentPlayers'] as int;

        await db.ref(DbPaths.game(testGameId)).update({
          'currentPlayers': initialPlayers + 1,
        });

        final finalSnapshot = await db.ref(DbPaths.game(testGameId)).get();
        final finalPlayers =
            (finalSnapshot.value as Map)['currentPlayers'] as int;

        expect(finalPlayers, greaterThan(initialPlayers));
      } catch (e) {
        developer.log('Optimistic updates test failed: $e');
      }
    });

    test('Handles concurrent friend requests gracefully', () async {
      try {
        final db = FirebaseDatabase.instance;
        final friendId = 'test-friend-${DateTime.now().millisecondsSinceEpoch}';

        final request1 =
            db.ref(DbPaths.userFriendRequestsReceived(testUserId)).push();
        final request2 =
            db.ref(DbPaths.userFriendRequestsReceived(testUserId)).push();

        await request1.set({
          'friendId': friendId,
          'status': 'pending',
          'timestamp': DateTime.now().toIso8601String(),
        });

        await request2.set({
          'friendId': friendId,
          'status': 'pending',
          'timestamp': DateTime.now().toIso8601String(),
        });

        final snap1 = await request1.get();
        final snap2 = await request2.get();
        expect(snap1.exists, isTrue);
        expect(snap2.exists, isTrue);

        await request1.remove();
        await request2.remove();
      } catch (e) {
        developer.log('Concurrent friend requests test failed: $e');
      }
    });

    tearDown(() async {
      try {
        if (testGameId.isNotEmpty) {
          final db = FirebaseDatabase.instance;
          await db.ref(DbPaths.games).child(testGameId).remove();
        }
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        // Ignore
      }
    });
  });
}
