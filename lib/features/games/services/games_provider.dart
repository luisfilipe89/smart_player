// lib/providers/services/games_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/games/services/games_service_instance.dart';
import 'package:move_young/features/games/services/games_service.dart';
import 'package:move_young/features/games/models/game.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/features/games/services/cloud_games_provider.dart';
import 'package:move_young/features/games/services/cloud_games_service_instance.dart';
import 'package:move_young/services/system/sync_provider.dart';
import 'package:move_young/models/infrastructure/service_error.dart';
import 'package:move_young/utils/logger.dart';

/// Provider for IGamesService with dependency injection.
///
/// Provides access to the games service that handles local database
/// operations and synchronization with cloud services.
final gamesServiceProvider = Provider<IGamesService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  return GamesServiceInstance(authService, cloudGamesService);
});

/// Reactive stream provider for games where the current user is a participant.
///
/// Automatically updates when games are created, joined, or modified.
/// Returns an empty list if the user is not authenticated.
final myGamesProvider = StreamProvider.autoDispose<List<Game>>((ref) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);

  return cloudGamesService.watchMyGames();
});

/// Reactive stream provider for past games where the user participated.
///
/// Returns games that have already occurred (historic games).
/// Returns an empty list if the user is not authenticated.
final historicGamesProvider = StreamProvider.autoDispose<List<Game>>((ref) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);

  return cloudGamesService.watchHistoricGames();
});

/// Reactive stream provider for games that the current user can join.
///
/// Returns public games that are not full and where the user is not already
/// a participant. Updates in real-time as games are created or filled.
final joinableGamesProvider = StreamProvider<List<Game>>((ref) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  return cloudGamesService.watchJoinableGames();
});

/// Reactive stream provider for games where the current user has a pending invite.
///
/// Automatically updates when invites are sent, accepted, or declined.
/// Returns an empty list if the user is not authenticated.
final invitedGamesProvider = StreamProvider<List<Game>>((ref) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);

  return cloudGamesService.watchInvitedGames();
});

/// Reactive stream provider for the count of pending game invites.
///
/// Useful for displaying badge counts in the UI.
/// Returns 0 if the user is not authenticated.
final pendingInvitesCountProvider = StreamProvider.autoDispose<int>((ref) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value(0);

  return cloudGamesService.watchPendingInvitesCount();
});

/// Reactive stream provider for a specific game by ID.
///
/// Provides real-time updates when the game is modified.
/// Returns `null` if the game doesn't exist.
final gameByIdProvider =
    StreamProvider.family.autoDispose<Game?, String>((ref, gameId) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  return cloudGamesService.watchGame(gameId);
});

/// Reactive stream provider for invite statuses of all users invited to a game.
///
/// Returns a map of user ID to status (e.g., 'pending', 'accepted', 'declined').
/// Updates in real-time as invites are accepted or declined.
final gameInviteStatusesProvider = StreamProvider.family
    .autoDispose<Map<String, String>, String>((ref, gameId) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  return cloudGamesService.watchGameInviteStatuses(gameId);
});

/// Helper class that provides action-based methods for game operations.
///
/// Handles network errors by automatically adding operations to the sync queue
/// for retry when network connectivity is restored.
class GamesActions {
  final IGamesService _gamesService;
  final CloudGamesServiceInstance _cloudGamesService;
  final SyncActions? _syncActions;

  GamesActions(this._gamesService, this._cloudGamesService, this._syncActions);

  /// Creates a new game in both local and cloud databases.
  ///
  /// Returns the generated game ID.
  Future<String> createGame(Game game) => _gamesService.createGame(game);

  /// Updates an existing game.
  Future<void> updateGame(Game game) => _gamesService.updateGame(game);

  /// Deletes a game (soft delete by setting isActive to false).
  Future<void> deleteGame(String gameId) => _gamesService.deleteGame(gameId);

  /// Joins the current user to a game.
  ///
  /// If a network error occurs, the operation is automatically added to
  /// the sync queue for retry when connectivity is restored.
  Future<void> joinGame(String gameId) async {
    try {
      await _gamesService.joinGame(gameId);
    } on NetworkException catch (e) {
      // Add to sync queue for retry when network is available
      NumberedLogger.w('Network error joining game, adding to sync queue: $e');
      await _syncActions?.addSyncOperation(
        type: 'game_join',
        data: {'gameId': gameId},
        operation: () async {
          await _gamesService.joinGame(gameId);
          return true;
        },
        itemId: gameId,
        priority: SyncServiceInstance.priorityNormal,
      );
      rethrow; // Re-throw so UI can show error
    } on ServiceException {
      rethrow; // Re-throw other service exceptions
    }
  }

  /// Removes the current user from a game.
  ///
  /// If a network error occurs, the operation is automatically added to
  /// the sync queue for retry when connectivity is restored.
  Future<void> leaveGame(String gameId) async {
    try {
      await _gamesService.leaveGame(gameId);
    } on NetworkException catch (e) {
      // Add to sync queue for retry when network is available
      NumberedLogger.w('Network error leaving game, adding to sync queue: $e');
      await _syncActions?.addSyncOperation(
        type: 'game_leave',
        data: {'gameId': gameId},
        operation: () async {
          await _gamesService.leaveGame(gameId);
          return true;
        },
        itemId: gameId,
        priority: SyncServiceInstance.priorityNormal,
      );
      rethrow; // Re-throw so UI can show error
    } on ServiceException {
      rethrow; // Re-throw other service exceptions
    }
  }

  /// Synchronizes local game data with the cloud database.
  Future<void> syncWithCloud() => _gamesService.syncWithCloud();

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
}

/// Provider for GamesActions, a helper class for game operations.
///
/// This provider wraps the games service and cloud games service to provide
/// a unified action-based API with automatic sync queue handling.
final gamesActionsProvider = Provider<GamesActions>((ref) {
  final gamesService = ref.watch(gamesServiceProvider);
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  final syncActions = ref.watch(syncActionsProvider);
  return GamesActions(gamesService, cloudGamesService, syncActions);
});
