// lib/providers/services/games_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/services/games_service_instance.dart';
import 'package:move_young/models/game.dart';
import 'package:move_young/providers/services/auth_provider.dart';
import 'package:move_young/providers/services/cloud_games_provider.dart';

// GamesService provider with dependency injection
final gamesServiceProvider = Provider<GamesServiceInstance>((ref) {
  final authService = ref.watch(authServiceProvider);
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  return GamesServiceInstance(authService, cloudGamesService);
});

// My games provider (reactive)
final myGamesProvider = FutureProvider.autoDispose<List<Game>>((ref) async {
  final gamesService = ref.watch(gamesServiceProvider);
  return await gamesService.getMyGames();
});

// Joinable games provider (reactive)
final joinableGamesProvider =
    FutureProvider.autoDispose<List<Game>>((ref) async {
  final gamesService = ref.watch(gamesServiceProvider);
  return await gamesService.getJoinableGames();
});

// Game by ID provider
final gameByIdProvider =
    FutureProvider.family.autoDispose<Game?, String>((ref, gameId) async {
  final gamesService = ref.watch(gamesServiceProvider);
  return await gamesService.getGameById(gameId);
});

// Helper class for games actions
class GamesActions {
  final GamesServiceInstance _gamesService;

  GamesActions(this._gamesService);

  Future<String> createGame(Game game) => _gamesService.createGame(game);
  Future<void> updateGame(Game game) => _gamesService.updateGame(game);
  Future<void> deleteGame(String gameId) => _gamesService.deleteGame(gameId);
  Future<void> joinGame(String gameId) => _gamesService.joinGame(gameId);
  Future<void> leaveGame(String gameId) => _gamesService.leaveGame(gameId);
  Future<void> syncWithCloud() => _gamesService.syncWithCloud();
}

// Games actions provider (for game operations)
final gamesActionsProvider = Provider<GamesActions>((ref) {
  final gamesService = ref.watch(gamesServiceProvider);
  return GamesActions(gamesService);
});
