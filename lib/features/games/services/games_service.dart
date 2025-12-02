import 'package:move_young/features/games/models/game.dart';

/// Interface for game-related operations to enable mocking and testability.
///
/// This interface defines the contract for game service implementations,
/// allowing for dependency injection and easier testing.
abstract class IGamesService {
  /// Creates a new game and returns its generated ID.
  Future<String> createGame(Game game);

  /// Gets all games where the current user is a participant.
  Future<List<Game>> getMyGames();

  /// Gets all public games that the current user can join.
  Future<List<Game>> getJoinableGames();

  /// Gets a specific game by its ID.
  ///
  /// Returns `null` if the game doesn't exist.
  Future<Game?> getGameById(String gameId);

  /// Updates an existing game.
  Future<void> updateGame(Game game);

  /// Deletes a game (soft delete by setting isActive to false).
  Future<void> deleteGame(String gameId);

  /// Joins the current user to a game.
  Future<void> joinGame(String gameId);

  /// Removes the current user from a game.
  Future<void> leaveGame(String gameId);

  /// Synchronizes local game data with the cloud database.
  Future<void> syncWithCloud();
}



