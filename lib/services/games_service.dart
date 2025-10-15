// lib/services/games_service.dart
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:move_young/models/game.dart';
import 'package:move_young/services/cloud_games_service.dart';
import 'package:move_young/services/auth_service.dart';

class GamesService {
  static Database? _database;
  static const String _tableName = 'games';

  // Initialize database
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    try {
      String path = join(await getDatabasesPath(), 'games.db');
      // Database path set

      // Check if the directory exists, create if not
      await getDatabasesPath();
      // Database directory checked

      // Try to create the database
      final db = await openDatabase(
        path,
        version: 2,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      // Database opened successfully
      return db;
    } catch (e) {
      // Error initializing database

      // Try alternative path
      try {
        // Trying alternative database path
        final altPath = 'games.db';
        final altDb = await openDatabase(
          altPath,
          version: 2,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
        // Alternative database path worked
        return altDb;
      } catch (altE) {
        // Alternative database path also failed
        rethrow;
      }
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Creating database table
    await db.execute('''
      CREATE TABLE $_tableName(
        id TEXT PRIMARY KEY,
        sport TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        location TEXT NOT NULL,
        maxPlayers INTEGER NOT NULL,
        currentPlayers INTEGER NOT NULL,
        description TEXT,
        organizerId TEXT NOT NULL,
        organizerName TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        address TEXT,
        latitude REAL,
        longitude REAL,
        skillLevels TEXT,
        equipment TEXT,
        cost REAL,
        contactInfo TEXT,
        imageUrl TEXT,
        players TEXT,
        isActive INTEGER DEFAULT 1
      )
    ''');
    // Database table created successfully
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    // Upgrading database
    if (oldVersion < 2) {
      // Add currentPlayers column
      // Adding currentPlayers column
      await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN currentPlayers INTEGER NOT NULL DEFAULT 0');
      // currentPlayers column added successfully
    }
  }

  // Create a new game (local + cloud sync)
  static Future<String> createGame(Game game) async {
    try {
      // Starting game creation
      final db = await database;
      // Database connection established

      // Enforce one game per user per day
      final startOfDay =
          DateTime(game.dateTime.year, game.dateTime.month, game.dateTime.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final List<Map<String, dynamic>> existing = await db.query(
        _tableName,
        where:
            'organizerId = ? AND dateTime >= ? AND dateTime < ? AND isActive = 1',
        whereArgs: [
          game.organizerId,
          startOfDay.toIso8601String(),
          endOfDay.toIso8601String(),
        ],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        throw Exception('only_one_game_per_day');
      }

      // Enforce at most 5 active organized games per user (upcoming only)
      final nowIso = DateTime.now().toIso8601String();
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM $_tableName WHERE organizerId = ? AND isActive = 1 AND dateTime > ?',
        [game.organizerId, nowIso],
      );
      final int currentActive = (rows.isNotEmpty
              ? int.tryParse((rows.first['cnt'] ?? 0).toString())
              : 0) ??
          0;
      if (currentActive >= 5) {
        throw Exception('max_active_organized_games');
      }

      // Create in cloud first to get canonical ID (if signed in)
      String finalId = game.id;
      Game toStore = game;
      if (AuthService.isSignedIn) {
        try {
          final cloudId = await CloudGamesService.createGame(game);
          finalId = cloudId;
          toStore = game.copyWith(id: cloudId);
        } catch (_) {
          // If cloud creation fails, keep local id; can add retry later
        }
      }

      // Save to local database with final ID
      await db.insert(_tableName, toStore.toJson());

      return finalId;
    } catch (e) {
      // Error in GamesService.createGame
      rethrow;
    }
  }

  // Get all games (local + cloud)
  static Future<List<Game>> getAllGames() async {
    final List<Game> games = [];

    // Get local games
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'isActive = ?',
        whereArgs: [1],
        orderBy: 'dateTime ASC',
      );

      games.addAll(maps.map((map) => Game.fromJson(map)).toList());
      // Retrieved games from local database
    } catch (e) {
      // Error getting local games
    }

    // Always fetch cloud games (public) regardless of auth state
    try {
      final cloudGames = await CloudGamesService.getPublicGames();
      games.addAll(cloudGames);
      // Retrieved games from cloud
    } catch (e) {
      // Error getting cloud games
    }

    // Remove duplicates by a composite key: organizerId + dateTime minute + location
    final Map<String, Game> uniqueByComposite = {};
    for (final game in games) {
      final String dtKey = DateTime(
        game.dateTime.year,
        game.dateTime.month,
        game.dateTime.day,
        game.dateTime.hour,
        game.dateTime.minute,
      ).toIso8601String();
      final String key =
          '${game.organizerId}|${game.location.toLowerCase()}|$dtKey';
      uniqueByComposite[key] = game;
    }

    final finalGames = uniqueByComposite.values.toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    return finalGames;
  }

