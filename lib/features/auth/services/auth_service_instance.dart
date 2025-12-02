// lib/features/auth/services/auth_service_instance.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:move_young/utils/logger.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:move_young/features/auth/services/auth_service.dart';
import 'package:move_young/models/infrastructure/service_error.dart';
import 'package:move_young/services/firebase_error_handler.dart';

/// Instance-based AuthService for use with Riverpod dependency injection
/// Uses direct try-catch patterns with FirebaseErrorHandler for error handling
class AuthServiceInstance implements IAuthService {
  final FirebaseAuth _auth;

  AuthServiceInstance(this._auth);

  // Get current user
  @override
  User? get currentUser => _auth.currentUser;

  // Check if user is signed in
  @override
  bool get isSignedIn => _auth.currentUser != null;

  // Get current user ID
  @override
  String? get currentUserId => _auth.currentUser?.uid;

  // Get current user nickname
  @override
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
  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  @override
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
        NumberedLogger.i('Google Sign-In: User cancelled');
        return null; // User cancellation is not an error
      }

      NumberedLogger.d('Google Sign-In: User selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw ServiceException(
          'Failed to get authentication tokens from Google',
        );
      }

      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      await _auth.currentUser?.reload();
      NumberedLogger.i('Google Sign-In: Success');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw FirebaseErrorHandler.toServiceException(e);
    } catch (e) {
      NumberedLogger.e('Google Sign-In Error: $e');
      if (e is ServiceException) rethrow;
      throw ServiceException('Failed to sign in with Google', originalError: e);
    }
  }

  // Sign in with email and password
  @override
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
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
      NumberedLogger.e('Error signing in with email: $e');
      throw FirebaseErrorHandler.toServiceException(e);
    }
  }

  // Create account with email and password
  @override
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
      NumberedLogger.e('Error creating account: $e');
      throw FirebaseErrorHandler.toServiceException(e);
    }
  }

  // Sign out
  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      NumberedLogger.e('Error signing out: $e');
      rethrow; // Re-throw to let UI know there was an error
    }
  }

  // Update user profile
  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException('No user signed in');
      }

      await user.updateDisplayName(displayName);
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      await user.reload();
    } catch (e) {
      NumberedLogger.e('Error updating profile: $e');
      rethrow;
    }
  }

  // Update email
  @override
  Future<void> updateEmail(String newEmail) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw AuthException('Not signed in');

      await user.verifyBeforeUpdateEmail(newEmail);
      NumberedLogger.i('Verification email sent to: $newEmail');
    } catch (e) {
      NumberedLogger.e('Error updating email: $e');
      rethrow;
    }
  }

  // Delete user account
  @override
  Future<DeleteAccountResult> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        NumberedLogger.w('No user to delete');
        return const DeleteAccountResult.failure('not_signed_in');
      }

      await user.delete();
      NumberedLogger.i('User account deleted successfully');
      return const DeleteAccountResult.success();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        NumberedLogger.w('Account deletion requires recent login');
        return const DeleteAccountResult.requiresRecentLogin();
      }
      NumberedLogger.e('Error deleting account (auth): $e');
      return DeleteAccountResult.failure(e.message ?? e.code);
    } catch (e) {
      NumberedLogger.e('Error deleting account: $e');
      return DeleteAccountResult.failure(e.toString());
    }
  }

  // Change password
  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw AuthException('Not signed in');

      final email = user.email;
      if (email == null) {
        throw ValidationException('No email on account');
      }

      // Reauthenticate with current password
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(newPassword);
      NumberedLogger.i('Password changed successfully');
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e, isSignup: false), code: e.code);
    } catch (e) {
      throw ServiceException('Password change failed', originalError: e);
    }
  }

  // Send password reset email
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      NumberedLogger.i('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e, isSignup: false), code: e.code);
    } catch (e) {
      throw ServiceException(
        'Failed to send password reset email',
        originalError: e,
      );
    }
  }

  // Change email
  @override
  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw AuthException('Not signed in');

      final email = user.email;
      if (email == null) {
        throw ValidationException('No email on account');
      }

      // Reauthenticate with current password
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Change email (requires verification)
      await user.verifyBeforeUpdateEmail(newEmail);
      NumberedLogger.i('Verification email sent to: $newEmail');
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e, isSignup: false), code: e.code);
    } catch (e) {
      throw ServiceException('Email change failed', originalError: e);
    }
  }

  // Check if user has password provider
  @override
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

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('Not signed in');

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw ValidationException('No email on account');
    }
    if (password.isEmpty) {
      throw ValidationException('auth_password_required');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      NumberedLogger.i('User reauthenticated successfully');
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e, isSignup: false), code: e.code);
    } catch (e) {
      throw ServiceException('Reauthentication failed', originalError: e);
    }
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

