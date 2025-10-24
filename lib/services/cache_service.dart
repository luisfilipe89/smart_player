import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class CacheService {
  static Database? _database;
  static const String _userProfilesTable = 'cached_user_profiles';
  static const String _gameDetailsTable = 'cached_game_details';

  // TTL settings
  static const Duration _userProfileTTL = Duration(hours: 1);
  static const Duration _gameDetailsTTL = Duration(minutes: 30);
  static const Duration _publicGamesTTL = Duration(minutes: 5);

  /// Initialize the cache database
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
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

  static Future<void> _onCreate(Database db, int version) async {
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
  static Future<void> cacheUserProfile(
      String uid, Map<String, dynamic> data) async {
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
      print('Failed to cache user profile: $e');
    }
  }

  /// Get cached user profile if not expired
  static Future<Map<String, dynamic>?> getCachedUserProfile(String uid) async {
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
        'displayName': profile['displayName'],
        'photoURL': profile['photoURL'],
        'email': profile['email'],
      };
    } catch (e) {
      print('Failed to get cached user profile: $e');
      return null;
    }
  }

  /// Cache multiple user profiles in batch
  static Future<void> cacheUserProfiles(
      Map<String, Map<String, dynamic>> profiles) async {
    try {
      final db = await database;
      final batch = db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final entry in profiles.entries) {
        final uid = entry.key;
        final data = entry.value;

        batch.insert(
          _userProfilesTable,
          {
            'uid': uid,
            'displayName': data['displayName'],
            'photoURL': data['photoURL'],
            'email': data['email'],
            'lastUpdated': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit();
    } catch (e) {
      print('Failed to cache user profiles: $e');
    }
  }

  /// Get multiple cached user profiles
  static Future<Map<String, Map<String, dynamic>>> getCachedUserProfiles(
      List<String> uids) async {
    try {
      final db = await database;
      final placeholders = uids.map((_) => '?').join(',');
      final result = await db.query(
        _userProfilesTable,
        where: 'uid IN ($placeholders)',
        whereArgs: uids,
      );

      final profiles = <String, Map<String, dynamic>>{};
      final now = DateTime.now();
      final expiredUids = <String>[];

      for (final row in result) {
        final uid = row['uid'] as String;
        final lastUpdated =
            DateTime.fromMillisecondsSinceEpoch(row['lastUpdated'] as int);

        if (now.difference(lastUpdated) > _userProfileTTL) {
          expiredUids.add(uid);
        } else {
          profiles[uid] = {
            'displayName': row['displayName'],
            'photoURL': row['photoURL'],
            'email': row['email'],
          };
        }
      }

      // Remove expired entries
      if (expiredUids.isNotEmpty) {
        final expiredPlaceholders = expiredUids.map((_) => '?').join(',');
        await db.delete(
          _userProfilesTable,
          where: 'uid IN ($expiredPlaceholders)',
          whereArgs: expiredUids,
        );
      }

      return profiles;
    } catch (e) {
      print('Failed to get cached user profiles: $e');
      return {};
    }
  }

  /// Cache game details
  static Future<void> cacheGameDetails(
      String gameId, Map<String, dynamic> details) async {
    try {
      final db = await database;
      await db.insert(
        _gameDetailsTable,
        {
          'gameId': gameId,
          'details': jsonEncode(details),
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Failed to cache game details: $e');
    }
  }

  /// Get cached game details if not expired
  static Future<Map<String, dynamic>?> getCachedGameDetails(
      String gameId) async {
    try {
      final db = await database;
      final result = await db.query(
        _gameDetailsTable,
        where: 'gameId = ?',
        whereArgs: [gameId],
      );

      if (result.isEmpty) return null;

      final row = result.first;
      final lastUpdated =
          DateTime.fromMillisecondsSinceEpoch(row['lastUpdated'] as int);
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

      return jsonDecode(row['details'] as String) as Map<String, dynamic>;
    } catch (e) {
      print('Failed to get cached game details: $e');
      return null;
    }
  }

  /// Cache public games list
  static Future<void> cachePublicGames(List<Map<String, dynamic>> games) async {
    try {
      final db = await database;
      await db.insert(
        _gameDetailsTable,
        {
          'gameId': 'public_games_list',
          'details': jsonEncode(games),
          'lastUpdated': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Failed to cache public games: $e');
    }
  }

  /// Get cached public games list if not expired
  static Future<List<Map<String, dynamic>>?> getCachedPublicGames() async {
    try {
      final db = await database;
      final result = await db.query(
        _gameDetailsTable,
        where: 'gameId = ?',
        whereArgs: ['public_games_list'],
      );

      if (result.isEmpty) return null;

      final row = result.first;
      final lastUpdated =
          DateTime.fromMillisecondsSinceEpoch(row['lastUpdated'] as int);
      final now = DateTime.now();

      // Check if cache is expired (shorter TTL for public games)
      if (now.difference(lastUpdated) > _publicGamesTTL) {
        // Remove expired cache
        await db.delete(
          _gameDetailsTable,
          where: 'gameId = ?',
          whereArgs: ['public_games_list'],
        );
        return null;
      }

      final gamesJson = jsonDecode(row['details'] as String) as List;
      return gamesJson.cast<Map<String, dynamic>>();
    } catch (e) {
      print('Failed to get cached public games: $e');
      return null;
    }
  }

  /// Clear expired cache entries
  static Future<void> clearExpiredCache() async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final userProfileExpiry = now - _userProfileTTL.inMilliseconds;
      final gameDetailsExpiry = now - _gameDetailsTTL.inMilliseconds;
      final publicGamesExpiry = now - _publicGamesTTL.inMilliseconds;

      // Clear expired user profiles
      await db.delete(
        _userProfilesTable,
        where: 'lastUpdated < ?',
        whereArgs: [userProfileExpiry],
      );

      // Clear expired game details (except public games list)
      await db.delete(
        _gameDetailsTable,
        where: 'lastUpdated < ? AND gameId != ?',
        whereArgs: [gameDetailsExpiry, 'public_games_list'],
      );

      // Clear expired public games list
      await db.delete(
        _gameDetailsTable,
        where: 'lastUpdated < ? AND gameId = ?',
        whereArgs: [publicGamesExpiry, 'public_games_list'],
      );
    } catch (e) {
      print('Failed to clear expired cache: $e');
    }
  }

  /// Clear all cache
  static Future<void> clearAllCache() async {
    try {
      final db = await database;
      await db.delete(_userProfilesTable);
      await db.delete(_gameDetailsTable);
    } catch (e) {
      print('Failed to clear all cache: $e');
    }
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final db = await database;

      final userProfilesCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM $_userProfilesTable')) ??
          0;

      final gameDetailsCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM $_gameDetailsTable')) ??
          0;

      return {
        'userProfilesCount': userProfilesCount,
        'gameDetailsCount': gameDetailsCount,
        'totalCacheEntries': userProfilesCount + gameDetailsCount,
      };
    } catch (e) {
      print('Failed to get cache stats: $e');
      return {
        'userProfilesCount': 0,
        'gameDetailsCount': 0,
        'totalCacheEntries': 0,
      };
    }
  }

  /// Close database connection
  static Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
