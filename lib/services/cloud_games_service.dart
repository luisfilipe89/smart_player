// lib/services/cloud_games_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/models/game.dart';
import 'package:move_young/db/db_paths.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

class CloudGamesService {
  static FirebaseDatabase get _database => FirebaseDatabase.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  // Database references
  static DatabaseReference get _gamesRef => _database.ref(DbPaths.games);
  static DatabaseReference get _usersRef => _database.ref(DbPaths.users);

  // Get current user ID
  static String? get _currentUserId => _auth.currentUser?.uid;

  // Create a new game in the cloud
  static Future<String> createGame(Game game) async {
    try {
      // Enforce at most 5 active upcoming organized games per user in cloud
      final organizerUid = _currentUserId ?? game.organizerId;
      if (organizerUid.isNotEmpty) {
        try {
          // Fetch user's created games and count active upcoming
          final List<Game> existing = await getUserGames();
          final int activeUpcoming = existing
              .where((g) => g.isActive && g.dateTime.isAfter(DateTime.now()))
              .length;
          if (activeUpcoming >= 5) {
            throw Exception('max_active_organized_games');
          }
        } catch (_) {}
      }

      final gameRef = _gamesRef.push();
      final gameId = gameRef.key!;

      // Prepare cloud data with proper types
      // Reuse organizerUid from above
      final initialPlayers =
          organizerUid.isNotEmpty ? [organizerUid] : <String>[];

      final gameData = game
          .copyWith(
            id: gameId,
            organizerId: organizerUid,
            players: initialPlayers,
            currentPlayers: initialPlayers.length,
          )
          .toCloudJson();
      gameData['updatedAt'] = DateTime.now().millisecondsSinceEpoch;

      // Auto-enroll organizer as a player (already reflected in data)

      await gameRef.set(gameData);

      // Add game to user's created games
      if (_currentUserId != null) {
        await _database
            .ref(DbPaths.userCreatedGames(_currentUserId!))
            .child(gameId)
            .set(true);
        await _database
            .ref(DbPaths.userJoinedGames(_currentUserId!))
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

  // Invite players to a game (organizer only)
  static Future<void> invitePlayers(String gameId, List<String> userIds,
      {String? sport, DateTime? dateTime}) async {
    final organizerId = _currentUserId;
    if (organizerId == null || userIds.isEmpty) return;
    // Write only under the game node to avoid cross-user writes blocked by rules
    final DatabaseReference invitesRef = _database.ref('games/$gameId/invites');
    final Map<String, Object?> batch = {};
    for (final uid in userIds) {
      batch[uid] = {
        'status': 'pending',
        'organizerId': organizerId,
        if (sport != null) 'sport': sport,
        if (dateTime != null) 'dateTime': dateTime.toIso8601String(),
        'ts': DateTime.now().millisecondsSinceEpoch,
      };
    }
    await invitesRef.update(batch);
  }

  // Fetch pending invited user IDs for a game (organizer-side display)
  static Future<List<String>> getInvitedUids(String gameId) async {
    try {
      final snap = await _database.ref('games/$gameId/invites').get();
      if (!snap.exists) return const [];
      final Map<dynamic, dynamic>? data = snap.value as Map<dynamic, dynamic>?;
      if (data == null) return const [];
      final List<String> uids = [];
      data.forEach((key, value) {
        final status = (value is Map) ? value['status']?.toString() : null;
        if (status == null || status == 'pending') {
          uids.add(key.toString());
        }
      });
      return uids;
    } catch (_) {
      return const [];
    }
  }

  // Fetch invite statuses for a game: { uid: 'pending'|'accepted'|'declined' }
  static Future<Map<String, String>> getInviteStatuses(String gameId) async {
    try {
      final snap = await _database.ref('games/$gameId/invites').get();
      if (!snap.exists) return const {};
      final Map<dynamic, dynamic>? data = snap.value as Map<dynamic, dynamic>?;
      if (data == null) return const {};
      final Map<String, String> result = {};
      data.forEach((key, value) {
        if (value is Map) {
          final status = value['status']?.toString() ?? 'pending';
          result[key.toString()] = status;
        } else {
          // Treat non-map invite entries as pending by default
          result[key.toString()] = 'pending';
        }
      });
      return result;
    } catch (_) {
      return const {};
    }
  }

  // List games where the current user has a pending invite
  static Future<List<Game>> getInvitedGamesForCurrentUser(
      {int limit = 100}) async {
    final uid = _currentUserId;
    if (uid == null) return [];
    try {
      Query query =
          _gamesRef.orderByChild('isActive').equalTo(true).limitToFirst(limit);
      final snapshot = await query.get();
      if (!snapshot.exists) return [];
      final List<Game> invited = [];
      for (final child in snapshot.children) {
        try {
          final Map<dynamic, dynamic> gameData =
              child.value as Map<dynamic, dynamic>;
          final invites = gameData['invites'];
          if (invites is Map && invites.containsKey(uid)) {
            final entry = invites[uid];
            if (entry is Map &&
                (entry['status']?.toString() ?? 'pending') == 'pending') {
              final game = Game.fromJson(Map<String, dynamic>.from(gameData));
              // Only show upcoming invites
              if (game.isUpcoming) invited.add(game);
            }
          }
        } catch (_) {}
      }
      // Sort upcoming invited games by time
      invited.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return invited;
    } catch (e) {
      return [];
    }
  }

  // Accept invite: mark as accepted and join game
  static Future<bool> acceptInvite(String gameId) async {
    final uid = _currentUserId;
    if (uid == null) return false;
    try {
      // Attempt to join first; if successful, mark invite accepted
      final displayName = _auth.currentUser?.displayName ?? 'User';
      final joined = await joinGame(gameId, uid, displayName);

      if (joined) {
        // Mark invite as accepted
        try {
          await _gamesRef
              .child(gameId)
              .child('invites')
              .child(uid)
              .child('status')
              .set('accepted');
        } catch (_) {}

        // Sync the game to local database
        try {
          final gameSnapshot = await _gamesRef.child(gameId).get();
          if (gameSnapshot.exists) {
            final gameData = gameSnapshot.value as Map<dynamic, dynamic>;
            final game = Game.fromJson(Map<String, dynamic>.from(gameData));

            // Insert into local SQLite database
            await _syncGameToLocalDb(game);
          }
        } catch (_) {
          // Local sync failed, but cloud join succeeded
        }
      }

      return joined;
    } catch (e) {
      return false;
    }
  }

  // Helper to sync game to local database (avoids circular dependency with GamesService)
  static Future<void> _syncGameToLocalDb(Game game) async {
    try {
      final dbPath = await getDatabasesPath();
      final db = await openDatabase(
        path.join(dbPath, 'games.db'),
        version: 2,
      );

      // Try to insert, or update if already exists
      await db.insert(
        'games',
        game.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Ignore local DB errors
    }
  }

  // Decline invite: mark status declined
  static Future<bool> declineInvite(String gameId) async {
    final uid = _currentUserId;
    if (uid == null) return false;
    try {
      await _gamesRef
          .child(gameId)
          .child('invites')
          .child(uid)
          .child('status')
          .set('declined');
      return true;
    } catch (e) {
      return false;
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

  // Get user's joined games
  static Future<List<Game>> getUserJoinedGames(String userId) async {
    try {
      final joinedSnap =
          await _usersRef.child(userId).child('joinedGames').get();
      if (!joinedSnap.exists) return [];

      final List<Game> games = [];
      for (final child in joinedSnap.children) {
        final gameId = child.key;
        if (gameId == null) continue;
        try {
          final gameSnapshot = await _gamesRef.child(gameId).get();
          if (gameSnapshot.exists) {
            final Map<dynamic, dynamic> gameData =
                gameSnapshot.value as Map<dynamic, dynamic>;
            final game = Game.fromJson(Map<String, dynamic>.from(gameData));
            if (game.isActive && game.isUpcoming) {
              games.add(game);
            }
          }
        } catch (_) {}
      }

      games.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return games;
    } catch (e) {
      return [];
    }
  }
}
