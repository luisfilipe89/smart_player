// lib/providers/services/games_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'games_service_instance.dart';
import 'package:move_young/models/core/game.dart';
import '../auth/auth_provider.dart';
import 'cloud_games_provider.dart';
import 'cloud_games_service_instance.dart';

// GamesService provider with dependency injection
final gamesServiceProvider = Provider<GamesServiceInstance>((ref) {
  final authService = ref.watch(authServiceProvider);
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  return GamesServiceInstance(authService, cloudGamesService);
});

// My games provider (reactive)
final myGamesProvider = FutureProvider.autoDispose<List<Game>>((ref) async {
  final gamesService = ref.watch(gamesServiceProvider);
  final list = await gamesService.getMyGames();
  // Invalidate on auth/user change is handled via providers; explicit invalidation occurs on actions
  return list;
});

// Joinable games provider (reactive)
final joinableGamesProvider =
    FutureProvider.autoDispose<List<Game>>((ref) async {
  final gamesService = ref.watch(gamesServiceProvider);
  final list = await gamesService.getJoinableGames();
  return list;
});

// Invited games provider (reactive)
final invitedGamesProvider =
    FutureProvider.autoDispose<List<Game>>((ref) async {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return [];

  return await cloudGamesService.getInvitedGamesForCurrentUser();
});

// Pending invites count provider (reactive stream)
final pendingInvitesCountProvider = StreamProvider.autoDispose<int>((ref) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value(0);

  return cloudGamesService.watchPendingInvitesCount();
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
  final CloudGamesServiceInstance _cloudGamesService;

  GamesActions(this._gamesService, this._cloudGamesService);

  Future<String> createGame(Game game) => _gamesService.createGame(game);
  Future<void> updateGame(Game game) => _gamesService.updateGame(game);
  Future<void> deleteGame(String gameId) => _gamesService.deleteGame(gameId);
  Future<void> joinGame(String gameId) => _gamesService.joinGame(gameId);
  Future<void> leaveGame(String gameId) => _gamesService.leaveGame(gameId);
  Future<void> syncWithCloud() => _gamesService.syncWithCloud();

  // Extras powered by cloud service directly
  Future<List<Game>> getInvitedGames() =>
      _cloudGamesService.getInvitedGamesForCurrentUser();
  Future<Map<String, String>> getGameInviteStatuses(String gameId) =>
      _cloudGamesService.getGameInviteStatuses(gameId);
}

// Games actions provider (for game operations)
final gamesActionsProvider = Provider<GamesActions>((ref) {
  final gamesService = ref.watch(gamesServiceProvider);
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  return GamesActions(gamesService, cloudGamesService);
});
