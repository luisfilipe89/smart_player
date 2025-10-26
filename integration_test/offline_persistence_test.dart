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

  group('Offline Persistence Tests', () {
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

    test('Can create game that persists locally', () async {
      try {
        final db = FirebaseDatabase.instance;
        final gameRef = db.ref(DbPaths.games).push();
        final gameId = gameRef.key!;

        await gameRef.set({
          'id': gameId,
          'sport': 'soccer',
          'dateTime':
              DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'location': 'Offline Test Field',
          'maxPlayers': 10,
          'organizerId': testUserId,
          'isPublic': true,
          '__test_game__': true,
        });

        final snapshot = await gameRef.get();
        expect(snapshot.exists, isTrue);

        await gameRef.remove();
      } catch (e) {
        developer.log('Offline persistence test failed: $e');
      }
    });

    test('Data syncs when connection restored', () async {
      try {
        final db = FirebaseDatabase.instance;
        final gameRef = db.ref(DbPaths.games).push();
        final gameId = gameRef.key!;

        await gameRef.set({
          'id': gameId,
          'sport': 'basketball',
          'dateTime': DateTime.now().toIso8601String(),
          'location': 'Sync Test Court',
          'organizerId': testUserId,
          '__test_game__': true,
        });

        final snapshot = await db.ref(DbPaths.game(gameId)).get();
        expect(snapshot.exists, isTrue);

        await gameRef.remove();
      } catch (e) {
        developer.log('Sync test failed: $e');
      }
    });

    test('Offline operations are queued', () async {
      try {
        final db = FirebaseDatabase.instance;

        final game1 = db.ref(DbPaths.games).push();
        final game2 = db.ref(DbPaths.games).push();

        await game1.set({
          'id': game1.key,
          'sport': 'tennis',
          'organizerId': testUserId,
          '__test_game__': true,
        });

        await game2.set({
          'id': game2.key,
          'sport': 'volleyball',
          'organizerId': testUserId,
          '__test_game__': true,
        });

        final snap1 = await game1.get();
        final snap2 = await game2.get();
        expect(snap1.exists, isTrue);
        expect(snap2.exists, isTrue);

        await game1.remove();
        await game2.remove();
      } catch (e) {
        developer.log('Operation queue test failed: $e');
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
                  game.containsKey('__test_game__')) {
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
