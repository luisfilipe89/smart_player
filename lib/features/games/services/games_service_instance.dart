// lib/features/games/services/games_service_instance.dart
import 'package:move_young/features/games/models/game.dart';
import 'package:move_young/features/auth/services/auth_service.dart';
import 'package:move_young/features/games/services/games_service.dart';
import 'package:move_young/models/infrastructure/service_error.dart';
import 'package:move_young/utils/logger.dart';
import 'package:move_young/services/firebase_error_handler.dart';
import 'package:move_young/features/games/services/cloud_games_service_instance.dart';

/// Instance-based GamesService - cloud-first, no SQLite
/// All game data is managed through Firebase Realtime Database
///
/// Wraps CloudGamesServiceInstance with error handling and authentication checks.
/// Error handling is done here at the service layer with direct try-catch patterns.
class GamesServiceInstance implements IGamesService {
  final IAuthService _authService;
  final CloudGamesServiceInstance _cloudGamesService;

  GamesServiceInstance(this._authService, this._cloudGamesService);

  /// Creates a new game in the cloud database.
  ///
  /// Validates that the user is authenticated before creating the game.
  /// Throws [AuthException] if the user is not authenticated.
  @override
  Future<String> createGame(Game game) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw AuthException('User not authenticated');
    }

    try {
      return await _cloudGamesService.createGame(game);
    } on ServiceException {
      rethrow; // Already typed, just rethrow
    } catch (e) {
      NumberedLogger.e('Error creating game: $e');
      throw FirebaseErrorHandler.toServiceException(e);
    }
  }

  /// Gets all games where the current user is a participant.
  ///
  /// Returns an empty list if the user is not authenticated or if an error occurs.
  @override
  Future<List<Game>> getMyGames() async {
    final userId = _authService.currentUserId;
    if (userId == null) return [];

    try {
      return await _cloudGamesService.getMyGames();
    } catch (e) {
      NumberedLogger.w('Error getting my games: $e');
      return []; // Return empty list on error (offline-friendly)
    }
  }

  /// Gets all public games that the current user can join.
  ///
  /// Returns an empty list if the user is not authenticated or if an error occurs.
  @override
  Future<List<Game>> getJoinableGames() async {
    final userId = _authService.currentUserId;
    if (userId == null) return [];

    try {
      return await _cloudGamesService.getJoinableGames();
    } catch (e) {
      NumberedLogger.w('Error getting joinable games: $e');
      return []; // Return empty list on error (offline-friendly)
    }
  }

  /// Gets a specific game by its ID.
  ///
  /// Returns `null` if the game doesn't exist or if an error occurs.
  @override
  Future<Game?> getGameById(String gameId) async {
    try {
      return await _cloudGamesService.getGameById(gameId);
    } catch (e) {
      NumberedLogger.w('Error getting game by ID: $e');
      return null; // Return null on error
    }
  }

  /// Updates an existing game.
  ///
  /// Validates that the user is authenticated and has permission to update the game.
  @override
  Future<void> updateGame(Game game) async {
    try {
      return await _cloudGamesService.updateGame(game);
    } on ServiceException {
      rethrow;
    } catch (e) {
      NumberedLogger.e('Error updating game: $e');
      throw FirebaseErrorHandler.toServiceException(e);
    }
  }

  /// Deletes a game (soft delete by setting isActive to false).
  ///
  /// Validates that the user is authenticated and has permission to delete the game.
  @override
  Future<void> deleteGame(String gameId) async {
    try {
      return await _cloudGamesService.deleteGame(gameId);
    } on ServiceException {
      rethrow;
    } catch (e) {
      NumberedLogger.e('Error deleting game: $e');
      throw FirebaseErrorHandler.toServiceException(e);
    }
  }

  /// Joins the current user to a game.
  ///
  /// Validates that the user is authenticated before joining.
  /// Throws [AuthException] if the user is not authenticated.
  @override
  Future<void> joinGame(String gameId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw AuthException('User not authenticated');
    }

    try {
      return await _cloudGamesService.joinGame(gameId);
    } on ServiceException {
      rethrow;
    } catch (e) {
      NumberedLogger.e('Error joining game: $e');
      throw FirebaseErrorHandler.toServiceException(e);
    }
  }

  /// Removes the current user from a game.
  ///
  /// Validates that the user is authenticated before leaving.
  /// Throws [AuthException] if the user is not authenticated.
  @override
  Future<void> leaveGame(String gameId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw AuthException('User not authenticated');
    }

    try {
      return await _cloudGamesService.leaveGame(gameId);
    } on ServiceException {
      rethrow;
    } catch (e) {
      NumberedLogger.e('Error leaving game: $e');
      throw FirebaseErrorHandler.toServiceException(e);
    }
  }

  // Sync games with cloud (no-op since we're always cloud-first now)
  @override
  Future<void> syncWithCloud() async {
    // No-op: we're always synced with cloud
    // This method is kept for interface compatibility
  }
}
