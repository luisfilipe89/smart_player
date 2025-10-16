// lib/services/cloud_games_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/models/game.dart';
import 'package:move_young/db/db_paths.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';

class CloudGamesService {
  static FirebaseDatabase get _database => FirebaseDatabase.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  // Database references
  static DatabaseReference get _gamesRef => _database.ref(DbPaths.games);
  static DatabaseReference get _usersRef => _database.ref(DbPaths.users);

  // Get current user ID
  static String? get _currentUserId => _auth.currentUser?.uid;

  // --- Helpers for slot keys ---
  static String _formatDateKey(DateTime dt) {
    final d = DateTime(dt.year, dt.month, dt.day);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static String _formatTimeKey(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh$mm';
  }

  // Attempt to clear an orphaned slot lock when no active game actually occupies it.
  // This can happen if the slot removal failed during cancellation due to transient errors or rules.
  static Future<bool> _clearOrphanedSlotIfNoActiveGame({
    required Game game,
    required String dateKey,
    required String fieldKey,
    required String timeKey,
  }) async {
    try {
      // Determine if any active game truly occupies the same field/time
      bool activeExists = false;

      if ((game.fieldId ?? '').isNotEmpty) {
        try {
          final Query byId =
              _gamesRef.orderByChild('fieldId').equalTo(game.fieldId);
          final DataSnapshot sId = await byId.get();
          if (sId.exists) {
            for (final child in sId.children) {
              try {
                final Map<dynamic, dynamic> map =
                    child.value as Map<dynamic, dynamic>;
                final g = Game.fromJson(Map<String, dynamic>.from(map));
                if (!g.isActive) continue;
                if (g.dateTime.year == game.dateTime.year &&
                    g.dateTime.month == game.dateTime.month &&
                    g.dateTime.day == game.dateTime.day &&
                    g.dateTime.hour == game.dateTime.hour &&
                    g.dateTime.minute == game.dateTime.minute) {
                  activeExists = true;
                  break;
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      // Fallback check by location if fieldId check found nothing
      if (!activeExists) {
        try {
          final Query byLocation =
              _gamesRef.orderByChild('location').equalTo(game.location);
          final DataSnapshot sLoc = await byLocation.get();
          if (sLoc.exists) {
            for (final child in sLoc.children) {
              try {
                final Map<dynamic, dynamic> map =
                    child.value as Map<dynamic, dynamic>;
                final g = Game.fromJson(Map<String, dynamic>.from(map));
                if (!g.isActive) continue;
                if (g.dateTime.year == game.dateTime.year &&
                    g.dateTime.month == game.dateTime.month &&
                    g.dateTime.day == game.dateTime.day &&
                    g.dateTime.hour == game.dateTime.hour &&
                    g.dateTime.minute == game.dateTime.minute) {
                  activeExists = true;
                  break;
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      if (activeExists) return false;

      // Build candidate field keys that might have been used historically
      final List<String> candidateFieldKeys = <String>{
        fieldKey,
        if ((game.fieldId ?? '').isNotEmpty) game.fieldId!,
        base64Url.encode(utf8.encode(game.location)),
        base64Url.encode(utf8.encode(game.location.trim())),
        base64Url.encode(
            utf8.encode(game.location.replaceAll(RegExp(r'\s+'), ' ').trim())),
      }.where((k) => k.isNotEmpty).toList();

      // Try removing each candidate path directly
      for (final k in candidateFieldKeys) {
        try {
          await _database.ref('slots/$dateKey/$k/$timeKey').remove();
          return true;
        } catch (_) {}
      }

      // As a last resort, inspect the date bucket and try to match a child that looks like ours
      try {
        final DataSnapshot daySnap =
            await _database.ref('slots/$dateKey').get();
        if (daySnap.exists) {
          for (final child in daySnap.children) {
            final String k = child.key ?? '';
            if (k.isEmpty) continue;
            // Quick filter: only consider keys that are in our candidate list, otherwise skip
            if (!candidateFieldKeys.contains(k)) continue;
            try {
              final DataSnapshot timeSnap =
                  await _database.ref('slots/$dateKey/$k/$timeKey').get();
              if (timeSnap.exists) {
                try {
                  await _database.ref('slots/$dateKey/$k/$timeKey').remove();
                  return true;
                } catch (_) {}
              }
            } catch (_) {}
          }
        }
      } catch (_) {}

      return false;
    } catch (_) {
      return false;
    }
  }

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

      // Atomic slot claim via RTDB rules: slots/<date>/<field>/<HHmm> = true
      final String dateKey = _formatDateKey(game.dateTime);
      final String fieldKey = (game.fieldId != null && game.fieldId!.isNotEmpty)
          ? game.fieldId!
          : base64Url.encode(utf8.encode(game.location));
      final String timeKey = _formatTimeKey(game.dateTime);
      try {
        await _database.ref('slots/$dateKey/$fieldKey/$timeKey').set(true);
      } catch (e) {
        // Permission denied -> already claimed
        // Best-effort recovery: clear orphaned lock and retry once
        final cleared = await _clearOrphanedSlotIfNoActiveGame(
          game: game,
          dateKey: dateKey,
          fieldKey: fieldKey,
          timeKey: timeKey,
        );
        if (cleared) {
          try {
            await _database.ref('slots/$dateKey/$fieldKey/$timeKey').set(true);
          } catch (_) {
            throw Exception('slot_already_booked');
          }
        } else {
          throw Exception('slot_already_booked');
        }
      }

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
      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      gameData['updatedAt'] = nowMs;
      // Track last organizer-driven edit separately from generic updates
      // so player joins/leaves don't trigger 'Modified' for invitees.
      gameData['lastOrganizerEditAt'] = gameData['createdAt'] ?? nowMs;

      // Persist slot keys for cleanup on cancel/update
      gameData['slotDate'] = dateKey;
      gameData['slotField'] = fieldKey;
      gameData['slotTime'] = timeKey;

      // Auto-enroll organizer as a player (already reflected in data)

      await gameRef.set(gameData);
      // Also index under users/<uid>/createdGames for discoverability and organizer UI
      if (organizerUid.isNotEmpty) {
        try {
          await _usersRef
              .child(organizerUid)
              .child('createdGames')
              .child(gameId)
              .set(true);
        } catch (_) {}
      }

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

  // Fetch invite status for current user for a specific game: 'pending' | 'accepted' | 'declined' | null
  static Future<String?> getInviteStatusForCurrentUser(String gameId) async {
    final uid = _currentUserId;
    if (uid == null) return null;
    try {
      // Preferred path: explicit status node
      final DataSnapshot s1 =
          await _database.ref('games/$gameId/invites/$uid/status').get();
      if (s1.exists) return s1.value?.toString();

      // Fallback: entire invite entry
      final DataSnapshot s2 =
          await _database.ref('games/$gameId/invites/$uid').get();
      if (!s2.exists) return null;
      final dynamic v = s2.value;
      if (v is Map && v['status'] != null) {
        return v['status'].toString();
      }
      // Treat bare invite entries as pending by default
      return 'pending';
    } catch (_) {
      return null;
    }
  }

  // Realtime stream of pending invites count for current user (upcoming only)
  static Stream<int> watchPendingInvitesCount({int limit = 200}) {
    final uid = _currentUserId;
    if (uid == null) return Stream<int>.value(0);
    try {
      final Query q =
          _gamesRef.orderByChild('invites/$uid/status').equalTo('pending');
      return q.onValue.map((event) {
        if (!event.snapshot.exists) return 0;
        int count = 0;
        for (final child in event.snapshot.children) {
          try {
            final Map<dynamic, dynamic> gameData =
                child.value as Map<dynamic, dynamic>;
            final game = Game.fromJson(Map<String, dynamic>.from(gameData));
            // Only count invites for active, upcoming games
            if (game.isActive && game.isUpcoming) count++;
          } catch (_) {}
        }
        return count;
      });
    } catch (_) {
      return Stream<int>.value(0);
    }
  }

  // List games where the current user has a pending invite
  static Future<List<Game>> getInvitedGamesForCurrentUser(
      {int limit = 100}) async {
    final uid = _currentUserId;
    if (uid == null) return [];
    try {
      // Fetch latest games to ensure newly created invites surface quickly
      Query query = _gamesRef.orderByChild('createdAt').limitToLast(limit);
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
              // Only show upcoming, active invites
              if (game.isActive && game.isUpcoming) invited.add(game);
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
      // Merge only safe fields and never resurrect canceled games accidentally
      final DataSnapshot snap = await _gamesRef.child(game.id).get();
      bool existingIsActive = true;
      if (snap.exists) {
        final Map<dynamic, dynamic> data = snap.value as Map<dynamic, dynamic>;
        final dynamic ia = data['isActive'];
        existingIsActive = ia is bool ? ia : ((ia ?? 1) == 1);
      }

      final Map<String, dynamic> payload = {
        // Do not write isActive here; preserve server value
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'sport': game.sport,
        'dateTime': game.dateTime.toIso8601String(),
        'dateTimeUtc': game.dateTime.toUtc().toIso8601String(),
        'location': game.location,
        'address': game.address,
        'latitude': game.latitude,
        'longitude': game.longitude,
        'maxPlayers': game.maxPlayers,
        'currentPlayers': game.currentPlayers,
        'description': game.description,
        'organizerId': game.organizerId,
        'organizerName': game.organizerName,
        'imageUrl': game.imageUrl,
        'skillLevels': game.skillLevels,
        'equipment': game.equipment,
        'cost': game.cost,
        'contactInfo': game.contactInfo,
        'players': game.players,
      }..removeWhere((k, v) => v == null);

      // If existing was inactive, ensure we do not flip it back
      if (!existingIsActive) {
        payload['isActive'] = false;
      }

      await _gamesRef.child(game.id).update(payload);
      // Game updated in cloud successfully
    } catch (e) {
      // Error updating game in cloud
      rethrow;
    }
  }

  // Update only allowed fields for an existing game (organizer-only)
  static Future<void> updateGameFields(
    String gameId, {
    DateTime? dateTime,
    String? location,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    try {
      // Organizer check
      final uid = _currentUserId;
      if (uid == null) throw Exception('not_authenticated');
      final DataSnapshot snap = await _gamesRef.child(gameId).get();
      if (!snap.exists) throw Exception('game_not_found');
      final Map<dynamic, dynamic> data = snap.value as Map<dynamic, dynamic>;
      final String organizerId = data['organizerId']?.toString() ?? '';
      if (organizerId != uid) throw Exception('not_authorized');

      final int nowMs = DateTime.now().millisecondsSinceEpoch;
      final Map<String, dynamic> updates = {
        'updatedAt': nowMs,
        'lastOrganizerEditAt': nowMs,
      };
      String? newDateKey;
      String? newTimeKey;
      String? newFieldKey;
      if (dateTime != null) {
        updates['dateTime'] = dateTime.toIso8601String();
        updates['dateTimeUtc'] = dateTime.toUtc().toIso8601String();
        newDateKey = _formatDateKey(dateTime);
        newTimeKey = _formatTimeKey(dateTime);
      }
      if (location != null) updates['location'] = location;
      if (address != null) updates['address'] = address;
      if (latitude != null) updates['latitude'] = latitude;
      if (longitude != null) updates['longitude'] = longitude;
      if (updates.length <= 1) return; // nothing to update

      // If time/field changed, attempt to move the slot lock atomically
      if ((newDateKey != null && newTimeKey != null) || location != null) {
        final String oldDate = data['slotDate']?.toString() ?? '';
        final String oldField = data['slotField']?.toString() ?? '';
        final String oldTime = data['slotTime']?.toString() ?? '';
        // Derive new field key (prefer existing fieldId)
        final String fieldId = data['fieldId']?.toString() ?? '';
        newFieldKey = fieldId.isNotEmpty
            ? fieldId
            : base64Url.encode(
                utf8.encode(location ?? data['location']?.toString() ?? ''));

        final String targetDate = newDateKey ?? oldDate;
        final String targetTime = newTimeKey ?? oldTime;
        final String targetField = newFieldKey;

        if (targetDate.isNotEmpty &&
            targetTime.isNotEmpty &&
            targetField.isNotEmpty) {
          try {
            await _database
                .ref('slots/$targetDate/$targetField/$targetTime')
                .set(true);
            // Success: write new slot keys and release old
            updates['slotDate'] = targetDate;
            updates['slotField'] = targetField;
            updates['slotTime'] = targetTime;
            if (oldDate.isNotEmpty &&
                oldField.isNotEmpty &&
                oldTime.isNotEmpty) {
              try {
                await _database
                    .ref('slots/$oldDate/$oldField/$oldTime')
                    .remove();
              } catch (_) {}
            }
          } catch (e) {
            // New slot already claimed
            throw Exception('slot_already_booked');
          }
        }
      }

      await _gamesRef.child(gameId).update(updates);
    } catch (e) {
      rethrow;
    }
  }

  // Cancel (soft-delete) a game: mark as inactive and keep record for invitees
  static Future<void> cancelGame(String gameId) async {
    try {
      final DataSnapshot snap = await _gamesRef.child(gameId).get();
      String? slotDate;
      String? slotField;
      String? slotTime;
      String? fallbackFieldKey;
      if (snap.exists) {
        final Map<dynamic, dynamic> data = snap.value as Map<dynamic, dynamic>;
        slotDate = data['slotDate']?.toString();
        slotField = data['slotField']?.toString();
        slotTime = data['slotTime']?.toString();
        // Build fallbacks from game properties if slot keys were not present (legacy games)
        if (slotDate == null || slotTime == null || slotField == null) {
          try {
            final game = Game.fromJson(Map<String, dynamic>.from(data));
            slotDate ??= _formatDateKey(game.dateTime);
            slotTime ??= _formatTimeKey(game.dateTime);
            if (game.fieldId != null && game.fieldId!.isNotEmpty) {
              slotField ??= game.fieldId;
            }
            // Also compute a base64(location) fallback so we can remove old-style locks
            fallbackFieldKey = base64Url.encode(utf8.encode(game.location));
          } catch (_) {}
        }
        // If still no field key, attempt deriving from current data['location'] even without Game parse
        if ((slotField == null || slotField.isEmpty) &&
            fallbackFieldKey == null) {
          try {
            final String loc = data['location']?.toString() ?? '';
            if (loc.isNotEmpty) {
              fallbackFieldKey = base64Url.encode(utf8.encode(loc));
            }
          } catch (_) {}
        }
      }

      await _gamesRef.child(gameId).update({
        'isActive': false,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'canceledAt': DateTime.now().millisecondsSinceEpoch,
        if (_currentUserId != null) 'canceledBy': _currentUserId,
      });

      // Release slot lock (try both stored key and fallback location-based key)
      if (slotDate != null && slotTime != null) {
        if (slotField != null && slotField.isNotEmpty) {
          try {
            await _database
                .ref('slots/$slotDate/$slotField/$slotTime')
                .remove();
          } catch (_) {}
        }
        if (fallbackFieldKey != null && fallbackFieldKey.isNotEmpty) {
          try {
            await _database
                .ref('slots/$slotDate/$fallbackFieldKey/$slotTime')
                .remove();
          } catch (_) {}
        }
        // As a final guard, if we had both keys identical or neither worked, ensure no duplicate residue by attempting both again silently
        try {
          if (slotField != null && slotField.isNotEmpty) {
            await _database
                .ref('slots/$slotDate/$slotField/$slotTime')
                .remove();
          }
        } catch (_) {}
        try {
          if (fallbackFieldKey != null && fallbackFieldKey.isNotEmpty) {
            await _database
                .ref('slots/$slotDate/$fallbackFieldKey/$slotTime')
                .remove();
          }
        } catch (_) {}
      }
    } catch (e) {
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

  // Remove only my mapping to a joined game (does not modify the game itself)
  static Future<void> removeFromMyJoined(String gameId) async {
    final uid = _currentUserId;
    if (uid == null) return;
    await _usersRef.child(uid).child('joinedGames').child(gameId).remove();
  }

  // Remove only my mapping to a created game (organizer view cleanup)
  static Future<void> removeFromMyCreated(String gameId) async {
    final uid = _currentUserId;
    if (uid == null) return;
    await _usersRef.child(uid).child('createdGames').child(gameId).remove();
  }

  // Get all public games
  static Future<List<Game>> getPublicGames({
    String? sport,
    String? searchQuery,
    int limit = 50,
  }) async {
    try {
      // Fetch the most recently created games to ensure new ones appear,
      // then filter client-side by upcoming/public/active
      final int fetch = (limit * 4).clamp(50, 400);
      Query query = _gamesRef.orderByChild('createdAt').limitToLast(fetch);

      final snapshot = await query.get();

      if (!snapshot.exists) {
        return [];
      }

      final List<Game> games = [];

      for (final child in snapshot.children) {
        try {
          final gameData = child.value as Map<dynamic, dynamic>;
          final game = Game.fromJson(Map<String, dynamic>.from(gameData));

          // Only public, active, upcoming games are discoverable
          if (!game.isPublic || !game.isActive || !game.isUpcoming) continue;
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

      // Sort by date/time ascending
      games.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      // Retrieved games from cloud successfully
      return games.take(limit).toList();
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

      // For private games, only allow invited users to join
      if (!game.isPublic) {
        try {
          final DataSnapshot inv =
              await gameRef.child('invites/$playerId/status').get();
          final String status =
              (inv.exists ? inv.value?.toString() : null) ?? 'pending';
          if (status != 'accepted') {
            return false;
          }
        } catch (_) {
          return false;
        }
      }

      // Update game
      final updatedPlayers = [...game.players, playerId];
      await gameRef.update({
        'players': updatedPlayers,
        'currentPlayers': updatedPlayers.length,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        // Note: do NOT touch lastOrganizerEditAt on join
      });

      // Add game to user's joined games
      await _usersRef
          .child(playerId)
          .child('joinedGames')
          .child(gameId)
          .set(true);

      // Ensure any existing invite record is marked as accepted
      try {
        await gameRef
            .child('invites')
            .child(playerId)
            .child('status')
            .set('accepted');
      } catch (_) {}

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

      // Proceed idempotently even if the player is not yet visible in the
      // players list (RTDB eventual consistency right after accept).
      // Update game: remove the player if present and recompute count.
      final updatedPlayers =
          game.players.where((id) => id != playerId).toList();
      await gameRef.update({
        'players': updatedPlayers,
        'currentPlayers': updatedPlayers.length,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        // Note: do NOT touch lastOrganizerEditAt on leave
      });

      // Remove game from user's joined games
      await _usersRef
          .child(playerId)
          .child('joinedGames')
          .child(gameId)
          .remove();

      // Best-effort: if there is an invite entry, mark it as 'left'
      try {
        await gameRef
            .child('invites')
            .child(playerId)
            .child('status')
            .set('left');
      } catch (_) {}

      // Player left game successfully (or was already not listed) — treat as ok
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
    final int fetch = (limit * 4).clamp(50, 400);
    Query query = _gamesRef.orderByChild('createdAt').limitToLast(fetch);

    return query.onValue.map((event) {
      if (!event.snapshot.exists) return <Game>[];

      final List<Game> games = [];

      for (final child in event.snapshot.children) {
        try {
          final gameData = child.value as Map<dynamic, dynamic>;
          final game = Game.fromJson(Map<String, dynamic>.from(gameData));

          // Only public, active, upcoming games are discoverable
          if (!game.isPublic || !game.isActive || !game.isUpcoming) continue;
          // Apply sport filter
          if (sport != null && game.sport != sport) continue;

          games.add(game);
        } catch (e) {
          // Error parsing game in stream
          continue;
        }
      }

      games.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return games.take(limit).toList();
    });
  }

  // Watch the current user's joined games in real time
  static Stream<List<Game>> watchUserJoinedGames(String userId,
      {int limit = 100}) {
    final DatabaseReference joinedRef =
        _usersRef.child(userId).child('joinedGames');
    return joinedRef.onValue.asyncMap((event) async {
      if (!event.snapshot.exists) return <Game>[];
      final List<Game> games = [];
      for (final child in event.snapshot.children) {
        final String? gameId = child.key;
        if (gameId == null) continue;
        try {
          final DataSnapshot gameSnap = await _gamesRef.child(gameId).get();
          if (!gameSnap.exists) continue;
          final Map<dynamic, dynamic> gameData =
              gameSnap.value as Map<dynamic, dynamic>;
          final game = Game.fromJson(Map<String, dynamic>.from(gameData));
          // Include upcoming games even if they were canceled, so Joining shows them
          if (game.isUpcoming) {
            games.add(game);
          }
        } catch (_) {}
      }
      games.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return games.take(limit).toList();
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
            if (game.isUpcoming) {
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

  // Busy slots for a field on a specific date (includes private and public, active only)
  static Future<Set<String>> getBusySlotsForFieldOnDate(
      String fieldName, DateTime date,
      {String? fieldId, int recentLimit = 300}) async {
    try {
      // Prefer canonical fieldId if provided
      if (fieldId != null && fieldId.isNotEmpty) {
        try {
          final Query byId = _gamesRef.orderByChild('fieldId').equalTo(fieldId);
          final DataSnapshot sId = await byId.get();
          final Set<String> byIdTimes = {};
          if (sId.exists) {
            for (final child in sId.children) {
              try {
                final Map<dynamic, dynamic> map =
                    child.value as Map<dynamic, dynamic>;
                final game = Game.fromJson(Map<String, dynamic>.from(map));
                // Exclude canceled games from busy slots
                if (!game.isActive) continue;
                final DateTime d = game.dateTime;
                if (d.year == date.year &&
                    d.month == date.month &&
                    d.day == date.day) {
                  final hh = game.dateTime.hour.toString().padLeft(2, '0');
                  final mm = game.dateTime.minute.toString().padLeft(2, '0');
                  byIdTimes.add('$hh:$mm');
                }
              } catch (_) {}
            }
          }
          if (byIdTimes.isNotEmpty) return byIdTimes;
        } catch (_) {}
      }

      final Query q = _gamesRef.orderByChild('location').equalTo(fieldName);
      final DataSnapshot snap = await q.get();
      if (!snap.exists) return <String>{};
      final Set<String> times = {};
      for (final child in snap.children) {
        try {
          final Map<dynamic, dynamic> map =
              child.value as Map<dynamic, dynamic>;
          final game = Game.fromJson(Map<String, dynamic>.from(map));
          if (!game.isActive) continue;
          final DateTime d = game.dateTime;
          if (d.year == date.year &&
              d.month == date.month &&
              d.day == date.day) {
            final hh = d.hour.toString().padLeft(2, '0');
            final mm = d.minute.toString().padLeft(2, '0');
            times.add('$hh:$mm');
          }
        } catch (_) {}
      }

      // Removed proximity fallback to avoid nearby-field collisions
      return times;
    } catch (_) {
      return <String>{};
    }
  }

  // Proximity helper removed after switching to fieldId-based matching

  // Check if the organizer modified the game after the invite was sent to the current user
  // Returns true if current user's invite exists and game's updatedAt > invite.ts, and status is not declined/left
  static Future<bool> isInviteModifiedForCurrentUser(String gameId) async {
    final uid = _currentUserId;
    if (uid == null) return false;
    try {
      final DataSnapshot snap = await _gamesRef.child(gameId).get();
      if (!snap.exists) return false;
      final Map<dynamic, dynamic> data = snap.value as Map<dynamic, dynamic>;
      final dynamic lastEditRaw = data['lastOrganizerEditAt'];
      final int lastEdit = lastEditRaw is int
          ? lastEditRaw
          : int.tryParse(lastEditRaw?.toString() ?? '') ?? 0;
      if (lastEdit == 0) return false;

      final dynamic invites = data['invites'];
      if (invites is! Map || !invites.containsKey(uid)) return false;
      final dynamic entry = invites[uid];
      if (entry is! Map) return false;
      final String status = entry['status']?.toString() ?? 'pending';
      if (status == 'declined' || status == 'left') return false;
      final dynamic tsRaw = entry['ts'];
      final int ts =
          tsRaw is int ? tsRaw : int.tryParse(tsRaw?.toString() ?? '') ?? 0;
      if (ts == 0) return false;
      return lastEdit > ts;
    } catch (_) {
      return false;
    }
  }
}
