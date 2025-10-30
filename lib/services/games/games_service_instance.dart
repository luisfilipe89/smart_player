// lib/services/games_service_instance.dart
import 'package:move_young/models/core/game.dart';
import '../auth/auth_service.dart';
import 'games_service.dart';
import '../../utils/service_error.dart';
import '../../utils/logger.dart';
import '../../services/firebase_error_handler.dart';
import '../../repositories/game_repository.dart';

/// Instance-based GamesService - cloud-first, no SQLite
/// All game data is managed through Firebase Realtime Database
///
/// Uses IGameRepository for data access abstraction.
/// Error handling is done here at the service layer with direct try-catch patterns.
class GamesServiceInstance implements IGamesService {
  final IAuthService _authService;
  final IGameRepository _gameRepository;

  GamesServiceInstance(this._authService, this._gameRepository);

  // Create a new game
  @override
  Future<String> createGame(Game game) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw AuthException('User not authenticated');
    }

    try {
      return await _gameRepository.createGame(game);
    } on ServiceException {
      rethrow; // Already typed, just rethrow
    } catch (e) {
      NumberedLogger.e('Error creating game: $e');
      throw FirebaseErrorHandler.toServiceException(e);
    }
  }

  // Get user's games
  @override
  Future<List<Game>> getMyGames() async {
    final userId = _authService.currentUserId;
    if (userId == null) return [];

    try {
      return await _gameRepository.getMyGames();
    } catch (e) {
      NumberedLogger.w('Error getting my games: $e');
      return []; // Return empty list on error (offline-friendly)
    }
  }

  // Get games that user can join
  @override
  Future<List<Game>> getJoinableGames() async {
    final userId = _authService.currentUserId;
    if (userId == null) return [];

    try {
      return await _gameRepository.getJoinableGames();
    } catch (e) {
      NumberedLogger.w('Error getting joinable games: $e');
      return []; // Return empty list on error (offline-friendly)
    }
  }

  // Get game by ID
  @override
  Future<Game?> getGameById(String gameId) async {
    try {
      return await _gameRepository.getGameById(gameId);
    } catch (e) {
      NumberedLogger.w('Error getting game by ID: $e');
      return null; // Return null on error
    }
  }

  // Update game
  @override
  Future<void> updateGame(Game game) async {
    try {
      return await _gameRepository.updateGame(game);
    } on ServiceException {
      rethrow;
    } catch (e) {
      NumberedLogger.e('Error updating game: $e');
      throw FirebaseErrorHandler.toServiceException(e);
    }
  }

  // Delete game
  @override
  Future<void> deleteGame(String gameId) async {
    try {
      return await _gameRepository.deleteGame(gameId);
    } on ServiceException {
      rethrow;
    } catch (e) {
      NumberedLogger.e('Error deleting game: $e');
      throw FirebaseErrorHandler.toServiceException(e);
    }
  }

  // Join a game
  @override
  Future<void> joinGame(String gameId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw AuthException('User not authenticated');
    }

    try {
      return await _gameRepository.addPlayerToGame(gameId, userId);
    } on ServiceException {
      rethrow;
    } catch (e) {
      NumberedLogger.e('Error joining game: $e');
      throw FirebaseErrorHandler.toServiceException(e);
    }
  }

  // Leave a game
  @override
  Future<void> leaveGame(String gameId) async {
    final userId = _authService.currentUserId;
    if (userId == null) {
      throw AuthException('User not authenticated');
    }

    try {
      return await _gameRepository.removePlayerFromGame(gameId, userId);
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
