// lib/providers/services/cloud_games_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cloud_games_service_instance.dart';
import 'package:move_young/models/core/game.dart';
import '../auth/auth_provider.dart';
import '../notifications/notification_provider.dart';
import 'package:move_young/providers/infrastructure/firebase_providers.dart';

// CloudGamesService provider with dependency injection
final cloudGamesServiceProvider = Provider<CloudGamesServiceInstance>((ref) {
  final firebaseDatabase = ref.watch(firebaseDatabaseProvider);
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  return CloudGamesServiceInstance(
    firebaseDatabase,
    firebaseAuth,
    notificationService,
  );
});

// My games provider (reactive)
final myGamesProvider = FutureProvider.autoDispose<List<Game>>((ref) async {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return [];

  return await cloudGamesService.getMyGames();
});

// Joinable games provider (reactive)
final joinableGamesProvider =
    FutureProvider.autoDispose<List<Game>>((ref) async {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return [];

  return await cloudGamesService.getJoinableGames();
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

// Cloud games actions provider (for game operations)
final cloudGamesActionsProvider = Provider<CloudGamesActions>((ref) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  return CloudGamesActions(cloudGamesService);
});

// Helper class for cloud games actions
class CloudGamesActions {
  final CloudGamesServiceInstance _cloudGamesService;

  CloudGamesActions(this._cloudGamesService);

  Future<String> createGame(Game game) => _cloudGamesService.createGame(game);
  Future<void> joinGame(String gameId) => _cloudGamesService.joinGame(gameId);
  Future<void> leaveGame(String gameId) => _cloudGamesService.leaveGame(gameId);
  Future<void> acceptGameInvite(String gameId) =>
      _cloudGamesService.acceptGameInvite(gameId);
  Future<void> declineGameInvite(String gameId) =>
      _cloudGamesService.declineGameInvite(gameId);
  Future<List<Game>> getMyGames() => _cloudGamesService.getMyGames();
  Future<List<Game>> getJoinableGames() =>
      _cloudGamesService.getJoinableGames();
  Future<List<Game>> getInvitedGames() =>
      _cloudGamesService.getInvitedGamesForCurrentUser();
  Future<Map<String, String>> getGameInviteStatuses(String gameId) =>
      _cloudGamesService.getGameInviteStatuses(gameId);
}
