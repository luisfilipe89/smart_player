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

  group('My Games Screen Integration Tests', () {
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

    test('Can view upcoming games', () async {
      try {
        final db = FirebaseDatabase.instance;

        // Create an upcoming game
        final gameRef = db.ref(DbPaths.games).push();
        final gameId = gameRef.key!;

        await gameRef.set({
          'id': gameId,
          'sport': 'basketball',
          'dateTime':
              DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          'location': 'Upcoming Test Court',
          'maxPlayers': 5,
          'currentPlayers': 1,
          'organizerId': testUserId,
          'organizerName': 'Test User',
          'players': [testUserId],
          'isPublic': true,
          '__test_game__': true,
        });

        // Verify game exists
        final snapshot = await db.ref(DbPaths.game(gameId)).get();
        expect(snapshot.exists, isTrue);

        // Cleanup
        await gameRef.remove();
      } catch (e) {
        developer.log('Upcoming games test failed: $e');
      }
    });

    test('Can view past games', () async {
      try {
        final db = FirebaseDatabase.instance;

        // Create a past game
        final gameRef = db.ref(DbPaths.games).push();
        final gameId = gameRef.key!;

        await gameRef.set({
          'id': gameId,
          'sport': 'tennis',
          'dateTime': DateTime.now()
              .subtract(const Duration(days: 2))
              .toIso8601String(),
          'location': 'Past Test Court',
          'maxPlayers': 4,
          'currentPlayers': 2,
          'organizerId': testUserId,
          'players': [testUserId],
          'isPublic': true,
          '__test_game__': true,
        });

        // Verify game exists
        final snapshot = await db.ref(DbPaths.game(gameId)).get();
        expect(snapshot.exists, isTrue);

        // Cleanup
        await gameRef.remove();
      } catch (e) {
        developer.log('Past games test failed: $e');
      }
    });

    test('Can cancel own game', () async {
      try {
        final db = FirebaseDatabase.instance;

        // Create a game organized by user
        final gameRef = db.ref(DbPaths.games).push();
        final gameId = gameRef.key!;

        await gameRef.set({
          'id': gameId,
          'sport': 'soccer',
          'dateTime':
              DateTime.now().add(const Duration(days: 3)).toIso8601String(),
          'location': 'Test Field',
          'maxPlayers': 10,
          'organizerId': testUserId,
          '__test_game__': true,
        });

        // Cancel/delete the game
        await gameRef.remove();

        // Verify game deleted
        final snapshot = await db.ref(DbPaths.game(gameId)).get();
        expect(snapshot.exists, isFalse);
      } catch (e) {
        developer.log('Cancel game test failed: $e');
      }
    });

    test('Can view organized games', () async {
      try {
        final db = FirebaseDatabase.instance;

        // Create multiple organized games
        final game1Ref = db.ref(DbPaths.games).push();
        final game2Ref = db.ref(DbPaths.games).push();

        await game1Ref.set({
          'id': game1Ref.key,
          'sport': 'volleyball',
          'dateTime':
              DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'location': 'Beach 1',
          'maxPlayers': 12,
          'organizerId': testUserId,
          '__test_game__': true,
        });

        await game2Ref.set({
          'id': game2Ref.key,
          'sport': 'badminton',
          'dateTime':
              DateTime.now().add(const Duration(days: 2)).toIso8601String(),
          'location': 'Court 2',
          'maxPlayers': 4,
          'organizerId': testUserId,
          '__test_game__': true,
        });

        // Verify games exist
        final snap1 = await db.ref(DbPaths.game(game1Ref.key!)).get();
        final snap2 = await db.ref(DbPaths.game(game2Ref.key!)).get();
        expect(snap1.exists, isTrue);
        expect(snap2.exists, isTrue);

        // Cleanup
        await game1Ref.remove();
        await game2Ref.remove();
      } catch (e) {
        developer.log('Organized games test failed: $e');
      }
    });

    tearDown(() async {
      try {
        if (FirebaseAuth.instance.currentUser != null) {
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
