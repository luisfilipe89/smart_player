import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/matches/services/matches_service_instance.dart';
import 'package:move_young/features/matches/services/matches_service.dart';
import 'package:move_young/features/matches/models/match.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/features/matches/services/cloud_matches_provider.dart';
import 'package:move_young/features/matches/services/cloud_matches_service_instance.dart';
import 'package:move_young/services/system/sync_provider.dart';
import 'package:move_young/models/infrastructure/service_error.dart';
import 'package:move_young/utils/logger.dart';

/// Provider for IMatchesService with dependency injection.
///
/// Provides access to the matches service that handles local database
/// operations and synchronization with cloud services.
final matchesServiceProvider = Provider<IMatchesService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final cloudMatchesService = ref.watch(cloudMatchesServiceProvider);
  return MatchesServiceInstance(authService, cloudMatchesService);
});

/// Reactive stream provider for matches where the current user is a participant.
///
/// Automatically updates when matches are created, joined, or modified.
/// Returns an empty list if the user is not authenticated.
final myMatchesProvider = StreamProvider.autoDispose<List<Match>>((ref) {
  final cloudMatchesService = ref.watch(cloudMatchesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);

  return cloudMatchesService.watchMyMatches();
});

/// Reactive stream provider for past matches where the user participated.
///
/// Returns matches that have already occurred (historic matches).
/// Returns an empty list if the user is not authenticated.
final historicMatchesProvider = StreamProvider.autoDispose<List<Match>>((ref) {
  final cloudMatchesService = ref.watch(cloudMatchesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);

  return cloudMatchesService.watchHistoricMatches();
});

/// Reactive stream provider for matches that the current user can join.
///
/// Returns public matches that are not full and where the user is not already
/// a participant. Updates in real-time as matches are created or filled.
final joinableMatchesProvider = StreamProvider<List<Match>>((ref) {
  final cloudMatchesService = ref.watch(cloudMatchesServiceProvider);
  return cloudMatchesService.watchJoinableMatches();
});

/// Reactive stream provider for matches where the current user has a pending invite.
///
/// Automatically updates when invites are sent, accepted, or declined.
/// Returns an empty list if the user is not authenticated.
final invitedMatchesProvider = StreamProvider<List<Match>>((ref) {
  final cloudMatchesService = ref.watch(cloudMatchesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value([]);

  return cloudMatchesService.watchInvitedMatches();
});

/// Reactive stream provider for the count of pending match invites.
///
/// Useful for displaying badge counts in the UI.
/// Returns 0 if the user is not authenticated.
final pendingInvitesCountProvider = StreamProvider.autoDispose<int>((ref) {
  final cloudMatchesService = ref.watch(cloudMatchesServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return Stream.value(0);

  return cloudMatchesService.watchPendingInvitesCount();
});

/// Reactive stream provider for a specific match by ID.
///
/// Provides real-time updates when the match is modified.
/// Returns `null` if the match doesn't exist.
final matchByIdProvider =
    StreamProvider.family.autoDispose<Match?, String>((ref, matchId) {
  final cloudMatchesService = ref.watch(cloudMatchesServiceProvider);
  return cloudMatchesService.watchMatch(matchId);
});

/// Reactive stream provider for invite statuses of all users invited to a match.
///
/// Returns a map of user ID to status (e.g., 'pending', 'accepted', 'declined').
/// Updates in real-time as invites are accepted or declined.
final matchInviteStatusesProvider = StreamProvider.family
    .autoDispose<Map<String, String>, String>((ref, matchId) {
  final cloudMatchesService = ref.watch(cloudMatchesServiceProvider);
  return cloudMatchesService.watchMatchInviteStatuses(matchId);
});

/// Helper class that provides action-based methods for match operations.
///
/// Handles network errors by automatically adding operations to the sync queue
/// for retry when network connectivity is restored.
class MatchesActions {
  final IMatchesService _matchesService;
  final CloudMatchesServiceInstance _cloudMatchesService;
  final SyncActions? _syncActions;

  MatchesActions(
      this._matchesService, this._cloudMatchesService, this._syncActions);

  /// Creates a new match in both local and cloud databases.
  ///
  /// Returns the generated match ID.
  Future<String> createMatch(Match match) => _matchesService.createMatch(match);

  /// Updates an existing match.
  Future<void> updateMatch(Match match) => _matchesService.updateMatch(match);

  /// Deletes a match (soft delete by setting isActive to false).
  Future<void> deleteMatch(String matchId) =>
      _matchesService.deleteMatch(matchId);

  /// Joins the current user to a match.
  ///
  /// If a network error occurs, the operation is automatically added to
  /// the sync queue for retry when network connectivity is restored.
  Future<void> joinMatch(String matchId) async {
    try {
      await _matchesService.joinMatch(matchId);
    } on NetworkException catch (e) {
      // Add to sync queue for retry when network is available
      NumberedLogger.w('Network error joining match, adding to sync queue: $e');
      await _syncActions?.addSyncOperation(
        type: 'match_join',
        data: {'matchId': matchId},
        operation: () async {
          await _matchesService.joinMatch(matchId);
          return true;
        },
        itemId: matchId,
        priority: SyncServiceInstance.priorityNormal,
      );
      rethrow; // Re-throw so UI can show error
    } on ServiceException {
      rethrow; // Re-throw other service exceptions
    }
  }

  /// Removes the current user from a match.
  ///
  /// If a network error occurs, the operation is automatically added to
  /// the sync queue for retry when connectivity is restored.
  Future<void> leaveMatch(String matchId) async {
    try {
      await _matchesService.leaveMatch(matchId);
    } on NetworkException catch (e) {
      // Add to sync queue for retry when network is available
      NumberedLogger.w('Network error leaving match, adding to sync queue: $e');
      await _syncActions?.addSyncOperation(
        type: 'match_leave',
        data: {'matchId': matchId},
        operation: () async {
          await _matchesService.leaveMatch(matchId);
          return true;
        },
        itemId: matchId,
        priority: SyncServiceInstance.priorityNormal,
      );
      rethrow; // Re-throw so UI can show error
    } on ServiceException {
      rethrow; // Re-throw other service exceptions
    }
  }

  /// Synchronizes local match data with the cloud database.
  Future<void> syncWithCloud() => _matchesService.syncWithCloud();

  /// Gets all matches where the current user has a pending invite.
  Future<List<Match>> getInvitedMatches() =>
      _cloudMatchesService.getInvitedMatchesForCurrentUser();

  /// Gets the invite statuses for all users invited to a match.
  ///
  /// Returns a map of user ID to status (e.g., 'pending', 'accepted', 'declined').
  Future<Map<String, String>> getMatchInviteStatuses(String matchId) =>
      _cloudMatchesService.getMatchInviteStatuses(matchId);

  /// Gets the invite status for the current user for a specific match.
  ///
  /// Returns the status string or null if the user is not invited.
  Future<String?> getUserInviteStatusForMatch(String matchId) =>
      _cloudMatchesService.getUserInviteStatusForMatch(matchId);
}

/// Provider for MatchesActions, a helper class for match operations.
///
/// This provider wraps the matches service and cloud matches service to provide
/// a unified action-based API with automatic sync queue handling.
final matchesActionsProvider = Provider<MatchesActions>((ref) {
  final matchesService = ref.watch(matchesServiceProvider);
  final cloudMatchesService = ref.watch(cloudMatchesServiceProvider);
  final syncActions = ref.watch(syncActionsProvider);
  return MatchesActions(matchesService, cloudMatchesService, syncActions);
});
