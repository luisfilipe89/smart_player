// lib/providers/services/cache_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cache_service_instance.dart';
import '../../providers/infrastructure/shared_preferences_provider.dart';
import '../../config/cache_config.dart';

// CacheService provider with dependency injection
// Note: Returns null if SharedPreferences is not initialized yet
final cacheServiceProvider = Provider<CacheServiceInstance?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final config = ref.watch(cacheConfigProvider);
  if (prefs == null) return null;
  return CacheServiceInstance(prefs, config);
});

// Cache statistics provider (reactive)
final cacheStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final cacheService = ref.watch(cacheServiceProvider);
  if (cacheService == null) {
    return {
      'userProfilesCount': 0,
      'gameDetailsCount': 0,
      'totalCacheEntries': 0,
    };
  }
  return await cacheService.getCacheStats();
});

// Helper class for cache actions
class CacheActions {
  final CacheServiceInstance? _cacheService;

  CacheActions(this._cacheService);

  Future<void> cacheUserProfile(String uid, Map<String, dynamic> data) async {
    await _cacheService?.cacheUserProfile(uid, data);
  }

  Future<Map<String, dynamic>?> getCachedUserProfile(String uid) async {
    return await _cacheService?.getCachedUserProfile(uid);
  }

  Future<void> cacheUserProfiles(
      Map<String, Map<String, dynamic>> profiles) async {
    await _cacheService?.cacheUserProfiles(profiles);
  }

  Future<Map<String, Map<String, dynamic>>> getCachedUserProfiles(
      List<String> uids) async {
    final service = _cacheService;
    if (service == null) return {};
    return await service.getCachedUserProfiles(uids);
  }

  Future<void> cacheGameDetails(
      String gameId, Map<String, dynamic> data) async {
    await _cacheService?.cacheGameDetails(gameId, data);
  }

  Future<Map<String, dynamic>?> getCachedGameDetails(String gameId) async {
    return await _cacheService?.getCachedGameDetails(gameId);
  }

  Future<void> cachePublicGames(List<Map<String, dynamic>> games) async {
    await _cacheService?.cachePublicGames(games);
  }

  Future<List<Map<String, dynamic>>?> getCachedPublicGames() async {
    return await _cacheService?.getCachedPublicGames();
  }

  Future<void> clearExpiredCache() async {
    await _cacheService?.clearExpiredCache();
  }

  Future<void> clearAllCache() async {
    await _cacheService?.clearAllCache();
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    final service = _cacheService;
    if (service == null) {
      return {
        'userProfilesCount': 0,
        'gameDetailsCount': 0,
        'totalCacheEntries': 0,
      };
    }
    return await service.getCacheStats();
  }
}

// Cache actions provider (for cache operations)
final cacheActionsProvider = Provider<CacheActions>((ref) {
  final cacheService = ref.watch(cacheServiceProvider);
  return CacheActions(cacheService);
});
