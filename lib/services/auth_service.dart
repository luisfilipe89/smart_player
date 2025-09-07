// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

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
      // Google Sign-In not implemented yet
      return null;
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
}
