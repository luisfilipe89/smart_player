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
  static String get currentUserDisplayName =>
      _auth.currentUser?.displayName ?? 'Anonymous User';

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
  static Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Signed in with email successfully
      return userCredential;
    } catch (e) {
      // Error signing in with email
      return null;
    }
  }

  // Alias for signInWithEmailAndPassword
  static Future<UserCredential?> signInWithEmail(
      String email, String password) async {
    return signInWithEmailAndPassword(email, password);
  }

  // Create account with email and password
  static Future<UserCredential?> createUserWithEmailAndPassword(
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
    } catch (e) {
      // Error creating account
      return null;
    }
  }

  // Alias for createUserWithEmailAndPassword (without displayName)
  static Future<UserCredential?> registerWithEmail(
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
      await _auth.currentUser?.updateDisplayName(displayName);
      await _auth.currentUser?.reload();
      // Display name updated successfully
    } catch (e) {
      // Error updating display name
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
