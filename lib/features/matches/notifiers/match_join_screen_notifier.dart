import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/matches/models/match.dart';
import 'package:move_young/features/matches/notifiers/match_join_screen_state.dart';
import 'package:move_young/features/matches/services/cloud_matches_provider.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/services/firebase_error_handler.dart';
import 'package:move_young/utils/logger.dart';

/// Notifier for managing matches join screen state
/// Handles match loading, filtering, and invite status caching
class MatchesJoinScreenNotifier extends StateNotifier<MatchesJoinScreenState> {
  final Ref _ref;

  MatchesJoinScreenNotifier(this._ref, String? highlightMatchId)
      : super(MatchesJoinScreenState.initial(highlightMatchId));

  /// Load matches with current filters applied
  Future<void> loadMatches() async {
    state = state.copyWith(
      isLoading: true,
      hasError: false,
      errorMessage: () => null,
    );

    try {
      final cloudMatchesService = _ref.read(cloudMatchesServiceProvider);
      List<Match> matches = await cloudMatchesService.getJoinableMatches();
      final now = DateTime.now();
      matches =
          matches.where((g) => g.dateTime.isAfter(now) && g.isActive).toList();

      // Apply sport filter
      if (state.selectedSport != 'all') {
        matches = matches.where((g) => g.sport == state.selectedSport).toList();
      }

      // Apply search filter
      if (state.searchQuery.isNotEmpty) {
        matches = matches.where((match) {
          final q = state.searchQuery.toLowerCase();
          return match.location.toLowerCase().contains(q) ||
              match.organizerName.toLowerCase().contains(q);
        }).toList();
      }

      // Exclude matches already joined by current user
      final String? myUid = _ref.read(currentUserIdProvider);
      if (myUid != null && myUid.isNotEmpty) {
        matches = matches.where((g) => !g.players.contains(myUid)).toList();
      }

      // Fetch invite statuses for all matches in parallel
      Map<String, String> inviteStatuses = {};
      if (myUid != null && myUid.isNotEmpty && matches.isNotEmpty) {
        final cloudMatchesActions = _ref.read(cloudMatchesActionsProvider);
        final inviteStatusFutures = matches.map((match) async {
          final status =
              await cloudMatchesActions.getUserInviteStatusForMatch(match.id);
          return MapEntry(match.id, status);
        });
        final results = await Future.wait(inviteStatusFutures);

        for (final entry in results) {
          if (entry.value != null) {
            inviteStatuses[entry.key] = entry.value!;
          }
        }
      }

      state = state.copyWith(
        matches: matches,
        isLoading: false,
        hasError: false,
        matchInviteStatuses: inviteStatuses,
      );
    } catch (e, stack) {
      NumberedLogger.e('Error loading matches: $e\n$stack');
      final errorMsg = FirebaseErrorHandler.getUserMessage(e);
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: () => errorMsg,
      );
    }
  }

  /// Set selected sport filter and reload matches
  void setSelectedSport(String sport) {
    state = state.copyWith(selectedSport: sport);
    loadMatches();
  }

  /// Set search query and reload matches
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadMatches();
  }

  /// Clear highlight ID
  void clearHighlightId() {
    state = state.copyWith(highlightId: () => null);
  }

  /// Remove a match from the list (for optimistic updates)
  void removeMatch(String matchId) {
    state = state.removeMatch(matchId);
  }
}

/// Provider for matches join screen notifier
final matchesJoinScreenNotifierProvider = StateNotifierProvider.autoDispose
    .family<MatchesJoinScreenNotifier, MatchesJoinScreenState, String?>(
        (ref, highlightMatchId) {
  return MatchesJoinScreenNotifier(ref, highlightMatchId);
});
