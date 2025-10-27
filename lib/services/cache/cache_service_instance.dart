// lib/services/cache_service_instance.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter/foundation.dart' show debugPrint;
import 'package:move_young/utils/logger.dart';

/// Simple cache service using in-memory + SharedPreferences
/// No SQLite, no platform channels, works everywhere
class CacheServiceInstance {
  final SharedPreferences _prefs;

  // In-memory cache for faster access
  final Map<String, CachedEntry> _memoryCache = {};

  // TTL settings
  static const Duration _userProfileTTL = Duration(hours: 1);
  static const Duration _gameDetailsTTL = Duration(minutes: 30);
  static const Duration _publicGamesTTL = Duration(minutes: 5);

  CacheServiceInstance(this._prefs);

  /// Get cache key for SharedPreferences
  String _key(String prefix, String id) => 'cache_${prefix}_$id';

  /// Check if cached data is expired
  bool _isExpired(String key, Duration ttl) {
    final cached = _memoryCache[key];
    if (cached == null) return true;
    return DateTime.now().difference(cached.timestamp) > ttl;
  }

  /// Try to get from memory first, then SharedPreferences
  CachedEntry? _getEntry(String key, Duration ttl) {
    // Check memory cache first
    if (!_isExpired(key, ttl)) {
      return _memoryCache[key];
    }

    // Try SharedPreferences
    try {
      final data = _prefs.getString(key);
      final timestampStr = _prefs.getString('${key}_ts');

      if (data == null || timestampStr == null) return null;

      final timestamp = DateTime.parse(timestampStr);
      final entry = CachedEntry(data, timestamp);

      if (DateTime.now().difference(timestamp) > ttl) {
        _prefs.remove(key);
        _prefs.remove('${key}_ts');
        return null;
      }

      // Update memory cache
      _memoryCache[key] = entry;
      return entry;
    } catch (e) {
      NumberedLogger.w('Failed to read cache: $e');
      return null;
    }
  }

  /// Write to both memory and SharedPreferences
  Future<void> _setEntry(String key, String data) async {
    try {
      final now = DateTime.now();
      final entry = CachedEntry(data, now);

      // Update memory
      _memoryCache[key] = entry;

      // Update SharedPreferences
      await _prefs.setString(key, data);
      await _prefs.setString('${key}_ts', now.toIso8601String());
    } catch (e) {
      NumberedLogger.w('Failed to write cache: $e');
    }
  }

  /// Cache user profile data
  Future<void> cacheUserProfile(String uid, Map<String, dynamic> data) async {
    final key = _key('user_profile', uid);
    final json = jsonEncode(data);
    await _setEntry(key, json);
  }

  /// Get cached user profile if not expired
  Future<Map<String, dynamic>?> getCachedUserProfile(String uid) async {
    final key = _key('user_profile', uid);
    final entry = _getEntry(key, _userProfileTTL);

    if (entry == null) return null;

    try {
      return jsonDecode(entry.data) as Map<String, dynamic>;
    } catch (e) {
      NumberedLogger.w('Failed to decode cached profile: $e');
      return null;
    }
  }

  /// Cache multiple user profiles in batch
  Future<void> cacheUserProfiles(
      Map<String, Map<String, dynamic>> profiles) async {
    final batch = <String, String>{};
    final timestamp = DateTime.now().toIso8601String();

    for (final entry in profiles.entries) {
      final uid = entry.key;
      final data = entry.value;
      final key = _key('user_profile', uid);
      final json = jsonEncode(data);

      batch[key] = json;
      batch['${key}_ts'] = timestamp;
    }

    // Write all at once
    for (final keyValue in batch.entries) {
      try {
        await _prefs.setString(keyValue.key, keyValue.value);

        // Update memory
        final key = keyValue.key.replaceFirst('_ts', '');
        if (!keyValue.key.endsWith('_ts')) {
          _memoryCache[key] = CachedEntry(
            keyValue.value,
            DateTime.parse(timestamp),
          );
        }
      } catch (e) {
        NumberedLogger.w('Failed to batch cache: $e');
      }
    }
  }

  /// Get multiple cached user profiles
  Future<Map<String, Map<String, dynamic>>> getCachedUserProfiles(
      List<String> uids) async {
    final profiles = <String, Map<String, dynamic>>{};

    for (final uid in uids) {
      final profile = await getCachedUserProfile(uid);
      if (profile != null) {
        profiles[uid] = profile;
      }
    }

    return profiles;
  }

  /// Cache game details
  Future<void> cacheGameDetails(
      String gameId, Map<String, dynamic> details) async {
    final key = _key('game_details', gameId);
    final json = jsonEncode(details);
    await _setEntry(key, json);
  }

  /// Get cached game details if not expired
  Future<Map<String, dynamic>?> getCachedGameDetails(String gameId) async {
    final key = _key('game_details', gameId);
    final entry = _getEntry(key, _gameDetailsTTL);

    if (entry == null) return null;

    try {
      return jsonDecode(entry.data) as Map<String, dynamic>;
    } catch (e) {
      NumberedLogger.w('Failed to decode cached game: $e');
      return null;
    }
  }

  /// Cache public games list
  Future<void> cachePublicGames(List<Map<String, dynamic>> games) async {
    final key = 'cache_public_games';
    final json = jsonEncode(games);
    await _setEntry(key, json);
  }

  /// Get cached public games list if not expired
  Future<List<Map<String, dynamic>>?> getCachedPublicGames() async {
    const key = 'cache_public_games';
    final entry = _getEntry(key, _publicGamesTTL);

    if (entry == null) return null;

    try {
      final games = jsonDecode(entry.data) as List;
      return games.cast<Map<String, dynamic>>();
    } catch (e) {
      NumberedLogger.w('Failed to decode cached public games: $e');
      return null;
    }
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    // Check memory cache
    for (final entry in _memoryCache.entries) {
      final age = now.difference(entry.value.timestamp);
      if (age > _userProfileTTL &&
          age > _gameDetailsTTL &&
          age > _publicGamesTTL) {
        expiredKeys.add(entry.key);
      }
    }

    // Remove expired entries
    for (final key in expiredKeys) {
      _memoryCache.remove(key);

      // Remove from SharedPreferences too
      try {
        await _prefs.remove(key);
        await _prefs.remove('${key}_ts');
      } catch (e) {
        NumberedLogger.w('Failed to clear expired cache: $e');
      }
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    _memoryCache.clear();

    try {
      final keys = _prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('cache_')) {
          await _prefs.remove(key);
        }
      }
    } catch (e) {
      NumberedLogger.w('Failed to clear all cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final keys = _prefs.getKeys();
      int userProfilesCount = 0;
      int gameDetailsCount = 0;

      for (final key in keys) {
        if (key.contains('user_profile') && !key.endsWith('_ts')) {
          userProfilesCount++;
        } else if (key.contains('game_details') && !key.endsWith('_ts')) {
          gameDetailsCount++;
        }
      }

      return {
        'userProfilesCount': userProfilesCount,
        'gameDetailsCount': gameDetailsCount,
        'totalCacheEntries': userProfilesCount + gameDetailsCount,
      };
    } catch (e) {
      NumberedLogger.w('Failed to get cache stats: $e');
      return {
        'userProfilesCount': 0,
        'gameDetailsCount': 0,
        'totalCacheEntries': 0,
      };
    }
  }
}

/// In-memory cache entry with timestamp
class CachedEntry {
  final String data;
  final DateTime timestamp;

  CachedEntry(this.data, this.timestamp);
}
