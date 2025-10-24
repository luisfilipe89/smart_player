// lib/services/games_service_instance.dart
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/services/auth_service_instance.dart';
import 'package:move_young/services/cloud_games_service_instance.dart';

/// Instance-based GamesService for use with Riverpod dependency injection
class GamesServiceInstance {
  final AuthServiceInstance _authService;
  final CloudGamesServiceInstance _cloudGamesService;

  Database? _database;
  static const String _tableName = 'games';

  GamesServiceInstance(this._authService, this._cloudGamesService);

  // Initialize database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      String path = join(await getDatabasesPath(), 'games.db');

      // Check if the directory exists, create if not
      await getDatabasesPath();

      // Try to create the database
      final db = await openDatabase(
        path,
        version: 5,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      return db;
    } catch (e) {
      // Try alternative path
      try {
        final altPath = 'games.db';
        final altDb = await openDatabase(
          altPath,
          version: 5,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
        return altDb;
      } catch (altE) {
        rethrow;
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName(
        id TEXT PRIMARY KEY,
        sport TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        location TEXT NOT NULL,
        fieldId TEXT,
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
        isActive INTEGER DEFAULT 1,
        isPublic INTEGER NOT NULL DEFAULT 1
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN currentPlayers INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN address TEXT');
      await db.execute('ALTER TABLE $_tableName ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE $_tableName ADD COLUMN longitude REAL');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN skillLevels TEXT');
      await db.execute('ALTER TABLE $_tableName ADD COLUMN equipment TEXT');
      await db.execute('ALTER TABLE $_tableName ADD COLUMN cost REAL');
      await db.execute('ALTER TABLE $_tableName ADD COLUMN contactInfo TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE $_tableName ADD COLUMN imageUrl TEXT');
      await db.execute('ALTER TABLE $_tableName ADD COLUMN players TEXT');
    }
  }

  // Create a new game
  Future<String> createGame(Game game) async {
    try {
      final db = await database;
      final userId = _authService.currentUserId;

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // If authenticated, create in cloud first
      if (_authService.isSignedIn) {
        final cloudGameId = await _cloudGamesService.createGame(game);
        final gameWithCloudId = game.copyWith(id: cloudGameId);
        await _insertGameLocally(db, gameWithCloudId);
        return cloudGameId;
      } else {
        // Create locally only
        await _insertGameLocally(db, game);
        return game.id;
      }
    } catch (e) {
      debugPrint('Error creating game: $e');
      rethrow;
    }
  }

  // Insert game into local database
  Future<void> _insertGameLocally(Database db, Game game) async {
    await db.insert(
      _tableName,
      _gameToMap(game),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Get user's games
  Future<List<Game>> getMyGames() async {
    try {
      final db = await database;
      final userId = _authService.currentUserId;

      if (userId == null) return [];

      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'organizerId = ?',
        whereArgs: [userId],
        orderBy: 'dateTime DESC',
      );

      return maps.map((map) => _mapToGame(map)).toList();
    } catch (e) {
      debugPrint('Error getting my games: $e');
      return [];
    }
  }

  // Get games that user can join
  Future<List<Game>> getJoinableGames() async {
    try {
      final db = await database;
      final userId = _authService.currentUserId;

      if (userId == null) return [];

      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'isActive = ? AND isPublic = ? AND organizerId != ?',
        whereArgs: [1, 1, userId],
        orderBy: 'dateTime ASC',
      );

      return maps.map((map) => _mapToGame(map)).toList();
    } catch (e) {
      debugPrint('Error getting joinable games: $e');
      return [];
    }
  }

  // Get game by ID
  Future<Game?> getGameById(String gameId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'id = ?',
        whereArgs: [gameId],
      );

      if (maps.isNotEmpty) {
        return _mapToGame(maps.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting game by ID: $e');
      return null;
    }
  }

  // Update game
  Future<void> updateGame(Game game) async {
    try {
      final db = await database;
      await db.update(
        _tableName,
        _gameToMap(game),
        where: 'id = ?',
        whereArgs: [game.id],
      );
    } catch (e) {
      debugPrint('Error updating game: $e');
      rethrow;
    }
  }

  // Delete game
  Future<void> deleteGame(String gameId) async {
    try {
      final db = await database;
      await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [gameId],
      );
    } catch (e) {
      debugPrint('Error deleting game: $e');
      rethrow;
    }
  }

  // Join a game
  Future<void> joinGame(String gameId) async {
    try {
      final game = await getGameById(gameId);
      if (game == null) {
        throw Exception('Game not found');
      }

      final userId = _authService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is already in the game
      if (game.players.contains(userId)) {
        throw Exception('Already joined this game');
      }

      // Check if game is full
      if (game.players.length >= game.maxPlayers) {
        throw Exception('Game is full');
      }

      // Update local database
      final updatedPlayers = List<String>.from(game.players)..add(userId);
      final updatedGame = game.copyWith(
        players: updatedPlayers,
        currentPlayers: updatedPlayers.length,
      );

      await updateGame(updatedGame);

      // If authenticated, also update in cloud
      if (_authService.isSignedIn) {
        await _cloudGamesService.joinGame(gameId);
      }
    } catch (e) {
      debugPrint('Error joining game: $e');
      rethrow;
    }
  }

  // Leave a game
  Future<void> leaveGame(String gameId) async {
    try {
      final game = await getGameById(gameId);
      if (game == null) {
        throw Exception('Game not found');
      }

      final userId = _authService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if user is in the game
      if (!game.players.contains(userId)) {
        throw Exception('Not in this game');
      }

      // Update local database
      final updatedPlayers = List<String>.from(game.players)..remove(userId);
      final updatedGame = game.copyWith(
        players: updatedPlayers,
        currentPlayers: updatedPlayers.length,
      );

      await updateGame(updatedGame);

      // If authenticated, also update in cloud
      if (_authService.isSignedIn) {
        await _cloudGamesService.leaveGame(gameId);
      }
    } catch (e) {
      debugPrint('Error leaving game: $e');
      rethrow;
    }
  }

  // Sync games with cloud
  Future<void> syncWithCloud() async {
    try {
      if (!_authService.isSignedIn) return;

      final db = await database;
      final userId = _authService.currentUserId;

      if (userId == null) return;

      // Get games from cloud
      final cloudGames = await _cloudGamesService.getMyGames();

      // Update local database with cloud games
      for (final game in cloudGames) {
        await _insertGameLocally(db, game);
      }
    } catch (e) {
      debugPrint('Error syncing with cloud: $e');
    }
  }

  // Convert Game to Map for database storage
  Map<String, dynamic> _gameToMap(Game game) {
    return {
      'id': game.id,
      'sport': game.sport,
      'dateTime': game.dateTime.toIso8601String(),
      'location': game.location,
      'fieldId': game.fieldId,
      'maxPlayers': game.maxPlayers,
      'currentPlayers': game.currentPlayers,
      'description': game.description,
      'organizerId': game.organizerId,
      'organizerName': game.organizerName,
      'createdAt': game.createdAt.toIso8601String(),
      'address': game.address,
      'latitude': game.latitude,
      'longitude': game.longitude,
      'skillLevels': game.skillLevels.join(','),
      'equipment': game.equipment,
      'cost': game.cost,
      'contactInfo': game.contactInfo,
      'imageUrl': game.imageUrl,
      'players': game.players.join(','),
      'isActive': game.isActive ? 1 : 0,
      'isPublic': game.isPublic ? 1 : 0,
    };
  }

  // Convert Map from database to Game
  Game _mapToGame(Map<String, dynamic> map) {
    return Game(
      id: map['id'],
      sport: map['sport'],
      dateTime: DateTime.parse(map['dateTime']),
      location: map['location'],
      fieldId: map['fieldId'],
      maxPlayers: map['maxPlayers'],
      currentPlayers: map['currentPlayers'] ?? 0,
      description: map['description'] ?? '',
      organizerId: map['organizerId'],
      organizerName: map['organizerName'],
      createdAt: DateTime.parse(map['createdAt']),
      address: map['address'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      skillLevels: map['skillLevels']?.split(',') ?? [],
      equipment: map['equipment'],
      cost: map['cost'],
      contactInfo: map['contactInfo'],
      imageUrl: map['imageUrl'],
      players: map['players']?.split(',') ?? [],
      isActive: map['isActive'] == 1,
      isPublic: map['isPublic'] == 1,
    );
  }

  // Close database
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
