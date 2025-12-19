import 'package:move_young/features/matches/models/match.dart';

/// Interface for match-related operations to enable mocking and testability.
///
/// This interface defines the contract for match service implementations,
/// allowing for dependency injection and easier testing.
abstract class IMatchesService {
  /// Creates a new match and returns its generated ID.
  Future<String> createMatch(Match match);

  /// Gets all matches where the current user is a participant.
  Future<List<Match>> getMyMatches();

  /// Gets all public matches that the current user can join.
  Future<List<Match>> getJoinableMatches();

  /// Gets a specific match by its ID.
  ///
  /// Returns `null` if the match doesn't exist.
  Future<Match?> getMatchById(String matchId);

  /// Updates an existing match.
  Future<void> updateMatch(Match match);

  /// Deletes a match (soft delete by setting isActive to false).
  Future<void> deleteMatch(String matchId);

  /// Joins the current user to a match.
  Future<void> joinMatch(String matchId);

  /// Removes the current user from a match.
  Future<void> leaveMatch(String matchId);

  /// Synchronizes local match data with the cloud database.
  Future<void> syncWithCloud();
}
