import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/games/models/game.dart';
import 'package:move_young/features/games/notifiers/games_my_screen_state.dart';
import 'package:move_young/features/games/services/games_provider.dart';
import 'package:move_young/services/external/weather_provider.dart';
import 'package:move_young/features/friends/services/friends_provider.dart';
import 'package:move_young/services/calendar/calendar_service.dart';
import 'package:move_young/models/infrastructure/cached_data.dart';
import 'package:move_young/utils/logger.dart';

/// Notifier for managing games my screen state
/// Handles weather caching, calendar status caching, and profile caching
class GamesMyScreenNotifier extends StateNotifier<GamesMyScreenState> {
  final Ref _ref;

  GamesMyScreenNotifier(this._ref, String? highlightGameId)
      : super(GamesMyScreenState.initial(highlightGameId));

  /// Safely update state, ignoring errors if notifier is disposed
  void _safeUpdateState(GamesMyScreenState Function(GamesMyScreenState) updater) {
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

  /// Pre-load calendar statuses for all games from database
  /// Moved to isolate to avoid blocking main thread
  Future<void> preloadCalendarStatuses() async {
    if (state.calendarPreloadInProgress) return;

    _safeUpdateState((s) => s.copyWith(calendarPreloadInProgress: true));

    // Defer heavy operation to avoid blocking UI
    Future.microtask(() async {
      try {
        // Ensure CalendarService is initialized
        await CalendarService.initialize();

        // Get all games from providers
        final myGamesAsync = _ref.read(myGamesProvider);
        final historicGamesAsync = _ref.read(historicGamesProvider);

        // Collect all game IDs from all tabs
        final allGameIds = <String>{};

        // Get games from myGamesAsync if available
        final myGames = myGamesAsync.valueOrNull;
        if (myGames != null) {
          for (final game in myGames) {
            allGameIds.add(game.id);
          }
        }

        // Get games from historicGamesAsync if available
        final historicGames = historicGamesAsync.valueOrNull;
        if (historicGames != null) {
          for (final game in historicGames) {
            allGameIds.add(game.id);
          }
        }

        // Batch check calendar status for all games
        if (allGameIds.isEmpty) {
          _safeUpdateState((s) => s.copyWith(calendarPreloadInProgress: false));
          return;
        }

        // Get all games that are in calendar from database
        final gamesInCalendar = await CalendarService.getAllGamesInCalendar();
        final gamesInCalendarSet = gamesInCalendar.toSet();

        // Update cache for all games
        final statuses = <String, bool>{};
        for (final gameId in allGameIds) {
          statuses[gameId] = gamesInCalendarSet.contains(gameId);
        }
        _safeUpdateState((s) => s
            .updateCalendarStatuses(statuses)
            .copyWith(calendarPreloadInProgress: false));

        NumberedLogger.i(
            'Preloaded calendar statuses for ${allGameIds.length} games (${gamesInCalendarSet.length} in calendar)');
      } catch (e, stackTrace) {
        NumberedLogger.e('Error preloading calendar statuses: $e');
        NumberedLogger.d('Stack trace: $stackTrace');
        // Non-critical, continue without cache
        _safeUpdateState((s) => s.copyWith(calendarPreloadInProgress: false));
      }
    });
  }

  /// Check calendar status for a game (cached)
  Future<bool?> getCalendarStatus(String gameId) async {
    // Return cached status if available
    if (state.calendarStatusByGameId.containsKey(gameId)) {
      return state.calendarStatusByGameId[gameId];
    }

    // Check if already loading
    if (state.calendarLoading.contains(gameId)) {
      return null; // Still loading
    }

    // Start loading
    state = state.copyWith(
      calendarLoading: {...state.calendarLoading, gameId},
      calendarStatusByGameId: {
        ...state.calendarStatusByGameId,
        gameId: null, // Mark as checking
      },
    );

    try {
      // Ensure CalendarService is initialized
      await CalendarService.initialize();

      final isInCalendar = await CalendarService.isGameInCalendar(gameId);
      _safeUpdateState((s) => s.updateCalendarStatus(gameId, isInCalendar).copyWith(
        calendarLoading: {
          ...s.calendarLoading..remove(gameId),
        },
      ));
      return isInCalendar;
    } catch (e, stackTrace) {
      NumberedLogger.e('Error checking calendar status: $e');
      NumberedLogger.d('Stack trace: $stackTrace');
      _safeUpdateState((s) => s
          .updateCalendarStatus(gameId, false) // Default to false on error
          .copyWith(
        calendarLoading: {
          ...s.calendarLoading..remove(gameId),
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

  /// Ensure weather data is loaded for a game (cached with TTL)
  Future<void> ensureWeatherForGame(Game game) async {
    if (game.latitude == null || game.longitude == null) return;
    final key = game.id;

    // Check if we have valid cached data (not expired)
    final cached = state.weatherByGameId[key];
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
        date: game.dateTime,
        latitude: game.latitude!,
        longitude: game.longitude!,
      );
      // Cache with TTL
      final cachedData = CachedData(
        map,
        DateTime.now(),
        expiry: GamesMyScreenState.weatherCacheTTL,
      );
      _safeUpdateState((s) => s.updateWeatherCache(key, cachedData).copyWith(
        weatherLoading: {
          ...s.weatherLoading..remove(key),
        },
      ));
    } catch (e) {
      NumberedLogger.e('Error fetching weather for game ${game.id}: $e');
      _safeUpdateState((s) => s.copyWith(
        weatherLoading: {
          ...s.weatherLoading..remove(key),
        },
      ));
    }
  }

  /// Get weather data for a game (from cache)
  Map<String, String>? getWeatherForGame(String gameId) {
    final cached = state.weatherByGameId[gameId];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }
    return null;
  }

  /// Get profile data for a user (from cache)
  Map<String, String?>? getProfile(String uid) {
    return state.profileCache[uid];
  }

  /// Check if calendar preload is needed based on game IDs
  bool needsCalendarPreload(Set<String> gameIds) {
    return state.calendarStatusByGameId.isEmpty ||
        gameIds.any((id) => !state.calendarStatusByGameId.containsKey(id));
  }

  /// Update calendar status for a specific game (used when adding/removing from calendar)
  void updateCalendarStatus(String gameId, bool status) {
    state = state.updateCalendarStatus(gameId, status);
  }
}

/// Provider for games my screen notifier
final gamesMyScreenNotifierProvider = StateNotifierProvider.autoDispose
    .family<GamesMyScreenNotifier, GamesMyScreenState, String?>(
        (ref, highlightGameId) {
  return GamesMyScreenNotifier(ref, highlightGameId);
});
