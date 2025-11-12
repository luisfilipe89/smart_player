// lib/providers/services/auth_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service_instance.dart';
import 'auth_service.dart';
import 'package:move_young/providers/infrastructure/firebase_providers.dart';

// AuthService provider with dependency injection
final authServiceProvider = Provider<IAuthService>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  return AuthServiceInstance(firebaseAuth);
});

// Current user provider (reactive)
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider) as AuthServiceInstance;
  return authService.authStateChanges;
});

// Auth state provider (simplified boolean)
final isSignedInProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) => user != null,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Current user ID provider
final currentUserIdProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) => user?.uid,
    loading: () => null,
    error: (_, __) => null,
  );
});

// Current user display name provider
final currentUserDisplayNameProvider = Provider<String>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) {
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
    },
    loading: () => 'User',
    error: (_, __) => 'User',
  );
});

String _capitalize(String input) {
  if (input.isEmpty) return input;
  if (input.length == 1) return input.toUpperCase();
  return input[0].toUpperCase() + input.substring(1);
}

// Auth actions provider (for sign in/out operations)
final authActionsProvider = Provider<AuthActions>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthActions(authService);
});

// Helper class for auth actions
class AuthActions {
  final IAuthService _authService;

  AuthActions(this._authService);

  Future<UserCredential?> signInWithGoogle() => _authService.signInWithGoogle();
  Future<UserCredential> signInWithEmailAndPassword(
          String email, String password) =>
      _authService.signInWithEmailAndPassword(email, password);
  Future<UserCredential> createUserWithEmailAndPassword(
          String email, String password, String displayName) =>
      _authService.createUserWithEmailAndPassword(email, password, displayName);
  Future<void> signOut() => _authService.signOut();
  Future<void> updateProfile({String? displayName, String? photoURL}) =>
      _authService.updateProfile(displayName: displayName, photoURL: photoURL);
  Future<void> updateEmail(String newEmail) =>
      _authService.updateEmail(newEmail);
  Future<DeleteAccountResult> deleteAccount() => _authService.deleteAccount();
  Future<void> changePassword(String currentPassword, String newPassword) =>
      _authService.changePassword(currentPassword, newPassword);
  Future<void> sendPasswordResetEmail(String email) =>
      _authService.sendPasswordResetEmail(email);
  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) =>
      _authService.changeEmail(
        currentPassword: currentPassword,
        newEmail: newEmail,
      );
  Future<void> reauthenticateWithPassword(String password) =>
      _authService.reauthenticateWithPassword(password);
  bool get hasPasswordProvider => _authService.hasPasswordProvider;
}
