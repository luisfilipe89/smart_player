// lib/services/games_service_instance.dart
// import 'package:flutter/foundation.dart';
import 'package:move_young/utils/logger.dart';
import 'package:move_young/models/core/game.dart';
import '../auth/auth_service.dart';
import 'games_service.dart';
import 'cloud_games_service_instance.dart';
import '../../utils/service_error.dart';

/// Instance-based GamesService - cloud-first, no SQLite
/// All game data is managed through Firebase Realtime Database
class GamesServiceInstance implements IGamesService {
  final IAuthService _authService;
  final CloudGamesServiceInstance _cloudGamesService;

  GamesServiceInstance(this._authService, this._cloudGamesService);

  // Create a new game
  @override
  Future<String> createGame(Game game) async {
    try {
      final userId = _authService.currentUserId;

      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      // Create in cloud
      final cloudGameId = await _cloudGamesService.createGame(game);
      return cloudGameId;
    } catch (e) {
      NumberedLogger.e('Error creating game: $e');
      rethrow;
    }
  }

  // Get user's games
  @override
  Future<List<Game>> getMyGames() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return [];

      // Fetch from cloud
      return await _cloudGamesService.getMyGames();
    } catch (e) {
      NumberedLogger.e('Error getting my games: $e');
      return [];
    }
  }

  // Get games that user can join
  @override
  Future<List<Game>> getJoinableGames() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) return [];

      // Fetch from cloud
      return await _cloudGamesService.getJoinableGames();
    } catch (e) {
      NumberedLogger.e('Error getting joinable games: $e');
      return [];
    }
  }

  // Get game by ID
  @override
  Future<Game?> getGameById(String gameId) async {
    try {
      // Fetch from cloud
      return await _cloudGamesService.getGameById(gameId);
    } catch (e) {
      NumberedLogger.e('Error getting game by ID: $e');
      return null;
    }
  }

  // Update game
  @override
  Future<void> updateGame(Game game) async {
    try {
      await _cloudGamesService.updateGame(game);
    } catch (e) {
      NumberedLogger.e('Error updating game: $e');
      rethrow;
    }
  }

  // Delete game
  @override
  Future<void> deleteGame(String gameId) async {
    try {
      await _cloudGamesService.deleteGame(gameId);
    } catch (e) {
      NumberedLogger.e('Error deleting game: $e');
      rethrow;
    }
  }

  // Join a game
  @override
  Future<void> joinGame(String gameId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      // Use cloud service to join
      await _cloudGamesService.joinGame(gameId);
    } catch (e) {
      NumberedLogger.e('Error joining game: $e');
      rethrow;
    }
  }

  // Leave a game
  @override
  Future<void> leaveGame(String gameId) async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      // Use cloud service to leave
      await _cloudGamesService.leaveGame(gameId);
    } catch (e) {
      NumberedLogger.e('Error leaving game: $e');
      rethrow;
    }
  }

  // Sync games with cloud (no-op since we're always cloud-first now)
  @override
  Future<void> syncWithCloud() async {
    // No-op: we're always synced with cloud
    NumberedLogger.d('syncWithCloud called (no-op - already cloud-first)');
  }
}
