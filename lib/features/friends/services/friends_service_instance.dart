import 'dart:async';
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert' show utf8;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:move_young/utils/logger.dart';
import 'package:move_young/db/db_paths.dart';
import 'package:move_young/models/infrastructure/cached_data.dart';
// Cache TTL can be added later if needed
import 'package:move_young/services/firebase_error_handler.dart';
import 'package:move_young/services/error_handler/service_error_handler_mixin.dart';
import 'package:move_young/services/notifications/notification_interface.dart';
import 'package:move_young/features/friends/services/friends_service.dart';
import 'package:move_young/models/infrastructure/service_error.dart';

class _ProfileAccess {
  final bool allowed;
  final String visibility;
  const _ProfileAccess({required this.allowed, required this.visibility});
}

/// Instance-based FriendsService for use with Riverpod dependency injection
/// Uses standardized error handling mixin for consistent error handling patterns
class FriendsServiceInstance with ServiceErrorHandlerMixin implements IFriendsService {
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

  static const _visibilityPublic = 'public';

  Future<DataSnapshot> _safeGet(String path) async {
    try {
      final snap = await _db.ref(path).get();
      NumberedLogger.d('🔍 READ OK: $path (exists: ${snap.exists})');
      return snap;
    } catch (e) {
      NumberedLogger.w('🔍 READ FAIL: $path -> $e');
      if (FirebaseErrorHandler.requiresAuthRefresh(e)) {
        NumberedLogger.w('🔍 Auth refresh required for: $path');
      }
      rethrow;
    }
  }

  Future<_ProfileAccess> _profileAccessFor(String targetUid) async {
    return const _ProfileAccess(
      allowed: true,
      visibility: _visibilityPublic,
    );
  }

