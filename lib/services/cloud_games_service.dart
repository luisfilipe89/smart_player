// lib/services/cloud_games_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/models/game.dart';

class CloudGamesService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Database references
  static DatabaseReference get _gamesRef => _database.ref('games');
  static DatabaseReference get _usersRef => _database.ref('users');

  // Get current user ID
  static String? get _currentUserId => _auth.currentUser?.uid;

  // Create a new game in the cloud
  static Future<String> createGame(Game game) async {
    try {
      final gameRef = _gamesRef.push();
      final gameId = gameRef.key!;

      // Convert game to Map for Firebase
      final gameData = {
        ...game.toJson(),
        'id': gameId,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await gameRef.set(gameData);

      // Add game to user's created games
      if (_currentUserId != null) {
        await _usersRef
            .child(_currentUserId!)
            .child('createdGames')
            .child(gameId)
            .set(true);
      }

      // Game created in cloud successfully
      return gameId;
    } catch (e) {
      // Error creating game in cloud
      rethrow;
    }
  }

  // Update an existing game
  static Future<void> updateGame(Game game) async {
    try {
      final gameData = {
        ...game.toJson(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _gamesRef.child(game.id).update(gameData);
      // Game updated in cloud successfully
    } catch (e) {
      // Error updating game in cloud
      rethrow;
    }
  }

  // Delete a game
  static Future<void> deleteGame(String gameId) async {
    try {
      await _gamesRef.child(gameId).remove();

      // Remove from user's created games
      if (_currentUserId != null) {
        await _usersRef
            .child(_currentUserId!)
            .child('createdGames')
            .child(gameId)
            .remove();
      }

      // Game deleted from cloud successfully
    } catch (e) {
      // Error deleting game from cloud
      rethrow;
    }
  }

  // Get all public games
  static Future<List<Game>> getPublicGames({
    String? sport,
    String? searchQuery,
    int limit = 50,
  }) async {
    try {
      Query query =
          _gamesRef.orderByChild('isActive').equalTo(true).limitToFirst(limit);

      final snapshot = await query.get();

      if (!snapshot.exists) {
        return [];
      }

      final List<Game> games = [];

      for (final child in snapshot.children) {
        try {
          final gameData = child.value as Map<dynamic, dynamic>;
          final game = Game.fromJson(Map<String, dynamic>.from(gameData));

          // Apply filters
          if (sport != null && game.sport != sport) continue;
          if (searchQuery != null &&
              !game.location
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase()) &&
              !game.description
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase())) {
            continue;
          }

          games.add(game);
        } catch (e) {
          // Error parsing game
          continue;
        }
      }

      // Retrieved games from cloud successfully
      return games;
    } catch (e) {
      // Error getting public games
      return [];
    }
  }

  // Get user's created games
  static Future<List<Game>> getUserGames() async {
    if (_currentUserId == null) return [];

    try {
      final snapshot =
          await _usersRef.child(_currentUserId!).child('createdGames').get();

      if (!snapshot.exists) return [];

      final List<Game> games = [];

      for (final child in snapshot.children) {
        final gameId = child.key!;
        final gameSnapshot = await _gamesRef.child(gameId).get();

        if (gameSnapshot.exists) {
          try {
            final gameData = gameSnapshot.value as Map<dynamic, dynamic>;
            final game = Game.fromJson(Map<String, dynamic>.from(gameData));
            games.add(game);
          } catch (e) {
            // Error parsing user game
            continue;
          }
        }
      }

      // Retrieved user games from cloud successfully
      return games;
    } catch (e) {
      // Error getting user games
      return [];
    }
  }

  // Join a game
  static Future<bool> joinGame(
      String gameId, String playerId, String playerName) async {
    try {
      final gameRef = _gamesRef.child(gameId);
      final gameSnapshot = await gameRef.get();

      if (!gameSnapshot.exists) {
        // Game not found
        return false;
      }

      final gameData = gameSnapshot.value as Map<dynamic, dynamic>;
      final game = Game.fromJson(Map<String, dynamic>.from(gameData));

      // Check if game is full
      if (game.currentPlayers >= game.maxPlayers) {
        // Game is full
        return false;
      }

      // Check if player already joined
      if (game.players.contains(playerId)) {
        // Player already joined
        return false;
      }

      // Update game
      final updatedPlayers = [...game.players, playerId];
      await gameRef.update({
        'players': updatedPlayers,
        'currentPlayers': updatedPlayers.length,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Add game to user's joined games
      await _usersRef
          .child(playerId)
          .child('joinedGames')
          .child(gameId)
          .set(true);

      // Player joined game successfully
      return true;
    } catch (e) {
      // Error joining game
      return false;
    }
  }

  // Leave a game
  static Future<bool> leaveGame(String gameId, String playerId) async {
    try {
      final gameRef = _gamesRef.child(gameId);
      final gameSnapshot = await gameRef.get();

      if (!gameSnapshot.exists) {
        // Game not found
        return false;
      }

      final gameData = gameSnapshot.value as Map<dynamic, dynamic>;
      final game = Game.fromJson(Map<String, dynamic>.from(gameData));

      // Check if player is in the game
      if (!game.players.contains(playerId)) {
        // Player not in game
        return false;
      }

      // Update game
      final updatedPlayers =
          game.players.where((id) => id != playerId).toList();
      await gameRef.update({
        'players': updatedPlayers,
        'currentPlayers': updatedPlayers.length,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      // Remove game from user's joined games
      await _usersRef
          .child(playerId)
          .child('joinedGames')
          .child(gameId)
          .remove();

      // Player left game successfully
      return true;
    } catch (e) {
      // Error leaving game
      return false;
    }
  }

  // Listen to real-time updates for a specific game
  static Stream<Game?> watchGame(String gameId) {
    return _gamesRef.child(gameId).onValue.map((event) {
      if (!event.snapshot.exists) return null;

      try {
        final gameData = event.snapshot.value as Map<dynamic, dynamic>;
        return Game.fromJson(Map<String, dynamic>.from(gameData));
      } catch (e) {
        // Error parsing game in stream
        return null;
      }
    });
  }

  // Listen to real-time updates for all public games
  static Stream<List<Game>> watchPublicGames({
    String? sport,
    int limit = 50,
  }) {
    Query query =
        _gamesRef.orderByChild('isActive').equalTo(true).limitToFirst(limit);

    return query.onValue.map((event) {
      if (!event.snapshot.exists) return <Game>[];

      final List<Game> games = [];

      for (final child in event.snapshot.children) {
        try {
          final gameData = child.value as Map<dynamic, dynamic>;
          final game = Game.fromJson(Map<String, dynamic>.from(gameData));

          // Apply sport filter
          if (sport != null && game.sport != sport) continue;

          games.add(game);
        } catch (e) {
          // Error parsing game in stream
          continue;
        }
      }

      return games;
    });
  }
}
