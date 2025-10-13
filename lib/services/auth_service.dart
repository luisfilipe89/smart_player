// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'package:crypto/crypto.dart' as crypto;
import 'package:move_young/db/db_paths.dart';

class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  // Get current user
  static User? get currentUser => _auth.currentUser;

  // Check if user is signed in
  static bool get isSignedIn => _auth.currentUser != null;

  // Get current user ID
  static String? get currentUserId => _auth.currentUser?.uid;

  // Get current user nickname
  static String get currentUserDisplayName {
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
  static Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
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

  // Listen to user profile changes (displayName, email, photoURL, etc.)
  static Stream<User?> get userChanges => _auth.userChanges();

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

  // Update email
  static Future<void> updateEmail(String newEmail) async {
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
  static Future<void> updateDisplayName(String displayName) async {
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

  // Map FirebaseAuthException to friendly message
  static String _mapFirebaseError(FirebaseAuthException e,
      {required bool isSignup}) {
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

  // Delete user account
  static Future<bool> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final String uid = user.uid;
      final String? email = user.email;

      // Best-effort cleanup of database and storage before deleting auth user
      try {
        await _cleanupUserData(uid: uid, email: email);
      } catch (e) {
        debugPrint('Cleanup before delete failed: $e');
      }

      // Attempt to delete auth account last (may require recent login)
      await user.delete();
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth delete failed: ${e.code}');
      return false;
    } catch (e) {
      debugPrint('Delete account failed: $e');
      return false;
    }
  }

  // Remove user data and cross-references from Realtime Database and Storage
  static Future<void> _cleanupUserData({
    required String uid,
    String? email,
  }) async {
    final DatabaseReference root = FirebaseDatabase.instance.ref();

    // Build a batch of updates to remove references
    final Map<String, Object?> updates = {};

    // 1) Remove email hash index if present
    if (email != null && email.trim().isNotEmpty) {
      final String emailLower = email.trim().toLowerCase();
      final String emailHash =
          crypto.sha256.convert(utf8.encode(emailLower)).toString();
      updates['usersByEmailHash/$emailHash'] = null;
    }

    // 2) Gather current relationships and requests to clean up cross refs
    final DataSnapshot friendsSnap =
        await root.child(DbPaths.userFriends(uid)).get();
    if (friendsSnap.exists && friendsSnap.value is Map) {
      final Map data = friendsSnap.value as Map;
      for (final dynamic k in data.keys) {
        final String otherUid = k.toString();
        updates['${DbPaths.userFriends(uid)}/$otherUid'] = null;
        updates['${DbPaths.userFriends(otherUid)}/$uid'] = null;
      }
    }

    final DataSnapshot sentReqSnap =
        await root.child(DbPaths.userFriendRequestsSent(uid)).get();
    if (sentReqSnap.exists && sentReqSnap.value is Map) {
      final Map data = sentReqSnap.value as Map;
      for (final dynamic k in data.keys) {
        final String toUid = k.toString();
        updates['${DbPaths.userFriendRequestsSent(uid)}/$toUid'] = null;
        updates['${DbPaths.userFriendRequestsReceived(toUid)}/$uid'] = null;
      }
    }

    final DataSnapshot recvReqSnap =
        await root.child(DbPaths.userFriendRequestsReceived(uid)).get();
    if (recvReqSnap.exists && recvReqSnap.value is Map) {
      final Map data = recvReqSnap.value as Map;
      for (final dynamic k in data.keys) {
        final String fromUid = k.toString();
        updates['${DbPaths.userFriendRequestsReceived(uid)}/$fromUid'] = null;
        updates['${DbPaths.userFriendRequestsSent(fromUid)}/$uid'] = null;
      }
    }

    // 3) Remove game invites for this user
    final DataSnapshot myInvitesSnap =
        await root.child(DbPaths.userGameInvites(uid)).get();
    if (myInvitesSnap.exists && myInvitesSnap.value is Map) {
      final Map data = myInvitesSnap.value as Map;
      for (final dynamic k in data.keys) {
        final String gameId = k.toString();
        updates['${DbPaths.gameInvites(gameId)}/$uid'] = null;
        updates['${DbPaths.userGameInvites(uid)}/$gameId'] =
            null; // redundant due to full user delete
      }
    }

    // 4) Remove joined games entry for this user and update game players lists
    final DataSnapshot joinedSnap =
        await root.child(DbPaths.userJoinedGames(uid)).get();
    if (joinedSnap.exists && joinedSnap.value is Map) {
      final Map data = joinedSnap.value as Map;
      for (final dynamic k in data.keys) {
        final String gameId = k.toString();
        try {
          final DataSnapshot playersSnap =
              await root.child(DbPaths.gamePlayers(gameId)).get();
          List<String> players = <String>[];
          bool originalWasString = false;
          if (playersSnap.exists) {
            final dynamic val = playersSnap.value;
            if (val is List) {
              players = val.map((e) => e.toString()).toList();
            } else if (val is String) {
              originalWasString = true;
              try {
                final decoded = jsonDecode(val);
                if (decoded is List) {
                  players = decoded.map((e) => e.toString()).toList();
                }
              } catch (_) {}
            }
          }
          if (players.contains(uid)) {
            players = players.where((p) => p != uid).toList();
            updates[DbPaths.gamePlayers(gameId)] =
                originalWasString ? jsonEncode(players) : players;
            updates['${DbPaths.game(gameId)}/currentPlayers'] = players.length;
          }
          updates['${DbPaths.userJoinedGames(uid)}/$gameId'] = null;
        } catch (e) {
          debugPrint('Failed to update players for game $gameId: $e');
        }
      }
    }

    // 5) Delete games organized by this user and clean participant references
    try {
      final Query myGamesQuery =
          root.child(DbPaths.games).orderByChild('organizerId').equalTo(uid);
      final DataSnapshot myGamesSnap = await myGamesQuery.get();
      if (myGamesSnap.exists && myGamesSnap.value is Map) {
        final Map gamesMap = myGamesSnap.value as Map;
        for (final dynamic gk in gamesMap.keys) {
          final String gameId = gk.toString();
          // Clean joinedGames of participants
          try {
            final DataSnapshot playersSnap =
                await root.child(DbPaths.gamePlayers(gameId)).get();
            List<String> players = <String>[];
            if (playersSnap.exists) {
              final dynamic val = playersSnap.value;
              if (val is List) {
                players = val.map((e) => e.toString()).toList();
              } else if (val is String) {
                try {
                  final decoded = jsonDecode(val);
                  if (decoded is List) {
                    players = decoded.map((e) => e.toString()).toList();
                  }
                } catch (_) {}
              }
            }
            for (final String pid in players) {
              updates['${DbPaths.userJoinedGames(pid)}/$gameId'] = null;
            }
          } catch (e) {
            debugPrint('Failed cleaning joinedGames for $gameId: $e');
          }

          // Clean invites mapping for this game across users
          try {
            final DataSnapshot invitesSnap =
                await root.child(DbPaths.gameInvites(gameId)).get();
            if (invitesSnap.exists && invitesSnap.value is Map) {
              final Map inv = invitesSnap.value as Map;
              for (final dynamic uk in inv.keys) {
                final String invitee = uk.toString();
                updates['${DbPaths.userGameInvites(invitee)}/$gameId'] = null;
              }
            }
          } catch (e) {
            debugPrint('Failed cleaning invites for $gameId: $e');
          }

          // Remove game node
          updates[DbPaths.game(gameId)] = null;
          // Also remove from my createdGames index (redundant when removing entire user)
          updates['${DbPaths.userCreatedGames(uid)}/$gameId'] = null;
        }
      }
    } catch (e) {
      debugPrint('Organizer games cleanup failed: $e');
    }

    // 6) Remove any friendTokens owned by this user
    try {
      final Query myTokensQuery = root
          .child(DbPaths.friendTokens)
          .orderByChild('ownerUid')
          .equalTo(uid);
      final DataSnapshot tokensSnap = await myTokensQuery.get();
      if (tokensSnap.exists && tokensSnap.value is Map) {
        final Map tokens = tokensSnap.value as Map;
        for (final dynamic tk in tokens.keys) {
          final String tokenId = tk.toString();
          updates['${DbPaths.friendTokens}/$tokenId'] = null;
        }
      }
    } catch (e) {
      debugPrint('Friend token cleanup failed: $e');
    }

    // 7) Finally, remove the entire user subtree
    updates[DbPaths.user(uid)] = null;

    if (updates.isNotEmpty) {
      await root.update(updates);
    }

    // 8) Delete user profile image from Storage (best-effort)
    try {
      final Reference profileRef =
          FirebaseStorage.instance.ref().child('users/$uid/profile.jpg');
      await profileRef.delete();
    } catch (e) {
      // Ignore if file does not exist or deletion fails
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
      debugPrint('Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'invalid-email':
          throw Exception('auth_email_invalid');
        case 'user-not-found':
          throw Exception('user_not_found');
        case 'too-many-requests':
          throw Exception('too_many_requests');
        case 'quota-exceeded':
          throw Exception('quota_exceeded');
        default:
          throw Exception('Could not send reset email (${e.code})');
      }
    } catch (e) {
      debugPrint('General error sending reset email: $e');
      rethrow;
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
          FirebaseDatabase.instance.ref(DbPaths.userMetadata(uid));
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

      // Use verifyBeforeUpdateEmail to update email with verification
      await user.verifyBeforeUpdateEmail(newEmail);

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
