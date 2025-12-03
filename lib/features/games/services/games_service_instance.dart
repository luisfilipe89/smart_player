import 'package:move_young/features/games/models/game.dart';
import 'package:move_young/features/auth/services/auth_service.dart';
import 'package:move_young/features/games/services/games_service.dart';
import 'package:move_young/models/infrastructure/service_error.dart';
import 'package:move_young/services/error_handler/service_error_handler_mixin.dart';
import 'package:move_young/features/games/services/cloud_games_service_instance.dart';

/// Instance-based GamesService - cloud-first, no SQLite
/// All game data is managed through Firebase Realtime Database
///
/// Wraps CloudGamesServiceInstance with error handling and authentication checks.
/// Uses standardized error handling mixin for consistent error handling patterns.
class GamesServiceInstance
    with ServiceErrorHandlerMixin
    implements IGamesService {
  final IAuthService _authService;
  final CloudGamesServiceInstance _cloudGamesService;

  GamesServiceInstance(this._authService, this._cloudGamesService);

  /// Ensures the user is authenticated, throwing [AuthException] if not.
  void _requireAuthentication() {
    if (_authService.currentUserId == null) {
      throw AuthException('User not authenticated');
    }
  }

  /// Creates a new game in the cloud database.
  ///
  /// Validates that the user is authenticated before creating the game.
  /// Throws [AuthException] if the user is not authenticated.
  @override
  Future<String> createGame(Game game) async {
    _requireAuthentication();
    return handleMutationError(
      () => _cloudGamesService.createGame(game),
      'creating game',
    );
  }

  /// Gets all games where the current user is a participant.
  ///
  /// Returns an empty list if the user is not authenticated or if an error occurs.
  @override
  Future<List<Game>> getMyGames() async {
    if (_authService.currentUserId == null) return [];
    return handleListQueryError(
      () => _cloudGamesService.getMyGames(),
      'getting my games',
    );
  }

  /// Gets all public games that the current user can join.
  ///
  /// Returns an empty list if the user is not authenticated or if an error occurs.
  @override
  Future<List<Game>> getJoinableGames() async {
    if (_authService.currentUserId == null) return [];
    return handleListQueryError(
      () => _cloudGamesService.getJoinableGames(),
      'getting joinable games',
    );
  }

  /// Gets a specific game by its ID.
  ///
  /// Returns `null` if the game doesn't exist or if an error occurs.
  @override
  Future<Game?> getGameById(String gameId) async {
    return handleNullableQueryError(
      () => _cloudGamesService.getGameById(gameId),
      'getting game by ID',
    );
  }

  /// Updates an existing game.
  ///
  /// Validates that the user is authenticated and has permission to update the game.
  @override
  Future<void> updateGame(Game game) async {
    return handleMutationError(
      () => _cloudGamesService.updateGame(game),
      'updating game',
    );
  }

  /// Deletes a game (soft delete by setting isActive to false).
  ///
  /// Validates that the user is authenticated and has permission to delete the game.
  @override
  Future<void> deleteGame(String gameId) async {
    return handleMutationError(
      () => _cloudGamesService.deleteGame(gameId),
      'deleting game',
    );
  }

  /// Joins the current user to a game.
  ///
  /// Validates that the user is authenticated before joining.
  /// Throws [AuthException] if the user is not authenticated.
  @override
  Future<void> joinGame(String gameId) async {
    _requireAuthentication();
    return handleMutationError(
      () => _cloudGamesService.joinGame(gameId),
      'joining game',
    );
  }

  /// Removes the current user from a game.
  ///
  /// Validates that the user is authenticated before leaving.
  /// Throws [AuthException] if the user is not authenticated.
  @override
  Future<void> leaveGame(String gameId) async {
    _requireAuthentication();
    return handleMutationError(
      () => _cloudGamesService.leaveGame(gameId),
      'leaving game',
    );
  }

  // Sync games with cloud (no-op since we're always cloud-first now)
  @override
  Future<void> syncWithCloud() async {
    // No-op: we're always synced with cloud
    // This method is kept for interface compatibility
  }
}
