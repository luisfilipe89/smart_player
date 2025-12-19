import 'package:move_young/features/matches/models/match.dart';
import 'package:move_young/features/auth/services/auth_service.dart';
import 'package:move_young/features/matches/services/matches_service.dart';
import 'package:move_young/models/infrastructure/service_error.dart';
import 'package:move_young/services/error_handler/service_error_handler_mixin.dart';
import 'package:move_young/features/matches/services/cloud_matches_service_instance.dart';

/// Instance-based MatchesService - cloud-first, no SQLite
/// All match data is managed through Firebase Realtime Database
///
/// Wraps CloudMatchesServiceInstance with error handling and authentication checks.
/// Uses standardized error handling mixin for consistent error handling patterns.
class MatchesServiceInstance
    with ServiceErrorHandlerMixin
    implements IMatchesService {
  final IAuthService _authService;
  final CloudMatchesServiceInstance _cloudMatchesService;

  MatchesServiceInstance(this._authService, this._cloudMatchesService);

  /// Ensures the user is authenticated, throwing [AuthException] if not.
  void _requireAuthentication() {
    if (_authService.currentUserId == null) {
      throw AuthException('User not authenticated');
    }
  }

  /// Creates a new match in the cloud database.
  ///
  /// Validates that the user is authenticated before creating the match.
  /// Throws [AuthException] if the user is not authenticated.
  @override
  Future<String> createMatch(Match match) async {
    _requireAuthentication();
    return handleMutationError(
      () => _cloudMatchesService.createMatch(match),
      'creating match',
    );
  }

  /// Gets all matches where the current user is a participant.
  ///
  /// Returns an empty list if the user is not authenticated or if an error occurs.
  @override
  Future<List<Match>> getMyMatches() async {
    if (_authService.currentUserId == null) return [];
    return handleListQueryError(
      () => _cloudMatchesService.getMyMatches(),
      'getting my matches',
    );
  }

  /// Gets all public matches that the current user can join.
  ///
  /// Returns an empty list if the user is not authenticated or if an error occurs.
  @override
  Future<List<Match>> getJoinableMatches() async {
    if (_authService.currentUserId == null) return [];
    return handleListQueryError(
      () => _cloudMatchesService.getJoinableMatches(),
      'getting joinable matches',
    );
  }

  /// Gets a specific match by its ID.
  ///
  /// Returns `null` if the match doesn't exist or if an error occurs.
  @override
  Future<Match?> getMatchById(String matchId) async {
    return handleNullableQueryError(
      () => _cloudMatchesService.getMatchById(matchId),
      'getting match by ID',
    );
  }

  /// Updates an existing match.
  ///
  /// Validates that the user is authenticated and has permission to update the match.
  @override
  Future<void> updateMatch(Match match) async {
    return handleMutationError(
      () => _cloudMatchesService.updateMatch(match),
      'updating match',
    );
  }

  /// Deletes a match (soft delete by setting isActive to false).
  ///
  /// Validates that the user is authenticated and has permission to delete the match.
  @override
  Future<void> deleteMatch(String matchId) async {
    return handleMutationError(
      () => _cloudMatchesService.deleteMatch(matchId),
      'deleting match',
    );
  }

  /// Joins the current user to a match.
  ///
  /// Validates that the user is authenticated before joining.
  /// Throws [AuthException] if the user is not authenticated.
  @override
  Future<void> joinMatch(String matchId) async {
    _requireAuthentication();
    return handleMutationError(
      () => _cloudMatchesService.joinMatch(matchId),
      'joining match',
    );
  }

  /// Removes the current user from a match.
  ///
  /// Validates that the user is authenticated before leaving.
  /// Throws [AuthException] if the user is not authenticated.
  @override
  Future<void> leaveMatch(String matchId) async {
    _requireAuthentication();
    return handleMutationError(
      () => _cloudMatchesService.leaveMatch(matchId),
      'leaving match',
    );
  }

  // Sync matches with cloud (no-op since we're always cloud-first now)
  @override
  Future<void> syncWithCloud() async {
    // No-op: we're always synced with cloud
    // This method is kept for interface compatibility
  }
}
