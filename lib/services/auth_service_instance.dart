// lib/services/auth_service_instance.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';

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
  Future<UserCredential?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      // Signed in anonymously successfully
      return userCredential;
    } catch (e) {
      // Error signing in anonymously
      return null;
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
        return null;
      }

      debugPrint('Google Sign-In: User selected: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint('Google Sign-In: Missing tokens');
        return null;
      }

      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      await _auth.currentUser?.reload();
      debugPrint('Google Sign-In: Success');
      return userCredential;
    } catch (e) {
      // Error signing in with Google
      debugPrint('Google Sign-In Error: $e');
      return null;
    }
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    if (password.isEmpty) {
      throw Exception('auth_password_required');
    }
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Ensure latest profile (displayName) is loaded
      await _auth.currentUser?.reload();
      // Signed in with email successfully
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e, isSignup: false));
    } catch (e) {
      throw Exception('Sign in failed: ${e.toString()}');
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

      // Created account with email successfully
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e, isSignup: true));
    } catch (e) {
      throw Exception('Account creation failed: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      // Signed out successfully
    } catch (e) {
      // Error signing out
    }
  }

  // Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await user.updateDisplayName(displayName);
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      await user.reload();
      // Profile updated successfully
    } catch (e) {
      // Error updating profile
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
      if (user != null && displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
        await user.reload();
        // Force refresh the user data
        await user.getIdToken(true);
        // Nickname updated successfully
      }
    } catch (e) {
      debugPrint('Error updating nickname: $e');
      // Error updating nickname
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
