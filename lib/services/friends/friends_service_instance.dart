// lib/services/friends_service_instance.dart
import 'dart:async';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert' show utf8;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/foundation.dart' show debugPrint;
import 'package:move_young/utils/logger.dart';
import 'package:move_young/db/db_paths.dart';
import 'package:move_young/models/infrastructure/cached_data.dart';
import 'package:move_young/services/firebase_error_handler.dart';
import '../notifications/notification_interface.dart';
import '../../utils/service_error.dart';

/// Instance-based FriendsService for use with Riverpod dependency injection
class FriendsServiceInstance {
  final FirebaseAuth _auth;
  final FirebaseDatabase _db;
  final INotificationService _notificationService;

  // Cache for friends data
  final Map<String, CachedData<List<String>>> _friendsCache = {};

  FriendsServiceInstance(
    this._auth,
    this._db,
    this._notificationService,
  );

  // Centralized helper to log RTDB reads and surface the exact failing path
  Future<DataSnapshot> _safeGet(String path) async {
    try {
      final snap = await _db.ref(path).get();
      NumberedLogger.d('🔍 READ OK: $path (exists: ${snap.exists})');
      return snap;
    } catch (e) {
      NumberedLogger.w('🔍 READ FAIL: $path -> $e');
      if (FirebaseErrorHandler.requiresAuthRefresh(e)) {
        NumberedLogger.w('🔍 Auth refresh required for: $path');
        // Could trigger auth refresh here if needed
      }
      rethrow;
    }
  }

