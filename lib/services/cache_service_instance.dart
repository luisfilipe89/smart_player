// lib/services/cache_service_instance.dart
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Instance-based CacheService for use with Riverpod dependency injection
class CacheServiceInstance {
  Database? _database;
  static const String _userProfilesTable = 'cached_user_profiles';
  static const String _gameDetailsTable = 'cached_game_details';

  // TTL settings
  static const Duration _userProfileTTL = Duration(hours: 1);
  static const Duration _gameDetailsTTL = Duration(minutes: 30);

  CacheServiceInstance();

  /// Initialize the cache database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      String path = join(await getDatabasesPath(), 'cache.db');
      final db = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
      );
      return db;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create user profiles cache table
    await db.execute('''
      CREATE TABLE $_userProfilesTable(
        uid TEXT PRIMARY KEY,
        displayName TEXT,
        photoURL TEXT,
        email TEXT,
        lastUpdated INTEGER NOT NULL
      )
    ''');

    // Create game details cache table
    await db.execute('''
      CREATE TABLE $_gameDetailsTable(
        gameId TEXT PRIMARY KEY,
        details TEXT NOT NULL,
        lastUpdated INTEGER NOT NULL
      )
    ''');
  }

  /// Cache user profile data
  Future<void> cacheUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      final db = await database;
      await db.insert(
        _userProfilesTable,
        {
          'uid': uid,
          'displayName': data['displayName'],
          'photoURL': data['photoURL'],
          'email': data['email'],
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // Cache failures should not break the app
      debugPrint('Failed to cache user profile: $e');
    }
  }

  /// Get cached user profile if not expired
  Future<Map<String, dynamic>?> getCachedUserProfile(String uid) async {
    try {
      final db = await database;
      final result = await db.query(
        _userProfilesTable,
        where: 'uid = ?',
        whereArgs: [uid],
      );

      if (result.isEmpty) return null;

      final profile = result.first;
      final lastUpdated =
          DateTime.fromMillisecondsSinceEpoch(profile['lastUpdated'] as int);
      final now = DateTime.now();

      // Check if cache is expired
      if (now.difference(lastUpdated) > _userProfileTTL) {
        // Remove expired cache
        await db.delete(
          _userProfilesTable,
          where: 'uid = ?',
          whereArgs: [uid],
        );
        return null;
      }

      return {
        'uid': profile['uid'],
        'displayName': profile['displayName'],
        'photoURL': profile['photoURL'],
        'email': profile['email'],
      };
    } catch (e) {
      debugPrint('Failed to get cached user profile: $e');
      return null;
    }
  }

  /// Cache game details
  Future<void> cacheGameDetails(
      String gameId, Map<String, dynamic> data) async {
    try {
      final db = await database;
      await db.insert(
        _gameDetailsTable,
        {
          'gameId': gameId,
          'details': jsonEncode(data),
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Failed to cache game details: $e');
    }
  }

  /// Get cached game details if not expired
  Future<Map<String, dynamic>?> getCachedGameDetails(String gameId) async {
    try {
      final db = await database;
      final result = await db.query(
        _gameDetailsTable,
        where: 'gameId = ?',
        whereArgs: [gameId],
      );

      if (result.isEmpty) return null;

      final game = result.first;
      final lastUpdated =
          DateTime.fromMillisecondsSinceEpoch(game['lastUpdated'] as int);
      final now = DateTime.now();

      // Check if cache is expired
      if (now.difference(lastUpdated) > _gameDetailsTTL) {
        // Remove expired cache
        await db.delete(
          _gameDetailsTable,
          where: 'gameId = ?',
          whereArgs: [gameId],
        );
        return null;
      }

      return jsonDecode(game['details'] as String);
    } catch (e) {
      debugPrint('Failed to get cached game details: $e');
      return null;
    }
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    try {
      final db = await database;
      final now = DateTime.now();

      // Clear expired user profiles
      await db.delete(
        _userProfilesTable,
        where: 'lastUpdated < ?',
        whereArgs: [now.subtract(_userProfileTTL).millisecondsSinceEpoch],
      );

      // Clear expired game details
      await db.delete(
        _gameDetailsTable,
        where: 'lastUpdated < ?',
        whereArgs: [now.subtract(_gameDetailsTTL).millisecondsSinceEpoch],
      );
    } catch (e) {
      debugPrint('Failed to clear expired cache: $e');
    }
  }

  /// Clear all cache
  Future<void> clearAllCache() async {
    try {
      final db = await database;
      await db.delete(_userProfilesTable);
      await db.delete(_gameDetailsTable);
    } catch (e) {
      debugPrint('Failed to clear all cache: $e');
    }
  }

  /// Get cache size in bytes (approximate)
  Future<int> getCacheSize() async {
    try {
      final db = await database;
      final userProfilesCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_userProfilesTable',
      );
      final gameDetailsCount = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_gameDetailsTable',
      );

      final userProfilesSize =
          (userProfilesCount.first['count'] as int) * 100; // Approximate
      final gameDetailsSize =
          (gameDetailsCount.first['count'] as int) * 500; // Approximate

      return userProfilesSize + gameDetailsSize;
    } catch (e) {
      debugPrint('Failed to get cache size: $e');
      return 0;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _database?.close();
    _database = null;
  }
}
