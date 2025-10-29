// lib/services/cloud_games_service_instance.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/db/db_paths.dart';
// import 'package:flutter/foundation.dart' show debugPrint;
import 'package:move_young/utils/logger.dart';
import 'package:move_young/models/infrastructure/cached_data.dart';
// Cache TTL configurable via constructor if needed
import '../notifications/notification_interface.dart';
import '../../utils/service_error.dart';
import 'package:move_young/utils/crashlytics_helper.dart';

// Background processing will be added when needed

/// Instance-based CloudGamesService for use with Riverpod dependency injection
class CloudGamesServiceInstance {
  final FirebaseDatabase _database;
  final FirebaseAuth _auth;
  final INotificationService _notificationService;
  final Duration _gamesTtl;

  // Query limits to prevent memory issues
  static const int _maxJoinableGames = 50;
  static const int _maxMyGames = 100;

  CloudGamesServiceInstance(
      this._database, this._auth, this._notificationService,
      {Duration? gamesTtl})
      : _gamesTtl = gamesTtl ?? const Duration(minutes: 5);

  // Cache for games data
  final Map<String, CachedData<List<Game>>> _gameCache = {};
  // default TTL retained for reference

  // Database references
  DatabaseReference get _gamesRef => _database.ref(DbPaths.games);
  DatabaseReference get _usersRef => _database.ref(DbPaths.users);

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // --- Helpers for slot keys ---
  // Format yyyy-MM-dd in local time for date partitioning
  String _dateKey(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // Format HHmm in local time for time partitioning (avoid ':' in keys)
  String _timeKey(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h$m';
  }

  // Compute a stable field key. Prefer explicit fieldId; else lat,lon; else sanitized name
  String _fieldKeyForGame(Game game) {
    if ((game.fieldId ?? '').toString().trim().isNotEmpty) {
      return game.fieldId!.trim();
    }
    if (game.latitude != null && game.longitude != null) {
      final lat = game.latitude!.toStringAsFixed(5).replaceAll('.', '_');
      final lon = game.longitude!.toStringAsFixed(5).replaceAll('.', '_');
      return '${lat}_${lon}';
    }
    final name = (game.location).toLowerCase();
    final sanitized = name
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    return sanitized.isEmpty ? 'unknown_field' : sanitized;
  }

  // Create a new game in the cloud
  Future<String> createGame(Game game) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      // Ensure the user has a profile
      await _ensureUserProfile(userId);

      // Create the game id now for an atomic multi-location update
      final gameRef = _gamesRef.push();
      final gameId = gameRef.key!;

      // Update game with the generated ID
      final gameWithId = game.copyWith(id: gameId);

      // Compute unique slot keys
      final dateKey = _dateKey(gameWithId.dateTime);
      final timeKey = _timeKey(gameWithId.dateTime);
      final fieldKey = _fieldKeyForGame(gameWithId);

      // Prepare atomic multi-path update:
      // - games/{id}
      // - users/{uid}/createdGames/{id}
      // - slots/{dateKey}/{fieldKey}/{timeKey} = true
      final Map<String, Object?> updates = {
        '${DbPaths.games}/$gameId': gameWithId.toCloudJson(),
        'users/$userId/createdGames/$gameId': {
          'sport': gameWithId.sport,
          'dateTime': gameWithId.dateTime.toIso8601String(),
          'location': gameWithId.location,
          'maxPlayers': gameWithId.maxPlayers,
        },
        'slots/$dateKey/$fieldKey/$timeKey': true,
      };

      // Atomic commit; will fail if slot already exists due to security rules
      await _database.ref().update(updates);

      // Send notifications to invited friends
      // This will be implemented when we add friend invites functionality
      // For now, we'll just log it
      NumberedLogger.i('Game created successfully: $gameId');
      CrashlyticsHelper.breadcrumb('game_create_ok:$gameId');

      return gameId;
    } catch (e, st) {
      NumberedLogger.e('Error creating game: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'game_create_fail');
      // Surface a clearer error message for slot collisions
      if (e.toString().toLowerCase().contains('permission') ||
          e.toString().toLowerCase().contains('denied')) {
        throw ValidationException('new_slot_unavailable');
      }
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

  // Update a game (atomically move slot if date/field/time changed)
  Future<void> updateGame(Game game) async {
    try {
      // Load existing game to compute old slot
      final existingSnap = await _gamesRef.child(game.id).get();
      if (!existingSnap.exists) {
        throw NotFoundException('Game not found');
      }
      final existing =
          Game.fromJson(Map<String, dynamic>.from(existingSnap.value as Map));

      final oldDateKey = _dateKey(existing.dateTime);
      final oldTimeKey = _timeKey(existing.dateTime);
      final oldFieldKey = _fieldKeyForGame(existing);

      final newDateKey = _dateKey(game.dateTime);
      final newTimeKey = _timeKey(game.dateTime);
      final newFieldKey = _fieldKeyForGame(game);

      final Map<String, Object?> updates = {
        '${DbPaths.games}/${game.id}': game.toCloudJson(),
      };

      final slotChanged = oldDateKey != newDateKey ||
          oldTimeKey != newTimeKey ||
          oldFieldKey != newFieldKey;
      if (slotChanged) {
        // Free old slot and claim new slot
        updates['slots/$oldDateKey/$oldFieldKey/$oldTimeKey'] = null;
        updates['slots/$newDateKey/$newFieldKey/$newTimeKey'] = true;
      }

      await _database.ref().update(updates);
      _clearCache();
    } catch (e, st) {
      NumberedLogger.e('Error updating game: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'game_update_fail');
      if (e.toString().toLowerCase().contains('permission') ||
          e.toString().toLowerCase().contains('denied')) {
        throw ValidationException('new_slot_unavailable');
      }
      rethrow;
    }
  }

  // Delete a game (also free its slot)
  Future<void> deleteGame(String gameId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      // Load existing game for slot
      final existingSnap = await _gamesRef.child(gameId).get();
      if (!existingSnap.exists) {
        // Nothing to delete
        await _usersRef
            .child(DbPaths.userCreatedGames(userId))
            .child(gameId)
            .remove();
        _clearCache();
        return;
      }
      final existing =
          Game.fromJson(Map<String, dynamic>.from(existingSnap.value as Map));
      final dateKey = _dateKey(existing.dateTime);
      final timeKey = _timeKey(existing.dateTime);
      final fieldKey = _fieldKeyForGame(existing);

      final Map<String, Object?> updates = {
        '${DbPaths.games}/$gameId': null,
        'users/$userId/createdGames/$gameId': null,
        'slots/$dateKey/$fieldKey/$timeKey': null,
      };

      await _database.ref().update(updates);
      _clearCache();
    } catch (e, st) {
      NumberedLogger.e('Error deleting game: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'game_delete_fail');
      rethrow;
    }
  }

  // Get games for the current user (both organized and joined)
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

      final gamesMap = <String, Game>{};
      final now = DateTime.now();

      // 1. Fetch games organized by the user
      final organizedSnapshot = await _gamesRef
          .orderByChild('organizerId')
          .equalTo(userId)
          .limitToFirst(_maxMyGames)
          .get();

      if (organizedSnapshot.exists) {
        final data = Map<dynamic, dynamic>.from(organizedSnapshot.value as Map);
        for (final entry in data.values) {
          try {
            final game = Game.fromJson(Map<String, dynamic>.from(entry));
            // Only include upcoming and active games in "My Games"
            if (game.isActive && game.dateTime.isAfter(now)) {
              gamesMap[game.id] = game;
            }
          } catch (e) {
            NumberedLogger.w('Error parsing organized game: $e');
          }
        }
      }

      // 2. Fetch games the user joined (from joinedGames index)
      final joinedGamesSnapshot =
          await _usersRef.child(DbPaths.userJoinedGames(userId)).get();

      if (joinedGamesSnapshot.exists) {
        final joinedData =
            Map<dynamic, dynamic>.from(joinedGamesSnapshot.value as Map);
        final gameIds = joinedData.keys.map((k) => k.toString()).toList();

        // Batch fetch all joined games
        final gameFutures = gameIds.map((id) => _gamesRef.child(id).get());
        final gameSnapshots = await Future.wait(gameFutures);

        for (final gameSnapshot in gameSnapshots) {
          if (gameSnapshot.exists) {
            try {
              final game = Game.fromJson(
                  Map<String, dynamic>.from(gameSnapshot.value as Map));
              // Only include upcoming and active games, and ensure user is actually in players list
              if (game.isActive &&
                  game.dateTime.isAfter(now) &&
                  game.players.contains(userId)) {
                gamesMap[game.id] = game;
              }
            } catch (e) {
              NumberedLogger.w('Error parsing joined game: $e');
            }
          }
        }
      }

      // Convert to list and sort by date (earliest first)
      final gamesList = gamesMap.values.toList();
      gamesList.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      // Cache the result
      _gameCache[cacheKey] = CachedData(
        gamesList,
        DateTime.now(),
        expiry: ttl ?? _gamesTtl,
      );

      return gamesList;
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
      _gameCache[cacheKey] = CachedData(
        games,
        DateTime.now(),
        expiry: ttl ?? _gamesTtl,
      );

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

      // Check cache first (only if TTL is not zero/force refresh)
      final cacheKey = 'invited_games_$userId';
      final shouldUseCache = ttl == null || ttl.inSeconds > 0;
      if (shouldUseCache) {
        final cached = _gameCache[cacheKey];
        if (cached != null && !cached.isExpired) {
          NumberedLogger.d('Using cached invited games for $userId');
          return cached.data;
        }
      } else {
        NumberedLogger.d('Force refreshing invited games for $userId (TTL=0)');
      }

      // Fetch from Firebase
      final snapshot =
          await _usersRef.child(DbPaths.userGameInvites(userId)).get();

      final games = <Game>[];
      if (snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        NumberedLogger.d(
            'Raw invite data for $userId: ${data.keys.length} entries');

        // Collect pending invite gameIds first
        final gameIds = <String>[];
        for (final entry in data.entries) {
          final gameId = entry.key.toString();
          final inviteData = entry.value;

          if (inviteData is! Map) {
            NumberedLogger.w(
                'Invite data for $gameId is not a Map: $inviteData');
            continue;
          }

          final inviteMap = Map<dynamic, dynamic>.from(inviteData);
          final status = inviteMap['status']?.toString();

          NumberedLogger.d('Game $gameId: status=$status');

          if (status == 'pending') {
            gameIds.add(gameId);
            NumberedLogger.d('Added pending game $gameId to list');
          } else {
            NumberedLogger.d(
                'Skipping game $gameId (status=$status, not pending)');
          }
        }

        NumberedLogger.d(
            'Found ${gameIds.length} pending invites out of ${data.length} total');

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

      // Cache the result (only if TTL is valid)
      if (shouldUseCache) {
        _gameCache[cacheKey] = CachedData(
          games,
          DateTime.now(),
          expiry: ttl ?? _gamesTtl,
        );
        NumberedLogger.d('Cached ${games.length} invited games for $userId');
      }

      NumberedLogger.i('Fetched ${games.length} invited games for $userId');
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

      final invitesData = Map<dynamic, dynamic>.from(snapshot.value as Map);
      final statuses = <String, String>{};

      for (final entry in invitesData.entries) {
        final uid = entry.key.toString();
        final inviteValue = entry.value;

        // Handle both Map and String cases
        String status;
        if (inviteValue is Map) {
          final inviteMap = Map<dynamic, dynamic>.from(inviteValue);
          status = inviteMap['status']?.toString() ?? 'pending';
        } else {
          // If it's just a string (legacy format)
          status = inviteValue?.toString() ?? 'pending';
        }

        statuses[uid] = status;
      }

      return statuses;
    } catch (e) {
      NumberedLogger.e('Error getting invite statuses for game $gameId: $e');
      return {};
    }
  }

  // Send game invites to friends
  Future<void> sendGameInvitesToFriends(
      String gameId, List<String> friendUids) async {
    try {
      if (friendUids.isEmpty) return;

      final userId = _currentUserId;
      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      NumberedLogger.d(
          'Sending invites for game $gameId to ${friendUids.length} friends');

      // Get game details to include in invites
      final game = await getGameById(gameId);
      if (game == null) {
        NumberedLogger.e('Game not found when sending invites: $gameId');
        throw NotFoundException('Game not found: $gameId');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final inviteDateString = game.dateTime.toIso8601String();

      // Prepare atomic multi-path update for all invites
      final Map<String, Object?> updates = {};

      for (final friendUid in friendUids) {
        // Write to games/{gameId}/invites/{uid}: {status: 'pending'}
        final gameInvitePath = '${DbPaths.games}/$gameId/invites/$friendUid';
        updates[gameInvitePath] = {
          'status': 'pending',
        };

        // Write to users/{uid}/gameInvites/{gameId}: {status, ts, organizerId, sport, date}
        final userInvitePath = 'users/$friendUid/gameInvites/$gameId';
        updates[userInvitePath] = {
          'status': 'pending',
          'ts': timestamp,
          'organizerId': game.organizerId,
          'sport': game.sport,
          'date': inviteDateString,
        };

        NumberedLogger.d(
            'Prepared invite paths: game=$gameInvitePath, user=$userInvitePath');
      }

      NumberedLogger.d(
          'Committing ${updates.length} invite updates atomically');

      // Atomic commit all invites
      try {
        await _database.ref().update(updates);
        NumberedLogger.i(
            'Successfully wrote ${friendUids.length} invites to database');
      } catch (e) {
        NumberedLogger.e('Failed to write invites to database: $e');
        NumberedLogger.e('Update paths were: ${updates.keys.join(', ')}');
        rethrow;
      }

      // Send notifications after successfully writing to DB
      for (final friendUid in friendUids) {
        try {
          await _notificationService.sendGameInviteNotification(
              friendUid, gameId);
          NumberedLogger.d('Notification sent to $friendUid');
        } catch (e) {
          // Log notification errors but don't fail the entire operation
          NumberedLogger.w('Failed to send notification to $friendUid: $e');
        }
      }

      NumberedLogger.i(
          'Game invites sent to ${friendUids.length} friends for game $gameId');
    } catch (e, stackTrace) {
      NumberedLogger.e('Error sending game invites: $e');
      NumberedLogger.e('Stack trace: $stackTrace');
      rethrow;
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