  // Ensure per-user indexes exist for discovery by contacts (email)
  @override
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
    updates[DbPaths.userProfileDisplayName(uid)] = displayName;
    if (user.photoURL != null && user.photoURL!.isNotEmpty) {
      updates[DbPaths.userProfilePhotoUrl(uid)] = user.photoURL;
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
        NumberedLogger.w(
            '🔍 Permission denied for user indexing - this is expected for some users');
      }
      // Swallow permission errors so UI doesn't break on best-effort indexing
    }
  }

  String _deriveNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'User';
    final emailParts = email.split('@');
    if (emailParts.isEmpty) return 'User';
    final String prefix = emailParts[0];
    final String cleaned = prefix.replaceAll(RegExp(r"[^A-Za-z]"), '');
    if (cleaned.isEmpty) return prefix;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  // Get user's friends list
  @override
  Future<List<String>> getUserFriends(String uid) async {
    final cacheKey = 'friends_$uid';

    // Check cache first
    if (_friendsCache.containsKey(cacheKey) &&
        !_friendsCache[cacheKey]!.isExpired) {
      return _friendsCache[cacheKey]!.data;
    }

    return handleListQueryError(
      () async {
      final snapshot = await _safeGet(DbPaths.userFriends(uid));
      if (snapshot.exists) {
        final friendsData = snapshot.value as Map<dynamic, dynamic>;
        final friends = friendsData.keys.map((key) => key.toString()).toList();

        // Cache the result
        _friendsCache[cacheKey] = CachedData(friends, DateTime.now());
        return friends;
      }
        return <String>[];
      },
      'getting friends for $uid',
    );
  }

  // Get user's friend requests (sent)
  @override
  Future<List<String>> getUserFriendRequestsSent(String uid) async {
    return handleListQueryError(
      () async {
      final snapshot = await _safeGet(DbPaths.userFriendRequestsSent(uid));
      if (snapshot.exists) {
        final requestsData = snapshot.value as Map<dynamic, dynamic>;
        return requestsData.keys.map((key) => key.toString()).toList();
      }
        return <String>[];
      },
      'getting sent friend requests for $uid',
    );
  }

  // Get user's friend requests (received)
  @override
  Future<List<String>> getUserFriendRequestsReceived(String uid) async {
    return handleListQueryError(
      () async {
      final snapshot = await _safeGet(DbPaths.userFriendRequestsReceived(uid));
      if (snapshot.exists) {
        final requestsData = snapshot.value as Map<dynamic, dynamic>;
        return requestsData.keys.map((key) => key.toString()).toList();
      }
        return <String>[];
      },
      'getting received friend requests for $uid',
    );
  }

  // Send friend request
  @override
  Future<bool> sendFriendRequest(String toUid) async {
    final fromUid = _auth.currentUser?.uid;
    if (fromUid == null) {
      throw const AuthException('User not authenticated');
    }

    return handleBooleanError(
      () async {
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
      },
      'sending friend request',
    );
  }

  // Accept friend request
  @override
  Future<bool> acceptFriendRequest(String fromUid) async {
    final toUid = _auth.currentUser?.uid;
    if (toUid == null) {
      throw const AuthException('User not authenticated');
    }

    return handleBooleanError(
      () async {
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
      await _notificationService.sendFriendAcceptedNotification(
        fromUid,
        toUid,
      );

      // Clear cache
      _friendsCache.remove('friends_$fromUid');
      _friendsCache.remove('friends_$toUid');

      return true;
      },
      'accepting friend request',
    );
  }

  // Decline friend request
  @override
  Future<bool> declineFriendRequest(String fromUid) async {
    final toUid = _auth.currentUser?.uid;
    if (toUid == null) {
      throw const AuthException('User not authenticated');
    }

    return handleBooleanError(
      () async {
      // Remove the received request (allowed for current user)
      await _db
          .ref(DbPaths.userFriendRequestsReceived(toUid))
          .child(fromUid)
          .remove();

      // Best-effort removal from sender's "sent" list (may fail due to rules)
        // Use handleVoidError for this nested operation since failure is acceptable
        await handleVoidError(
          () => _db
            .ref(DbPaths.userFriendRequestsSent(fromUid))
            .child(toUid)
              .remove(),
          'removing sent request entry for $fromUid -> $toUid',
        );

      // Clear cache
      _friendsCache.remove('friends_$fromUid');
      _friendsCache.remove('friends_$toUid');

      return true;
      },
      'declining friend request',
    );
  }

  @override
  Future<bool> cancelFriendRequest(String toUid) async {
    final fromUid = _auth.currentUser?.uid;
    if (fromUid == null) {
      throw const AuthException('User not authenticated');
    }

    return handleBooleanError(
      () async {
      await _db.ref().update({
        '${DbPaths.userFriendRequestsSent(fromUid)}/$toUid': null,
        '${DbPaths.userFriendRequestsReceived(toUid)}/$fromUid': null,
      });

      _friendsCache.remove('friends_$fromUid');
      _friendsCache.remove('friends_$toUid');

      return true;
      },
      'cancelling friend request',
    );
  }

  // Remove friend
  @override
  Future<bool> removeFriend(String friendUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      throw const AuthException('User not authenticated');
    }

    return handleBooleanError(
      () async {
      // Remove from friends list for both users
      await _db.ref().update({
        '${DbPaths.userFriends(currentUid)}/$friendUid': null,
        '${DbPaths.userFriends(friendUid)}/$currentUid': null,
      });

      // Notify the removed friend
      await _notificationService.sendFriendRemovedNotification(
        removedUserUid: friendUid,
        removerUid: currentUid,
      );

      // Clear cache
      _friendsCache.remove('friends_$currentUid');
      _friendsCache.remove('friends_$friendUid');

      return true;
      },
      'removing friend',
    );
  }

  // Block friend
  @override
  Future<bool> blockFriend(String friendUid) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) {
      throw const AuthException('User not authenticated');
    }

    return handleBooleanError(
      () async {
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
      },
      'blocking friend',
    );
  }

  // Search users by email
  @override
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
          return [
            {
              ...userProfile,
              'email': emailLower,
            }
          ];
        }
      }
      return [];
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        NumberedLogger.w(
            'Email search permission denied; returning fallback stub for $email');
        final fallbackUid = crypto.sha256
            .convert(utf8.encode('fallback_$email'))
            .toString();
        return [
          {
            'uid': fallbackUid,
            'displayName': '',
            'photoURL': '',
            'visibility': _visibilityPublic,
            'email': email.trim().toLowerCase(),
            'isFallback': 'true',
          }
        ];
      }
      NumberedLogger.e('Error searching users by email: $e');
      return [];
    } catch (e) {
      NumberedLogger.e('Error searching users by email: $e');
      return [];
    }
  }

  // Search users by display name
  @override
  Future<List<Map<String, String>>> searchUsersByDisplayName(
      String name) async {
    final nameLower = name.trim().toLowerCase();
    if (nameLower.isEmpty) return [];

    try {
      final query = _db
          .ref('usersByDisplayNameLower')
          .orderByKey()
          .startAt(nameLower)
          .endAt('$nameLower\uf8ff')
          .limitToFirst(20);

      final snapshot = await query.get();
      if (!snapshot.exists) {
        return [];
      }

      final rawData = snapshot.value;
      if (rawData is! Map) {
        return [];
      }

      final Set<String> collectedUids = {};
      final List<String> orderedUids = [];

      rawData.forEach((_, value) {
        if (value is Map) {
          value.forEach((uid, flag) {
            if (flag == true || flag == 1 || flag == 'true') {
              final uidString = uid.toString();
              if (collectedUids.add(uidString)) {
                orderedUids.add(uidString);
              }
            }
          });
        }
      });

      final profiles = await Future.wait(
        orderedUids.map((uid) => _getUserProfile(uid)),
      );

      return profiles.whereType<Map<String, String>>().toList();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        NumberedLogger.w(
            'Display name prefix search not permitted, falling back to exact match.');
        return _searchUsersByDisplayNameExact(nameLower);
      }
      NumberedLogger.e('Error searching users by display name: $e');
      return [];
    } catch (e) {
      NumberedLogger.e('Error searching users by display name: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> _searchUsersByDisplayNameExact(
      String nameLower) async {
    try {
      final snapshot =
          await _safeGet('usersByDisplayNameLower/$nameLower');

      if (!snapshot.exists) {
        return [];
      }

      final data = snapshot.value;
      if (data is! Map) {
        return [];
      }

      final List<Map<String, String>> results = [];
      for (final entry in data.entries) {
        final uid = entry.key?.toString();
        if (uid == null) continue;
        final profile = await _getUserProfile(uid);
        if (profile != null) {
          results.add(profile);
        }
      }
      return results;
    } catch (e) {
      NumberedLogger.e(
          'Fallback display name search failed for "$nameLower": $e');
      return [];
    }
  }

  // Get user profile
  Future<Map<String, String>?> _getUserProfile(String uid) async {
    try {
      final access = await _profileAccessFor(uid);

      final snapshot = await _safeGet('users/$uid/profile');
      if (snapshot.exists) {
        final profileData = snapshot.value as Map<dynamic, dynamic>;
        return {
          'uid': uid,
          'displayName': profileData['displayName']?.toString() ?? 'Unknown',
          'photoURL': profileData['photoURL']?.toString() ?? '',
          'visibility': access.visibility,
        };
      }
      return {
        'uid': uid,
        'displayName': '',
        'photoURL': '',
        'visibility': access.visibility,
      };
    } catch (e) {
      NumberedLogger.e('Error getting user profile for $uid: $e');
      return null;
    }
  }

  // Get minimal profile for a user
  @override
  Future<Map<String, String?>> fetchMinimalProfile(String uid) async {
    try {
      final access = await _profileAccessFor(uid);

      final snapshot = await _safeGet('users/$uid/profile');
      if (snapshot.exists) {
        final profileData = snapshot.value as Map<dynamic, dynamic>;
        return {
          'uid': uid,
          'displayName': profileData['displayName']?.toString(),
          'photoURL': profileData['photoURL']?.toString(),
          'visibility': access.visibility,
        };
      }
      return {
        'uid': uid,
        'displayName': null,
        'photoURL': null,
        'visibility': access.visibility,
      };
    } catch (e) {
      NumberedLogger.e('Error fetching minimal profile for $uid: $e');
      return {
        'uid': uid,
        'displayName': null,
        'photoURL': null,
        'visibility': _visibilityPublic,
        'visibilitySetting': _visibilityPublic,
      };
    }
  }

  // Watch friends list
  @override
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
  @override
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
  @override
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
  @override
  void clearCache() {
    _friendsCache.clear();
  }

  // Clear expired cache entries
  @override
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
  @override
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
  @override
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
  @override
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

  // Get suggested friends based on mutual friends
  @override
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
  @override
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
  @override
  Stream<void> watchFriendRequestReceived(String uid) {
    final receivedRef = _db.ref('users/$uid/friendRequests/received');
    return receivedRef.limitToLast(1).onChildAdded.map((_) {});
  }
}
