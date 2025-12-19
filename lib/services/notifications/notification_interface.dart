/// Interface for notification service
/// This abstraction breaks circular dependencies between services
abstract class INotificationService {
  /// Send a friend request notification
  Future<void> sendFriendRequestNotification(String toUid, String fromUid);

  /// Notify that a friend request was accepted
  Future<void> sendFriendAcceptedNotification(String toUid, String fromUid);

  /// Notify a user that a friend removed them
  Future<void> sendFriendRemovedNotification({
    required String removedUserUid,
    required String removerUid,
  });

  /// Send a match edited notification to all players
  Future<void> sendMatchEditedNotification(String matchId);

  /// Send a match cancelled notification to all players
  Future<void> sendMatchCancelledNotification(String matchId);
}
