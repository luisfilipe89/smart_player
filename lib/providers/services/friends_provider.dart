// lib/providers/services/friends_provider.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/services/friends_service_instance.dart';
import 'package:move_young/services/connectivity_service.dart';
import 'package:move_young/services/cache_service.dart';
import 'package:move_young/providers/services/auth_provider.dart';
import 'package:move_young/providers/services/notification_provider.dart';

// Firebase Auth instance provider
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

// Firebase Database instance provider
final firebaseDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  return FirebaseDatabase.instance;
});

// NotificationService provider will be added when needed
// final notificationServiceProvider = Provider<NotificationService>((ref) {
//   return NotificationService();
// });

// ConnectivityService provider
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

// CacheService provider
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

// FriendsService provider with dependency injection
final friendsServiceProvider = Provider<FriendsServiceInstance>((ref) {
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
  final FriendsServiceInstance _friendsService;

  FriendsActions(this._friendsService);

  Future<bool> sendFriendRequest(String toUid) =>
      _friendsService.sendFriendRequest(toUid);
  Future<bool> acceptFriendRequest(String fromUid) =>
      _friendsService.acceptFriendRequest(fromUid);
  Future<bool> declineFriendRequest(String fromUid) =>
      _friendsService.declineFriendRequest(fromUid);
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
}

// Friends actions provider (for friend operations)
final friendsActionsProvider = Provider<FriendsActions>((ref) {
  final friendsService = ref.watch(friendsServiceProvider);
  return FriendsActions(friendsService);
});
