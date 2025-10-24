// lib/providers/services/cache_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/services/cache_service_instance.dart';

// CacheService provider with dependency injection
final cacheServiceProvider = Provider<CacheServiceInstance>((ref) {
  return CacheServiceInstance();
});

// Cache size provider (reactive)
final cacheSizeProvider = FutureProvider.autoDispose<int>((ref) async {
  final cacheService = ref.watch(cacheServiceProvider);
  return await cacheService.getCacheSize();
});

// Helper class for cache actions
class CacheActions {
  final CacheServiceInstance _cacheService;

  CacheActions(this._cacheService);

  Future<void> cacheUserProfile(String uid, Map<String, dynamic> data) =>
      _cacheService.cacheUserProfile(uid, data);
  Future<Map<String, dynamic>?> getCachedUserProfile(String uid) =>
      _cacheService.getCachedUserProfile(uid);
  Future<void> cacheGameDetails(String gameId, Map<String, dynamic> data) =>
      _cacheService.cacheGameDetails(gameId, data);
  Future<Map<String, dynamic>?> getCachedGameDetails(String gameId) =>
      _cacheService.getCachedGameDetails(gameId);
  Future<void> clearExpiredCache() => _cacheService.clearExpiredCache();
  Future<void> clearAllCache() => _cacheService.clearAllCache();
  Future<int> getCacheSize() => _cacheService.getCacheSize();
}

// Cache actions provider (for cache operations)
final cacheActionsProvider = Provider<CacheActions>((ref) {
  final cacheService = ref.watch(cacheServiceProvider);
  return CacheActions(cacheService);
});
