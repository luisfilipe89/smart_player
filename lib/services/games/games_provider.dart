// lib/providers/services/games_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'games_service_instance.dart';
import 'games_service.dart';
import 'package:move_young/models/core/game.dart';
import '../auth/auth_provider.dart';
import 'cloud_games_provider.dart';
import 'cloud_games_service_instance.dart';

// GamesService provider with dependency injection
final gamesServiceProvider = Provider<IGamesService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  return GamesServiceInstance(authService, cloudGamesService);
});

// My games provider (reactive) - using stream for real-time updates
final myGamesProvider = StreamProvider.autoDispose<List<Game>>((ref) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);

  return cloudGamesService.watchMyGames();
});

// Historic games provider (reactive) - past games where user participated
final historicGamesProvider = StreamProvider.autoDispose<List<Game>>((ref) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);

  return cloudGamesService.watchHistoricGames();
});

// Joinable games provider (reactive stream)
final joinableGamesProvider = StreamProvider<List<Game>>((ref) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  return cloudGamesService.watchJoinableGames();
});

// Invited games provider (reactive stream for real-time updates)
final invitedGamesProvider = StreamProvider<List<Game>>((ref) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);

  return cloudGamesService.watchInvitedGames();
});

// Pending invites count provider (reactive stream)
final pendingInvitesCountProvider = StreamProvider.autoDispose<int>((ref) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value(0);

  return cloudGamesService.watchPendingInvitesCount();
});

// Game by ID provider (stream for real-time updates)
final gameByIdProvider =
    StreamProvider.family.autoDispose<Game?, String>((ref, gameId) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  return cloudGamesService.watchGame(gameId);
});

// Game invite statuses provider (stream for real-time updates)
final gameInviteStatusesProvider = StreamProvider.family
    .autoDispose<Map<String, String>, String>((ref, gameId) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  return cloudGamesService.watchGameInviteStatuses(gameId);
});

// Helper class for games actions
class GamesActions {
  final IGamesService _gamesService;
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
  Future<String?> getUserInviteStatusForGame(String gameId) =>
      _cloudGamesService.getUserInviteStatusForGame(gameId);
}

// Games actions provider (for game operations)
final gamesActionsProvider = Provider<GamesActions>((ref) {
  final gamesService = ref.watch(gamesServiceProvider);
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  return GamesActions(gamesService, cloudGamesService);
});