  // Ensure per-user indexes exist for discovery by contacts (email)
  Future<void> ensureUserIndexes() async {
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
    } catch (e) {
      NumberedLogger.w('🔍 Index update failed: $e');
      if (FirebaseErrorHandler.isPermissionDenied(e)) {
        NumberedLogger.w('🔍 Permission denied for user indexing - this is expected for some users');
      }
      // Swallow permission errors so UI doesn't break on best-effort indexing
    }
  }

  String _deriveNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'User';
    final String prefix = email.split('@').first;
    final String cleaned = prefix.replaceAll(RegExp(r"[^A-Za-z]"), '');
    if (cleaned.isEmpty) return prefix;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  // Get user's friends list
  Future<List<String>> getUserFriends(String uid) async {
    final cacheKey = 'friends_$uid';

    // Check cache first
    if (_friendsCache.containsKey(cacheKey) &&
        !_friendsCache[cacheKey]!.isExpired) {
      return _friendsCache[cacheKey]!.data;
    }

    try {
      final snapshot = await _safeGet(DbPaths.userFriends(uid));
      if (snapshot.exists) {
        final friendsData = snapshot.value as Map<dynamic, dynamic>;
        final friends = friendsData.keys.map((key) => key.toString()).toList();

        // Cache the result
        _friendsCache[cacheKey] = CachedData(friends, DateTime.now());
        return friends;
      }
      return [];
    } catch (e) {
      NumberedLogger.e('Error getting friends for $uid: $e');
      return [];
    }
  }

  // Get user's friend requests (sent)
  Future<List<String>> getUserFriendRequestsSent(String uid) async {
    try {
      final snapshot = await _safeGet(DbPaths.userFriendRequestsSent(uid));
      if (snapshot.exists) {
        final requestsData = snapshot.value as Map<dynamic, dynamic>;
        return requestsData.keys.map((key) => key.toString()).toList();
      }
      return [];
    } catch (e) {
      NumberedLogger.e('Error getting sent friend requests for $uid: $e');
      return [];
    }
  }

  // Get user's friend requests (received)
  Future<List<String>> getUserFriendRequestsReceived(String uid) async {
    try {
      final snapshot = await _safeGet(DbPaths.userFriendRequestsReceived(uid));
      if (snapshot.exists) {
        final requestsData = snapshot.value as Map<dynamic, dynamic>;
        return requestsData.keys.map((key) => key.toString()).toList();
      }
      return [];
    } catch (e) {
      NumberedLogger.e('Error getting received friend requests for $uid: $e');
      return [];
    }
  }

  // Send friend request
  Future<bool> sendFriendRequest(String toUid) async {
    try {
      final fromUid = _auth.currentUser?.uid;
      if (fromUid == null) return false;

      // Check if already friends
      final friends = await getUserFriends(fromUid);
      if (friends.contains(toUid)) return false;

      // Check if request already sent
      final sentRequests = await getUserFriendRequestsSent(fromUid);
      if (sentRequests.contains(toUid)) return false;

      // Send request
      await _db.ref().update({
        '${DbPaths.userFriendRequestsSent(fromUid)}/$toUid': true,
        '${DbPaths.userFriendRequestsReceived(toUid)}/$fromUid': true,
      });

      // Record the request for rate limiting
      await _recordFriendRequest(fromUid);

      // Send notification
      await _notificationService.sendFriendRequestNotification(toUid, fromUid);

      // Clear cache
      _friendsCache.remove('friends_$fromUid');
      _friendsCache.remove('friends_$toUid');

      return true;
    } catch (e) {
      NumberedLogger.e('Error sending friend request: $e');
      return false;
    }
  }

  // Accept friend request
  Future<bool> acceptFriendRequest(String fromUid) async {
    try {
      final toUid = _auth.currentUser?.uid;
      if (toUid == null) return false;

      // Add to friends list for both users
      await _db.ref().update({
        '${DbPaths.userFriends(fromUid)}/$toUid': true,
        '${DbPaths.userFriends(toUid)}/$fromUid': true,
      });

      // Remove from requests
      await _db.ref().update({
        '${DbPaths.userFriendRequestsSent(fromUid)}/$toUid': null,
        '${DbPaths.userFriendRequestsReceived(toUid)}/$fromUid': null,
      });

      // Send notification
      await _notificationService.sendFriendRequestNotification(fromUid, toUid);

      // Clear cache
      _friendsCache.remove('friends_$fromUid');
      _friendsCache.remove('friends_$toUid');

      return true;
    } catch (e) {
      NumberedLogger.e('Error accepting friend request: $e');
      return false;
    }
  }

  // Decline friend request
  Future<bool> declineFriendRequest(String fromUid) async {
    try {
      final toUid = _auth.currentUser?.uid;
      if (toUid == null) return false;

      // Remove from requests
      await _db.ref().update({
        '${DbPaths.userFriendRequestsSent(fromUid)}/$toUid': null,
        '${DbPaths.userFriendRequestsReceived(toUid)}/$fromUid': null,
      });

      // Clear cache
      _friendsCache.remove('friends_$fromUid');
      _friendsCache.remove('friends_$toUid');

      return true;
    } catch (e) {
      NumberedLogger.e('Error declining friend request: $e');
      return false;
    }
  }

  // Remove friend
  Future<bool> removeFriend(String friendUid) async {
    try {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid == null) return false;

      // Remove from friends list for both users
      await _db.ref().update({
        '${DbPaths.userFriends(currentUid)}/$friendUid': null,
        '${DbPaths.userFriends(friendUid)}/$currentUid': null,
      });

      // Clear cache
      _friendsCache.remove('friends_$currentUid');
      _friendsCache.remove('friends_$friendUid');

      return true;
    } catch (e) {
      NumberedLogger.e('Error removing friend: $e');
      return false;
    }
  }

  // Block friend
  Future<bool> blockFriend(String friendUid) async {
    try {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid == null) return false;

      // Add to blocked users list
      await _db.ref().update({
        'users/$currentUid/blockedUsers/$friendUid': true,
      });

      // Remove from friends list if already friends
      await _db.ref().update({
        '${DbPaths.userFriends(currentUid)}/$friendUid': null,
        '${DbPaths.userFriends(friendUid)}/$currentUid': null,
      });

      // Remove any pending friend requests
      await _db.ref().update({
        '${DbPaths.userFriendRequestsSent(currentUid)}/$friendUid': null,
        '${DbPaths.userFriendRequestsReceived(currentUid)}/$friendUid': null,
        '${DbPaths.userFriendRequestsSent(friendUid)}/$currentUid': null,
        '${DbPaths.userFriendRequestsReceived(friendUid)}/$currentUid': null,
      });

      // Clear cache
      _friendsCache.remove('friends_$currentUid');
      _friendsCache.remove('friends_$friendUid');

      return true;
    } catch (e) {
      NumberedLogger.e('Error blocking friend: $e');
      return false;
    }
  }

  // Search users by email
  Future<List<Map<String, String>>> searchUsersByEmail(String email) async {
    try {
      final emailLower = email.trim().toLowerCase();
      final emailHash =
          crypto.sha256.convert(utf8.encode(emailLower)).toString();

      final snapshot = await _safeGet('usersByEmailHash/$emailHash');
      if (snapshot.exists) {
        final uid = snapshot.value.toString();
        final userProfile = await _getUserProfile(uid);
        if (userProfile != null) {
          return [userProfile];
        }
      }
      return [];
    } catch (e) {
      NumberedLogger.e('Error searching users by email: $e');
      return [];
    }
  }

  // Search users by display name
  Future<List<Map<String, String>>> searchUsersByDisplayName(
      String name) async {
    try {
      final nameLower = name.trim().toLowerCase();
      final snapshot = await _safeGet('usersByDisplayNameLower/$nameLower');

      if (snapshot.exists) {
        final usersData = snapshot.value as Map<dynamic, dynamic>;
        final List<Map<String, String>> results = [];

        for (final uid in usersData.keys) {
          final userProfile = await _getUserProfile(uid.toString());
          if (userProfile != null) {
            results.add(userProfile);
          }
        }
        return results;
      }
      return [];
    } catch (e) {
      NumberedLogger.e('Error searching users by display name: $e');
      return [];
    }
  }

  // Get user profile
  Future<Map<String, String>?> _getUserProfile(String uid) async {
    try {
      final snapshot = await _safeGet('users/$uid/profile');
      if (snapshot.exists) {
        final profileData = snapshot.value as Map<dynamic, dynamic>;
        return {
          'uid': uid,
          'displayName': profileData['displayName']?.toString() ?? 'Unknown',
          'photoURL': profileData['photoURL']?.toString() ?? '',
        };
      }
      return null;
    } catch (e) {
      NumberedLogger.e('Error getting user profile for $uid: $e');
      return null;
    }
  }

  // Get minimal profile for a user
  Future<Map<String, String?>> fetchMinimalProfile(String uid) async {
    try {
      final snapshot = await _safeGet('users/$uid/profile');
      if (snapshot.exists) {
        final profileData = snapshot.value as Map<dynamic, dynamic>;
        return {
          'uid': uid,
          'displayName': profileData['displayName']?.toString(),
          'photoURL': profileData['photoURL']?.toString(),
        };
      }
      return {
        'uid': uid,
        'displayName': null,
        'photoURL': null,
      };
    } catch (e) {
      NumberedLogger.e('Error fetching minimal profile for $uid: $e');
      return {
        'uid': uid,
        'displayName': null,
        'photoURL': null,
      };
    }
  }

  // Watch friends list
  Stream<List<String>> watchUserFriends(String uid) {
    return _db.ref(DbPaths.userFriends(uid)).onValue.map((event) {
      if (event.snapshot.exists) {
        final friendsData = event.snapshot.value as Map<dynamic, dynamic>;
        return friendsData.keys.map((key) => key.toString()).toList();
      }
      return <String>[];
    });
  }

  // Watch friend requests received
  Stream<List<String>> watchUserFriendRequestsReceived(String uid) {
    return _db
        .ref(DbPaths.userFriendRequestsReceived(uid))
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        final requestsData = event.snapshot.value as Map<dynamic, dynamic>;
        return requestsData.keys.map((key) => key.toString()).toList();
      }
      return <String>[];
    });
  }

  // Watch friend requests sent
  Stream<List<String>> watchUserFriendRequestsSent(String uid) {
    return _db.ref(DbPaths.userFriendRequestsSent(uid)).onValue.map((event) {
      if (event.snapshot.exists) {
        final requestsData = event.snapshot.value as Map<dynamic, dynamic>;
        return requestsData.keys.map((key) => key.toString()).toList();
      }
      return <String>[];
    });
  }

  // Clear cache
  void clearCache() {
    _friendsCache.clear();
  }

  // Clear expired cache entries
  void clearExpiredCache() {
    _friendsCache.removeWhere((key, value) => value.isExpired);
  }

  // Safe DateTime parsing for rate limiting
  DateTime? _parseTimestamp(dynamic value) {
    try {
      if (value is String) {
        return DateTime.parse(value);
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return null;
    } catch (e) {
      NumberedLogger.w('Invalid timestamp format: $value');
      return null;
    }
  }

  // Rate limiting functionality
  static const int _maxRequestsPerHour = 10;
  static const Duration _rateLimitWindow = Duration(hours: 1);

  // Get remaining friend requests for a user
  Future<int> getRemainingRequests(String uid) async {
    try {
      final snapshot = await _safeGet('users/$uid/rateLimit');
      if (snapshot.exists) {
        final rateLimitData = snapshot.value as Map<dynamic, dynamic>;
        final requests = rateLimitData['requests'] as List<dynamic>? ?? [];
        final now = DateTime.now();

        // Filter requests within the last hour
        final recentRequests = requests.where((request) {
          final requestTime = _parseTimestamp(request['timestamp']);
          if (requestTime == null) return false;
          return now.difference(requestTime) < _rateLimitWindow;
        }).toList();

        return _maxRequestsPerHour - recentRequests.length;
      }
      return _maxRequestsPerHour;
    } catch (e) {
      NumberedLogger.e('Error getting remaining requests for $uid: $e');
      return _maxRequestsPerHour;
    }
  }

  // Get remaining cooldown time for a user
  Future<Duration> getRemainingCooldown(String uid) async {
    try {
      final snapshot = await _safeGet('users/$uid/rateLimit');
      if (snapshot.exists) {
        final rateLimitData = snapshot.value as Map<dynamic, dynamic>;
        final requests = rateLimitData['requests'] as List<dynamic>? ?? [];
        final now = DateTime.now();

        if (requests.isNotEmpty) {
          // Find the oldest request within the rate limit window
          final validTimestamps = requests
              .map((request) => _parseTimestamp(request['timestamp']))
              .where((timestamp) => timestamp != null)
              .cast<DateTime>();

          if (validTimestamps.isEmpty) return Duration.zero;

          final oldestRequest =
              validTimestamps.reduce((a, b) => a.isBefore(b) ? a : b);

          final timeUntilReset =
              oldestRequest.add(_rateLimitWindow).difference(now);
          return timeUntilReset.isNegative ? Duration.zero : timeUntilReset;
        }
      }
      return Duration.zero;
    } catch (e) {
      NumberedLogger.e('Error getting remaining cooldown for $uid: $e');
      return Duration.zero;
    }
  }

  // Check if user can send friend request
  Future<bool> canSendFriendRequest(String uid) async {
    final remaining = await getRemainingRequests(uid);
    return remaining > 0;
  }

  // Record a friend request for rate limiting
  Future<void> _recordFriendRequest(String uid) async {
    try {
      final now = DateTime.now();
      final requestData = {
        'timestamp': now.toIso8601String(),
      };

      await _db.ref().update({
        'users/$uid/rateLimit/requests/${now.millisecondsSinceEpoch}':
            requestData,
      });
    } catch (e) {
      NumberedLogger.e('Error recording friend request for $uid: $e');
    }
  }

  // Generate friend token for QR code
  Future<String> generateFriendToken() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('Not signed in');

    final uid = user.uid;
    final now = DateTime.now();
    final expiry =
        now.add(const Duration(minutes: 10)); // Token expires in 10 minutes

    final tokenData = {
      'uid': uid,
      'expiry': expiry.millisecondsSinceEpoch,
    };

    final token = crypto.sha256
        .convert(utf8.encode('$uid-${now.millisecondsSinceEpoch}'))
        .toString();

    // Store token in database
    await _db.ref('friendTokens/$token').set(tokenData);

    return token;
  }

  // Consume friend token from QR scan
  Future<bool> consumeFriendToken(String token) async {
    try {
      final snap = await _safeGet('friendTokens/$token');

      if (!snap.exists) {
        NumberedLogger.w('Friend token not found: $token');
        return false;
      }

      final data = snap.value as Map<dynamic, dynamic>;
      final expiry = DateTime.fromMillisecondsSinceEpoch(data['expiry'] as int);

      if (DateTime.now().isAfter(expiry)) {
        NumberedLogger.w('Friend token expired: $token');
        return false;
      }

      final fromUid = data['uid'] as String;
      final user = _auth.currentUser;

      if (user == null || user.uid == fromUid) {
        NumberedLogger.w('Cannot add self as friend');
        return false;
      }

      // Send friend request
      await sendFriendRequest(fromUid);

      // Clean up used token
      await _db.ref('friendTokens/$token').remove();

      return true;
    } catch (e) {
      NumberedLogger.e('Error consuming friend token: $e');
      return false;
    }
  }

  // Get suggested friends based on mutual friends
  Future<List<Map<String, String>>> getSuggestedFriends() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final uid = user.uid;

    try {
      // Get current friends
      final friends = await getUserFriends(uid);

      if (friends.isEmpty) return [];

      // Get friends of friends
      final suggestionsMap = <String, Set<String>>{};

      for (final friendUid in friends.take(5)) {
        // Limit to first 5 friends
        final friendFriends = await getUserFriends(friendUid);
        for (final potentialFriend in friendFriends) {
          if (potentialFriend != uid && !friends.contains(potentialFriend)) {
            suggestionsMap
                .putIfAbsent(potentialFriend, () => <String>{})
                .add(friendUid);
          }
        }
      }

      // Convert to list with mutual friends count
      final suggestions = suggestionsMap.entries.map((entry) {
        return {
          'uid': entry.key,
          'mutualCount': entry.value.length.toString(),
        };
      }).toList();

      // Sort by mutual friends count (descending)
      suggestions.sort((a, b) {
        final aCount = int.tryParse(a['mutualCount'] ?? '0') ?? 0;
        final bCount = int.tryParse(b['mutualCount'] ?? '0') ?? 0;
        return bCount.compareTo(aCount);
      });

      return suggestions.take(10).toList(); // Return top 10 suggestions
    } catch (e) {
      NumberedLogger.e('Error getting suggested friends: $e');
      return [];
    }
  }

  // Get mutual friends count with another user
  Future<int> fetchMutualFriendsCount(String uid) async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    final myUid = user.uid;

    try {
      final myFriends = await getUserFriends(myUid);
      final theirFriends = await getUserFriends(uid);

      // Count mutual friends
      final mutualCount =
          myFriends.where((friend) => theirFriends.contains(friend)).length;

      return mutualCount;
    } catch (e) {
      NumberedLogger.e('Error getting mutual friends count: $e');
      return 0;
    }
  }

  // Stream that emits when a new friend request is received
  Stream<void> watchFriendRequestReceived(String uid) {
    final receivedRef = _db.ref('users/$uid/friendRequests/received');
    return receivedRef.limitToLast(1).onChildAdded.map((_) {});
  }
}
