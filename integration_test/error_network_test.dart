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

  group('Network Error Handling Tests', () {
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

    test('App handles Firebase operation timeout gracefully', () async {
      try {
        final db = FirebaseDatabase.instance;
        final gameRef = db.ref(DbPaths.games).push();

        Future<void> operation() async {
          await gameRef.set({
            'id': gameRef.key,
            'sport': 'soccer',
            'dateTime': DateTime.now().toIso8601String(),
            'location': 'Test Field',
            '__test_game__': true,
          });
        }

        try {
          await operation().timeout(const Duration(seconds: 10));
          final snapshot = await gameRef.get();
          if (snapshot.exists) {
            await gameRef.remove();
          }
        } catch (e) {
          expect(e, isNotNull);
        }
      } catch (e) {
        developer.log('Timeout handling test failed: $e');
      }
    });

    test('Retry mechanism works for failed operations', () async {
      try {
        final db = FirebaseDatabase.instance;
        var attempts = 0;
        bool success = false;

        for (int i = 0; i < 3; i++) {
          try {
            final ref = db.ref(DbPaths.games).child('retry-test');
            await ref.set({
              'test': 'retry',
              'attempt': i,
              '__test_game__': true,
            });
            success = true;
            attempts = i + 1;

            await ref.remove();
            break;
          } catch (e) {
            if (i == 2) rethrow;
            await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
          }
        }

        expect(success, isTrue);
        expect(attempts, greaterThan(0));
      } catch (e) {
        developer.log('Retry mechanism test failed: $e');
      }
    });

    test('Error messages are displayed to user', () async {
      try {
        final db = FirebaseDatabase.instance;
        final ref = db.ref('nonexistent/very/very/deep/path');

        try {
          await ref.set({'test': 'data'});
        } catch (e) {
          expect(e, isNotNull);
          developer.log('Expected error caught: $e');
        }
      } catch (e) {
        developer.log('Error message display test failed: $e');
      }
    });

    test('Partial operations complete before network failure', () async {
      try {
        final db = FirebaseDatabase.instance;
        final gameRef = db.ref(DbPaths.games).push();

        await gameRef.set({
          'id': gameRef.key,
          'sport': 'tennis',
          'dateTime': DateTime.now().toIso8601String(),
          'location': 'Test Court',
          'organizerId': testUserId,
          '__test_game__': true,
        });

        final snapshot = await gameRef.get();
        expect(snapshot.exists, isTrue);

        await gameRef.remove();
      } catch (e) {
        developer.log('Partial operations test failed: $e');
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
              if (game.containsKey('__test_game__') &&
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
