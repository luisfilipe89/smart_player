import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/matches/services/cloud_matches_service_instance.dart';
import 'package:move_young/features/matches/models/match.dart';
import 'package:move_young/providers/infrastructure/firebase_providers.dart';

/// Provider for CloudMatchesServiceInstance with dependency injection.
///
/// Provides access to the cloud matches service that handles all Firebase
/// Realtime Database operations for matches, including creation, joining,
/// leaving, and invite management.
final cloudMatchesServiceProvider =
    Provider<CloudMatchesServiceInstance>((ref) {
  final firebaseDatabase = ref.watch(firebaseDatabaseProvider);
  final firebaseAuth = ref.watch(firebaseAuthProvider);

  return CloudMatchesServiceInstance(
    firebaseDatabase,
    firebaseAuth,
  );
});

/// Provider for CloudMatchesActions, a helper class for match operations.
///
/// This provider wraps CloudMatchesServiceInstance to provide a simpler
/// action-based API for match operations without direct access to streams.
final cloudMatchesActionsProvider = Provider<CloudMatchesActions>((ref) {
  final cloudMatchesService = ref.watch(cloudMatchesServiceProvider);
  return CloudMatchesActions(cloudMatchesService);
});

/// Helper class that provides action-based methods for cloud match operations.
///
/// This class wraps CloudMatchesServiceInstance to provide a simpler API
/// for one-off match operations. For reactive data, use the stream providers
/// in matches_provider.dart instead.
class CloudMatchesActions {
  final CloudMatchesServiceInstance _cloudMatchesService;

  CloudMatchesActions(this._cloudMatchesService);

  /// Creates a new match in the cloud database.
  ///
  /// Returns the generated match ID.
  Future<String> createMatch(Match match) =>
      _cloudMatchesService.createMatch(match);

  /// Joins the current user to a match.
  Future<void> joinMatch(String matchId) =>
      _cloudMatchesService.joinMatch(matchId);

  /// Removes the current user from a match.
  Future<void> leaveMatch(String matchId) =>
      _cloudMatchesService.leaveMatch(matchId);

  /// Accepts a match invite for the current user.
  Future<void> acceptMatchInvite(String matchId) =>
      _cloudMatchesService.acceptMatchInvite(matchId);

  /// Declines a match invite for the current user.
  Future<void> declineMatchInvite(String matchId) =>
      _cloudMatchesService.declineMatchInvite(matchId);

  /// Gets all matches where the current user is a participant.
  Future<List<Match>> getMyMatches() => _cloudMatchesService.getMyMatches();

  /// Gets all public matches that the current user can join.
  Future<List<Match>> getJoinableMatches() =>
      _cloudMatchesService.getJoinableMatches();

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

  /// Sends match invites to a list of friend user IDs.
  Future<void> sendMatchInvitesToFriends(
          String matchId, List<String> friendUids) =>
      _cloudMatchesService.sendMatchInvitesToFriends(matchId, friendUids);

  /// Removes a match from the current user's created matches list.
  Future<void> removeFromMyCreated(String matchId) =>
      _cloudMatchesService.removeFromMyCreated(matchId);

  /// Removes a match from the current user's joined matches list.
  Future<void> removeFromMyJoined(String matchId) =>
      _cloudMatchesService.removeFromMyJoined(matchId);
}
