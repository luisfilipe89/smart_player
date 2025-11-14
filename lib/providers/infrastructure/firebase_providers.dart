import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Firebase Auth
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

// Firebase Database with offline persistence enabled
// Persistence is configured lazily on first access to avoid startup overhead
final firebaseDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  final db = FirebaseDatabase.instance;
  // Enable offline persistence lazily - only when database is actually accessed
  // This avoids potential heavy initialization during startup
  // Note: setPersistenceEnabled must be called before any database operations
  // but can be deferred until the first database access
  Future.microtask(() {
    try {
      db.setPersistenceEnabled(true);
      db.setPersistenceCacheSizeBytes(100 * 1024 * 1024); // 100MB cache
    } catch (_) {
      // Ignore if already set or if persistence isn't supported
    }
  });
  return db;
});

// Firebase Messaging
final firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});
