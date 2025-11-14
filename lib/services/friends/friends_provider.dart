// lib/providers/services/friends_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'friends_service_instance.dart';
import 'friends_service.dart';
import '../auth/auth_provider.dart';
import '../notifications/notification_provider.dart';
import 'package:move_young/providers/infrastructure/firebase_providers.dart';

// NotificationService provider will be added when needed
// final notificationServiceProvider = Provider<NotificationService>((ref) {
//   return NotificationService();
// });

// Use the centralized connectivity service provider

// Use the centralized cache service provider

// FriendsService provider with dependency injection
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

// Friends list provider (reactive)
final friendsListProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final friendsService = ref.watch(friendsServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return [];
  return await friendsService.getUserFriends(userId);
});

// Friend requests received provider (reactive)
final friendRequestsReceivedProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final friendsService = ref.watch(friendsServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return [];
  return await friendsService.getUserFriendRequestsReceived(userId);
});

// Friend requests sent provider (reactive)
final friendRequestsSentProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final friendsService = ref.watch(friendsServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return [];
  return await friendsService.getUserFriendRequestsSent(userId);
});

// Watch friends list provider (reactive stream)
final watchFriendsListProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
  final friendsService = ref.watch(friendsServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);
  return friendsService.watchUserFriends(userId);
});

// Watch friend requests received provider (reactive stream)
final watchFriendRequestsReceivedProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
  final friendsService = ref.watch(friendsServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);
  return friendsService.watchUserFriendRequestsReceived(userId);
});

// Watch friend requests sent provider (reactive stream)
final watchFriendRequestsSentProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
  final friendsService = ref.watch(friendsServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);
  return friendsService.watchUserFriendRequestsSent(userId);
});

// Helper class for friends actions
class FriendsActions {
  final IFriendsService _friendsService;

  FriendsActions(this._friendsService);

  Future<bool> sendFriendRequest(String toUid) =>
      _friendsService.sendFriendRequest(toUid);
  Future<bool> acceptFriendRequest(String fromUid) =>
      _friendsService.acceptFriendRequest(fromUid);
  Future<bool> declineFriendRequest(String fromUid) =>
      _friendsService.declineFriendRequest(fromUid);
  Future<bool> cancelFriendRequest(String toUid) =>
      _friendsService.cancelFriendRequest(toUid);
  Future<bool> removeFriend(String friendUid) =>
      _friendsService.removeFriend(friendUid);
  Future<bool> blockFriend(String friendUid) =>
      _friendsService.blockFriend(friendUid);
  Future<List<Map<String, String>>> searchUsersByEmail(String email) =>
      _friendsService.searchUsersByEmail(email);
  Future<List<Map<String, String>>> searchUsersByDisplayName(String name) =>
      _friendsService.searchUsersByDisplayName(name);
  Future<Map<String, String?>> fetchMinimalProfile(String uid) =>
      _friendsService.fetchMinimalProfile(uid);
  Future<void> ensureUserIndexes() => _friendsService.ensureUserIndexes();

  // Rate limiting methods
  Future<int> getRemainingRequests(String uid) =>
      _friendsService.getRemainingRequests(uid);
  Future<Duration> getRemainingCooldown(String uid) =>
      _friendsService.getRemainingCooldown(uid);
  Future<bool> canSendFriendRequest(String uid) =>
      _friendsService.canSendFriendRequest(uid);
  Future<List<Map<String, String>>> getSuggestedFriends() =>
      _friendsService.getSuggestedFriends();
  Future<int> fetchMutualFriendsCount(String uid) =>
      _friendsService.fetchMutualFriendsCount(uid);
  Stream<void> watchFriendRequestReceived(String uid) =>
      _friendsService.watchFriendRequestReceived(uid);
}

// Friends actions provider (for friend operations)
final friendsActionsProvider = Provider<FriendsActions>((ref) {
  final friendsService = ref.watch(friendsServiceProvider);
  return FriendsActions(friendsService);
});
