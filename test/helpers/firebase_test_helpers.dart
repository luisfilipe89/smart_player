import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Helper class for Firebase emulator testing
class FirebaseTestHelpers {
  static bool _isInitialized = false;

  /// Initialize Firebase with emulator settings
  static Future<void> initializeFirebaseEmulators() async {
    try {
      if (_isInitialized) {
        return; // Already initialized
      }

      // Initialize Firebase with emulator configuration
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'demo-key',
          appId: 'demo-app-id',
          messagingSenderId: '123456789',
          projectId: 'demo-test',
          authDomain: 'demo-test.firebaseapp.com',
          databaseURL: 'http://localhost:9000?ns=demo-test',
          storageBucket: 'demo-test.appspot.com',
        ),
      );

      // Connect to emulators AFTER initialization
      await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
      FirebaseDatabase.instance.useDatabaseEmulator('localhost', 9000);

      _isInitialized = true;
    } catch (e, stackTrace) {
      // Log the error for debugging
      print('Firebase initialization error: $e');
      print('Stack trace: $stackTrace');

      // If already initialized, that's okay
      if (!e.toString().contains('already initialized') &&
          !e.toString().contains('instance.get')) {
        rethrow;
      }
    }
  }

  /// Clean up test data
  static Future<void> cleanup() async {
    try {
      // Sign out current user
      await FirebaseAuth.instance.signOut();

      // Note: Database cleanup would require specific service calls
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Get Firebase App for testing
  static FirebaseApp get app => Firebase.app();
}

/// Test constants for Firebase emulator
class FirebaseEmulatorConfig {
  static const String projectId = 'demo-test';
  static const String authHost = 'localhost:9099';
  static const String databaseHost = 'localhost:9000';
  static const int authPort = 9099;
  static const int databasePort = 9000;
}
