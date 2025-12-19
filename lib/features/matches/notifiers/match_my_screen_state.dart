import 'package:flutter/foundation.dart';
import 'package:move_young/models/infrastructure/cached_data.dart';

/// Immutable state class for the matches my screen
@immutable
class MatchesMyScreenState {
  // Weather cache per matchId with TTL (1 hour expiry)
  final Map<String, CachedData<Map<String, String>>> weatherByMatchId;
  final Set<String> weatherLoading;
  static const Duration weatherCacheTTL = Duration(hours: 1);

  // Calendar status cache per matchId: true = in calendar, false = not in calendar, null = checking
  final Map<String, bool?> calendarStatusByMatchId;
  final Set<String> calendarLoading;
  final bool calendarPreloadInProgress;

  // Profile cache: uid -> profile data
  final Map<String, Map<String, String?>> profileCache;
  final Set<String> profileLoading;

  // Highlight ID for scrolling
  final String? highlightId;

  const MatchesMyScreenState({
    this.weatherByMatchId = const {},
    this.weatherLoading = const {},
    this.calendarStatusByMatchId = const {},
    this.calendarLoading = const {},
    this.calendarPreloadInProgress = false,
    this.profileCache = const {},
    this.profileLoading = const {},
    this.highlightId,
  });

  /// Create initial state
  factory MatchesMyScreenState.initial(String? highlightMatchId) {
    return MatchesMyScreenState(
      highlightId: highlightMatchId,
    );
  }

  /// Copy with method for immutable updates
  MatchesMyScreenState copyWith({
    Map<String, CachedData<Map<String, String>>>? weatherByMatchId,
    Set<String>? weatherLoading,
    Map<String, bool?>? calendarStatusByMatchId,
    Set<String>? calendarLoading,
    bool? calendarPreloadInProgress,
    Map<String, Map<String, String?>>? profileCache,
    Set<String>? profileLoading,
    String? Function()? highlightId,
  }) {
    return MatchesMyScreenState(
      weatherByMatchId: weatherByMatchId ?? this.weatherByMatchId,
      weatherLoading: weatherLoading ?? this.weatherLoading,
      calendarStatusByMatchId:
          calendarStatusByMatchId ?? this.calendarStatusByMatchId,
      calendarLoading: calendarLoading ?? this.calendarLoading,
      calendarPreloadInProgress:
          calendarPreloadInProgress ?? this.calendarPreloadInProgress,
      profileCache: profileCache ?? this.profileCache,
      profileLoading: profileLoading ?? this.profileLoading,
      highlightId: highlightId != null ? highlightId() : this.highlightId,
    );
  }

  /// Helper to update weather cache for a specific match
  MatchesMyScreenState updateWeatherCache(
    String matchId,
    CachedData<Map<String, String>>? cachedData,
  ) {
    final updated = Map<String, CachedData<Map<String, String>>>.from(
      weatherByMatchId,
    );
    if (cachedData != null) {
      updated[matchId] = cachedData;
    } else {
      updated.remove(matchId);
    }
    return copyWith(weatherByMatchId: updated);
  }

  /// Helper to update calendar status for a specific match
  MatchesMyScreenState updateCalendarStatus(String matchId, bool? status) {
    final updated = Map<String, bool?>.from(calendarStatusByMatchId);
    updated[matchId] = status;
    return copyWith(calendarStatusByMatchId: updated);
  }

  /// Helper to update calendar statuses for multiple matches
  MatchesMyScreenState updateCalendarStatuses(Map<String, bool> statuses) {
    final updated = Map<String, bool?>.from(calendarStatusByMatchId);
    updated.addAll(statuses.map((key, value) => MapEntry(key, value as bool?)));
    return copyWith(calendarStatusByMatchId: updated);
  }

  /// Helper to update profile cache
  MatchesMyScreenState updateProfileCache(
      String uid, Map<String, String?> profile) {
    final updated = Map<String, Map<String, String?>>.from(profileCache);
    updated[uid] = profile;
    return copyWith(profileCache: updated);
  }

  /// Helper to update multiple profiles
  MatchesMyScreenState updateProfiles(
      Map<String, Map<String, String?>> profiles) {
    final updated = Map<String, Map<String, String?>>.from(profileCache);
    updated.addAll(profiles);
    return copyWith(profileCache: updated);
  }
}
