import 'package:flutter/foundation.dart';
import 'package:move_young/features/games/models/game.dart';

/// Immutable state class for the games join screen
@immutable
class GamesJoinScreenState {
  final List<Game> games;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final String selectedSport;
  final String searchQuery;
  final String? highlightId;
  final Map<String, String> gameInviteStatuses;

  const GamesJoinScreenState({
    this.games = const [],
    this.isLoading = false,
    this.hasError = false,
    this.errorMessage,
    this.selectedSport = 'all',
    this.searchQuery = '',
    this.highlightId,
    this.gameInviteStatuses = const {},
  });

  /// Create initial state
  factory GamesJoinScreenState.initial(String? highlightGameId) {
    return GamesJoinScreenState(
      highlightId: highlightGameId,
    );
  }

  /// Copy with method for immutable updates
  GamesJoinScreenState copyWith({
    List<Game>? games,
    bool? isLoading,
    bool? hasError,
    String? Function()? errorMessage,
    String? selectedSport,
    String? searchQuery,
    String? Function()? highlightId,
    Map<String, String>? gameInviteStatuses,
  }) {
    return GamesJoinScreenState(
      games: games ?? this.games,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
      selectedSport: selectedSport ?? this.selectedSport,
      searchQuery: searchQuery ?? this.searchQuery,
      highlightId: highlightId != null ? highlightId() : this.highlightId,
      gameInviteStatuses: gameInviteStatuses ?? this.gameInviteStatuses,
    );
  }

  /// Helper to update invite statuses
  GamesJoinScreenState updateInviteStatuses(Map<String, String> statuses) {
    return copyWith(gameInviteStatuses: statuses);
  }

  /// Helper to remove a game (for optimistic updates)
  GamesJoinScreenState removeGame(String gameId) {
    return copyWith(
      games: games.where((g) => g.id != gameId).toList(),
    );
  }
}

