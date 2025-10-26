// lib/services/auth_service_instance.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import '../../utils/service_error.dart';
import '../firebase_error_handler.dart';

/// Instance-based AuthService for use with Riverpod dependency injection
class AuthServiceInstance {
  final FirebaseAuth _auth;

  AuthServiceInstance(this._auth);

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Get current user nickname
  String get currentUserDisplayName {
    final user = _auth.currentUser;
    if (user == null) return 'Anonymous User';

    // If nickname is null or empty, try to get email prefix
    final rawDisplayName = user.displayName?.trim() ?? '';
    if (rawDisplayName.isNotEmpty) {
      // Use only the nickname for greeting
      final nickname = rawDisplayName.split(RegExp(r"\s+")).first;
      return _capitalize(nickname);
    }

    if (user.email != null && user.email!.isNotEmpty) {
      final emailPrefix = user.email!.split('@')[0];
      // Strip non-letters and capitalize best-effort
      final cleaned = emailPrefix.replaceAll(RegExp(r"[^A-Za-z]"), '');
      if (cleaned.isNotEmpty) return _capitalize(cleaned);
      return emailPrefix; // fallback as-is
    }
    return 'User';
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    if (input.length == 1) return input.toUpperCase();
    return input[0].toUpperCase() + input.substring(1);
  }

  // Stream methods
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Stream<User?> get userChanges => _auth.userChanges();

  // Sign in anonymously
  Future<UserCredential> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw FirebaseErrorHandler.toServiceException(e);
    } catch (e) {
      throw ServiceException('Failed to sign in anonymously', originalError: e);
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Web uses Firebase Auth popup provider
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        final credential = await _auth.signInWithPopup(provider);
        await _auth.currentUser?.reload();
        return credential;
      }

      // Mobile (Android/iOS) uses google_sign_in
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User aborted the sign-in flow
        debugPrint('Google Sign-In: User cancelled');
        return null; // User cancellation is not an error
      }

      debugPrint('Google Sign-In: User selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw ServiceException(
            'Failed to get authentication tokens from Google');
      }

      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      await _auth.currentUser?.reload();
      debugPrint('Google Sign-In: Success');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw FirebaseErrorHandler.toServiceException(e);
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (e is ServiceException) rethrow;
      throw ServiceException('Failed to sign in with Google', originalError: e);
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    if (password.isEmpty) {
      throw ValidationException('auth_password_required');
    }
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Ensure latest profile (displayName) is loaded
      await _auth.currentUser?.reload();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e, isSignup: false), code: e.code);
    } catch (e) {
      if (e is ServiceException) rethrow;
      throw ServiceException('Sign in failed', originalError: e);
    }
  }

  // Create account with email and password
  Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update nickname
      await userCredential.user?.updateDisplayName(displayName);
      await userCredential.user?.reload();

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e, isSignup: true), code: e.code);
    } catch (e) {
      if (e is ServiceException) rethrow;
      throw ServiceException('Account creation failed', originalError: e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow; // Re-throw to let UI know there was an error
    }
  }

  // Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }

      await user.updateDisplayName(displayName);
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      await user.reload();
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  // Update email
  Future<void> updateEmail(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not signed in');

      await user.verifyBeforeUpdateEmail(newEmail);
      debugPrint('Verification email sent to: $newEmail');
    } catch (e) {
      debugPrint('Error updating email: $e');
      rethrow;
    }
  }

  // Update nickname
  Future<void> updateDisplayName(String displayName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in');
      }
      if (displayName.isEmpty) {
        throw Exception('Display name cannot be empty');
      }

      await user.updateDisplayName(displayName);
      await user.reload();
      // Force refresh the user data
      await user.getIdToken(true);
    } catch (e) {
      debugPrint('Error updating nickname: $e');
      rethrow;
    }
  }

  // Delete user account
  Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('No user to delete');
        return false;
      }

      // Delete the user account
      await user.delete();
      debugPrint('User account deleted successfully');
      return true;
    } catch (e) {
      debugPrint('Error deleting account: $e');
      return false;
    }
  }

  // Change password
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not signed in');

      final email = user.email;
      if (email == null) {
        throw Exception('No email on account');
      }

      // Reauthenticate with current password
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(newPassword);
      debugPrint('Password changed successfully');
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e, isSignup: false));
    } catch (e) {
      throw Exception('Password change failed: ${e.toString()}');
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      debugPrint('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e, isSignup: false));
    } catch (e) {
      throw Exception('Failed to send password reset email: ${e.toString()}');
    }
  }

  // Change email
  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not signed in');

      final email = user.email;
      if (email == null) {
        throw Exception('No email on account');
      }

      // Reauthenticate with current password
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Change email (requires verification)
      await user.verifyBeforeUpdateEmail(newEmail);
      debugPrint('Verification email sent to: $newEmail');
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e, isSignup: false));
    } catch (e) {
      throw Exception('Email change failed: ${e.toString()}');
    }
  }

  // Check if user has password provider
  bool get hasPasswordProvider {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Check if user has email/password provider
    final providers = user.providerData;
    for (var provider in providers) {
      if (provider.providerId == 'password') {
        return true;
      }
    }
    return false;
  }

  // Map FirebaseAuthException to friendly message
  String _mapFirebaseError(FirebaseAuthException e, {required bool isSignup}) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'error_email_in_use';
      case 'invalid-email':
        return 'auth_email_invalid';
      case 'invalid-credential':
        // Newer SDK often returns this for wrong email/password
        return 'wrong_password';
      case 'invalid-login-credentials':
        // Alias observed on some platforms
        return 'wrong_password';
      case 'missing-password':
        return 'auth_password_required';
      case 'weak-password':
        return 'auth_password_too_short';
      case 'user-not-found':
        return 'user_not_found';
      case 'wrong-password':
        return 'wrong_password';
      case 'user-disabled':
        return 'user_disabled';
      case 'operation-not-allowed':
        return 'operation_not_allowed';
      case 'too-many-requests':
        return 'too_many_requests';
      case 'network-request-failed':
        return 'network_error';
      default:
        return isSignup ? 'error_generic_signup' : 'error_generic_signin';
    }
  }
}
