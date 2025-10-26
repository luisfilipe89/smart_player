import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/db/db_paths.dart';
import 'package:move_young/firebase_options.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Game Management Flow Integration Tests', () {
    late String testUserId;
    late FirebaseDatabase db;

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
      // Ensure authenticated user exists
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        // Ignore if already signed out
      }
      final user = (await FirebaseAuth.instance.signInAnonymously()).user!;
      testUserId = user.uid;
      db = FirebaseDatabase.instance;
    });

    tearDown(() async {
      // Clean up: remove any test games
      try {
        if (FirebaseAuth.instance.currentUser != null) {
          // Remove any games created during tests
          final gamesRef = db.ref(DbPaths.games);
          final snapshot = await gamesRef.get();
          if (snapshot.exists) {
            final games = Map<String, dynamic>.from(snapshot.value as Map);
            for (final entry in games.entries) {
              final game = Map<String, dynamic>.from(entry.value as Map);
              if (game['organizerId'] == testUserId &&
                  game.containsKey('__test_game__')) {
                await gamesRef.child(entry.key).remove();
              }
            }
          }
        }
      } catch (e) {
        // Ignore cleanup errors
      }
    });

    test('User can create a game in Firebase', () async {
      try {
        final gameRef = db.ref(DbPaths.games).push();
        final gameId = gameRef.key!;

        final game = Game(
          id: gameId,
          sport: 'soccer',
          dateTime: DateTime.now().add(const Duration(days: 1)),
          location: 'Test Field - Integration Test',
          maxPlayers: 10,
          description: 'Integration test game',
          organizerId: testUserId,
          organizerName: 'Test User',
          createdAt: DateTime.now(),
          players: const [],
          currentPlayers: 0,
          isPublic: true,
        );

        // Create game with test marker
        final gameData = game.toCloudJson();
        gameData['__test_game__'] = true;
        await gameRef.set(gameData);

        // Verify game exists
        final snapshot = await db.ref(DbPaths.game(gameId)).get();
        expect(snapshot.exists, isTrue);
        expect((snapshot.value as Map)['sport'], 'soccer');
        expect((snapshot.value as Map)['organizerId'], testUserId);

        // Cleanup
        await gameRef.remove();
      } catch (e) {
        fail('Game creation failed: $e');
      }
    });

    test('User can update game information', () async {
      try {
        // Create a test game first
        final gameRef = db.ref(DbPaths.games).push();
        final gameId = gameRef.key!;

        await gameRef.set({
          'id': gameId,
          'sport': 'soccer',
          'organizerId': testUserId,
          'organizerName': 'Test User',
          'dateTime': DateTime.now().toIso8601String(),
          'location': 'Original Field',
          'maxPlayers': 10,
          'currentPlayers': 0,
          '__test_game__': true,
        });

        // Update the location
        await db.ref(DbPaths.game(gameId)).update({
          'location': 'Updated Field - Integration Test',
        });

        // Verify update
        final snapshot = await db.ref(DbPaths.game(gameId)).get();
        expect((snapshot.value as Map)['location'],
            'Updated Field - Integration Test');

        // Cleanup
        await gameRef.remove();
      } catch (e) {
        fail('Game update failed: $e');
      }
    });

    test('User can delete their own game', () async {
      try {
        // Create a test game
        final gameRef = db.ref(DbPaths.games).push();
        final gameId = gameRef.key!;

        await gameRef.set({
          'id': gameId,
          'sport': 'basketball',
          'organizerId': testUserId,
          'organizerName': 'Test User',
          'dateTime': DateTime.now().toIso8601String(),
          'location': 'Test Court',
          'maxPlayers': 5,
          'currentPlayers': 0,
          '__test_game__': true,
        });

        // Verify game exists
        var snapshot = await db.ref(DbPaths.game(gameId)).get();
        expect(snapshot.exists, isTrue);

        // Delete game
        await gameRef.remove();

        // Verify game is deleted
        snapshot = await db.ref(DbPaths.game(gameId)).get();
        expect(snapshot.exists, isFalse);
      } catch (e) {
        fail('Game deletion failed: $e');
      }
    });

    test('User can join a game', () async {
      try {
        // Create a test game
        final gameRef = db.ref(DbPaths.games).push();
        final gameId = gameRef.key!;

        await gameRef.set({
          'id': gameId,
          'sport': 'volleyball',
          'organizerId': testUserId,
          'organizerName': 'Test User',
          'dateTime': DateTime.now().toIso8601String(),
          'location': 'Test Beach',
          'maxPlayers': 12,
          'currentPlayers': 0,
          'players': [],
          '__test_game__': true,
        });

        // Join the game
        final playersRef = db.ref(DbPaths.gamePlayers(gameId));
        await playersRef.child(testUserId).set(true);

        // Update player count
        await db.ref(DbPaths.game(gameId)).update({
          'players': [testUserId],
          'currentPlayers': 1,
        });

        // Verify player joined
        final snapshot = await db.ref(DbPaths.game(gameId)).get();
        final gameData = Map<String, dynamic>.from(snapshot.value as Map);
        expect(gameData['currentPlayers'], 1);
        expect(List.from(gameData['players']), contains(testUserId));

        // Cleanup
        await gameRef.remove();
      } catch (e) {
        fail('Join game failed: $e');
      }
    });

    tearDownAll(() async {
      // Final cleanup
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        // Ignore
      }
    });
  });
}
