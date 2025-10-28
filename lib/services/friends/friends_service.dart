/// Interface for friends-related operations to enable mocking and testability
abstract class IFriendsService {
  Future<List<String>> getUserFriends(String uid);
  Future<List<String>> getUserFriendRequestsSent(String uid);
  Future<List<String>> getUserFriendRequestsReceived(String uid);

  Future<bool> sendFriendRequest(String toUid);
  Future<bool> acceptFriendRequest(String fromUid);
  Future<bool> declineFriendRequest(String fromUid);
  Future<bool> removeFriend(String friendUid);
  Future<bool> blockFriend(String friendUid);

  Future<List<Map<String, String>>> searchUsersByEmail(String email);
  Future<List<Map<String, String>>> searchUsersByDisplayName(String name);
  // Internal profile fetching exists in implementation; not part of interface
  Future<Map<String, String?>> fetchMinimalProfile(String uid);

  Stream<List<String>> watchUserFriends(String uid);
  Stream<List<String>> watchUserFriendRequestsReceived(String uid);
  Stream<List<String>> watchUserFriendRequestsSent(String uid);

  void clearCache();
  void clearExpiredCache();

  // Rate limiting
  Future<int> getRemainingRequests(String uid);
  Future<Duration> getRemainingCooldown(String uid);
  Future<bool> canSendFriendRequest(String uid);

  // QR token
  Future<String> generateFriendToken();
  Future<bool> consumeFriendToken(String token);

  // Suggestions / mutual
  Future<List<Map<String, String>>> getSuggestedFriends();
  Future<int> fetchMutualFriendsCount(String uid);
  Stream<void> watchFriendRequestReceived(String uid);

  // Best-effort indexing
  Future<void> ensureUserIndexes();
}
