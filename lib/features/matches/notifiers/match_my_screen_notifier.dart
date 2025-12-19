import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/matches/models/match.dart';
import 'package:move_young/features/matches/notifiers/match_my_screen_state.dart';
import 'package:move_young/features/matches/services/match_provider.dart';
import 'package:move_young/services/external/weather_provider.dart';
import 'package:move_young/features/friends/services/friends_provider.dart';
import 'package:move_young/services/calendar/calendar_service.dart';
import 'package:move_young/models/infrastructure/cached_data.dart';
import 'package:move_young/utils/logger.dart';

/// Notifier for managing matches my screen state
/// Handles weather caching, calendar status caching, and profile caching
class MatchesMyScreenNotifier extends StateNotifier<MatchesMyScreenState> {
  final Ref _ref;

  MatchesMyScreenNotifier(this._ref, String? highlightMatchId)
      : super(MatchesMyScreenState.initial(highlightMatchId));

  /// Safely update state, ignoring errors if notifier is disposed
  void _safeUpdateState(
      MatchesMyScreenState Function(MatchesMyScreenState) updater) {
    try {
      state = updater(state);
    } on StateError catch (e) {
      // Ignore errors if notifier is disposed (e.g., user navigated away)
      if (e.message.contains('dispose') || e.message.contains('mounted')) {
        return;
      }
      rethrow;
    } catch (e) {
      // Catch any other errors that might indicate disposed state
      final errorStr = e.toString();
      if (errorStr.contains('dispose') || errorStr.contains('mounted')) {
        return;
      }
      rethrow;
    }
  }

  /// Clear highlight ID
  void clearHighlightId() {
    state = state.copyWith(highlightId: () => null);
  }

  /// Pre-load calendar statuses for all matches from database
  /// Moved to isolate to avoid blocking main thread
  Future<void> preloadCalendarStatuses() async {
    if (state.calendarPreloadInProgress) return;

    _safeUpdateState((s) => s.copyWith(calendarPreloadInProgress: true));

    // Defer heavy operation to avoid blocking UI
    Future.microtask(() async {
      try {
        // Ensure CalendarService is initialized
        await CalendarService.initialize();

        // Get all matches from providers
        final myMatchesAsync = _ref.read(myMatchesProvider);
        final historicMatchesAsync = _ref.read(historicMatchesProvider);

        // Collect all match IDs from all tabs
        final allMatchIds = <String>{};

        // Get matches from myMatchesAsync if available
        final myMatches = myMatchesAsync.valueOrNull;
        if (myMatches != null) {
          for (final match in myMatches) {
            allMatchIds.add(match.id);
          }
        }

        // Get matches from historicMatchesAsync if available
        final historicMatches = historicMatchesAsync.valueOrNull;
        if (historicMatches != null) {
          for (final match in historicMatches) {
            allMatchIds.add(match.id);
          }
        }

        // Batch check calendar status for all matches
        if (allMatchIds.isEmpty) {
          _safeUpdateState((s) => s.copyWith(calendarPreloadInProgress: false));
          return;
        }

        // Get all matches that are in calendar from database
        final matchesInCalendar =
            await CalendarService.getAllMatchesInCalendar();
        final matchesInCalendarSet = matchesInCalendar.toSet();

        // Update cache for all matches
        final statuses = <String, bool>{};
        for (final matchId in allMatchIds) {
          statuses[matchId] = matchesInCalendarSet.contains(matchId);
        }
        _safeUpdateState((s) => s
            .updateCalendarStatuses(statuses)
            .copyWith(calendarPreloadInProgress: false));

        NumberedLogger.i(
            'Preloaded calendar statuses for ${allMatchIds.length} matches (${matchesInCalendarSet.length} in calendar)');
      } catch (e, stackTrace) {
        NumberedLogger.e('Error preloading calendar statuses: $e');
        NumberedLogger.d('Stack trace: $stackTrace');
        // Non-critical, continue without cache
        _safeUpdateState((s) => s.copyWith(calendarPreloadInProgress: false));
      }
    });
  }

