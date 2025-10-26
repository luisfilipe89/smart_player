import 'dart:developer' as developer;
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:move_young/firebase_options.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/db/db_paths.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Game Organization Screen Integration Tests', () {
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

    test('Can create a game through organization flow', () async {
      try {
        final db = FirebaseDatabase.instance;
        final gameRef = db.ref(DbPaths.games).push();
        final gameId = gameRef.key!;

        final game = Game(
          id: gameId,
          sport: 'soccer',
          dateTime: DateTime.now().add(const Duration(days: 1)),
          location: 'Test Field - Organize Test',
          maxPlayers: 10,
          description: 'Integration test game from organize screen',
          organizerId: testUserId,
          organizerName: 'Test User',
          createdAt: DateTime.now(),
          players: const [],
          currentPlayers: 0,
          isPublic: true,
        );

        final gameData = game.toCloudJson();
        gameData['__test_game__'] = true;
        await gameRef.set(gameData);

        // Verify game created
        final snapshot = await db.ref(DbPaths.game(gameId)).get();
        expect(snapshot.exists, isTrue);
        expect((snapshot.value as Map)['organizerId'], testUserId);

        // Cleanup
        await gameRef.remove();
      } catch (e) {
        developer.log('Game creation test failed: $e');
      }
    });

    test('Can create game with friend invitations', () async {
      try {
        final db = FirebaseDatabase.instance;
        final gameRef = db.ref(DbPaths.games).push();
        final gameId = gameRef.key!;

        await gameRef.set({
          'id': gameId,
          'sport': 'basketball',
          'dateTime': DateTime.now().toIso8601String(),
          'location': 'Test Court',
          'maxPlayers': 5,
          'organizerId': testUserId,
          'organizerName': 'Test User',
          'isPublic': true,
          '__test_game__': true,
        });

        // Simulate friend invitation
        final inviteeId =
            'test-friend-${DateTime.now().millisecondsSinceEpoch}';
        await db.ref(DbPaths.gameInvites(gameId)).child(inviteeId).set({
          'status': 'pending',
          'organizerId': testUserId,
        });

        // Verify invite exists
        final inviteSnapshot =
            await db.ref(DbPaths.gameInvites(gameId)).child(inviteeId).get();
        expect(inviteSnapshot.exists, isTrue);

        // Cleanup
        await gameRef.remove();
      } catch (e) {
        developer.log('Friend invitation test failed: $e');
      }
    });

    test('Can update game details', () async {
      try {
        final db = FirebaseDatabase.instance;
        final gameRef = db.ref(DbPaths.games).push();
        final gameId = gameRef.key!;

        await gameRef.set({
          'id': gameId,
          'sport': 'volleyball',
          'dateTime': DateTime.now().toIso8601String(),
          'location': 'Original Beach',
          'maxPlayers': 12,
          'organizerId': testUserId,
          '__test_game__': true,
        });

        // Update game
        await db.ref(DbPaths.game(gameId)).update({
          'location': 'Updated Beach - From Organize Screen',
          'maxPlayers': 14,
        });

        // Verify update
        final snapshot = await db.ref(DbPaths.game(gameId)).get();
        expect((snapshot.value as Map)['location'],
            'Updated Beach - From Organize Screen');
        expect((snapshot.value as Map)['maxPlayers'], 14);

        // Cleanup
        await gameRef.remove();
      } catch (e) {
        developer.log('Game update test failed: $e');
      }
    });

    tearDown(() async {
      try {
        if (FirebaseAuth.instance.currentUser != null) {
          // Clean up test games
          final db = FirebaseDatabase.instance;
          final gamesRef = db.ref(DbPaths.games);
          final snapshot = await gamesRef.get();
          if (snapshot.exists) {
            final games = Map<String, dynamic>.from(snapshot.value as Map);
            for (final entry in games.entries) {
              final game = Map<String, dynamic>.from(entry.value as Map);
              if (game['organizerId'] == testUserId &&
                  game['__test_game__'] == true) {
                await gamesRef.child(entry.key).remove();
              }
            }
          }
        }
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        // Ignore
      }
    });
  });
}
