import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/games/models/game.dart';
import 'package:move_young/features/games/notifiers/games_join_screen_state.dart';
import 'package:move_young/features/games/services/cloud_games_provider.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/services/firebase_error_handler.dart';
import 'package:move_young/utils/logger.dart';

/// Notifier for managing games join screen state
/// Handles game loading, filtering, and invite status caching
class GamesJoinScreenNotifier extends StateNotifier<GamesJoinScreenState> {
  final Ref _ref;

  GamesJoinScreenNotifier(this._ref, String? highlightGameId)
      : super(GamesJoinScreenState.initial(highlightGameId));

  /// Load games with current filters applied
  Future<void> loadGames() async {
    state = state.copyWith(
      isLoading: true,
      hasError: false,
      errorMessage: () => null,
    );

    try {
      final cloudGamesService = _ref.read(cloudGamesServiceProvider);
      List<Game> games = await cloudGamesService.getJoinableGames();
      final now = DateTime.now();
      games = games
          .where((g) => g.dateTime.isAfter(now) && g.isActive)
          .toList();

      // Apply sport filter
      if (state.selectedSport != 'all') {
        games = games.where((g) => g.sport == state.selectedSport).toList();
      }

      // Apply search filter
      if (state.searchQuery.isNotEmpty) {
        games = games.where((game) {
          final q = state.searchQuery.toLowerCase();
          return game.location.toLowerCase().contains(q) ||
              game.organizerName.toLowerCase().contains(q);
        }).toList();
      }

      // Exclude games already joined by current user
      final String? myUid = _ref.read(currentUserIdProvider);
      if (myUid != null && myUid.isNotEmpty) {
        games = games.where((g) => !g.players.contains(myUid)).toList();
      }

      // Fetch invite statuses for all games in parallel
      Map<String, String> inviteStatuses = {};
      if (myUid != null && myUid.isNotEmpty && games.isNotEmpty) {
        final cloudGamesActions = _ref.read(cloudGamesActionsProvider);
        final inviteStatusFutures = games.map((game) async {
          final status =
              await cloudGamesActions.getUserInviteStatusForGame(game.id);
          return MapEntry(game.id, status);
        });
        final results = await Future.wait(inviteStatusFutures);

        for (final entry in results) {
          if (entry.value != null) {
            inviteStatuses[entry.key] = entry.value!;
          }
        }
      }

      state = state.copyWith(
        games: games,
        isLoading: false,
        hasError: false,
        gameInviteStatuses: inviteStatuses,
      );
    } catch (e, stack) {
      NumberedLogger.e('Error loading games: $e\n$stack');
      final errorMsg = FirebaseErrorHandler.getUserMessage(e);
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: () => errorMsg,
      );
    }
  }

  /// Set selected sport filter and reload games
  void setSelectedSport(String sport) {
    state = state.copyWith(selectedSport: sport);
    loadGames();
  }

  /// Set search query and reload games
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadGames();
  }

  /// Clear highlight ID
  void clearHighlightId() {
    state = state.copyWith(highlightId: () => null);
  }

  /// Remove a game from the list (for optimistic updates)
  void removeGame(String gameId) {
    state = state.removeGame(gameId);
  }
}

/// Provider for games join screen notifier
final gamesJoinScreenNotifierProvider =
    StateNotifierProvider.autoDispose.family<GamesJoinScreenNotifier,
        GamesJoinScreenState, String?>((ref, highlightGameId) {
  return GamesJoinScreenNotifier(ref, highlightGameId);
});

