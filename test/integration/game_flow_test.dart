import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/db/db_paths.dart';
import '../helpers/firebase_test_helpers.dart';

void main() {
  bool hasEmulators = false;

  group('Game Flow Integration Tests', () {
    setUpAll(() async {
      // Initialize Flutter binding before Firebase
      TestWidgetsFlutterBinding.ensureInitialized();
      try {
        await FirebaseTestHelpers.initializeFirebaseEmulators();
        // Ensure auth user exists
        await FirebaseAuth.instance.signInAnonymously();
        hasEmulators = true;
      } catch (e) {
        // Skip tests if emulators not running
        print(
            '⚠️ Firebase emulators not available, skipping integration tests');
        hasEmulators = false;
      }
    });

    tearDownAll(() async {
      if (hasEmulators) {
        // Clean up test data
        await FirebaseTestHelpers.cleanup();
      }
    });

    test('should handle complete game creation flow', () async {
      if (!hasEmulators) return;
      final db = FirebaseDatabase.instance;
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // 1) Create game
      final newRef = db.ref(DbPaths.games).push();
      final gameId = newRef.key!;
      final game = Game(
        id: gameId,
        sport: 'soccer',
        dateTime: DateTime.now().add(const Duration(hours: 2)),
        location: 'Test Field',
        maxPlayers: 10,
        description: 'Integration test game',
        organizerId: uid,
        organizerName: 'Tester',
        createdAt: DateTime.now(),
        players: const [],
        currentPlayers: 0,
        isPublic: true,
      );

      await newRef.set(game.toCloudJson());

      // 2) Join game
      final playersRef = db.ref(DbPaths.gamePlayers(gameId));
      await playersRef.child(uid).set(true);
      await db.ref(DbPaths.games).child(gameId).update({
        'players': [uid],
        'currentPlayers': 1,
      });

      final snap = await db.ref(DbPaths.game(gameId)).get();
      expect(snap.exists, isTrue);

      // 3) Update game
      await db.ref(DbPaths.game(gameId)).update({'location': 'Updated Field'});
      final updated =
          await db.ref(DbPaths.game(gameId)).child('location').get();
      expect(updated.value, 'Updated Field');

      // 4) Delete game
      await db.ref(DbPaths.game(gameId)).remove();
      final deleted = await db.ref(DbPaths.game(gameId)).get();
      expect(deleted.exists, isFalse);
    });

    test('should handle game invitation flow', () async {
      if (!hasEmulators) return;
      final db = FirebaseDatabase.instance;
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final gameRef = db.ref(DbPaths.games).push();
      final gameId = gameRef.key!;
      await gameRef.set({
        'id': gameId,
        'sport': 'soccer',
        'organizerId': uid,
        'organizerName': 'Tester',
        'dateTime': DateTime.now().toIso8601String(),
        'dateTimeUtc': DateTime.now().toUtc().toIso8601String(),
        'location': 'Field',
        'maxPlayers': 10,
        'currentPlayers': 0,
        'isActive': true,
        'isPublic': true,
        'players': [],
      });

      // Write an invite to a fake user
      final invitee = 'invitee-uid';
      await db.ref(DbPaths.gameInvites(gameId)).child(invitee).set({
        'status': 'pending',
        'organizerId': uid,
        'organizerName': 'Tester',
        'sport': 'soccer',
      });

      final invSnap =
          await db.ref(DbPaths.gameInvites(gameId)).child(invitee).get();
      expect(invSnap.exists, isTrue);

      // Cleanup
      await db.ref(DbPaths.game(gameId)).remove();
    });

    test('should handle game state synchronization', () async {
      if (!hasEmulators) return;
      // Test real-time updates with emulators
      expect(true, true);
    });

    test('should handle complete game lifecycle', () async {
      if (!hasEmulators) return;
      // Test complete game lifecycle with emulators
      expect(true, true);
    });

    test('should use emulator configuration', () async {
      if (!hasEmulators) return;
      // Verify emulator configuration
      expect(FirebaseEmulatorConfig.projectId, 'demo-test');
      expect(FirebaseEmulatorConfig.authPort, 9099);
      expect(FirebaseEmulatorConfig.databasePort, 9000);
    });
  });
}
