// lib/services/cloud_games_service_instance.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/db/db_paths.dart';
// import 'package:flutter/foundation.dart' show debugPrint;
import 'package:move_young/utils/logger.dart';
import 'package:move_young/models/infrastructure/cached_data.dart';
import '../notifications/notification_interface.dart';
import '../../utils/service_error.dart';
import 'package:move_young/utils/crashlytics_helper.dart';

// Background processing will be added when needed

/// Instance-based CloudGamesService for use with Riverpod dependency injection
class CloudGamesServiceInstance {
  final FirebaseDatabase _database;
  final FirebaseAuth _auth;
  final INotificationService _notificationService;

  // Query limits to prevent memory issues
  static const int _maxJoinableGames = 50;
  static const int _maxMyGames = 100;

  CloudGamesServiceInstance(
    this._database,
    this._auth,
    this._notificationService,
  );

  // Cache for games data
  final Map<String, CachedData<List<Game>>> _gameCache = {};
  static const Duration _defaultCacheTtl = Duration(minutes: 5);

  // Database references
  DatabaseReference get _gamesRef => _database.ref(DbPaths.games);
  DatabaseReference get _usersRef => _database.ref(DbPaths.users);

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // --- Helpers for slot keys ---
  // These helpers will be added when needed for slot management

  // Create a new game in the cloud
  Future<String> createGame(Game game) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      // Ensure the user has a profile
      await _ensureUserProfile(userId);

      // Create the game
      final gameRef = _gamesRef.push();
      final gameId = gameRef.key!;

      // Update game with the generated ID
      final gameWithId = game.copyWith(id: gameId);

      // Save to Firebase
      await gameRef.set(gameWithId.toJson());

      // Update user's created games index
      await _usersRef
          .child(DbPaths.userCreatedGames(userId))
          .child(gameId)
          .set({
        'sport': gameWithId.sport,
        'dateTime': gameWithId.dateTime.toIso8601String(),
        'location': gameWithId.location,
        'maxPlayers': gameWithId.maxPlayers,
      });

      // Send notifications to invited friends
      // This will be implemented when we add friend invites functionality
      // For now, we'll just log it
      NumberedLogger.i('Game created successfully: $gameId');
      CrashlyticsHelper.breadcrumb('game_create_ok:$gameId');

