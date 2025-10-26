import '../models/infrastructure/cached_data.dart';

/// Mixin providing reusable cache functionality for services
mixin CacheMixin<T> {
  /// Cache storage
  final Map<String, CachedData<T>> _cache = {};

  /// Gets cached data or fetches and caches if expired/missing
  ///
  /// [key] - Unique cache key
  /// [fetch] - Function to fetch fresh data if cache is expired/missing
  /// [ttl] - Time to live for cached data (default: 5 minutes)
  Future<T> getCached(
    String key,
    Future<T> Function() fetch, {
    Duration ttl = const Duration(minutes: 5),
  }) async {
    // Check if cached data exists and is still valid
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    // Fetch fresh data
    final data = await fetch();

    // Store in cache
    _cache[key] = CachedData(data, DateTime.now());

    return data;
  }

  /// Invalidates a specific cache entry
  void invalidateCache(String key) {
    _cache.remove(key);
  }

  /// Clears all expired cache entries
  void clearExpiredCache() {
    _cache.removeWhere((_, value) => value.isExpired);
  }

  /// Clears all cache entries
  void clearCache() {
    _cache.clear();
  }

  /// Gets cache info for debugging
  Map<String, dynamic> getCacheInfo() {
    return {
      'totalEntries': _cache.length,
      'expiredEntries': _cache.values.where((v) => v.isExpired).length,
    };
  }
}
