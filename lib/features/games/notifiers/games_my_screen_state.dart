import 'package:flutter/foundation.dart';
import 'package:move_young/models/infrastructure/cached_data.dart';

/// Immutable state class for the games my screen
@immutable
class GamesMyScreenState {
  // Weather cache per gameId with TTL (1 hour expiry)
  final Map<String, CachedData<Map<String, String>>> weatherByGameId;
  final Set<String> weatherLoading;
  static const Duration weatherCacheTTL = Duration(hours: 1);

  // Calendar status cache per gameId: true = in calendar, false = not in calendar, null = checking
  final Map<String, bool?> calendarStatusByGameId;
  final Set<String> calendarLoading;
  final bool calendarPreloadInProgress;

  // Profile cache: uid -> profile data
  final Map<String, Map<String, String?>> profileCache;
  final Set<String> profileLoading;

  // Highlight ID for scrolling
  final String? highlightId;

  const GamesMyScreenState({
    this.weatherByGameId = const {},
    this.weatherLoading = const {},
    this.calendarStatusByGameId = const {},
    this.calendarLoading = const {},
    this.calendarPreloadInProgress = false,
    this.profileCache = const {},
    this.profileLoading = const {},
    this.highlightId,
  });

  /// Create initial state
  factory GamesMyScreenState.initial(String? highlightGameId) {
    return GamesMyScreenState(
      highlightId: highlightGameId,
    );
  }

  /// Copy with method for immutable updates
  GamesMyScreenState copyWith({
    Map<String, CachedData<Map<String, String>>>? weatherByGameId,
    Set<String>? weatherLoading,
    Map<String, bool?>? calendarStatusByGameId,
    Set<String>? calendarLoading,
    bool? calendarPreloadInProgress,
    Map<String, Map<String, String?>>? profileCache,
    Set<String>? profileLoading,
    String? Function()? highlightId,
  }) {
    return GamesMyScreenState(
      weatherByGameId: weatherByGameId ?? this.weatherByGameId,
      weatherLoading: weatherLoading ?? this.weatherLoading,
      calendarStatusByGameId:
          calendarStatusByGameId ?? this.calendarStatusByGameId,
      calendarLoading: calendarLoading ?? this.calendarLoading,
      calendarPreloadInProgress:
          calendarPreloadInProgress ?? this.calendarPreloadInProgress,
      profileCache: profileCache ?? this.profileCache,
      profileLoading: profileLoading ?? this.profileLoading,
      highlightId: highlightId != null ? highlightId() : this.highlightId,
    );
  }

  /// Helper to update weather cache for a specific game
  GamesMyScreenState updateWeatherCache(
    String gameId,
    CachedData<Map<String, String>>? cachedData,
  ) {
    final updated = Map<String, CachedData<Map<String, String>>>.from(
      weatherByGameId,
    );
    if (cachedData != null) {
      updated[gameId] = cachedData;
    } else {
      updated.remove(gameId);
    }
    return copyWith(weatherByGameId: updated);
  }

  /// Helper to update calendar status for a specific game
  GamesMyScreenState updateCalendarStatus(String gameId, bool? status) {
    final updated = Map<String, bool?>.from(calendarStatusByGameId);
    updated[gameId] = status;
    return copyWith(calendarStatusByGameId: updated);
  }

  /// Helper to update calendar statuses for multiple games
  GamesMyScreenState updateCalendarStatuses(Map<String, bool> statuses) {
    final updated = Map<String, bool?>.from(calendarStatusByGameId);
    updated.addAll(statuses.map((key, value) => MapEntry(key, value as bool?)));
    return copyWith(calendarStatusByGameId: updated);
  }

  /// Helper to update profile cache
  GamesMyScreenState updateProfileCache(
      String uid, Map<String, String?> profile) {
    final updated = Map<String, Map<String, String?>>.from(profileCache);
    updated[uid] = profile;
    return copyWith(profileCache: updated);
  }

  /// Helper to update multiple profiles
  GamesMyScreenState updateProfiles(
      Map<String, Map<String, String?>> profiles) {
    final updated = Map<String, Map<String, String?>>.from(profileCache);
    updated.addAll(profiles);
    return copyWith(profileCache: updated);
  }
}