  // Get games by organizer
  static Future<List<Game>> getGamesByOrganizer(String organizerId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'organizerId = ? AND isActive = ?',
      whereArgs: [organizerId, 1],
      orderBy: 'dateTime ASC',
    );
    return maps.map((map) => Game.fromJson(map)).toList();
  }

  // Get upcoming games
  static Future<List<Game>> getUpcomingGames() async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'dateTime > ? AND isActive = ?',
      whereArgs: [now, 1],
      orderBy: 'dateTime ASC',
    );
    return maps.map((map) => Game.fromJson(map)).toList();
  }

  // Get game by ID
  static Future<Game?> getGameById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ? AND isActive = ?',
      whereArgs: [id, 1],
    );
    if (maps.isNotEmpty) {
      return Game.fromJson(maps.first);
    }
    return null;
  }

  // Get games for a specific field (by location name) on a specific date
  static Future<List<Game>> getGamesForFieldOnDate(
      String locationName, DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'location = ? AND dateTime >= ? AND dateTime < ? AND isActive = ?',
      whereArgs: [
        locationName,
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String(),
        1,
      ],
      orderBy: 'dateTime ASC',
    );
    return maps.map((map) => Game.fromJson(map)).toList();
  }

  // Update game
  static Future<void> updateGame(Game game) async {
    final db = await database;
    await db.update(
      _tableName,
      game.toJson(),
      where: 'id = ?',
      whereArgs: [game.id],
    );
  }

  // Partial local update: update only allowed fields
  static Future<void> updateGameFieldsLocal(
    String gameId, {
    DateTime? dateTime,
    String? location,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final db = await database;
    final Map<String, dynamic> map = {};
    if (dateTime != null) map['dateTime'] = dateTime.toIso8601String();
    if (location != null) map['location'] = location;
    if (address != null) map['address'] = address;
    if (latitude != null) map['latitude'] = latitude;
    if (longitude != null) map['longitude'] = longitude;
    if (map.isEmpty) return;
    await db.update(_tableName, map, where: 'id = ?', whereArgs: [gameId]);
  }

  // Join a game (add player) - local + cloud sync
  static Future<bool> joinGame(
      String gameId, String playerId, String playerName) async {
    try {
      // Try cloud first if authenticated
      if (AuthService.isSignedIn) {
        final cloudSuccess =
            await CloudGamesService.joinGame(gameId, playerId, playerName);
        if (cloudSuccess) {
          // Sync to local database
          final game = await getGameById(gameId);
          if (game != null) {
            final players = List<String>.from(game.players);
            if (!players.contains(playerId)) {
              players.add(playerId);
              final updatedGame = game.copyWith(players: players);
              await updateGame(updatedGame);
            }
          }
          return true;
        }
      }

      // Fallback to local only
      final game = await getGameById(gameId);
      if (game == null || game.isFull) return false;

      // Add player to the game
      final players = List<String>.from(game.players);
      if (!players.contains(playerId)) {
        players.add(playerId);
        final updatedGame = game.copyWith(players: players);
        await updateGame(updatedGame);
        return true;
      }
      return false;
    } catch (e) {
      // Error joining game
      return false;
    }
  }

  // Leave a game (remove player)
  static Future<bool> leaveGame(String gameId, String playerId) async {
    final game = await getGameById(gameId);
    if (game == null) return false;

    final players = List<String>.from(game.players);
    if (players.contains(playerId)) {
      players.remove(playerId);
      final updatedGame = game.copyWith(players: players);
      await updateGame(updatedGame);
      return true;
    }
    return false;
  }

  // Cancel/Delete game (soft delete)
  static Future<void> cancelGame(String gameId) async {
    final db = await database;
    await db.update(
      _tableName,
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [gameId],
    );
  }

  // Remove local record for a specific game (used for hiding canceled games locally)
  static Future<void> removeLocalGame(String gameId) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [gameId],
    );
  }

  // Search games by sport
  static Future<List<Game>> searchGamesBySport(String sport) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'sport = ? AND isActive = ?',
      whereArgs: [sport, 1],
      orderBy: 'dateTime ASC',
    );
    return maps.map((map) => Game.fromJson(map)).toList();
  }

  // Search games by location (within radius)
  static Future<List<Game>> searchGamesByLocation(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'isActive = ?',
      whereArgs: [1],
    );

    final games = maps.map((map) => Game.fromJson(map)).toList();

    // Filter by distance (simple implementation)
    return games.where((game) {
      if (game.latitude == null || game.longitude == null) return false;

      final distance = _calculateDistance(
        latitude,
        longitude,
        game.latitude!,
        game.longitude!,
      );

      return distance <= radiusKm;
    }).toList();
  }

  // Calculate distance between two points (Haversine formula)
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Get games statistics
  static Future<Map<String, dynamic>> getGamesStats() async {
    final db = await database;

    final totalGames = Sqflite.firstIntValue(await db
            .rawQuery('SELECT COUNT(*) FROM $_tableName WHERE isActive = 1')) ??
        0;

    final upcomingGames = Sqflite.firstIntValue(await db.rawQuery('''
        SELECT COUNT(*) FROM $_tableName 
        WHERE dateTime > ? AND isActive = 1
      ''', [DateTime.now().toIso8601String()])) ?? 0;

    final pastGames = totalGames - upcomingGames;

    return {
      'totalGames': totalGames,
      'upcomingGames': upcomingGames,
      'pastGames': pastGames,
    };
  }

  // Close database
  static Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
