// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Check if user is signed in
  static bool get isSignedIn => _auth.currentUser != null;

  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;

  // Get current user display name
  static String get currentUserDisplayName {
    final user = _auth.currentUser;
    if (user == null) return 'Anonymous User';

    // If display name is null or empty, try to get email prefix
    final rawDisplayName = user.displayName?.trim() ?? '';
    if (rawDisplayName.isNotEmpty) {
      // Use only the first name for greeting
      final firstName = rawDisplayName.split(RegExp(r"\s+")).first;
      return _capitalize(firstName);
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

  static String _capitalize(String input) {
    if (input.isEmpty) return input;
    if (input.length == 1) return input.toUpperCase();
    return input[0].toUpperCase() + input.substring(1);
  }

  // Sign in anonymously
  static Future<UserCredential?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      // Signed in anonymously successfully
      return userCredential;
    } catch (e) {
      // Error signing in anonymously
      return null;
    }
  }

  // Sign in with Google (simplified - requires google_sign_in package)
  static Future<UserCredential?> signInWithGoogle() async {
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
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final oauthCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      await _auth.currentUser?.reload();
      return userCredential;
    } catch (e) {
      // Error signing in with Google
      return null;
    }
  }

  // Sign in with email and password
  static Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
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

  // Alias for signInWithEmailAndPassword
  static Future<UserCredential> signInWithEmail(
      String email, String password) async {
    return signInWithEmailAndPassword(email, password);
  }

  // Create account with email and password
  static Future<UserCredential> createUserWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
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

  // Alias for createUserWithEmailAndPassword (without displayName)
  static Future<UserCredential> registerWithEmail(
      String email, String password) async {
    return createUserWithEmailAndPassword(email, password, '');
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      // Signed out successfully
    } catch (e) {
      // Error signing out
    }
  }

  // Listen to auth state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Update user profile
  static Future<void> updateProfile({
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

  // Update display name
  static Future<void> updateDisplayName(String displayName) async {
    try {
      final user = _auth.currentUser;
      if (user != null && displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
        await user.reload();
        // Force refresh the user data
        await user.getIdToken(true);
        // Display name updated successfully
      }
    } catch (e) {
      print('Error updating display name: $e');
      // Error updating display name
    }
  }

  // Map FirebaseAuthException to friendly message
  static String _mapFirebaseError(FirebaseAuthException e,
      {required bool isSignup}) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'error_email_in_use';
      case 'invalid-email':
        return 'auth_email_invalid';
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

  // Delete user account
  static Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await user.delete();
      // Account deleted successfully
      return true;
    } catch (e) {
      // Error deleting account
      return false;
    }
  }

  // ----- Account management helpers -----

  // Whether the current user has a password provider linked
  static bool get hasPasswordProvider {
    final providers =
        _auth.currentUser?.providerData.map((p) => p.providerId).toList() ??
            const [];
    return providers.contains('password');
  }

  // Change password for email/password users (requires re-auth)
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw Exception('No email on account');
    }

    try {
      final cred = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      await user.reload();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
          throw Exception('Current password is incorrect');
        case 'weak-password':
          throw Exception('New password is too weak');
        case 'requires-recent-login':
          throw Exception('Please sign in again and retry');
        default:
          throw Exception('Could not change password (${e.code})');
      }
    }
  }

  // Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw Exception('Invalid email');
        case 'user-not-found':
          throw Exception('No account found for this email');
        default:
          throw Exception('Could not send reset email (${e.code})');
      }
    }
  }

  // Change email (email/password users). Uses re-auth with current password then verifies new email.
  static Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');
    final existingEmail = user.email;
    if (existingEmail == null || existingEmail.isEmpty) {
      throw Exception('No email on account');
    }

    try {
      // Enforce cooldown between email change requests
      final uid = user.uid;
      final DatabaseReference metaRef =
          FirebaseDatabase.instance.ref('users/$uid/metadata');
      const int cooldownHours = 24; // adjust policy as needed
      final cooldownMs = Duration(hours: cooldownHours).inMilliseconds;
      final metaSnapshot = await metaRef.child('emailChangeRequestedAt').get();
      if (metaSnapshot.exists) {
        final lastMs = int.tryParse(metaSnapshot.value.toString()) ?? 0;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (lastMs > 0 && (nowMs - lastMs) < cooldownMs) {
          final remainingMs = cooldownMs - (nowMs - lastMs);
          final remainingHours = (remainingMs / (1000 * 60 * 60)).ceil();
          throw Exception(
              'You can change your email again in ~$remainingHours hour(s).');
        }
      }

      // Re-authenticate with current password
      final cred = EmailAuthProvider.credential(
        email: existingEmail,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);

      // Prefer verifyBeforeUpdateEmail if available, else updateEmail
      try {
        await user.verifyBeforeUpdateEmail(newEmail);
      } on NoSuchMethodError {
        await user.updateEmail(newEmail);
      }

      await user.reload();

      // Record request time to enforce cooldown
      await metaRef.update({
        'emailChangeRequestedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw Exception('Invalid email');
        case 'email-already-in-use':
          throw Exception('Email already in use');
        case 'wrong-password':
          throw Exception('Current password is incorrect');
        case 'requires-recent-login':
          throw Exception('Please sign in again and retry');
        default:
          throw Exception('Could not change email (${e.code})');
      }
    }
  }
}
