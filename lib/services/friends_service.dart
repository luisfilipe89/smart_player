// lib/services/friends_service.dart
import 'dart:async';

import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert' show utf8;
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:move_young/services/notification_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:move_young/db/db_paths.dart';

class FriendsService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseDatabase get _db => FirebaseDatabase.instance;

  static DatabaseReference _userRef(String uid) => _db.ref(DbPaths.user(uid));

  // Centralized helper to log RTDB reads and surface the exact failing path
  static Future<DataSnapshot> _safeGet(String path) async {
    try {
      final snap = await _db.ref(path).get();
      debugPrint('🔍 READ OK: $path (exists: ${snap.exists})');
      return snap;
    } catch (e) {
      debugPrint('🔍 READ FAIL: $path -> $e');
      rethrow;
    }
  }

  // Ensure per-user indexes exist for discovery by contacts (email)
  static Future<void> ensureUserIndexes() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final String uid = user.uid;

    final Map<String, Object?> updates = {};

    // Index by lowercase email if present
    final String? email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      final String emailLower = email.toLowerCase();
      // Use hashed index to avoid invalid chars and storing raw email as key
      final String emailHash =
          crypto.sha256.convert(utf8.encode(emailLower)).toString();
      updates['usersByEmailHash/$emailHash'] = uid;
    }

    // Minimal public profile for list rendering
    final String displayName = (user.displayName?.trim().isNotEmpty == true)
        ? user.displayName!.trim()
        : _deriveNameFromEmail(user.email);
    updates['users/$uid/profile/displayName'] = displayName;
    if (user.photoURL != null && user.photoURL!.isNotEmpty) {
      updates['users/$uid/profile/photoURL'] = user.photoURL;
    }

    // Index by lowercase display name for prefix search
    final String displayNameLower = displayName.toLowerCase();
    if (displayNameLower.isNotEmpty) {
      updates['usersByDisplayNameLower/$displayNameLower/$uid'] = true;
    }

    if (updates.isEmpty) return;
    try {
      await _db.ref().update(updates);
    } catch (_) {
      // Swallow permission errors so UI doesn't break on best-effort indexing
    }
  }

  static String _deriveNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'User';
    final String prefix = email.split('@').first;
    final String cleaned = prefix.replaceAll(RegExp(r"[^A-Za-z]"), '');
    if (cleaned.isEmpty) return prefix;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  // Streams
  static Stream<List<String>> friendsStream(String uid) {
    return _userRef(uid).child('friends').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        return data.keys.cast<String>().toList()..sort();
      }
      return <String>[];
    });
  }

  static Stream<List<String>> receivedRequestsStream(String uid) {
    return _userRef(uid).child('friendRequests/received').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        return data.keys.cast<String>().toList()..sort();
      }
      return <String>[];
    });
  }

  static Stream<List<String>> sentRequestsStream(String uid) {
    return _userRef(uid).child('friendRequests/sent').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        return data.keys.cast<String>().toList()..sort();
      }
      return <String>[];
    });
  }

  // Actions
  static Future<bool> sendFriendRequestToUid(String toUid) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final String fromUid = user.uid;
    if (fromUid == toUid) return false;

    debugPrint(
        '🔍 Skipping allowRequests check - assuming friend requests are allowed');
    // Skip the allowRequests check for now to avoid permission issues

    debugPrint('🔍 Checking if can send request...');
    // De-duplicate and blocklist checks
    try {
      if (!await _canSendRequest(fromUid: fromUid, toUid: toUid)) {
        debugPrint('🔍 Cannot send request (duplicate/existing)');
        return false;
      }
    } catch (e) {
      debugPrint('🔍 Error checking canSendRequest: $e');
      return false;
    }

    debugPrint('🔍 Checking if blocked...');
    try {
      if (await isBlockedBetween(fromUid, toUid)) {
        debugPrint('🔍 Users are blocked');
        return false;
      }
    } catch (e) {
      debugPrint('🔍 Error checking blocked status: $e');
      return false;
    }

    debugPrint('🔍 Checking rate limit...');
    // Rate-limit: max 10/hour per user (client-side)
    try {
      final allowed = await _checkAndBumpRateLimit(fromUid);
      if (!allowed) {
        debugPrint('🔍 Rate limit exceeded');
        return false;
      }
    } catch (e) {
      debugPrint('🔍 Error checking rate limit: $e');
      return false;
    }

    debugPrint('🔍 Creating friend request updates...');
    final Map<String, Object?> updates = {
      'users/$fromUid/friendRequests/sent/$toUid': true,
      'users/$toUid/friendRequests/received/$fromUid': true,
    };

    try {
      await _db.ref().update(updates);

      // Write notification data for friend request
      try {
        await NotificationService.writeNotificationData(
          recipientUid: toUid,
          type: 'friend_request',
          data: {
            'fromUid': fromUid,
            'fromName': 'Unknown', // You might want to get the actual name
            'message': 'sent you a friend request',
          },
        );
      } catch (e) {
        debugPrint('🔍 Error writing notification data: $e');
        // Don't fail the friend request if notification writing fails
      }

      debugPrint('🔍 Friend request created successfully');
      return true;
    } catch (e) {
      debugPrint('🔍 Error creating friend request: $e');
      // Provide more specific error feedback
      if (e.toString().contains('permission-denied')) {
        debugPrint('🔍 Permission denied - database rules may need updating');
      }
      return false;
    }
  }

  static Future<bool> _canSendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    try {
      // Only check the sender's side to avoid permission issues
      final paths = [
        'users/$fromUid/friends/$toUid',
        'users/$fromUid/friendRequests/sent/$toUid',
      ];
      final snaps = await Future.wait(paths.map((p) => _safeGet(p)));
      // If any exists, block
      for (final s in snaps) {
        if (s.exists) return false;
      }
      return true;
    } catch (e) {
      debugPrint('🔍 Error in _canSendRequest: $e');
      // On permission error, allow the request to proceed
      return true;
    }
  }

  static const int _rateLimitWindowMs = 60 * 60 * 1000; // 1 hour
  static const int _rateLimitMaxRequests = 10;

  static Future<bool> _checkAndBumpRateLimit(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'friends_req_times_$uid';
      final now = DateTime.now().millisecondsSinceEpoch;
      final List<String> raw = prefs.getStringList(key) ?? <String>[];
      final List<int> times =
          raw.map((e) => int.tryParse(e) ?? 0).where((t) => t > 0).toList();
      // purge old
      final cutoff = now - _rateLimitWindowMs;
      final recent = times.where((t) => t >= cutoff).toList();
      if (recent.length >= _rateLimitMaxRequests) return false;
      recent.add(now);
      await prefs.setStringList(key, recent.map((e) => e.toString()).toList());
      return true;
    } catch (_) {
      // On prefs failure, allow rather than block
      return true;
    }
  }

  static Future<bool> acceptFriendRequest(String fromUid) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final String myUid = user.uid;
    debugPrint('🔍 acceptFriendRequest: start, myUid=$myUid fromUid=$fromUid');
    bool wroteMine = false;
    bool wroteOther = false;

    // Step 1: create friendship edges (each write wrapped for rule safety)
    try {
      await _db.ref('users/$myUid/friends/$fromUid').set(true);
      wroteMine = true;
      debugPrint('🔍 acceptFriendRequest: wrote users/$myUid/friends/$fromUid');
    } catch (e) {
      debugPrint('🔍 acceptFriendRequest: write my friends edge failed: $e');
    }
    try {
      await _db.ref('users/$fromUid/friends/$myUid').set(true);
      wroteOther = true;
      debugPrint('🔍 acceptFriendRequest: wrote users/$fromUid/friends/$myUid');
    } catch (e) {
      debugPrint('🔍 acceptFriendRequest: write other friends edge failed: $e');
    }

    final bool ok = wroteMine && wroteOther;
    debugPrint('🔍 acceptFriendRequest: edges result ok=$ok');

    // Step 2: best-effort cleanup of request entries; ignore permission errors
    try {
      await _db.ref('users/$myUid/friendRequests/received/$fromUid').remove();
      debugPrint('🔍 acceptFriendRequest: removed my received');
    } catch (e) {
      debugPrint('🔍 acceptFriendRequest: could not remove my received: $e');
    }
    try {
      await _db.ref('users/$fromUid/friendRequests/sent/$myUid').remove();
      debugPrint('🔍 acceptFriendRequest: removed sender sent');
    } catch (e) {
      debugPrint('🔍 acceptFriendRequest: could not remove sender sent: $e');
    }

    // Write notification data for friend request acceptance
    if (ok) {
      try {
        await NotificationService.writeNotificationData(
          recipientUid: fromUid,
          type: 'friend_request_accepted',
          data: {
            'fromUid': myUid,
            'fromName': 'Unknown', // You might want to get the actual name
            'message': 'accepted your friend request',
          },
        );
      } catch (e) {
        debugPrint('🔍 Error writing notification data: $e');
        // Don't fail the friend acceptance if notification writing fails
      }
    }

    debugPrint('🔍 acceptFriendRequest: end return=$ok');
    return ok;
  }

  static Future<bool> declineFriendRequest(String fromUid) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final String myUid = user.uid;
    bool removedLocal = false;
    // Always remove my own received request (permitted by rules)
    try {
      await _db.ref('users/$myUid/friendRequests/received/$fromUid').remove();
      removedLocal = true;
    } catch (e) {
      debugPrint(
          '🔍 declineFriendRequest: failed to remove local received: $e');
    }

    // Best-effort: attempt to clean the sender's sent entry; ignore if denied
    try {
      await _db.ref('users/$fromUid/friendRequests/sent/$myUid').remove();
    } catch (e) {
      debugPrint('🔍 declineFriendRequest: ignore cleanup of sender sent: $e');
    }

    return removedLocal;
  }

  static Future<bool> cancelSentFriendRequest(String toUid) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final String myUid = user.uid;

    bool ok = true;
    try {
      await _db.ref('users/$myUid/friendRequests/sent/$toUid').remove();
    } catch (_) {
      ok = false;
    }
    // Best-effort mirror cleanup; ignore permission failures
    try {
      await _db.ref('users/$toUid/friendRequests/received/$myUid').remove();
    } catch (_) {}
    return ok;
  }

  // --- Privacy helpers ---
  static Future<String> _getVisibility(String uid) async {
    try {
      final DataSnapshot v =
          await _db.ref('users/$uid/settings/profile/visibility').get();
      final String vis = v.value?.toString() ?? 'public';
      if (vis != 'public' && vis != 'friends' && vis != 'private') {
        return 'public';
      }
      return vis;
    } catch (e) {
      // On permission errors, default to public so basic profile can render
      debugPrint('🔍 _getVisibility read failed for $uid: $e');
      return 'public';
    }
  }

  static Future<bool> _isProfileVisibleTo({
    required String viewerUid,
    required String targetUid,
    required String visibility,
  }) async {
    if (viewerUid == targetUid || visibility == 'public') return true;
    if (visibility == 'private') return false;
    // friends-only → check friendship (viewer-side only to avoid cross-user read)
    try {
      final DataSnapshot s =
          await _db.ref('users/$viewerUid/friends/$targetUid').get();
      return s.exists;
    } catch (e) {
      // On permission error, assume not visible to be safe
      debugPrint('🔍 _isProfileVisibleTo check failed: $e');
      return false;
    }
  }

  // Blocking
  static Future<void> blockUser(String otherUid) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final String myUid = user.uid;
    await _db.ref('users/$myUid/blocks/$otherUid').set(true);
    // Optional: clean up any pending requests between users
    final Map<String, Object?> updates = {
      'users/$myUid/friendRequests/sent/$otherUid': null,
      'users/$myUid/friendRequests/received/$otherUid': null,
      'users/$otherUid/friendRequests/sent/$myUid': null,
      'users/$otherUid/friendRequests/received/$myUid': null,
    };
    await _db.ref().update(updates);
  }

  static Future<void> unblockUser(String otherUid) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final String myUid = user.uid;
    await _db.ref('users/$myUid/blocks/$otherUid').remove();
  }

  static Stream<List<String>> blockedUsersStream(String uid) {
    return _db.ref('users/$uid/blocks').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is Map) return data.keys.cast<String>().toList()..sort();
      return <String>[];
    });
  }

  // User privacy settings
  static Future<void> setAllowRequests(bool allow) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.ref('users/$uid/settings/allowRequests').set(allow);
  }

  static Stream<bool> allowRequestsStream(String uid) {
    return _db
        .ref('users/$uid/settings/allowRequests')
        .onValue
        .map((e) => e.snapshot.value != false);
  }

  // Report user audit trail
  static Future<void> reportUser({
    required String targetUid,
    required String reason,
  }) async {
    final reporter = _auth.currentUser?.uid;
    if (reporter == null || reporter == targetUid) return;
    final id = const Uuid().v4();
    await _db.ref('reports/$id').set({
      'reporter': reporter,
      'target': targetUid,
      'reason': reason,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<bool> isBlockedBetween(String a, String b) async {
    try {
      // Only check the current user's blocks to avoid permission issues
      final user = _auth.currentUser;
      if (user == null) return false;

      final snap = await _safeGet('users/${user.uid}/blocks/$b');
      return snap.exists;
    } catch (e) {
      debugPrint('🔍 Error in isBlockedBetween: $e');
      // On permission error, assume not blocked
      return false;
    }
  }

  static Future<bool> removeFriend(String friendUid) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final String myUid = user.uid;
    final Map<String, Object?> updates = {
      'users/$myUid/friends/$friendUid': null,
      'users/$friendUid/friends/$myUid': null,
    };
    await _db.ref().update(updates);
    return true;
  }

  static Future<String?> searchUidByEmail(String email) async {
    final String emailLower = email.trim().toLowerCase();
    if (emailLower.isEmpty) return null;
    final String emailHash =
        crypto.sha256.convert(utf8.encode(emailLower)).toString();
    final DataSnapshot snap =
        await _db.ref('usersByEmailHash/$emailHash').get();
    if (!snap.exists) return null;
    final String targetUid = snap.value?.toString() ?? '';
    if (targetUid.isEmpty) return null;
    // Enforce privacy for private profiles in search (hide from others)
    final String? viewer = _auth.currentUser?.uid;
    final String visibility = await _getVisibility(targetUid);
    if (visibility == 'private' && viewer != targetUid) {
      return null;
    }
    return targetUid;
  }

  // Search users by username or email
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final String searchQuery = query.trim().toLowerCase();
    if (searchQuery.isEmpty) return [];

    final List<Map<String, dynamic>> results = [];
    final String? currentUid = _auth.currentUser?.uid;

    try {
      // Search by email first
      if (searchQuery.contains('@')) {
        final String? targetUid = await searchUidByEmail(searchQuery);
        if (targetUid != null && targetUid != currentUid) {
          final userData = await _getUserProfile(targetUid);
          if (userData != null) {
            results.add(userData);
          }
        }
      } else {
        // Name prefix search disabled due to RTDB permission constraints
        return results;
      }
    } catch (e) {
      // Return empty list on error
      return [];
    }

    return results;
  }

  // Helper method to get user profile data
  static Future<Map<String, dynamic>?> _getUserProfile(String uid) async {
    try {
      // Read only the minimal profile subtree to comply with rules
      final DataSnapshot profileSnap =
          await _db.ref('users/$uid/profile').get();
      if (!profileSnap.exists || profileSnap.value is! Map) return null;

      final Map<dynamic, dynamic> profile =
          profileSnap.value as Map<dynamic, dynamic>;

      return {
        'uid': uid,
        'displayName': profile['displayName'] ?? 'Unknown User',
        // Email is stored at the user root which is not readable; omit here
        'email': '',
        'photoURL': profile['photoURL'],
      };
    } catch (e) {
      return null;
    }
  }

  // Get suggested friends based on mutual friends and same games
  static Future<List<Map<String, dynamic>>> getSuggestedFriends(
      String uid) async {
    final List<Map<String, dynamic>> suggestions = [];
    final Set<String> suggestedUids = <String>{};

    try {
      // Get current user's friends
      final friends = await _getUserFriends(uid);
      final friendsSet = friends.toSet();

      // Get mutual friends suggestions
      final mutualSuggestions =
          await _getMutualFriendsSuggestions(uid, friendsSet);
      for (final suggestion in mutualSuggestions) {
        if (!suggestedUids.contains(suggestion['uid'])) {
          suggestions.add(suggestion);
          suggestedUids.add(suggestion['uid']);
        }
      }

      // Get same games suggestions
      final sameGamesSuggestions =
          await _getSameGamesSuggestions(uid, friendsSet);
      for (final suggestion in sameGamesSuggestions) {
        if (!suggestedUids.contains(suggestion['uid'])) {
          suggestions.add(suggestion);
          suggestedUids.add(suggestion['uid']);
        }
      }

      // Limit to 10 suggestions and shuffle
      suggestions.shuffle();
      return suggestions.take(10).toList();
    } catch (e) {
      return [];
    }
  }

  // Get mutual friends suggestions
  static Future<List<Map<String, dynamic>>> _getMutualFriendsSuggestions(
      String uid, Set<String> friendsSet) async {
    final List<Map<String, dynamic>> suggestions = [];

    try {
      // Get friends of friends
      for (final friendUid in friendsSet) {
        final friendFriends = await _getUserFriends(friendUid);

        for (final friendOfFriend in friendFriends) {
          // Skip if already friends or is self
          if (friendOfFriend == uid || friendsSet.contains(friendOfFriend)) {
            continue;
          }

          // Check if profile is not private
          final visibility = await _getVisibility(friendOfFriend);
          if (visibility == 'private') continue;

          // Get user profile
          final userProfile = await _getUserProfile(friendOfFriend);
          if (userProfile != null) {
            suggestions.add({
              ...userProfile,
              'reason': 'friends_mutual_friends'.tr(),
            });
          }
        }
      }
    } catch (e) {
      // Return empty list on error
    }

    return suggestions;
  }

  // Get same games suggestions
  static Future<List<Map<String, dynamic>>> _getSameGamesSuggestions(
      String uid, Set<String> friendsSet) async {
    final List<Map<String, dynamic>> suggestions = [];

    try {
      // Get user's games
      final userGames = await _getUserGames(uid);

      // Find other users who played in the same games
      for (final gameId in userGames) {
        final gamePlayers = await _getGamePlayers(gameId);

        for (final playerUid in gamePlayers) {
          // Skip if already friends or is self
          if (playerUid == uid || friendsSet.contains(playerUid)) {
            continue;
          }

          // Check if profile is not private
          final visibility = await _getVisibility(playerUid);
          if (visibility == 'private') continue;

          // Get user profile
          final userProfile = await _getUserProfile(playerUid);
          if (userProfile != null) {
            suggestions.add({
              ...userProfile,
              'reason': 'friends_same_games'.tr(),
            });
          }
        }
      }
    } catch (e) {
      // Return empty list on error
    }

    return suggestions;
  }

  // Helper method to get user's friends
  static Future<List<String>> _getUserFriends(String uid) async {
    try {
      final DataSnapshot friendsSnapshot =
          await _db.ref('users/$uid/friends').get();
      if (!friendsSnapshot.exists) return [];

      final Map<dynamic, dynamic> friends =
          friendsSnapshot.value as Map<dynamic, dynamic>;
      return friends.keys.cast<String>().toList();
    } catch (e) {
      return [];
    }
  }

  // Helper method to get user's games
  static Future<List<String>> _getUserGames(String uid) async {
    try {
      final DataSnapshot gamesSnapshot =
          await _db.ref('users/$uid/games').get();
      if (!gamesSnapshot.exists) return [];

      final Map<dynamic, dynamic> games =
          gamesSnapshot.value as Map<dynamic, dynamic>;
      return games.keys.cast<String>().toList();
    } catch (e) {
      return [];
    }
  }

  // Helper method to get game players
  static Future<List<String>> _getGamePlayers(String gameId) async {
    try {
      final DataSnapshot playersSnapshot =
          await _db.ref('games/$gameId/players').get();
      if (!playersSnapshot.exists) return [];

      final Map<dynamic, dynamic> players =
          playersSnapshot.value as Map<dynamic, dynamic>;
      return players.keys.cast<String>().toList();
    } catch (e) {
      return [];
    }
  }

  // QR token flow
  static Future<String?> generateFriendToken({
    Duration ttl = const Duration(minutes: 10),
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final String token = const Uuid().v4();
    final int expMs = DateTime.now().add(ttl).millisecondsSinceEpoch;
    await _db.ref('friendTokens/$token').set({
      'ownerUid': user.uid,
      'exp': expMs,
    });
    return token;
  }

  static Future<bool> consumeFriendToken(String token) async {
    debugPrint('🔍 consumeFriendToken called with: $token');
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('🔍 No authenticated user');
      return false;
    }
    debugPrint('🔍 Current user: ${user.uid}');

    // Normalize token in case a full URL or text was scanned
    final String normalized = _normalizeToken(token);
    debugPrint('🔍 Normalized token: $normalized');

    if (normalized.isEmpty) {
      debugPrint('🔍 Token normalization resulted in empty string');
      return false;
    }

    try {
      final DatabaseReference tokenRef =
          _db.ref(DbPaths.friendToken(normalized));
      debugPrint('🔍 Attempting to read token: friendTokens/$normalized');
      final DataSnapshot snap = await _safeGet(DbPaths.friendToken(normalized));
      debugPrint('🔍 Token read successful, exists: ${snap.exists}');

      if (!snap.exists) {
        debugPrint('🔍 Token does not exist in database');
        return false;
      }

      final Map data = (snap.value as Map);
      final String ownerUid = data['ownerUid']?.toString() ?? '';
      final int exp = int.tryParse(data['exp']?.toString() ?? '') ?? 0;
      debugPrint('🔍 Token owner: $ownerUid, expires: $exp');

      if (ownerUid.isEmpty) {
        debugPrint('🔍 Empty owner UID');
        return false;
      }

      if (ownerUid == user.uid) {
        debugPrint('🔍 Cannot add yourself as friend');
        return false;
      }

      if (DateTime.now().millisecondsSinceEpoch > exp) {
        // Expired token
        await tokenRef.remove();
        debugPrint('🔍 Token expired');
        return false;
      }

      // Direct writes with per-path logging to see which rule fails
      debugPrint('🔍 Sending friend request to: $ownerUid');
      bool ok = false;
      final String fromUid = user.uid;

      // First, write sender's "sent" edge (should be allowed for self)
      final String sentPath =
          '${DbPaths.userFriendRequestsSent(fromUid)}/$ownerUid';
      try {
        debugPrint('🔍 WRITE TRY: $sentPath = true');
        await _db.ref(sentPath).set(true);
        debugPrint('🔍 WRITE OK: $sentPath');
      } catch (e) {
        debugPrint('🔍 WRITE FAIL: $sentPath -> $e');
        return false;
      }

      // Then, write receiver's "received" edge (should be allowed for sender)
      final String recvPath =
          '${DbPaths.userFriendRequestsReceived(ownerUid)}/$fromUid';
      try {
        debugPrint('🔍 WRITE TRY: $recvPath = true');
        await _db.ref(recvPath).set(true);
        debugPrint('🔍 WRITE OK: $recvPath');
        ok = true;
      } catch (e) {
        debugPrint('🔍 WRITE FAIL: $recvPath -> $e');
        ok = false;
      }

      if (ok) {
        // Only the owner is allowed to modify/delete the token per rules.
        if (user.uid == ownerUid) {
          await tokenRef.remove();
          debugPrint('🔍 Token removed by owner');
        } else {
          debugPrint('🔍 Skipping token removal (not owner)');
        }
      }

      return ok;
    } catch (e) {
      debugPrint('🔍 Error in consumeFriendToken: $e');
      return false;
    }
  }

  // Extract UUID token from arbitrary strings like
  // "moveyoung://friend?token=<uuid>" or plain <uuid>
  static String _normalizeToken(String raw) {
    final RegExp uuidPattern = RegExp(
      r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}",
    );
    final match = uuidPattern.firstMatch(raw);
    if (match != null) return match.group(0)!;
    // Try query param token=
    final uri = Uri.tryParse(raw);
    if (uri != null) {
      final t = uri.queryParameters['token'];
      if (t != null && t.isNotEmpty) {
        final m = uuidPattern.firstMatch(t);
        if (m != null) return m.group(0)!;
        return t;
      }
    }
    return raw.trim();
  }

  // Helpers to read minimal profile for a uid
  static Future<String> fetchDisplayName(String uid) async {
    final DataSnapshot snap =
        await _db.ref('users/$uid/profile/displayName').get();
    if (!snap.exists) return 'User';
    final String name = snap.value?.toString() ?? 'User';
    if (name.trim().isEmpty) return 'User';
    return name;
  }

  static Future<String?> fetchPhotoURL(String uid) async {
    final DataSnapshot snap =
        await _db.ref('users/$uid/profile/photoURL').get();
    if (!snap.exists) return null;
    final String url = snap.value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }

  static Future<Map<String, String?>> fetchMinimalProfile(String uid) async {
    // Enforce profile visibility
    final String viewer = _auth.currentUser?.uid ?? '';
    final String visibility = await _getVisibility(uid);
    final bool allowed = await _isProfileVisibleTo(
        viewerUid: viewer, targetUid: uid, visibility: visibility);

    if (!allowed) {
      return {'displayName': 'User', 'photoURL': null};
    }

    final DataSnapshot snap = await _db.ref('users/$uid/profile').get();
    if (!snap.exists || snap.value is! Map) {
      return {'displayName': 'User', 'photoURL': null};
    }
    final Map data = snap.value as Map;
    final String name = (data['displayName']?.toString() ?? '').trim();
    final String url = (data['photoURL']?.toString() ?? '').trim();
    return {
      'displayName': name.isEmpty ? 'User' : name,
      'photoURL': url.isEmpty ? null : url,
    };
  }

  // Batch fetch minimal profiles for a list of uids
  static Future<Map<String, Map<String, String?>>> fetchMinimalProfiles(
      List<String> uids) async {
    final Map<String, Map<String, String?>> result = {};
    if (uids.isEmpty) return result;

    // Fetch all profiles concurrently
    final List<Future<void>> tasks = [];
    for (final uid in uids.toSet()) {
      tasks.add(() async {
        final Map<String, String?> data = await fetchMinimalProfile(uid);
        result[uid] = data;
      }());
    }
    await Future.wait(tasks);
    return result;
  }

  // Batch compute mutual friends counts for a list of other user uids
  static Future<Map<String, int>> fetchMutualFriendsCounts(
      List<String> otherUids) async {
    // Disabled: requires cross-user friends list reads; return empty map
    return {};
  }

  // Mutual friends count between current user and other user
  static Future<int> fetchMutualFriendsCount(String otherUid) async {
    // Disabled: cross-user collection read; return 0
    return 0;
  }
}
