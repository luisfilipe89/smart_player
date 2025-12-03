import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/games/services/cloud_games_service_instance.dart';
import 'package:move_young/features/games/models/game.dart';
import 'package:move_young/services/notifications/notification_provider.dart';
import 'package:move_young/providers/infrastructure/firebase_providers.dart';

/// Provider for CloudGamesServiceInstance with dependency injection.
///
/// Provides access to the cloud games service that handles all Firebase
/// Realtime Database operations for games, including creation, joining,
/// leaving, and invite management.
final cloudGamesServiceProvider = Provider<CloudGamesServiceInstance>((ref) {
  final firebaseDatabase = ref.watch(firebaseDatabaseProvider);
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  return CloudGamesServiceInstance(
    firebaseDatabase,
    firebaseAuth,
    notificationService,
  );
});

/// Provider for CloudGamesActions, a helper class for game operations.
///
/// This provider wraps CloudGamesServiceInstance to provide a simpler
/// action-based API for game operations without direct access to streams.
final cloudGamesActionsProvider = Provider<CloudGamesActions>((ref) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  return CloudGamesActions(cloudGamesService);
});

/// Helper class that provides action-based methods for cloud game operations.
///
/// This class wraps CloudGamesServiceInstance to provide a simpler API
/// for one-off game operations. For reactive data, use the stream providers
/// in games_provider.dart instead.
class CloudGamesActions {
  final CloudGamesServiceInstance _cloudGamesService;

  CloudGamesActions(this._cloudGamesService);

  /// Creates a new game in the cloud database.
  ///
  /// Returns the generated game ID.
  Future<String> createGame(Game game) => _cloudGamesService.createGame(game);

  /// Joins the current user to a game.
  Future<void> joinGame(String gameId) => _cloudGamesService.joinGame(gameId);

  /// Removes the current user from a game.
  Future<void> leaveGame(String gameId) => _cloudGamesService.leaveGame(gameId);

  /// Accepts a game invite for the current user.
  Future<void> acceptGameInvite(String gameId) =>
      _cloudGamesService.acceptGameInvite(gameId);

  /// Declines a game invite for the current user.
  Future<void> declineGameInvite(String gameId) =>
      _cloudGamesService.declineGameInvite(gameId);

  /// Gets all games where the current user is a participant.
  Future<List<Game>> getMyGames() => _cloudGamesService.getMyGames();

  /// Gets all public games that the current user can join.
  Future<List<Game>> getJoinableGames() =>
      _cloudGamesService.getJoinableGames();

  /// Gets all games where the current user has a pending invite.
  Future<List<Game>> getInvitedGames() =>
      _cloudGamesService.getInvitedGamesForCurrentUser();

  /// Gets the invite statuses for all users invited to a game.
  ///
  /// Returns a map of user ID to status (e.g., 'pending', 'accepted', 'declined').
  Future<Map<String, String>> getGameInviteStatuses(String gameId) =>
      _cloudGamesService.getGameInviteStatuses(gameId);

  /// Gets the invite status for the current user for a specific game.
  ///
  /// Returns the status string or null if the user is not invited.
  Future<String?> getUserInviteStatusForGame(String gameId) =>
      _cloudGamesService.getUserInviteStatusForGame(gameId);

  /// Sends game invites to a list of friend user IDs.
  Future<void> sendGameInvitesToFriends(
          String gameId, List<String> friendUids) =>
      _cloudGamesService.sendGameInvitesToFriends(gameId, friendUids);

  /// Removes a game from the current user's created games list.
  Future<void> removeFromMyCreated(String gameId) =>
      _cloudGamesService.removeFromMyCreated(gameId);

  /// Removes a game from the current user's joined games list.
  Future<void> removeFromMyJoined(String gameId) =>
      _cloudGamesService.removeFromMyJoined(gameId);
}
