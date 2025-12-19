import 'package:flutter/foundation.dart';
import 'package:move_young/features/matches/models/match.dart';

/// Immutable state class for the matchs join screen
@immutable
class MatchesJoinScreenState {
  final List<Match> matches;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final String selectedSport;
  final String searchQuery;
  final String? highlightId;
  final Map<String, String> matchInviteStatuses;

  const MatchesJoinScreenState({
    this.matches = const [],
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage,
    this.selectedSport = 'all',
    this.searchQuery = '',
    this.highlightId,
    this.matchInviteStatuses = const {},
  });

  /// Create initial state
  factory MatchesJoinScreenState.initial(String? highlightMatchId) {
    return MatchesJoinScreenState(
      highlightId: highlightMatchId,
    );
  }

  /// Copy with method for immutable updates
  MatchesJoinScreenState copyWith({
    List<Match>? matches,
    bool? isLoading,
    bool? hasError,
    String? Function()? errorMessage,
    String? selectedSport,
    String? searchQuery,
    String? Function()? highlightId,
    Map<String, String>? matchInviteStatuses,
  }) {
    return MatchesJoinScreenState(
      matches: matches ?? this.matches,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      selectedSport: selectedSport ?? this.selectedSport,
      searchQuery: searchQuery ?? this.searchQuery,
      highlightId: highlightId != null ? highlightId() : this.highlightId,
      matchInviteStatuses: matchInviteStatuses ?? this.matchInviteStatuses,
    );
  }

  /// Helper to update invite statuses
  MatchesJoinScreenState updateInviteStatuses(Map<String, String> statuses) {
    return copyWith(matchInviteStatuses: statuses);
  }

  /// Helper to remove a match (for optimistic updates)
  MatchesJoinScreenState removeMatch(String matchId) {
    return copyWith(
      matches: matches.where((g) => g.id != matchId).toList(),
    );
  }
}
