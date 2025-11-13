// lib/providers/services/cloud_games_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cloud_games_service_instance.dart';
import 'package:move_young/models/core/game.dart';
// import '../auth/auth_provider.dart';
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
// Moved to games_provider.dart

// Joinable games provider (reactive)
// Moved to games_provider.dart

// Invited games provider (reactive)
// Moved to games_provider.dart

// Pending invites count provider (reactive stream)
// Moved to games_provider.dart

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
  Future<String?> getUserInviteStatusForGame(String gameId) =>
      _cloudGamesService.getUserInviteStatusForGame(gameId);
  Future<void> sendGameInvitesToFriends(
          String gameId, List<String> friendUids) =>
      _cloudGamesService.sendGameInvitesToFriends(gameId, friendUids);
  Future<void> removeFromMyCreated(String gameId) =>
      _cloudGamesService.removeFromMyCreated(gameId);
  Future<void> removeFromMyJoined(String gameId) =>
      _cloudGamesService.removeFromMyJoined(gameId);
}
