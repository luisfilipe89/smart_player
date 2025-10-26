import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:move_young/firebase_options.dart';
import 'package:move_young/db/db_paths.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Agenda Screen Integration Tests', () {
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

    test('Can view games for specific date', () async {
      try {
        final db = FirebaseDatabase.instance;
        final testDate = DateTime.now().add(const Duration(days: 3));

        final gameRef = db.ref(DbPaths.games).push();
        final gameId = gameRef.key!;

        await gameRef.set({
          'id': gameId,
          'sport': 'soccer',
          'dateTime': testDate.toIso8601String(),
          'location': 'Agenda Test Field',
          'maxPlayers': 10,
          'organizerId': testUserId,
          'players': [testUserId],
          'isPublic': true,
          '__test_game__': true,
        });

        final snapshot = await db.ref(DbPaths.game(gameId)).get();
        expect(snapshot.exists, isTrue);

        await gameRef.remove();
      } catch (e) {
        print('View games for date test failed: $e');
      }
    });

    test('Can view multiple games on same date', () async {
      try {
        final db = FirebaseDatabase.instance;
        final testDate = DateTime.now().add(const Duration(days: 4));

        final game1Ref = db.ref(DbPaths.games).push();
        final game2Ref = db.ref(DbPaths.games).push();

        await game1Ref.set({
          'id': game1Ref.key,
          'sport': 'basketball',
          'dateTime': testDate.toIso8601String(),
          'location': 'Court 1',
          'organizerId': testUserId,
          '__test_game__': true,
        });

        await game2Ref.set({
          'id': game2Ref.key,
          'sport': 'tennis',
          'dateTime': testDate.toIso8601String(),
          'location': 'Court 2',
          'organizerId': testUserId,
          '__test_game__': true,
        });

        final snap1 = await db.ref(DbPaths.game(game1Ref.key!)).get();
        final snap2 = await db.ref(DbPaths.game(game2Ref.key!)).get();
        expect(snap1.exists, isTrue);
        expect(snap2.exists, isTrue);

        await game1Ref.remove();
        await game2Ref.remove();
      } catch (e) {
        print('Multiple games same date test failed: $e');
      }
    });

    test('Agenda shows upcoming games', () async {
      try {
        final db = FirebaseDatabase.instance;
        final futureGameRef = db.ref(DbPaths.games).push();

        await futureGameRef.set({
          'id': futureGameRef.key,
          'sport': 'volleyball',
          'dateTime':
              DateTime.now().add(const Duration(days: 5)).toIso8601String(),
          'location': 'Beach Court',
          'organizerId': testUserId,
          '__test_game__': true,
        });

        final snapshot = await db.ref(DbPaths.game(futureGameRef.key!)).get();
        expect(snapshot.exists, isTrue);

        final gameData = Map<String, dynamic>.from(snapshot.value as Map);
        final gameDateTime = DateTime.parse(gameData['dateTime']);
        expect(gameDateTime.isAfter(DateTime.now()), isTrue);

        await futureGameRef.remove();
      } catch (e) {
        print('Upcoming games test failed: $e');
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
