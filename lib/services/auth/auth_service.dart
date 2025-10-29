import 'package:firebase_auth/firebase_auth.dart';

/// Interface for authentication service to enable mocking and testability
abstract class IAuthService {
  // State
  User? get currentUser;
  bool get isSignedIn;
  String? get currentUserId;
  String get currentUserDisplayName;

  // Streams
  Stream<User?> get authStateChanges;
  Stream<User?> get userChanges;

  // Auth flows
  Future<UserCredential> signInAnonymously();
  Future<UserCredential?> signInWithGoogle();
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password);
  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  );
  Future<void> signOut();

  // Profile
  Future<void> updateProfile({String? displayName, String? photoURL});
  Future<void> updateEmail(String newEmail);
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> sendPasswordResetEmail(String email);
  Future<void> changeEmail(
      {required String currentPassword, required String newEmail});
  Future<void> updateDisplayName(String displayName);
  Future<bool> deleteAccount();

  // Providers
  bool get hasPasswordProvider;
}
