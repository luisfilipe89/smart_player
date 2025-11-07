/// Repository pattern for game data operations
///
/// The repository pattern abstracts data access, making it easier to:
/// - Swap data sources (Firebase, local DB, API, etc.)
/// - Test services with mock repositories
/// - Implement caching strategies
/// - Handle offline-first scenarios
///
/// Note: Repositories are thin wrappers that delegate to data sources.
/// Error handling is done at the service layer, not the repository layer.
library;

import 'package:move_young/models/core/game.dart';
import '../services/games/cloud_games_service_instance.dart';

/// Repository interface for game data operations
abstract class IGameRepository {
  /// Create a new game
  Future<String> createGame(Game game);

  /// Get game by ID
  Future<Game?> getGameById(String gameId);

  /// Get all games for current user (organized + joined)
  Future<List<Game>> getMyGames();

  /// Get all public games that can be joined
  Future<List<Game>> getJoinableGames();

  /// Get games organized by user
  Future<List<Game>> getGamesByOrganizer(String organizerId);

  /// Get games user has joined
  Future<List<Game>> getGamesByPlayer(String playerId);

  /// Update game
  Future<void> updateGame(Game game);

  /// Delete game
  Future<void> deleteGame(String gameId);

  /// Add player to game (join)
  Future<void> addPlayerToGame(String gameId, String playerId);

  /// Remove player from game (leave)
  Future<void> removePlayerFromGame(String gameId, String playerId);
}

/// Firebase-based implementation of game repository
///
/// This wraps CloudGamesServiceInstance to provide a repository abstraction.
/// Repositories are thin - they just delegate. Error handling happens at service layer.
class GameRepository implements IGameRepository {
  final CloudGamesServiceInstance _cloudService;

  GameRepository(this._cloudService);

  @override
  Future<String> createGame(Game game) async {
    return await _cloudService.createGame(game);
  }

  @override
  Future<Game?> getGameById(String gameId) async {
    return await _cloudService.getGameById(gameId);
  }

  @override
  Future<List<Game>> getGamesByOrganizer(String organizerId) async {
    // CloudGamesServiceInstance doesn't have this method, so we filter getMyGames
    final allGames = await _cloudService.getMyGames();
    return allGames.where((g) => g.organizerId == organizerId).toList();
  }

  @override
  Future<List<Game>> getGamesByPlayer(String playerId) async {
    final allGames = await _cloudService.getMyGames();
    return allGames.where((g) => g.players.contains(playerId)).toList();
  }

  @override
  Future<List<Game>> getMyGames() async {
    return await _cloudService.getMyGames();
  }

  @override
  Future<List<Game>> getJoinableGames() async {
    return await _cloudService.getJoinableGames();
  }

  @override
  Future<void> updateGame(Game game) async {
    return await _cloudService.updateGame(game);
  }

  @override
  Future<void> deleteGame(String gameId) async {
    return await _cloudService.deleteGame(gameId);
  }

  @override
  Future<void> addPlayerToGame(String gameId, String playerId) async {
    return await _cloudService.joinGame(gameId);
  }

  @override
  Future<void> removePlayerFromGame(String gameId, String playerId) async {
    return await _cloudService.leaveGame(gameId);
  }
}
