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
  Future<DeleteAccountResult> deleteAccount();
  Future<void> reauthenticateWithPassword(String password);

  // Providers
  bool get hasPasswordProvider;
}

enum DeleteAccountStatus {
  success,
  requiresRecentLogin,
  failure,
}

class DeleteAccountResult {
  final DeleteAccountStatus status;
  final String? errorMessage;

  const DeleteAccountResult._(this.status, [this.errorMessage]);

  const DeleteAccountResult.success() : this._(DeleteAccountStatus.success);

  const DeleteAccountResult.requiresRecentLogin()
      : this._(DeleteAccountStatus.requiresRecentLogin);

  const DeleteAccountResult.failure([String? message])
      : this._(DeleteAccountStatus.failure, message);

  bool get isSuccess => status == DeleteAccountStatus.success;
  bool get needsReauthentication =>
      status == DeleteAccountStatus.requiresRecentLogin;
}
