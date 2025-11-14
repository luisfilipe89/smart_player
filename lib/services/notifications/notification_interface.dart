/// Interface for notification service
/// This abstraction breaks circular dependencies between services
abstract class INotificationService {
  /// Send a friend request notification
  Future<void> sendFriendRequestNotification(String toUid, String fromUid);

  /// Notify that a friend request was accepted
  Future<void> sendFriendAcceptedNotification(String toUid, String fromUid);

  /// Send a game reminder notification
  Future<void> sendGameReminderNotification(String gameId, DateTime gameTime);

  /// Notify a user that a friend removed them
  Future<void> sendFriendRemovedNotification({
    required String removedUserUid,
    required String removerUid,
  });

  /// Send a game edited notification to all players
  Future<void> sendGameEditedNotification(String gameId);

  /// Send a game cancelled notification to all players
  Future<void> sendGameCancelledNotification(String gameId);
}
