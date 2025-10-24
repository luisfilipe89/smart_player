// lib/providers/services/cache_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cache_service_instance.dart';

// CacheService provider with dependency injection
final cacheServiceProvider = Provider<CacheServiceInstance>((ref) {
  return CacheServiceInstance();
});

// Cache statistics provider (reactive)
final cacheStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final cacheService = ref.watch(cacheServiceProvider);
  return await cacheService.getCacheStats();
});

// Helper class for cache actions
class CacheActions {
  final CacheServiceInstance _cacheService;

  CacheActions(this._cacheService);

  Future<void> cacheUserProfile(String uid, Map<String, dynamic> data) =>
      _cacheService.cacheUserProfile(uid, data);
  Future<Map<String, dynamic>?> getCachedUserProfile(String uid) =>
      _cacheService.getCachedUserProfile(uid);
  Future<void> cacheUserProfiles(Map<String, Map<String, dynamic>> profiles) =>
      _cacheService.cacheUserProfiles(profiles);
  Future<Map<String, Map<String, dynamic>>> getCachedUserProfiles(
          List<String> uids) =>
      _cacheService.getCachedUserProfiles(uids);
  Future<void> cacheGameDetails(String gameId, Map<String, dynamic> data) =>
      _cacheService.cacheGameDetails(gameId, data);
  Future<Map<String, dynamic>?> getCachedGameDetails(String gameId) =>
      _cacheService.getCachedGameDetails(gameId);
  Future<void> cachePublicGames(List<Map<String, dynamic>> games) =>
      _cacheService.cachePublicGames(games);
  Future<List<Map<String, dynamic>>?> getCachedPublicGames() =>
      _cacheService.getCachedPublicGames();
  Future<void> clearExpiredCache() => _cacheService.clearExpiredCache();
  Future<void> clearAllCache() => _cacheService.clearAllCache();
  Future<Map<String, dynamic>> getCacheStats() => _cacheService.getCacheStats();
}

// Cache actions provider (for cache operations)
final cacheActionsProvider = Provider<CacheActions>((ref) {
  final cacheService = ref.watch(cacheServiceProvider);
  return CacheActions(cacheService);
});
