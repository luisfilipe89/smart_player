import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/friends/services/friends_service_instance.dart';
import 'package:move_young/features/friends/services/friends_service.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/services/notifications/notification_provider.dart';
import 'package:move_young/providers/infrastructure/firebase_providers.dart';
import 'package:move_young/services/system/sync_provider.dart';
import 'package:move_young/utils/logger.dart';
import 'package:move_young/services/firebase_error_handler.dart';

/// Provider for IFriendsService with dependency injection.
///
/// Provides access to the friends service that handles friend relationships,
/// friend requests, and user search functionality.
final friendsServiceProvider = Provider<IFriendsService>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final firebaseDatabase = ref.watch(firebaseDatabaseProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return FriendsServiceInstance(
    firebaseAuth,
    firebaseDatabase,
    notificationService,
  );
});

/// Reactive stream provider for the current user's friends list.
///
/// Returns a list of friend user IDs. Automatically updates when friendships
/// are added or removed. Returns an empty list if the user is not authenticated.
final watchFriendsListProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
  final friendsService = ref.watch(friendsServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);
  return friendsService.watchUserFriends(userId);
});

/// Reactive stream provider for friend requests received by the current user.
///
/// Returns a list of user IDs who have sent friend requests.
/// Automatically updates when requests are received, accepted, or declined.
/// Returns an empty list if the user is not authenticated.
final watchFriendRequestsReceivedProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
  final friendsService = ref.watch(friendsServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);
  return friendsService.watchUserFriendRequestsReceived(userId);
});

/// Reactive stream provider for friend requests sent by the current user.
///
/// Returns a list of user IDs to whom friend requests have been sent.
/// Automatically updates when requests are sent, accepted, or cancelled.
/// Returns an empty list if the user is not authenticated.
final watchFriendRequestsSentProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
  final friendsService = ref.watch(friendsServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);
  return friendsService.watchUserFriendRequestsSent(userId);
});

/// Helper class that provides action-based methods for friend operations.
///
/// Handles network errors by automatically adding operations to the sync queue
/// for retry when network connectivity is restored. Friend accept operations
/// are given high priority since they affect both users.
class FriendsActions {
  final IFriendsService _friendsService;
  final SyncActions? _syncActions;

  FriendsActions(this._friendsService, this._syncActions);

  /// Sends a friend request to another user.
  ///
  /// Returns `true` if the request was sent successfully.
  /// If a network error occurs, the operation is automatically added to
  /// the sync queue for retry when connectivity is restored.
  Future<bool> sendFriendRequest(String toUid) async {
    try {
      return await _friendsService.sendFriendRequest(toUid);
    } catch (e) {
      // Check if it's a network error
      if (FirebaseErrorHandler.isNetworkError(e) ||
          FirebaseErrorHandler.isUnavailableError(e)) {
        // Add to sync queue for retry when network is available
        NumberedLogger.w(
            'Network error sending friend request, adding to sync queue: $e');
        await _syncActions?.addSyncOperation(
          type: 'friend_request',
          data: {'toUid': toUid},
          operation: () async {
            return await _friendsService.sendFriendRequest(toUid);
          },
          itemId: toUid,
          priority: SyncServiceInstance.priorityNormal,
        );
      }
      rethrow; // Re-throw so UI can show error
    }
  }

  /// Accepts a friend request from another user.
  ///
  /// Returns `true` if the request was accepted successfully.
  /// If a network error occurs, the operation is automatically added to
  /// the sync queue with high priority for retry when connectivity is restored.
  Future<bool> acceptFriendRequest(String fromUid) async {
    try {
      return await _friendsService.acceptFriendRequest(fromUid);
    } catch (e) {
      // Check if it's a network error
      if (FirebaseErrorHandler.isNetworkError(e) ||
          FirebaseErrorHandler.isUnavailableError(e)) {
        // Add to sync queue for retry when network is available
        // Friend accept is high priority since it affects both users
        NumberedLogger.w(
            'Network error accepting friend request, adding to sync queue: $e');
        await _syncActions?.addSyncOperation(
          type: 'friend_accept',
          data: {'fromUid': fromUid},
          operation: () async {
            return await _friendsService.acceptFriendRequest(fromUid);
          },
          itemId: fromUid,
          priority: SyncServiceInstance.priorityHigh,
        );
      }
      rethrow; // Re-throw so UI can show error
    }
  }
  /// Declines a friend request from another user.
  Future<bool> declineFriendRequest(String fromUid) =>
      _friendsService.declineFriendRequest(fromUid);

  /// Cancels a friend request that was previously sent.
  Future<bool> cancelFriendRequest(String toUid) =>
      _friendsService.cancelFriendRequest(toUid);

  /// Removes a friend from the friends list.
  Future<bool> removeFriend(String friendUid) =>
      _friendsService.removeFriend(friendUid);

  /// Blocks a user, preventing them from sending friend requests.
  Future<bool> blockFriend(String friendUid) =>
      _friendsService.blockFriend(friendUid);

  /// Searches for users by email address.
  ///
  /// Returns a list of maps containing user information (uid, displayName, email).
  Future<List<Map<String, String>>> searchUsersByEmail(String email) =>
      _friendsService.searchUsersByEmail(email);

  /// Searches for users by display name.
  ///
  /// Returns a list of maps containing user information (uid, displayName, email).
  Future<List<Map<String, String>>> searchUsersByDisplayName(String name) =>
      _friendsService.searchUsersByDisplayName(name);

  /// Fetches minimal profile information for a user.
  ///
  /// Returns a map with uid, displayName, and email (email may be null).
  Future<Map<String, String?>> fetchMinimalProfile(String uid) =>
      _friendsService.fetchMinimalProfile(uid);

  /// Ensures that user search indexes are properly set up in the database.
  Future<void> ensureUserIndexes() => _friendsService.ensureUserIndexes();

  /// Gets the remaining number of friend requests the user can send today.
  Future<int> getRemainingRequests(String uid) =>
      _friendsService.getRemainingRequests(uid);

  /// Gets the remaining cooldown duration before the user can send more requests.
  Future<Duration> getRemainingCooldown(String uid) =>
      _friendsService.getRemainingCooldown(uid);

  /// Checks if the user can send a friend request (not rate limited).
  Future<bool> canSendFriendRequest(String uid) =>
      _friendsService.canSendFriendRequest(uid);

  /// Gets a list of suggested friends based on mutual connections.
  ///
  /// Returns a list of maps containing user information (uid, displayName, email).
  Future<List<Map<String, String>>> getSuggestedFriends() =>
      _friendsService.getSuggestedFriends();

  /// Gets the count of mutual friends between the current user and another user.
  Future<int> fetchMutualFriendsCount(String uid) =>
      _friendsService.fetchMutualFriendsCount(uid);

  /// Watches for new friend requests from a specific user.
  ///
  /// Emits events when a friend request is received from the specified user.
  Stream<void> watchFriendRequestReceived(String uid) =>
      _friendsService.watchFriendRequestReceived(uid);
}

/// Provider for FriendsActions, a helper class for friend operations.
///
/// This provider wraps the friends service to provide a unified action-based
/// API with automatic sync queue handling for network operations.
final friendsActionsProvider = Provider<FriendsActions>((ref) {
  final friendsService = ref.watch(friendsServiceProvider);
  final syncActions = ref.watch(syncActionsProvider);
  return FriendsActions(friendsService, syncActions);
});
