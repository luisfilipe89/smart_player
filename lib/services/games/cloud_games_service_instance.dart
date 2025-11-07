// lib/services/cloud_games_service_instance.dart
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/db/db_paths.dart';
// import 'package:flutter/foundation.dart' show debugPrint;
import 'package:move_young/utils/logger.dart';
import '../notifications/notification_interface.dart';
import '../../utils/service_error.dart';
import 'package:move_young/utils/crashlytics_helper.dart';

// Background processing will be added when needed

/// Instance-based CloudGamesService for use with Riverpod dependency injection
class CloudGamesServiceInstance {
  final FirebaseDatabase _database;
  final FirebaseAuth _auth;
  // Notifications are now handled automatically by Cloud Function onGameInviteCreate
  // Keep this for backward compatibility with provider setup
  // ignore: unused_field
  final INotificationService _notificationService;

  // Query limits to prevent memory issues
  static const int _maxJoinableGames = 50;
  static const int _maxMyGames = 100;

  CloudGamesServiceInstance(
      this._database, this._auth, this._notificationService);

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
      return '${lat}_$lon';
    }
    final name = (game.location).toLowerCase();
    final sanitized = name
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    return sanitized.isEmpty ? 'unknown_field' : sanitized;
  }

  // Check if a slot is occupied by an active game
  Future<bool> _isSlotOccupiedByActiveGame(
      String dateKey, String fieldKey, String timeKey) async {
    try {
      // Query all active games
      final snapshot =
          await _gamesRef.orderByChild('isActive').equalTo(true).get();

      if (!snapshot.exists) {
        return false;
      }

      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      for (final entry in data.values) {
        try {
          final gameData = Map<String, dynamic>.from(entry);
          final game = Game.fromJson(gameData);

          // Check if this game uses the same slot
          final gameDateKey =
              gameData['slotDate']?.toString() ?? _dateKey(game.dateTime);
          final gameFieldKey =
              gameData['slotField']?.toString() ?? _fieldKeyForGame(game);
          final gameTimeKey =
              gameData['slotTime']?.toString() ?? _timeKey(game.dateTime);

          if (gameDateKey == dateKey &&
              gameFieldKey == fieldKey &&
              gameTimeKey == timeKey) {
            NumberedLogger.i(
                'Slot occupied by active game ${game.id} at ${game.location}');
            return true;
          }
        } catch (e) {
          NumberedLogger.w('Error parsing game when checking slot: $e');
        }
      }

      return false;
    } catch (e) {
      NumberedLogger.e('Error checking slot occupancy: $e');
      // On error, assume slot might be occupied to be safe
      return true;
    }
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

      // Compute unique slot keys
      final dateKey = _dateKey(game.dateTime);
      final timeKey = _timeKey(game.dateTime);
      final fieldKey = _fieldKeyForGame(game);

      // Check if slot exists and is occupied by an active game
      final slotRef = _database.ref('slots/$dateKey/$fieldKey/$timeKey');
      final slotSnapshot = await slotRef.get();

      if (slotSnapshot.exists && slotSnapshot.value == true) {
        // Slot exists, check if it's actually occupied by an active game
        final isOccupied =
            await _isSlotOccupiedByActiveGame(dateKey, fieldKey, timeKey);

        if (isOccupied) {
          NumberedLogger.w(
              'Slot $dateKey/$fieldKey/$timeKey is occupied by an active game');
          throw ValidationException('new_slot_unavailable');
        } else {
          // Stale slot - clean it up before creating new game
          NumberedLogger.i(
              'Cleaning up stale slot $dateKey/$fieldKey/$timeKey before creating game');
          await slotRef.set(null);
        }
      }

      // Create the game id now for an atomic multi-location update
      final gameRef = _gamesRef.push();
      final gameId = gameRef.key!;

      // Update game with the generated ID and initialize updatedAt to createdAt
      final gameWithId = game.copyWith(
        id: gameId,
        updatedAt: game.createdAt,
        updatedBy: userId,
      );

      // Prepare game data with slot keys for reliable cancellation
      final gameData = gameWithId.toCloudJson();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      gameData['lastOrganizerEditAt'] = nowMs; // Track organizer edits
      gameData['slotDate'] = dateKey;
      gameData['slotField'] = fieldKey;
      gameData['slotTime'] = timeKey;

      // Prepare atomic multi-path update:
      // - games/{id}
      // - users/{uid}/createdGames/{id}
      // - slots/{dateKey}/{fieldKey}/{timeKey} = true
      final Map<String, Object?> updates = {
        '${DbPaths.games}/$gameId': gameData,
        'users/$userId/createdGames/$gameId': {
          'sport': gameWithId.sport,
          'dateTime': gameWithId.dateTime.toIso8601String(),
          'location': gameWithId.location,
          'maxPlayers': gameWithId.maxPlayers,
        },
        'slots/$dateKey/$fieldKey/$timeKey': true,
      };

      // Atomic commit; should succeed now that we've cleaned up stale slots
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
      // Re-throw ValidationException as-is (already handled)
      if (e is ValidationException) {
        rethrow;
      }
      // For permission errors, check if it's actually a slot conflict
      if (e.toString().toLowerCase().contains('permission') ||
          e.toString().toLowerCase().contains('denied')) {
        // Double-check: query active games to see if slot is truly occupied
        try {
          final dateKey = _dateKey(game.dateTime);
          final timeKey = _timeKey(game.dateTime);
          final fieldKey = _fieldKeyForGame(game);
          final isOccupied =
              await _isSlotOccupiedByActiveGame(dateKey, fieldKey, timeKey);
          if (isOccupied) {
            throw ValidationException('new_slot_unavailable');
          }
        } catch (_) {
          // If check fails, assume it's a slot conflict
          throw ValidationException('new_slot_unavailable');
        }
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
    // Declare variables outside try block for catch block access
    bool slotChanged = false;
    String? newDateKey;
    String? newFieldKey;
    String? newTimeKey;

    try {
      // Load existing game to compute old slot
      final existingSnap = await _gamesRef.child(game.id).get();
      if (!existingSnap.exists) {
        throw NotFoundException('Game not found');
      }
      final existing =
          Game.fromJson(Map<String, dynamic>.from(existingSnap.value as Map));

      // Preserve isActive state - never resurrect cancelled games
      final bool existingIsActive = existing.isActive;
      final existingData = Map<String, dynamic>.from(existingSnap.value as Map);

      final oldDateKey = _dateKey(existing.dateTime);
      final oldTimeKey = _timeKey(existing.dateTime);
      final oldFieldKey = _fieldKeyForGame(existing);

      newDateKey = _dateKey(game.dateTime);
      newTimeKey = _timeKey(game.dateTime);
      newFieldKey = _fieldKeyForGame(game);

      // Ensure updatedAt and updatedBy are set, and preserve isActive state
      final now = DateTime.now();
      final gameToUpdate = game.copyWith(
        updatedAt: now,
        updatedBy: _currentUserId,
        isActive: existingIsActive, // Never resurrect cancelled games
      );

      slotChanged = oldDateKey != newDateKey ||
          oldTimeKey != newTimeKey ||
          oldFieldKey != newFieldKey;

      // Prepare game data with updated slot keys and lastOrganizerEditAt
      final gameData = gameToUpdate.toCloudJson();
      final nowMs = now.millisecondsSinceEpoch;
      gameData['lastOrganizerEditAt'] = nowMs; // Track organizer edits

      if (slotChanged) {
        // Update slot keys in game data
        gameData['slotDate'] = newDateKey;
        gameData['slotField'] = newFieldKey;
        gameData['slotTime'] = newTimeKey;
      } else {
        // Preserve existing slot keys if slot didn't change
        if (existingData['slotDate'] != null) {
          gameData['slotDate'] = existingData['slotDate'];
        }
        if (existingData['slotField'] != null) {
          gameData['slotField'] = existingData['slotField'];
        }
        if (existingData['slotTime'] != null) {
          gameData['slotTime'] = existingData['slotTime'];
        }
      }

      final Map<String, Object?> updates = {
        '${DbPaths.games}/${game.id}': gameData,
      };

      if (slotChanged) {
        // Check if new slot is occupied by an active game
        final newSlotRef =
            _database.ref('slots/$newDateKey/$newFieldKey/$newTimeKey');
        final newSlotSnapshot = await newSlotRef.get();

        if (newSlotSnapshot.exists && newSlotSnapshot.value == true) {
          // Slot exists, check if it's actually occupied by an active game
          final isOccupied = await _isSlotOccupiedByActiveGame(
              newDateKey, newFieldKey, newTimeKey);

          if (isOccupied) {
            NumberedLogger.w(
                'New slot $newDateKey/$newFieldKey/$newTimeKey is occupied by an active game');
            throw ValidationException('new_slot_unavailable');
          } else {
            // Stale slot - clean it up before claiming
            NumberedLogger.i(
                'Cleaning up stale slot $newDateKey/$newFieldKey/$newTimeKey before updating game');
            await newSlotRef.set(null);
          }
        }

        // Free old slot and claim new slot atomically
        updates['slots/$oldDateKey/$oldFieldKey/$oldTimeKey'] = null;
        updates['slots/$newDateKey/$newFieldKey/$newTimeKey'] = true;
      }

      await _database.ref().update(updates);
      // Streams will update automatically - no cache clearing needed
    } catch (e, st) {
      NumberedLogger.e('Error updating game: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'game_update_fail');
      // Re-throw ValidationException as-is (already handled)
      if (e is ValidationException) {
        rethrow;
      }
      // For permission errors, check if it's actually a slot conflict
      if (e.toString().toLowerCase().contains('permission') ||
          e.toString().toLowerCase().contains('denied')) {
        // Check if it's related to slot change
        if (slotChanged &&
            newDateKey != null &&
            newFieldKey != null &&
            newTimeKey != null) {
          try {
            final isOccupied = await _isSlotOccupiedByActiveGame(
                newDateKey, newFieldKey, newTimeKey);
            if (isOccupied) {
              throw ValidationException('new_slot_unavailable');
            }
          } catch (_) {
            // If check fails, assume it's a slot conflict
            throw ValidationException('new_slot_unavailable');
          }
        }
      }
      rethrow;
    }
  }

  // Cancel a game (mark inactive) and free its slot
  // Step 1: Cancel shows "Cancelled" to everyone and hides from Join screen
  // Step 2: Each user can use Remove to hide it from their My Games
  Future<void> deleteGame(String gameId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      // Load existing game for slot
      final existingSnap = await _gamesRef.child(gameId).get();
      if (!existingSnap.exists) {
        // Nothing to delete - just remove from user's createdGames index
        await _usersRef
            .child(DbPaths.userCreatedGames(userId))
            .child(gameId)
            .remove();
        // Streams will update automatically - no cache clearing needed
        return;
      }
      final existingData = Map<String, dynamic>.from(existingSnap.value as Map);
      final existing = Game.fromJson(existingData);

      // Get slot keys from stored data (preferred) or compute from game
      String? dateKey = existingData['slotDate']?.toString();
      String? fieldKey = existingData['slotField']?.toString();
      String? timeKey = existingData['slotTime']?.toString();

      // Fallback to computing if not stored (legacy games)
      dateKey ??= _dateKey(existing.dateTime);
      timeKey ??= _timeKey(existing.dateTime);
      fieldKey ??= _fieldKeyForGame(existing);

      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      // STEP 1: Mark game as inactive so it:
      // - Shows "Cancelled" badge to everyone (invited users)
      // - Hides from "Join a Game" screen (isActive=false filter)
      // - Stays in My Games lists so users can see it was cancelled
      // DO NOT remove from createdGames/joinedGames yet - let users decide when to remove
      final Map<String, Object?> updates = {
        // Mark game inactive instead of deleting so invitees see "Cancelled"
        '${DbPaths.games}/$gameId/isActive': false,
        '${DbPaths.games}/$gameId/updatedAt': nowMs,
        '${DbPaths.games}/$gameId/updatedBy': userId,
        '${DbPaths.games}/$gameId/canceledAt': nowMs,
        // Free the slot
        'slots/$dateKey/$fieldKey/$timeKey': null,
      };

      await _database.ref().update(updates);
      // Streams will update automatically - no cache clearing needed
    } catch (e, st) {
      NumberedLogger.e('Error deleting game: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'game_delete_fail');
      rethrow;
    }
  }

  // Remove game from user's createdGames index (hides it from organizer view)
  Future<void> removeFromMyCreated(String gameId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      await _usersRef
          .child(DbPaths.userCreatedGames(userId))
          .child(gameId)
          .remove();

      // Streams will update automatically - no cache clearing needed
    } catch (e, st) {
      NumberedLogger.e('Error removing game from created: $e');
      CrashlyticsHelper.recordError(e, st,
          reason: 'game_remove_from_created_fail');
      rethrow;
    }
  }

  // Remove game from user's joinedGames index (hides it from joined games list)
  Future<void> removeFromMyJoined(String gameId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw AuthException('User not authenticated');
      }

      await _usersRef
          .child(DbPaths.userJoinedGames(userId))
          .child(gameId)
          .remove();

      // Streams will update automatically - no cache clearing needed
    } catch (e, st) {
      NumberedLogger.e('Error removing game from joined: $e');
      CrashlyticsHelper.recordError(e, st,
          reason: 'game_remove_from_joined_fail');
      rethrow;
    }
  }

  // Get games for the current user (both organized and joined)
  // Note: No caching - direct Firebase query for real-time consistency (matches old behavior)
  Future<List<Game>> getMyGames({Duration? ttl}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return [];
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
            // Include upcoming games (active or cancelled) so users can see cancellation status
            if (game.dateTime.isAfter(now)) {
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
              // Include upcoming games (active or cancelled), and ensure user is actually in players list
              if (game.dateTime.isAfter(now) && game.players.contains(userId)) {
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

      return gamesList;
    } catch (e) {
      NumberedLogger.e('Error getting my games: $e');
      return [];
    }
  }

  // Get games that the user can join
  // Note: No caching - direct Firebase query for real-time consistency (matches old behavior)
  Future<List<Game>> getJoinableGames({Duration? ttl}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return [];
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
            final entryMap = Map<String, dynamic>.from(entry);
            final game = Game.fromJson(entryMap);

            // Filter out games organized by the current user
            if (game.organizerId == userId) {
              continue;
            }

            // For private games, only include if user has been invited
            final isPublic = entryMap['isPublic'] is bool
                ? entryMap['isPublic'] as bool
                : ((entryMap['isPublic'] ?? 1) == 1);

            if (!isPublic) {
              // Check if user has an invite for this private game
              final invites = entryMap['invites'];
              if (invites is Map) {
                final inviteMap = Map<dynamic, dynamic>.from(invites);
                final userInvite = inviteMap[userId];
                // Check if invite exists and has status 'pending' (or is just a string 'pending')
                final hasInvite = userInvite != null &&
                    (userInvite == 'pending' ||
                        (userInvite is Map &&
                            (userInvite['status']?.toString() ?? 'pending') ==
                                'pending'));

                if (!hasInvite) {
                  // Private game and user not invited - exclude it
                  continue;
                }
              } else {
                // Private game with no invites structure - exclude it
                continue;
              }
            }

            games.add(game);
          } catch (e) {
            NumberedLogger.w('Error parsing game: $e');
          }
        }
      }

      return games;
    } catch (e) {
      NumberedLogger.e('Error getting joinable games: $e');
      return [];
    }
  }

  // Watch joinable games (reactive)
  Stream<List<Game>> watchJoinableGames() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    return _gamesRef.orderByChild('isActive').equalTo(true).onValue.map((e) {
      if (!e.snapshot.exists) return <Game>[];
      final map = Map<dynamic, dynamic>.from(e.snapshot.value as Map);
      final list = <Game>[];
      for (final entry in map.values) {
        try {
          final entryMap = Map<String, dynamic>.from(entry);
          final g = Game.fromJson(entryMap);
          if (!g.isActive) continue;
          if (!g.dateTime.isAfter(DateTime.now())) continue;
          if (g.organizerId == userId) continue;

          // For private games, only include if user has been invited
          final isPublic = entryMap['isPublic'] is bool
              ? entryMap['isPublic'] as bool
              : ((entryMap['isPublic'] ?? 1) == 1);

          if (!isPublic) {
            // Check if user has an invite for this private game
            final invites = entryMap['invites'];
            if (invites is Map) {
              final inviteMap = Map<dynamic, dynamic>.from(invites);
              final userInvite = inviteMap[userId];
              // Check if invite exists and has status 'pending' (or is just a string 'pending')
              final hasInvite = userInvite != null &&
                  (userInvite == 'pending' ||
                      (userInvite is Map &&
                          (userInvite['status']?.toString() ?? 'pending') ==
                              'pending'));

              if (!hasInvite) {
                // Private game and user not invited - exclude it
                continue;
              }
            } else {
              // Private game with no invites structure - exclude it
              continue;
            }
          }

          list.add(g);
        } catch (_) {}
      }
      list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return list;
    });
  }

  // Get invited games for the current user
  // Note: No caching - direct Firebase query for real-time consistency
  Future<List<Game>> getInvitedGamesForCurrentUser({Duration? ttl}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return [];
      }

      // Fetch from Firebase - no cache to match old fast behavior
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
              // Only include active upcoming games - cancelled games should disappear
              if (game.isUpcoming && game.isActive) {
                games.add(game);
              }
            } catch (e) {
              NumberedLogger.w('Error parsing invited game: $e');
            }
          }
        }
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

    // Streams will update automatically - no cache clearing needed
    return fixes;
  }

  // Watch pending invites count
  // Uses watchInvitedGames() to ensure real-time updates when games are cancelled
  Stream<int> watchPendingInvitesCount() {
    return watchInvitedGames().map((games) {
      // Count only games where user hasn't joined yet (excludes games they accepted)
      final userId = _currentUserId;
      if (userId == null) return 0;

      final filteredGames =
          games.where((g) => !g.players.contains(userId)).toList();
      NumberedLogger.d(
          'Badge count: ${filteredGames.length} pending invites (${games.length} total invited games)');
      return filteredGames.length;
    });
  }

  // Watch a single game for real-time updates
  Stream<Game?> watchGame(String gameId) {
    return _gamesRef.child(gameId).onValue.map((event) {
      if (!event.snapshot.exists) return null;
      try {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return Game.fromJson(data);
      } catch (e) {
        NumberedLogger.w('Error parsing watched game: $e');
        return null;
      }
    });
  }

  // Watch invite statuses for a game in real-time
  Stream<Map<String, String>> watchGameInviteStatuses(String gameId) {
    return _gamesRef.child(gameId).child('invites').onValue.map((event) {
      final statuses = <String, String>{};
      if (!event.snapshot.exists) return statuses;

      final invitesData =
          Map<dynamic, dynamic>.from(event.snapshot.value as Map);
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
    });
  }

  // Watch invited games for the current user in real-time
  // Uses Firebase Query to automatically watch all games with pending invites
  // This matches the old fast behavior where the query automatically emits on any game change
  Stream<List<Game>> watchInvitedGames() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    // Use Firebase Query to watch all games with pending invites for this user
    // This automatically emits when ANY matching game changes (including cancellations)
    // This is the same approach as the old version and is more efficient and reliable
    final Query query =
        _gamesRef.orderByChild('invites/$userId/status').equalTo('pending');

    NumberedLogger.d('🔍 Starting watchInvitedGames query for user: $userId');
    NumberedLogger.d('🔍 Query path: invites/$userId/status = pending');

    return query.onValue
        .map((event) {
          NumberedLogger.d(
              '🔔 Query event received: exists=${event.snapshot.exists}');
          if (!event.snapshot.exists) {
            NumberedLogger.d('📭 Query returned no results');
            return <Game>[];
          }

          final List<Game> invited = [];
          NumberedLogger.d(
              '🔍 Parsing ${event.snapshot.children.length} games from query');

          // Parse all games from the query result
          // Firebase query automatically emits when ANY matching game changes
          for (final child in event.snapshot.children) {
            try {
              final Map<dynamic, dynamic> gameData =
                  child.value as Map<dynamic, dynamic>;

              // Check if user has pending invite
              final invites = gameData['invites'];
              if (invites is Map && invites.containsKey(userId)) {
                final entry = invites[userId];
                if (entry is Map &&
                    (entry['status']?.toString() ?? 'pending') == 'pending') {
                  final game =
                      Game.fromJson(Map<String, dynamic>.from(gameData));
                  // Only include active upcoming games - cancelled games should disappear
                  if (game.isUpcoming && game.isActive) {
                    invited.add(game);
                  }
                }
              }
            } catch (e) {
              NumberedLogger.w('Error parsing invited game from query: $e');
            }
          }

          // Sort by date (earliest first) - matches old behavior
          invited.sort((a, b) => a.dateTime.compareTo(b.dateTime));

          NumberedLogger.d(
              '📤 Query emitted ${invited.length} active upcoming invited games');

          return invited;
        })
        .transform(StreamTransformer<List<Game>, List<Game>>.fromHandlers(
          handleData: (data, sink) {
            sink.add(data);
          },
          handleError: (error, stackTrace, sink) {
            NumberedLogger.e('Error in watchInvitedGames: $error');
            sink.add(<Game>[]);
          },
        ))
        .transform(_distinctGamesTransformer());
  }

  // Watch games organized by current user for real-time updates
  Stream<List<Game>> watchMyGames() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    final now = DateTime.now();

    // Stream 1: Watch organized games by organizerId (captures all game data changes)
    // This will emit whenever ANY game organized by this user changes (cancellation, updates, etc.)
    final organizedGamesStream = _gamesRef
        .orderByChild('organizerId')
        .equalTo(userId)
        .onValue
        .asyncMap((event) async {
      final gamesMap = <String, Game>{};

      // Get current createdGames index to filter
      final createdIndexSnapshot =
          await _usersRef.child(DbPaths.userCreatedGames(userId)).get();
      final Set<String> createdGameIds = {};
      if (createdIndexSnapshot.exists) {
        final createdData =
            Map<dynamic, dynamic>.from(createdIndexSnapshot.value as Map);
        createdGameIds.addAll(createdData.keys.map((k) => k.toString()));
      }

      if (event.snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        for (final entry in data.values) {
          try {
            final game = Game.fromJson(Map<String, dynamic>.from(entry));
            // Only include if:
            // 1. Game is in userCreatedGames index (respects removal)
            // 2. Game is upcoming (includes cancelled games)
            if (createdGameIds.contains(game.id) &&
                game.dateTime.isAfter(now)) {
              gamesMap[game.id] = game;
            }
          } catch (e) {
            NumberedLogger.w('Error parsing organized game: $e');
          }
        }
      }

      return gamesMap;
    });

    // Stream 1b: Also watch userCreatedGames index to trigger re-filtering when games are removed
    // When index changes, we need to re-emit organized games with updated filter
    final createdIndexWatchStream = _usersRef
        .child(DbPaths.userCreatedGames(userId))
        .onValue
        .asyncMap((event) async {
      // Get current organized games and re-filter by index
      final organizedSnapshot =
          await _gamesRef.orderByChild('organizerId').equalTo(userId).get();

      final gamesMap = <String, Game>{};
      final Set<String> createdGameIds = {};

      if (event.snapshot.exists) {
        final createdData =
            Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        createdGameIds.addAll(createdData.keys.map((k) => k.toString()));
      }

      if (organizedSnapshot.exists) {
        final data = Map<dynamic, dynamic>.from(organizedSnapshot.value as Map);
        for (final entry in data.values) {
          try {
            final game = Game.fromJson(Map<String, dynamic>.from(entry));
            if (createdGameIds.contains(game.id) &&
                game.dateTime.isAfter(now)) {
              gamesMap[game.id] = game;
            }
          } catch (e) {
            NumberedLogger.w(
                'Error parsing organized game from index watch: $e');
          }
        }
      }

      return gamesMap;
    });

    // Stream 2: Watch joined games index AND fetch their current data
    // This handles both index changes (add/remove) and initial state
    final joinedGamesStream = _usersRef
        .child(DbPaths.userJoinedGames(userId))
        .onValue
        .asyncMap((event) async {
      final gamesMap = <String, Game>{};

      if (!event.snapshot.exists) return gamesMap;

      final joinedData =
          Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final joinedIds = joinedData.keys.map((k) => k.toString()).toList();

      // Fetch current state of all joined games
      for (final gameId in joinedIds) {
        try {
          final gameSnapshot = await _gamesRef.child(gameId).get();
          if (!gameSnapshot.exists) continue;
          final game = Game.fromJson(
              Map<String, dynamic>.from(gameSnapshot.value as Map));
          // Include upcoming games (active or cancelled), and ensure user is actually in players list
          if (game.dateTime.isAfter(now) && game.players.contains(userId)) {
            gamesMap[game.id] = game;
          }
        } catch (e) {
          NumberedLogger.w('Error fetching joined game $gameId: $e');
        }
      }

      return gamesMap;
    });

    // Stream 3: Watch individual game data streams for joined games (catches cancellations/updates)
    // When index changes, we watch each game's data stream to catch real-time updates
    final joinedGamesDataStreamController =
        StreamController<Map<String, Game>>();
    final joinedGameSubscriptions = <String, StreamSubscription<Game?>>{};
    final joinedGamesDataCache = <String, Game>{};

    // Helper to update watched games when index changes
    void updateWatchedJoinedGames(Set<String> gameIds) {
      // Cancel subscriptions for games no longer in index
      final gamesToRemove = joinedGameSubscriptions.keys
          .where((id) => !gameIds.contains(id))
          .toList();
      for (final gameId in gamesToRemove) {
        joinedGameSubscriptions[gameId]?.cancel();
        joinedGameSubscriptions.remove(gameId);
        joinedGamesDataCache.remove(gameId);
      }

      // Add subscriptions for new games
      for (final gameId in gameIds) {
        if (!joinedGameSubscriptions.containsKey(gameId)) {
          final sub = watchGame(gameId).listen((game) {
            if (game != null &&
                game.dateTime.isAfter(now) &&
                game.players.contains(userId)) {
              joinedGamesDataCache[gameId] = game;
            } else {
              joinedGamesDataCache.remove(gameId);
            }
            if (!joinedGamesDataStreamController.isClosed) {
              joinedGamesDataStreamController
                  .add(Map<String, Game>.from(joinedGamesDataCache));
            }
          }, onError: (e) {
            if (!joinedGamesDataStreamController.isClosed) {
              joinedGamesDataStreamController.addError(e);
            }
          });
          joinedGameSubscriptions[gameId] = sub;
        }
      }

      // IMPORTANT: Emit update after removing games so the UI updates immediately
      if (!joinedGamesDataStreamController.isClosed) {
        joinedGamesDataStreamController
            .add(Map<String, Game>.from(joinedGamesDataCache));
      }
    }

    // Cleanup when stream is cancelled - note: joinedIndexWatchSubRef is set below
    final joinedGamesDataStream = joinedGamesDataStreamController.stream;

    // Combine all streams
    final controller = StreamController<List<Game>>();
    StreamSubscription<Map<String, Game>>? organizedSub;
    StreamSubscription<Map<String, Game>>? organizedIndexSub;
    StreamSubscription<Map<String, Game>>? joinedIndexSub;
    StreamSubscription<Map<String, Game>>? joinedDataSub;
    StreamSubscription<DatabaseEvent>? joinedIndexWatchSubRef;

    // Track current state
    Map<String, Game> organizedGames = {};
    Map<String, Game> joinedGames = {};

    void emitCombined() {
      if (controller.isClosed) return;

      // Merge organized and joined games (organized take precedence)
      final allGamesMap = <String, Game>{
        ...joinedGames,
        ...organizedGames, // Organized games override joined if same ID
      };

      final allGames = allGamesMap.values.toList();
      allGames.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      controller.add(allGames);
    }

    // Watch organized games stream (game data changes)
    organizedSub = organizedGamesStream.listen((games) {
      organizedGames = games;
      emitCombined();
    }, onError: (e) {
      if (!controller.isClosed) controller.addError(e);
    });

    // Watch created games index stream (index changes trigger re-filtering)
    organizedIndexSub = createdIndexWatchStream.listen((games) {
      organizedGames = games;
      emitCombined();
    }, onError: (e) {
      if (!controller.isClosed) controller.addError(e);
    });

    // Watch joined games index stream (handles add/remove from index)
    joinedIndexSub = joinedGamesStream.listen((games) {
      // Update or add games from index fetch
      for (final entry in games.entries) {
        joinedGames[entry.key] = entry.value;
      }
      // Note: Don't remove games here - let joinedGamesDataStream handle removals
      // based on index watch, which will stop emitting for removed games
      emitCombined();
    }, onError: (e) {
      if (!controller.isClosed) controller.addError(e);
    });

    // Watch individual game data streams for joined games (handles cancellations/updates)
    joinedDataSub = joinedGamesDataStream.listen((games) {
      // Update joined games with latest data from individual streams
      for (final entry in games.entries) {
        joinedGames[entry.key] = entry.value;
      }
      // Remove games that are no longer in the cache (removed from index)
      joinedGames.removeWhere((key, _) => !games.containsKey(key));
      emitCombined();
    }, onError: (e) {
      if (!controller.isClosed) controller.addError(e);
    });

    // Store reference to index watch subscription for updating watched games
    joinedIndexWatchSubRef = _usersRef
        .child(DbPaths.userJoinedGames(userId))
        .onValue
        .listen((event) {
      if (!event.snapshot.exists) {
        updateWatchedJoinedGames({});
        return;
      }
      final joinedData =
          Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final gameIds = joinedData.keys.map((k) => k.toString()).toSet();
      updateWatchedJoinedGames(gameIds);
    });

    // Initial fetch to populate data
    Future.microtask(() async {
      // Fetch initial organized games
      final organizedSnapshot =
          await _gamesRef.orderByChild('organizerId').equalTo(userId).get();
      final createdIndexSnapshot =
          await _usersRef.child(DbPaths.userCreatedGames(userId)).get();
      final Set<String> createdGameIds = {};
      if (createdIndexSnapshot.exists) {
        final createdData =
            Map<dynamic, dynamic>.from(createdIndexSnapshot.value as Map);
        createdGameIds.addAll(createdData.keys.map((k) => k.toString()));
      }
      if (organizedSnapshot.exists) {
        final data = Map<dynamic, dynamic>.from(organizedSnapshot.value as Map);
        for (final entry in data.values) {
          try {
            final game = Game.fromJson(Map<String, dynamic>.from(entry));
            if (createdGameIds.contains(game.id) &&
                game.dateTime.isAfter(now)) {
              organizedGames[game.id] = game;
            }
          } catch (e) {
            NumberedLogger.w('Error parsing initial organized game: $e');
          }
        }
      }

      // Fetch initial joined games
      final joinedSnapshot =
          await _usersRef.child(DbPaths.userJoinedGames(userId)).get();
      if (joinedSnapshot.exists) {
        final joinedData =
            Map<dynamic, dynamic>.from(joinedSnapshot.value as Map);
        final joinedIds = joinedData.keys.map((k) => k.toString()).toSet();
        updateWatchedJoinedGames(joinedIds);

        for (final gameId in joinedIds) {
          try {
            final gameSnapshot = await _gamesRef.child(gameId).get();
            if (gameSnapshot.exists) {
              final game = Game.fromJson(
                  Map<String, dynamic>.from(gameSnapshot.value as Map));
              if (game.dateTime.isAfter(now) && game.players.contains(userId)) {
                joinedGames[game.id] = game;
              }
            }
          } catch (e) {
            NumberedLogger.w('Error fetching initial joined game $gameId: $e');
          }
        }
      }

      emitCombined();
    });

    controller.onCancel = () {
      organizedSub?.cancel();
      organizedIndexSub?.cancel();
      joinedIndexSub?.cancel();
      joinedDataSub?.cancel();
      joinedIndexWatchSubRef?.cancel();
      for (final sub in joinedGameSubscriptions.values) {
        sub.cancel();
      }
      joinedGameSubscriptions.clear();
      joinedGamesDataStreamController.close();
    };

    // Use a more lenient distinct that only checks for meaningful changes
    // but still emits when games are added/removed or player counts change
    return controller.stream.distinct((prev, next) {
      if (prev.length != next.length) return false;

      // Create maps for faster lookup
      final prevMap = {for (var g in prev) g.id: g};
      final nextMap = {for (var g in next) g.id: g};

      for (final gameId in prevMap.keys) {
        final prevGame =
            prevMap[gameId]!; // Safe: we're iterating over keys that exist
        final nextGame = nextMap[gameId];

        if (nextGame == null) return false; // Game was removed

        // Check for meaningful changes
        if (prevGame.currentPlayers != nextGame.currentPlayers ||
            prevGame.players.length != nextGame.players.length ||
            prevGame.dateTime != nextGame.dateTime ||
            prevGame.location != nextGame.location ||
            prevGame.updatedAt != nextGame.updatedAt ||
            prevGame.isActive != nextGame.isActive) {
          return false; // Something meaningful changed
        }
      }

      // Check for new games
      for (final gameId in nextMap.keys) {
        if (!prevMap.containsKey(gameId)) return false;
      }

      return true; // No meaningful changes
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

      // Prepare atomic updates
      final Map<String, Object?> updates = {};

      // Update the game
      updates['${DbPaths.games}/$gameId/players'] = updatedPlayers;
      updates['${DbPaths.games}/$gameId/currentPlayers'] =
          updatedPlayers.length;

      // Update invite status in games/{gameId}/invites/{uid} if it exists
      final inviteCheckSnapshot =
          await _gamesRef.child(gameId).child('invites').child(userId).get();
      if (inviteCheckSnapshot.exists) {
        updates['${DbPaths.games}/$gameId/invites/$userId/status'] = 'accepted';
      }

      // Remove from user's invite list (this will trigger badge update)
      updates['users/$userId/gameInvites/$gameId'] = null;

      // Add game to user's joined games
      updates['users/$userId/joinedGames/$gameId'] = {
        'sport': game.sport,
        'dateTime': game.dateTime.toIso8601String(),
        'location': game.location,
        'maxPlayers': game.maxPlayers,
        'joinedAt': DateTime.now().toIso8601String(),
      };

      // Commit all updates atomically
      await _database.ref().update(updates);

      // Streams will update automatically - no cache clearing needed
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

      // Prepare atomic updates
      final Map<String, Object?> updates = {};

      // Update the game
      updates['${DbPaths.games}/$gameId/players'] = updatedPlayers;
      updates['${DbPaths.games}/$gameId/currentPlayers'] =
          updatedPlayers.length;

      // Update invite status to 'left' if invite exists (so organizer sees red cross)
      final inviteCheckSnapshot =
          await _gamesRef.child(gameId).child('invites').child(userId).get();
      if (inviteCheckSnapshot.exists) {
        updates['${DbPaths.games}/$gameId/invites/$userId/status'] = 'left';
      }

      // Commit updates atomically
      await _database.ref().update(updates);

      // Remove game from user's joined games
      await _usersRef
          .child(DbPaths.userJoinedGames(userId))
          .child(gameId)
          .remove();

      // Streams will update automatically - no cache clearing needed
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

      // Prepare atomic updates
      final Map<String, Object?> updates = {};

      // Update invite status to 'declined' if invite exists (so organizer sees red cross)
      final inviteCheckSnapshot =
          await _gamesRef.child(gameId).child('invites').child(userId).get();
      if (inviteCheckSnapshot.exists) {
        updates['${DbPaths.games}/$gameId/invites/$userId/status'] = 'declined';
      }

      // Remove from user's invite list (this will trigger badge update)
      updates['users/$userId/gameInvites/$gameId'] = null;

      // Commit all updates atomically
      await _database.ref().update(updates);

      // Streams will update automatically - no cache clearing needed
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

      // Notifications are automatically sent by Cloud Function onGameInviteCreate
      // when invites are written to /games/{gameId}/invites/{inviteeUid}
      NumberedLogger.i(
          'Game invites sent to ${friendUids.length} friends for game $gameId. Notifications will be sent automatically by Cloud Function.');
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

  // Cache invalidation methods (no-op - no caching to match old fast behavior)
  // Kept for API compatibility but doesn't do anything since we're not caching
  void invalidateAllCache() {
    // No-op: no cache in use to match old real-time behavior
  }

  void clearExpiredCache() {
    // No-op: no cache in use to match old real-time behavior
  }

  // Custom distinct transformer for game lists
  StreamTransformer<List<Game>, List<Game>> _distinctGamesTransformer() {
    List<Game>? lastValue;
    return StreamTransformer<List<Game>, List<Game>>.fromHandlers(
      handleData: (data, sink) {
        if (lastValue == null) {
          lastValue = data;
          sink.add(data);
          return;
        }

        final prev = lastValue!;
        final next = data;

        // Only emit if list actually changed meaningfully
        if (prev.length != next.length) {
          NumberedLogger.d(
              '🔄 Distinct: List length changed ${prev.length} -> ${next.length}');
          lastValue = next;
          sink.add(next);
          return;
        }

        // Create maps for faster lookup
        final prevMap = {for (var g in prev) g.id: g};
        final nextMap = {for (var g in next) g.id: g};

        for (final gameId in prevMap.keys) {
          final prevGame = prevMap[gameId]!;
          final nextGame = nextMap[gameId];

          if (nextGame == null) {
            NumberedLogger.d('🔄 Distinct: Game $gameId was removed');
            lastValue = next;
            sink.add(next);
            return;
          }

          // Check for meaningful changes (especially isActive for cancellations)
          if (prevGame.isActive != nextGame.isActive ||
              prevGame.currentPlayers != nextGame.currentPlayers ||
              prevGame.players.length != nextGame.players.length ||
              prevGame.dateTime != nextGame.dateTime ||
              prevGame.location != nextGame.location ||
              prevGame.address != nextGame.address ||
              prevGame.maxPlayers != nextGame.maxPlayers ||
              prevGame.updatedAt != nextGame.updatedAt) {
            NumberedLogger.d(
                '🔄 Distinct: Game $gameId changed - isActive: ${prevGame.isActive}->${nextGame.isActive}');
            lastValue = next;
            sink.add(next);
            return;
          }
        }

        // Check for new games
        for (final gameId in nextMap.keys) {
          if (!prevMap.containsKey(gameId)) {
            NumberedLogger.d('🔄 Distinct: New game $gameId added');
            lastValue = next;
            sink.add(next);
            return;
          }
        }

        // No meaningful changes, don't emit
      },
    );
  }
}
