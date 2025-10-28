import 'package:move_young/models/core/game.dart';

/// Interface for game-related operations to enable mocking and testability
abstract class IGamesService {
  Future<String> createGame(Game game);
  Future<List<Game>> getMyGames();
  Future<List<Game>> getJoinableGames();
  Future<Game?> getGameById(String gameId);
  Future<void> updateGame(Game game);
  Future<void> deleteGame(String gameId);
  Future<void> joinGame(String gameId);
  Future<void> leaveGame(String gameId);
  Future<void> syncWithCloud();
}



