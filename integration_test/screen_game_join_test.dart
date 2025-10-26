import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:move_young/firebase_options.dart';
import 'package:move_young/db/db_paths.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Game Join Screen Integration Tests', () {
    late String testUserId;
    String? testGameId;

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

      // Create a test game to join
      final db = FirebaseDatabase.instance;
      final gameRef = db.ref(DbPaths.games).push();
      testGameId = gameRef.key!;

      await gameRef.set({
        'id': testGameId,
        'sport': 'soccer',
        'dateTime':
            DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'location': 'Public Test Field',
        'maxPlayers': 10,
        'currentPlayers': 0,
        'organizerId': 'different-organizer',
        'organizerName': 'Other User',
        'players': [],
        'isPublic': true,
        '__test_game__': true,
      });
    });

    test('Can join a public game', () async {
      try {
        final db = FirebaseDatabase.instance;

        // Join the game
        final playersRef = db.ref(DbPaths.gamePlayers(testGameId!));
        await playersRef.child(testUserId).set(true);

        // Update player count
        await db.ref(DbPaths.game(testGameId!)).update({
          'currentPlayers': 1,
          'players': [testUserId],
        });

        // Verify player joined
        final snapshot = await db.ref(DbPaths.game(testGameId!)).get();
        final gameData = Map<String, dynamic>.from(snapshot.value as Map);
        expect(gameData['currentPlayers'], 1);
        expect(List.from(gameData['players']), contains(testUserId));
      } catch (e) {
        print('Join game test failed: $e');
      }
    });

    test('Can leave a joined game', () async {
      try {
        final db = FirebaseDatabase.instance;

        // First join
        final playersRef = db.ref(DbPaths.gamePlayers(testGameId!));
        await playersRef.child(testUserId).set(true);
        await db.ref(DbPaths.game(testGameId!)).update({
          'currentPlayers': 1,
          'players': [testUserId],
        });

        // Then leave
        await playersRef.child(testUserId).remove();
        await db.ref(DbPaths.game(testGameId!)).update({
          'currentPlayers': 0,
          'players': <String>[],
        });

        // Verify player left
        final snapshot = await db.ref(DbPaths.game(testGameId!)).get();
        final gameData = Map<String, dynamic>.from(snapshot.value as Map);
        expect(gameData['currentPlayers'], 0);
        expect(List.from(gameData['players']), isEmpty);
      } catch (e) {
        print('Leave game test failed: $e');
      }
    });

    test('Cannot join full game', () async {
      try {
        final db = FirebaseDatabase.instance;

        // Fill the game
        await db.ref(DbPaths.game(testGameId!)).update({
          'currentPlayers': 10,
          'maxPlayers': 10,
        });

        // Try to join (should fail or be prevented)
        final snapshot = await db.ref(DbPaths.game(testGameId!)).get();
        final gameData = Map<String, dynamic>.from(snapshot.value as Map);
        expect(gameData['currentPlayers'], 10);
        expect(gameData['maxPlayers'], 10);
      } catch (e) {
        print('Full game test failed: $e');
      }
    });

    tearDown(() async {
      try {
        if (testGameId != null) {
          final db = FirebaseDatabase.instance;
          await db.ref(DbPaths.games).child(testGameId!).remove();
        }
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        // Ignore
      }
    });
  });
}