      return gameId;
    } catch (e, st) {
      NumberedLogger.e('Error creating game: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'game_create_fail');
      rethrow;
    }
  }

  // Get a single game by ID
  Future<Game?> getGameById(String gameId) async {
    try {
      final snapshot = await _gamesRef.child(gameId).get();

      if (!snapshot.exists) {
        return null;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return Game.fromJson(data);
    } catch (e) {
      NumberedLogger.e('Error getting game by ID: $e');
      return null;
    }
  }

  // Update a game
  Future<void> updateGame(Game game) async {
    try {
      await _gamesRef.child(game.id).update(game.toJson());
      _clearCache(); // Invalidate cache
    } catch (e, st) {
      NumberedLogger.e('Error updating game: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'game_update_fail');
      rethrow;
    }
  }

  // Delete a game
  Future<void> deleteGame(String gameId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      // Remove the game
      await _gamesRef.child(gameId).remove();

      // Remove from user's created games index
      await _usersRef
          .child(DbPaths.userCreatedGames(userId))
          .child(gameId)
          .remove();

      _clearCache(); // Invalidate cache
    } catch (e, st) {
      NumberedLogger.e('Error deleting game: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'game_delete_fail');
      rethrow;
    }
  }

  // Get games for the current user
  Future<List<Game>> getMyGames({Duration? ttl}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return [];
      }

      // Check cache first
      final cacheKey = 'my_games_$userId';
      final cached = _gameCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }

      // Fetch from Firebase with limit
      final snapshot = await _gamesRef
          .orderByChild('organizerId')
          .equalTo(userId)
          .limitToFirst(_maxMyGames)
          .get();

      final games = <Game>[];
      if (snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        for (final entry in data.values) {
          try {
            final game = Game.fromJson(Map<String, dynamic>.from(entry));
            games.add(game);
          } catch (e) {
            NumberedLogger.w('Error parsing game: $e');
          }
        }
      }

      // Cache the result
      _gameCache[cacheKey] =
          CachedData(games, DateTime.now(), expiry: ttl ?? _defaultCacheTtl);

      return games;
    } catch (e) {
      NumberedLogger.e('Error getting my games: $e');
      return [];
    }
  }

  // Get games that the user can join
  Future<List<Game>> getJoinableGames({Duration? ttl}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return [];
      }

      // Check cache first
      final cacheKey = 'joinable_games_$userId';
      final cached = _gameCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }

      // Fetch from Firebase with limit
      final snapshot = await _gamesRef
          .orderByChild('isActive')
          .equalTo(true)
          .limitToFirst(_maxJoinableGames)
          .get();

      final games = <Game>[];
      if (snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        for (final entry in data.values) {
          try {
            final game = Game.fromJson(Map<String, dynamic>.from(entry));
            // Filter out games organized by the current user
            if (game.organizerId != userId) {
              games.add(game);
            }
          } catch (e) {
            NumberedLogger.w('Error parsing game: $e');
          }
        }
      }

      // Cache the result
      _gameCache[cacheKey] =
          CachedData(games, DateTime.now(), expiry: ttl ?? _defaultCacheTtl);

      return games;
    } catch (e) {
      NumberedLogger.e('Error getting joinable games: $e');
      return [];
    }
  }

  // Get invited games for the current user
  Future<List<Game>> getInvitedGamesForCurrentUser({Duration? ttl}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return [];
      }

      // Check cache first
      final cacheKey = 'invited_games_$userId';
      final cached = _gameCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }

      // Fetch from Firebase
      final snapshot =
          await _usersRef.child(DbPaths.userGameInvites(userId)).get();

      final games = <Game>[];
      if (snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

        // Collect pending invite gameIds first
        final gameIds = <String>[];
        for (final entry in data.entries) {
          final inviteData = entry.value as Map<dynamic, dynamic>;
          if (inviteData['status'] == 'pending') {
            gameIds.add(entry.key);
          }
        }

        // Batch fetch all games in parallel to avoid N+1 query pattern
        final gameFutures = gameIds.map((id) => _gamesRef.child(id).get());
        final gameSnapshots = await Future.wait(gameFutures);

        for (final gameSnapshot in gameSnapshots) {
          if (gameSnapshot.exists) {
            try {
              final game = Game.fromJson(
                  Map<String, dynamic>.from(gameSnapshot.value as Map));
              games.add(game);
            } catch (e) {
              NumberedLogger.w('Error parsing invited game: $e');
            }
          }
        }
      }

      // Cache the result
      _gameCache[cacheKey] =
          CachedData(games, DateTime.now(), expiry: ttl ?? _defaultCacheTtl);

      return games;
    } catch (e) {
      NumberedLogger.e('Error getting invited games: $e');
      return [];
    }
  }

  /// Validates that user indexes and game documents are consistent.
  /// Returns a list of human-readable issues; empty if healthy.
  Future<List<String>> validateUserGameIndexes({String? userId}) async {
    final issues = <String>[];
    final uid = userId ?? _currentUserId;
    if (uid == null) return issues;

    try {
      // 1) createdGames index must reference existing games
      final createdIdx =
          await _usersRef.child(DbPaths.userCreatedGames(uid)).get();
      if (createdIdx.exists) {
        final map = Map<dynamic, dynamic>.from(createdIdx.value as Map);
        for (final gameId in map.keys) {
          final snap = await _gamesRef.child(gameId.toString()).get();
          if (!snap.exists) {
            issues.add('Orphan createdGames index: $gameId');
          }
        }
      }

      // 2) joinedGames index must reference existing games and contain the user in players
      final joinedIdx =
          await _usersRef.child(DbPaths.userJoinedGames(uid)).get();
      if (joinedIdx.exists) {
        final map = Map<dynamic, dynamic>.from(joinedIdx.value as Map);
        for (final gameId in map.keys) {
          final snap = await _gamesRef.child(gameId.toString()).get();
          if (!snap.exists) {
            issues.add('Orphan joinedGames index: $gameId');
            continue;
          }
          try {
            final game =
                Game.fromJson(Map<String, dynamic>.from(snap.value as Map));
            if (!game.players.contains(uid)) {
              issues
                  .add('joinedGames mismatch: $gameId missing user in players');
            }
          } catch (_) {
            issues.add('Corrupt game json for $gameId');
          }
        }
      }

      // 3) invites pointing to non-existing games
      final invitesIdx =
          await _usersRef.child(DbPaths.userGameInvites(uid)).get();
      if (invitesIdx.exists) {
        final map = Map<dynamic, dynamic>.from(invitesIdx.value as Map);
        for (final gameId in map.keys) {
          final snap = await _gamesRef.child(gameId.toString()).get();
          if (!snap.exists) {
            issues.add('Invite to non-existing game: $gameId');
          }
        }
      }
    } catch (e) {
      NumberedLogger.e('validateUserGameIndexes error: $e');
    }

    return issues;
  }

  /// Opportunistic self-healing for simple inconsistencies
  /// Only removes obviously broken indexes; never mutates game docs here.
  Future<int> fixSimpleInconsistencies({String? userId}) async {
    int fixes = 0;
    final uid = userId ?? _currentUserId;
    if (uid == null) return fixes;

    try {
      // Remove createdGames entries whose game does not exist
      final createdIdx =
          await _usersRef.child(DbPaths.userCreatedGames(uid)).get();
      if (createdIdx.exists) {
        final map = Map<dynamic, dynamic>.from(createdIdx.value as Map);
        for (final gameId in map.keys) {
          final exists =
              (await _gamesRef.child(gameId.toString()).get()).exists;
          if (!exists) {
            await _usersRef
                .child(DbPaths.userCreatedGames(uid))
                .child(gameId.toString())
                .remove();
            fixes++;
          }
        }
      }

      // Remove joinedGames entries whose game does not exist
      final joinedIdx =
          await _usersRef.child(DbPaths.userJoinedGames(uid)).get();
      if (joinedIdx.exists) {
        final map = Map<dynamic, dynamic>.from(joinedIdx.value as Map);
        for (final gameId in map.keys) {
          final exists =
              (await _gamesRef.child(gameId.toString()).get()).exists;
          if (!exists) {
            await _usersRef
                .child(DbPaths.userJoinedGames(uid))
                .child(gameId.toString())
                .remove();
            fixes++;
          }
        }
      }

      // Remove invites that point to non-existing games
      final invitesIdx =
          await _usersRef.child(DbPaths.userGameInvites(uid)).get();
      if (invitesIdx.exists) {
        final map = Map<dynamic, dynamic>.from(invitesIdx.value as Map);
        for (final gameId in map.keys) {
          final exists =
              (await _gamesRef.child(gameId.toString()).get()).exists;
          if (!exists) {
            await _usersRef
                .child(DbPaths.userGameInvites(uid))
                .child(gameId.toString())
                .remove();
            fixes++;
          }
        }
      }
    } catch (e) {
      NumberedLogger.e('fixSimpleInconsistencies error: $e');
    }

    if (fixes > 0) _clearCache();
    return fixes;
  }

  // Watch pending invites count
  Stream<int> watchPendingInvitesCount() {
    return _usersRef
        .child(DbPaths.userGameInvites(_currentUserId ?? ''))
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return 0;

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      int count = 0;
      for (final entry in data.values) {
        if (entry is Map && entry['status'] == 'pending') {
          count++;
        }
      }
      return count;
    });
  }

  // Join a game
  Future<void> joinGame(String gameId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      // Get the game
      final gameSnapshot = await _gamesRef.child(gameId).get();
      if (!gameSnapshot.exists) {
        throw NotFoundException('Game not found');
      }

      final game =
          Game.fromJson(Map<String, dynamic>.from(gameSnapshot.value as Map));

      // Check if user is already in the game
      if (game.players.contains(userId)) {
        throw AlreadyExistsException('Already joined this game');
      }

      // Check if game is full
      if (game.players.length >= game.maxPlayers) {
        throw ValidationException('Game is full');
      }

      // Add user to the game
      final updatedPlayers = List<String>.from(game.players)..add(userId);

      // Update the game
      await _gamesRef.child(gameId).update({
        'players': updatedPlayers,
        'currentPlayers': updatedPlayers.length,
      });

      // Add game to user's joined games
      await _usersRef.child(DbPaths.userJoinedGames(userId)).child(gameId).set({
        'sport': game.sport,
        'dateTime': game.dateTime.toIso8601String(),
        'location': game.location,
        'maxPlayers': game.maxPlayers,
        'joinedAt': DateTime.now().toIso8601String(),
      });

      // Remove from invites if it was an invite
      await _usersRef
          .child(DbPaths.userGameInvites(userId))
          .child(gameId)
          .remove();

      // Clear cache
      _clearCache();
    } catch (e, st) {
      NumberedLogger.e('Error joining game: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'game_join_fail');
      rethrow;
    }
  }

  // Leave a game
  Future<void> leaveGame(String gameId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      // Get the game
      final gameSnapshot = await _gamesRef.child(gameId).get();
      if (!gameSnapshot.exists) {
        throw NotFoundException('Game not found');
      }

      final game =
          Game.fromJson(Map<String, dynamic>.from(gameSnapshot.value as Map));

      // Check if user is in the game
      if (!game.players.contains(userId)) {
        throw NotFoundException('Not in this game');
      }

      // Remove user from the game
      final updatedPlayers = List<String>.from(game.players)..remove(userId);

      // Update the game
      await _gamesRef.child(gameId).update({
        'players': updatedPlayers,
        'currentPlayers': updatedPlayers.length,
      });

      // Remove game from user's joined games
      await _usersRef
          .child(DbPaths.userJoinedGames(userId))
          .child(gameId)
          .remove();

      // Clear cache
      _clearCache();
    } catch (e, st) {
      NumberedLogger.e('Error leaving game: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'game_leave_fail');
      rethrow;
    }
  }

  // Accept game invite
  Future<void> acceptGameInvite(String gameId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      // Check if user has a pending invite for this game
      final inviteSnapshot = await _usersRef
          .child(DbPaths.userGameInvites(userId))
          .child(gameId)
          .get();

      if (!inviteSnapshot.exists) {
        throw NotFoundException('No pending invite for this game');
      }

      final inviteData = Map<String, dynamic>.from(inviteSnapshot.value as Map);
      if (inviteData['status'] != 'pending') {
        throw ValidationException('Invite is not pending');
      }

      // Join the game (this will also remove the invite)
      await joinGame(gameId);
    } catch (e) {
      NumberedLogger.e('Error accepting game invite: $e');
      rethrow;
    }
  }

  // Decline game invite
  Future<void> declineGameInvite(String gameId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      // Remove the invite
      await _usersRef
          .child(DbPaths.userGameInvites(userId))
          .child(gameId)
          .remove();

      // Clear cache
      _clearCache();
    } catch (e) {
      NumberedLogger.e('Error declining game invite: $e');
      rethrow;
    }
  }

  // Get invite statuses for a game
  Future<Map<String, String>> getGameInviteStatuses(String gameId) async {
    try {
      final snapshot = await _gamesRef.child(gameId).child('invites').get();

      if (!snapshot.exists) {
        return {};
      }

      final invitesData = Map<String, dynamic>.from(snapshot.value as Map);
      final statuses = <String, String>{};

      for (final entry in invitesData.entries) {
        final uid = entry.key;
        final inviteData = entry.value as Map<String, dynamic>;
        statuses[uid] = inviteData['status']?.toString() ?? 'pending';
      }

      return statuses;
    } catch (e) {
      NumberedLogger.e('Error getting invite statuses for game $gameId: $e');
      return {};
    }
  }

  // Send game invites to friends
  // This will be implemented when we add friend invites functionality
  // For now, we'll just log it
  Future<void> sendGameInvitesToFriends(
      String gameId, List<String> friendUids) async {
    try {
      for (final friendUid in friendUids) {
        await _notificationService.sendGameInviteNotification(
            friendUid, gameId);
      }
      NumberedLogger.i(
          'Game invites sent to ${friendUids.length} friends for game $gameId');
    } catch (e) {
      NumberedLogger.e('Error sending game invites: $e');
    }
  }

  // Ensure user profile exists
  Future<void> _ensureUserProfile(String userId) async {
    try {
      final userRef = _usersRef.child(DbPaths.user(userId));
      final snapshot = await userRef.get();

      if (!snapshot.exists) {
        // Create basic user profile
        await userRef.set({
          'createdAt': DateTime.now().toIso8601String(),
          'lastSeen': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      NumberedLogger.e('Error ensuring user profile: $e');
    }
  }

  // Clear cache
  void _clearCache() {
    _gameCache.clear();
  }

  // Public cache invalidation for auth changes or external triggers
  void invalidateAllCache() {
    _clearCache();
  }

  // Clear expired cache entries
  void clearExpiredCache() {
    _gameCache.removeWhere((key, value) => value.isExpired);
  }
}