  /// Check calendar status for a match (cached)
  Future<bool?> getCalendarStatus(String matchId) async {
    // Return cached status if available
    if (state.calendarStatusByMatchId.containsKey(matchId)) {
      return state.calendarStatusByMatchId[matchId];
    }

    // Check if already loading
    if (state.calendarLoading.contains(matchId)) {
      return null; // Still loading
    }

    // Start loading
    state = state.copyWith(
      calendarLoading: {...state.calendarLoading, matchId},
      calendarStatusByMatchId: {
        ...state.calendarStatusByMatchId,
        matchId: null, // Mark as checking
      },
    );

    try {
      // Ensure CalendarService is initialized
      await CalendarService.initialize();

      final isInCalendar = await CalendarService.isMatchInCalendar(matchId);
      _safeUpdateState(
          (s) => s.updateCalendarStatus(matchId, isInCalendar).copyWith(
                calendarLoading: {
                  ...s.calendarLoading..remove(matchId),
                },
              ));
      return isInCalendar;
    } catch (e, stackTrace) {
      NumberedLogger.e('Error checking calendar status: $e');
      NumberedLogger.d('Stack trace: $stackTrace');
      _safeUpdateState((s) => s
              .updateCalendarStatus(matchId, false) // Default to false on error
              .copyWith(
            calendarLoading: {
              ...s.calendarLoading..remove(matchId),
            },
          ));
      return false;
    }
  }

  /// Load missing profiles in the background and update cache
  Future<void> loadMissingProfiles(List<String> uids) async {
    if (uids.isEmpty) return;

    // Filter out already cached or loading profiles
    final missing = uids
        .where((uid) =>
            !state.profileCache.containsKey(uid) &&
            !state.profileLoading.contains(uid))
        .toList();

    if (missing.isEmpty) return;

    // Mark as loading
    state = state.copyWith(
      profileLoading: {...state.profileLoading, ...missing},
    );

    // Load in background
    final results = await Future.wait(
      missing.map((uid) async {
        try {
          final friendsActions = _ref.read(friendsActionsProvider);
          final profile = await friendsActions.fetchMinimalProfile(uid);
          return MapEntry(uid, profile);
        } catch (e) {
          // Cache placeholder on error to avoid retrying
          return MapEntry(
            uid,
            <String, String?>{
              'uid': uid,
              'displayName': null,
            },
          );
        }
      }),
    );

    // Update cache
    final profiles = Map<String, Map<String, String?>>.fromEntries(results);
    _safeUpdateState((s) => s.updateProfiles(profiles).copyWith(
          profileLoading: {
            ...s.profileLoading..removeAll(missing),
          },
        ));
  }

  /// Ensure weather data is loaded for a match (cached with TTL)
  Future<void> ensureWeatherForMatch(Match match) async {
    if (match.latitude == null || match.longitude == null) return;
    final key = match.id;

    // Check if we have valid cached data (not expired)
    final cached = state.weatherByMatchId[key];
    if (cached != null && !cached.isExpired) {
      return; // Already have fresh data
    }

    if (state.weatherLoading.contains(key)) return;

    _safeUpdateState((s) => s.copyWith(
          weatherLoading: {...s.weatherLoading, key},
        ));

    try {
      final weatherActions = _ref.read(weatherActionsProvider);
      final map = await weatherActions.fetchWeatherForDate(
        date: match.dateTime,
        latitude: match.latitude!,
        longitude: match.longitude!,
      );
      // Cache with TTL
      final cachedData = CachedData(
        map,
        DateTime.now(),
        expiry: MatchesMyScreenState.weatherCacheTTL,
      );
      _safeUpdateState((s) => s.updateWeatherCache(key, cachedData).copyWith(
            weatherLoading: {
              ...s.weatherLoading..remove(key),
            },
          ));
    } catch (e) {
      NumberedLogger.e('Error fetching weather for match ${match.id}: $e');
      _safeUpdateState((s) => s.copyWith(
            weatherLoading: {
              ...s.weatherLoading..remove(key),
            },
          ));
    }
  }

  /// Get weather data for a match (from cache)
  Map<String, String>? getWeatherForMatch(String matchId) {
    final cached = state.weatherByMatchId[matchId];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }
    return null;
  }

  /// Get profile data for a user (from cache)
  Map<String, String?>? getProfile(String uid) {
    return state.profileCache[uid];
  }

  /// Check if calendar preload is needed based on match IDs
  bool needsCalendarPreload(Set<String> matchIds) {
    return state.calendarStatusByMatchId.isEmpty ||
        matchIds.any((id) => !state.calendarStatusByMatchId.containsKey(id));
  }

  /// Update calendar status for a specific match (used when adding/removing from calendar)
  void updateCalendarStatus(String matchId, bool status) {
    state = state.updateCalendarStatus(matchId, status);
  }
}

/// Provider for matches my screen notifier
final matchesMyScreenNotifierProvider = StateNotifierProvider.autoDispose
    .family<MatchesMyScreenNotifier, MatchesMyScreenState, String?>(
        (ref, highlightMatchId) {
  return MatchesMyScreenNotifier(ref, highlightMatchId);
});
