import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/features/matches/models/match.dart';
import 'package:move_young/db/db_paths.dart';
import 'package:move_young/utils/logger.dart';
import 'package:move_young/services/notifications/notification_interface.dart';
import 'package:move_young/models/infrastructure/service_error.dart';
import 'package:move_young/utils/crashlytics_helper.dart';
import 'package:move_young/services/calendar/calendar_service.dart';
import 'package:move_young/models/infrastructure/cached_data.dart';
import 'package:move_young/utils/time_slot_utils.dart';
import 'package:move_young/utils/type_converters.dart';
import 'package:move_young/utils/geolocation_utils.dart';

/// Instance-based CloudMatchesService for use with Riverpod dependency injection
class CloudMatchesServiceInstance {
  final FirebaseDatabase _database;
  final FirebaseAuth _auth;
  // Notification service for sending match edited/cancelled notifications
  final INotificationService _notificationService;

  // Query limits to prevent memory issues
  static const int _maxJoinableMatches = 50;
  static const int _maxMyMatches = 100;

  // Cache for match lists with TTL (short-term cache for performance)
  final Map<String, CachedData<List<Match>>> _matchesCache = {};
  static const Duration _defaultCacheTTL =
      Duration(seconds: 30); // 30 second cache

  CloudMatchesServiceInstance(
      this._database, this._auth, this._notificationService);

  /// Invalidate cache for a specific user or all users
  void _invalidateCache({String? userId}) {
    if (userId != null) {
      _matchesCache.remove('myMatches_$userId');
      _matchesCache.remove('invitedMatches_$userId');
    } else {
      // Invalidate all caches
      _matchesCache.clear();
    }
  }

  // Database references
  DatabaseReference get _matchesRef => _database.ref(DbPaths.matches);
  DatabaseReference get _usersRef => _database.ref(DbPaths.users);

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Require current user ID (throws if not authenticated)
  String _requireCurrentUserId() {
    final uid = _currentUserId;
    if (uid == null) {
      throw AuthException('User not authenticated');
    }
    return uid;
  }

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
    // Round down to nearest hour for 1-hour slots only
    // This ensures all times in the same hour map to the same slot (e.g., 10:00, 10:15, 10:30 all -> 1000)
    final h = local.hour.toString().padLeft(2, '0');
    return '${h}00'; // Always use :00 minutes for 1-hour slots
  }

  // Helper function to check if two 1-hour time slots overlap
  // Uses shared utility for consistency
  // Keep as private method to maintain encapsulation and allow for future logging/validation
  bool _timeSlotsOverlap(String timeKey1, String timeKey2) {
    return timeSlotsOverlap(timeKey1, timeKey2);
  }

  // Validate match data before creating/updating
  void _validateMatchData(Match match) {
    // Validate location
    if (match.location.trim().isEmpty) {
      throw ValidationException('Location is required');
    }
    if (match.location.length > 200) {
      throw ValidationException(
          'Location name is too long (max 200 characters)');
    }

    // Validate description
    if (match.description.length > 1000) {
      throw ValidationException(
          'Description is too long (max 1000 characters)');
    }

    // Validate contactInfo if provided
    if (match.contactInfo != null && match.contactInfo!.isNotEmpty) {
      final contact = match.contactInfo!.trim();
      if (contact.length > 100) {
        throw ValidationException(
            'Contact information is too long (max 100 characters)');
      }
      // Basic validation: should be email or phone-like
      final isEmail = contact.contains('@') && contact.contains('.');
      final isPhone = RegExp(r'^[\d\s\+\-\(\)]+$').hasMatch(contact);
      if (!isEmail && !isPhone) {
        throw ValidationException(
            'Contact information must be a valid email or phone number');
      }
    }

    // Validate equipment if provided
    if (match.equipment != null && match.equipment!.isNotEmpty) {
      if (match.equipment!.length > 500) {
        throw ValidationException(
            'Equipment notes are too long (max 500 characters)');
      }
    }

    // Validate organizer name
    if (match.organizerName.trim().isEmpty) {
      throw ValidationException('Organizer name is required');
    }
    if (match.organizerName.length > 50) {
      throw ValidationException(
          'Organizer name is too long (max 50 characters)');
    }

    // Validate maxPlayers
    if (match.maxPlayers < 2 || match.maxPlayers > 100) {
      throw ValidationException('Max players must be between 2 and 100');
    }

    // Validate sport
    if (match.sport.trim().isEmpty) {
      throw ValidationException('Sport is required');
    }
    if (match.sport.length > 50) {
      throw ValidationException('Sport name is too long (max 50 characters)');
    }

    // Validate cost if provided
    if (match.cost != null && (match.cost! < 0 || match.cost! > 10000)) {
      throw ValidationException('Cost must be between 0 and 10000');
    }
  }

  // Compute a stable field key. Prefer explicit fieldId; else lat,lon; else sanitized name
  String _fieldKeyForMatch(Match match) {
    // Safely check and use fieldId
    final fieldId = match.fieldId?.trim();
    if (fieldId != null && fieldId.isNotEmpty) {
      // Sanitize fieldId to remove slashes and other problematic characters for Firebase paths
      return fieldId.replaceAll('/', '_').replaceAll('\\', '_');
    }
    // Use coordinates if available
    if (match.latitude != null && match.longitude != null) {
      final lat = match.latitude!.toStringAsFixed(5).replaceAll('.', '_');
      final lon = match.longitude!.toStringAsFixed(5).replaceAll('.', '_');
      return '${lat}_$lon';
    }
    final name = (match.location).toLowerCase();
    final sanitized = name
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    return sanitized.isEmpty ? 'unknown_field' : sanitized;
  }

  // Check if a slot is occupied by an active match (excluding the specified matchId if provided)
  Future<bool> _isSlotOccupiedByActiveMatch(
      String dateKey, String fieldKey, String timeKey,
      {String? excludeMatchId}) async {
    try {
      // Query all active matches
      final snapshot =
          await _matchesRef.orderByChild('isActive').equalTo(true).get();

      if (!snapshot.exists) {
        return false;
      }

      final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
      for (final entry in data.values) {
        try {
          if (entry == null) continue;
          final matchData = Map<String, dynamic>.from(entry);
          if (matchData.isEmpty) continue;
          final match = Match.fromJson(matchData);

          // Check if this match uses the same slot
          final matchDateKey =
              matchData['slotDate']?.toString() ?? _dateKey(match.dateTime);
          final matchFieldKey =
              matchData['slotField']?.toString() ?? _fieldKeyForMatch(match);
          final matchTimeKey =
              matchData['slotTime']?.toString() ?? _timeKey(match.dateTime);

          // Skip the excluded match (useful when checking after creation)
          if (excludeMatchId != null && match.id == excludeMatchId) {
            continue;
          }

          if (matchDateKey == dateKey &&
              matchFieldKey == fieldKey &&
              _timeSlotsOverlap(matchTimeKey, timeKey)) {
            NumberedLogger.i(
                'Slot occupied by active match ${match.id} at ${match.location} (overlaps with existing match at $matchTimeKey)');
            return true;
          }
        } catch (e) {
          NumberedLogger.w('Error parsing match when checking slot: $e');
        }
      }

      return false;
    } catch (e) {
      NumberedLogger.e('Error checking slot occupancy: $e');
      // On error, assume slot might be occupied to be safe
      return true;
    }
  }

  // Check if user already has a match at the same date+time (for conflict prevention)
  Future<Match?> _checkUserTimeConflict(
      String userId, DateTime dateTime) async {
    try {
      final now = DateTime.now();
      final targetDateKey = _dateKey(dateTime);
      final targetTimeKey = _timeKey(dateTime);

      // Check organized matches
      final organizedSnapshot =
          await _matchesRef.orderByChild('organizerId').equalTo(userId).get();

      if (organizedSnapshot.exists) {
        final data = Map<dynamic, dynamic>.from(organizedSnapshot.value as Map);
        for (final entry in data.values) {
          try {
            final match = Match.fromJson(Map<String, dynamic>.from(entry));
            // Only check upcoming active matches
            if (match.isActive &&
                match.dateTime.isAfter(now) &&
                _dateKey(match.dateTime) == targetDateKey &&
                _timeSlotsOverlap(_timeKey(match.dateTime), targetTimeKey)) {
              return match;
            }
          } catch (e) {
            NumberedLogger.w(
                'Error parsing match when checking time conflict: $e');
          }
        }
      }

      // Check joined matches
      final joinedMatchsSnapshot =
          await _usersRef.child(DbPaths.userJoinedMatches(userId)).get();

      if (joinedMatchsSnapshot.exists) {
        final joinedData =
            Map<dynamic, dynamic>.from(joinedMatchsSnapshot.value as Map);
        final matchIds = joinedData.keys.map((k) => k.toString()).toList();

        // Batch fetch joined matches
        for (final matchId in matchIds) {
          try {
            final matchSnapshot = await _matchesRef.child(matchId).get();
            if (!matchSnapshot.exists) continue;
            final match = Match.fromJson(
                Map<String, dynamic>.from(matchSnapshot.value as Map));
            // Only check upcoming active matches where user is actually a player
            if (match.isActive &&
                match.dateTime.isAfter(now) &&
                match.players.contains(userId) &&
                _dateKey(match.dateTime) == targetDateKey &&
                _timeSlotsOverlap(_timeKey(match.dateTime), targetTimeKey)) {
              return match;
            }
          } catch (e) {
            NumberedLogger.w(
                'Error checking joined match $matchId for conflict: $e');
          }
        }
      }

      return null; // No conflict found
    } catch (e) {
      NumberedLogger.e('Error checking user time conflict: $e');
      // On error, return null to allow the operation (fail open to avoid blocking users)
      return null;
    }
  }

  // Create a new match in the cloud
  Future<String> createMatch(Match match) async {
    try {
      final userId = _requireCurrentUserId();

      // Validate match data
      _validateMatchData(match);

      // Ensure the user has a profile
      await _ensureUserProfile(userId);

      // Check if user already has a match at the same date+time
      final conflictingMatch =
          await _checkUserTimeConflict(userId, match.dateTime);
      if (conflictingMatch != null) {
        NumberedLogger.w(
            'User $userId already has a match at ${match.dateTime} (conflicts with match ${conflictingMatch.id})');
        throw ValidationException('user_already_busy');
      }

      // Compute unique slot keys
      final dateKey = _dateKey(match.dateTime);
      final timeKey = _timeKey(match.dateTime);
      final fieldKey = _fieldKeyForMatch(match);

      // Check slot availability first (before transaction)
      final isOccupied =
          await _isSlotOccupiedByActiveMatch(dateKey, fieldKey, timeKey);
      if (isOccupied) {
        NumberedLogger.w(
            'Slot $dateKey/$fieldKey/$timeKey is occupied by an active match');
        throw ValidationException('new_slot_unavailable');
      }

      // Use transaction to atomically claim the slot (prevents race conditions)
      // Note: We check slot availability before transaction, then use transaction
      // to atomically claim it, preventing race conditions
      final slotRef = _database.ref('slots/$dateKey/$fieldKey/$timeKey');
      final transactionResult = await slotRef.runTransaction((current) {
        // Check if slot is already claimed (race condition check)
        // If current value is true, another process claimed it
        try {
          final slotValue = (current as dynamic)?.value;
          if (slotValue == true) {
            // Another process claimed it between our check and transaction
            return Transaction.abort();
          }
        } catch (_) {
          // If we can't read the value, abort to be safe
          return Transaction.abort();
        }
        // Claim the slot atomically
        return Transaction.success(true);
      });

      if (!transactionResult.committed) {
        // Slot was claimed by another process between our check and transaction
        // Double-check if it's actually occupied by an active match
        final isOccupiedNow =
            await _isSlotOccupiedByActiveMatch(dateKey, fieldKey, timeKey);
        if (isOccupiedNow) {
          NumberedLogger.w(
              'Slot $dateKey/$fieldKey/$timeKey is occupied (transaction aborted)');
          throw ValidationException('new_slot_unavailable');
        }

        // If not occupied, check if slot has a stale value (from cancelled match or failed transaction)
        final slotSnapshot = await slotRef.get();
        if (slotSnapshot.exists && slotSnapshot.value == true) {
          // Stale slot - clean it up and retry transaction once
          NumberedLogger.i(
              'Cleaning up stale slot $dateKey/$fieldKey/$timeKey and retrying transaction');
          await slotRef.set(null);

          // Retry the transaction once after cleanup
          final retryResult = await slotRef.runTransaction((current) {
            try {
              final slotValue = (current as dynamic)?.value;
              if (slotValue == true) {
                return Transaction.abort();
              }
            } catch (_) {
              return Transaction.abort();
            }
            return Transaction.success(true);
          });

          if (!retryResult.committed) {
            // Still failed after cleanup - likely a real race condition
            NumberedLogger.w(
                'Slot $dateKey/$fieldKey/$timeKey transaction failed after cleanup (race condition)');
            throw ValidationException('new_slot_unavailable');
          }
          // Transaction succeeded after cleanup - continue with match creation
        } else {
          // Transaction failed but slot is null/doesn't exist - likely a race condition
          // This is rare but can happen - treat as unavailable
          NumberedLogger.w(
              'Slot $dateKey/$fieldKey/$timeKey transaction failed (race condition)');
          throw ValidationException('new_slot_unavailable');
        }
      }

      // Create the match id now for an atomic multi-location update
      final matchRef = _matchesRef.push();
      final matchId = matchRef.key;
      if (matchId == null) {
        // Rollback slot claim if match ID generation fails
        try {
          await slotRef.set(null);
        } catch (rollbackError) {
          NumberedLogger.w(
              'Failed to rollback slot after match ID generation failure: $rollbackError');
        }
        throw ServiceException('Failed to generate match ID');
      }

      // Update match with the generated ID and initialize updatedAt to createdAt
      final matchWithId = match.copyWith(
        id: matchId,
        updatedAt: match.createdAt,
        updatedBy: userId,
      );

      // Prepare match data with slot keys for reliable cancellation
      final matchData = matchWithId.toCloudJson();
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      matchData['lastOrganizerEditAt'] = nowMs; // Track organizer edits
      matchData['slotDate'] = dateKey;
      matchData['slotField'] = fieldKey;
      matchData['slotTime'] = timeKey;

      // Write each path individually (update() has issues with nested validation rules)
      // - matches/{id}
      // - users/{uid}/createdMatchs/{id}
      // - slots/{dateKey}/{fieldKey}/{timeKey} = true (already claimed in transaction)
      // Track what was written for rollback if any write fails
      bool matchWritten = false;
      bool indexWritten = false;

      try {
        await _database.ref('${DbPaths.matches}/$matchId').set(matchData);
        matchWritten = true;

        await _database.ref('users/$userId/createdMatchs/$matchId').set({
          'sport': matchWithId.sport,
          'dateTime': matchWithId.dateTime.toIso8601String(),
          'location': matchWithId.location,
          'maxPlayers': matchWithId.maxPlayers,
        });
        indexWritten = true;
      } catch (e) {
        // Rollback any writes that succeeded
        if (indexWritten) {
          try {
            await _database
                .ref('users/$userId/createdMatchs/$matchId')
                .remove();
          } catch (rollbackError) {
            NumberedLogger.w(
                'Failed to rollback createdMatchs index during match creation: $rollbackError');
          }
        }

        if (matchWritten) {
          try {
            await _database.ref('${DbPaths.matches}/$matchId').remove();
          } catch (rollbackError) {
            NumberedLogger.w(
                'Failed to rollback match during match creation: $rollbackError');
          }
        }

        // Rollback slot claim
        try {
          await slotRef.set(null);
        } catch (rollbackError) {
          NumberedLogger.w(
              'Failed to rollback slot during match creation: $rollbackError');
        }

        rethrow;
      }

      // Invalidate cache for the organizer
      _invalidateCache(userId: userId);

      // Send notifications to invited friends
      // This will be implemented when we add friend invites functionality
      // For now, we'll just log it
      NumberedLogger.i('Match created successfully: $matchId');
      CrashlyticsHelper.breadcrumb('match_create_ok:$matchId');

      return matchId;
    } catch (e, st) {
      NumberedLogger.e('Error creating match: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'match_create_fail');
      // Re-throw ValidationException as-is (already handled)
      if (e is ValidationException) {
        rethrow;
      }
      // Check if it's a permission error (could indicate slot conflict)
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          // Double-check: query active matches to see if slot is truly occupied
          try {
            final dateKey = _dateKey(match.dateTime);
            final timeKey = _timeKey(match.dateTime);
            final fieldKey = _fieldKeyForMatch(match);
            final isOccupied =
                await _isSlotOccupiedByActiveMatch(dateKey, fieldKey, timeKey);
            if (isOccupied) {
              throw ValidationException('new_slot_unavailable');
            }
          } catch (checkError) {
            // If check fails or slot is occupied, assume it's a slot conflict
            if (checkError is ValidationException) {
              rethrow;
            }
            throw ValidationException('new_slot_unavailable');
          }
        }
      }
      rethrow;
    }
  }

  // Get a single match by ID
  Future<Match?> getMatchById(String matchId) async {
    try {
      final snapshot = await _matchesRef.child(matchId).get();

      if (!snapshot.exists) {
        return null;
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      return Match.fromJson(data);
    } catch (e) {
      NumberedLogger.e('Error getting match by ID: $e');
      return null;
    }
  }

  // Update a match (atomically move slot if date/field/time changed)
  Future<void> updateMatch(Match match) async {
    // Validate match data
    _validateMatchData(match);
    // Declare variables outside try block for catch block access
    bool slotChanged = false;
    String? newDateKey;
    String? newFieldKey;
    String? newTimeKey;

    try {
      // Load existing match to compute old slot
      final existingSnap = await _matchesRef.child(match.id).get();
      if (!existingSnap.exists) {
        throw NotFoundException('Match not found');
      }
      final existing =
          Match.fromJson(Map<String, dynamic>.from(existingSnap.value as Map));

      // Preserve isActive state - never resurrect cancelled matches
      final bool existingIsActive = existing.isActive;
      final existingData = Map<String, dynamic>.from(existingSnap.value as Map);

      final oldDateKey = _dateKey(existing.dateTime);
      final oldTimeKey = _timeKey(existing.dateTime);
      final oldFieldKey = _fieldKeyForMatch(existing);

      newDateKey = _dateKey(match.dateTime);
      newTimeKey = _timeKey(match.dateTime);
      newFieldKey = _fieldKeyForMatch(match);

      // Ensure updatedAt and updatedBy are set, and preserve isActive state
      final now = DateTime.now();
      final matchToUpdate = match.copyWith(
        updatedAt: now,
        updatedBy: _currentUserId,
        isActive: existingIsActive, // Never resurrect cancelled matches
      );

      slotChanged = oldDateKey != newDateKey ||
          oldTimeKey != newTimeKey ||
          oldFieldKey != newFieldKey;

      // Check if match details actually changed (excluding metadata and player fields)
      // We should only send notifications if match details changed, not just invites
      final bool matchDetailsChanged = existing.sport != match.sport ||
          existing.dateTime != match.dateTime ||
          existing.location != match.location ||
          existing.address != match.address ||
          existing.latitude != match.latitude ||
          existing.longitude != match.longitude ||
          existing.fieldId != match.fieldId ||
          existing.maxPlayers != match.maxPlayers ||
          existing.description != match.description ||
          existing.isPublic != match.isPublic ||
          existing.imageUrl != match.imageUrl ||
          existing.skillLevels.toString() != match.skillLevels.toString() ||
          existing.equipment != match.equipment ||
          existing.cost != match.cost ||
          existing.contactInfo != match.contactInfo;

      // Prepare match data with updated slot keys and lastOrganizerEditAt
      final matchData = matchToUpdate.toCloudJson();
      final nowMs = now.millisecondsSinceEpoch;
      matchData['lastOrganizerEditAt'] = nowMs; // Track organizer edits

      if (slotChanged) {
        // Update slot keys in match data
        matchData['slotDate'] = newDateKey;
        matchData['slotField'] = newFieldKey;
        matchData['slotTime'] = newTimeKey;
      } else {
        // Preserve existing slot keys if slot didn't change
        if (existingData['slotDate'] != null) {
          matchData['slotDate'] = existingData['slotDate'];
        }
        if (existingData['slotField'] != null) {
          matchData['slotField'] = existingData['slotField'];
        }
        if (existingData['slotTime'] != null) {
          matchData['slotTime'] = existingData['slotTime'];
        }
      }

      final Map<String, Object?> updates = {
        '${DbPaths.matches}/${match.id}': matchData,
      };

      if (slotChanged) {
        // Check if new slot is occupied by an active match
        final newSlotRef =
            _database.ref('slots/$newDateKey/$newFieldKey/$newTimeKey');
        final newSlotSnapshot = await newSlotRef.get();

        if (newSlotSnapshot.exists && newSlotSnapshot.value == true) {
          // Slot exists, check if it's actually occupied by an active match
          // Exclude the current match from the check to avoid false conflicts when updating
          final isOccupied = await _isSlotOccupiedByActiveMatch(
              newDateKey, newFieldKey, newTimeKey,
              excludeMatchId: match.id);

          if (isOccupied) {
            NumberedLogger.w(
                'New slot $newDateKey/$newFieldKey/$newTimeKey is occupied by an active match');
            throw ValidationException('new_slot_unavailable');
          } else {
            // Stale slot - clean it up before claiming
            NumberedLogger.i(
                'Cleaning up stale slot $newDateKey/$newFieldKey/$newTimeKey before updating match');
            await newSlotRef.set(null);
          }
        }

        // Free old slot and claim new slot atomically
        updates['slots/$oldDateKey/$oldFieldKey/$oldTimeKey'] = null;
        updates['slots/$newDateKey/$newFieldKey/$newTimeKey'] = true;
      }

      await _database.ref().update(updates);
      // Streams will update automatically - no cache clearing needed

      // Only send notifications if match details actually changed
      // Don't send notifications if only invites were added (no match details changed)
      if (matchDetailsChanged) {
        // Send notifications to all players (excluding organizer)
        try {
          NumberedLogger.i(
              'Sending match edited notification for match ${match.id} (match details changed)');
          await _notificationService.sendMatchEditedNotification(match.id);
          NumberedLogger.i(
              'Successfully queued match edited notification for match ${match.id}');
        } catch (e, st) {
          NumberedLogger.e('Error sending match edited notification: $e');
          NumberedLogger.d('Stack trace: $st');
          // Don't fail the update if notification fails
        }
      } else {
        NumberedLogger.d(
            'Skipping match edited notification for match ${match.id} - no match details changed (only invites or participant changes)');
      }

      // Sync calendar event only if match details changed
      // Calendar events show match details (date, time, location), not invites
      // So there's no need to update calendar if only invites were added
      if (matchDetailsChanged) {
        try {
          NumberedLogger.i(
              'Syncing calendar event for edited match ${match.id}');
          await CalendarService.updateMatchInCalendar(match);
          NumberedLogger.i(
              'Successfully synced calendar event for match ${match.id}');
        } catch (e, st) {
          NumberedLogger.w('Error syncing calendar event for edited match: $e');
          NumberedLogger.d('Stack trace: $st');
          // Don't fail the update if calendar sync fails (calendar sync is best-effort)
        }
      } else {
        NumberedLogger.d(
            'Skipping calendar sync for match ${match.id} - no match details changed');
      }
    } catch (e, st) {
      NumberedLogger.e('Error updating match: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'match_update_fail');
      // Re-throw ValidationException as-is (already handled)
      if (e is ValidationException) {
        rethrow;
      }
      // Check if it's a permission error (could indicate slot conflict)
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          // Check if it's related to slot change
          if (slotChanged &&
              newDateKey != null &&
              newFieldKey != null &&
              newTimeKey != null) {
            try {
              // Exclude the current match from the check to avoid false conflicts when updating
              final isOccupied = await _isSlotOccupiedByActiveMatch(
                  newDateKey, newFieldKey, newTimeKey,
                  excludeMatchId: match.id);
              if (isOccupied) {
                throw ValidationException('new_slot_unavailable');
              }
            } catch (checkError) {
              // If check fails or slot is occupied, assume it's a slot conflict
              if (checkError is ValidationException) {
                rethrow;
              }
              throw ValidationException('new_slot_unavailable');
            }
          }
        }
      }
      rethrow;
    } finally {
      // Invalidate cache for the organizer
      if (match.organizerId == _currentUserId) {
        _invalidateCache(userId: match.organizerId);
      }
    }
  }

  // Cancel a match (mark inactive) and free its slot
  // Step 1: Cancel shows "Cancelled" to everyone and hides from Join screen
  // Step 2: Each user can use Remove to hide it from their My Matchs
  Future<void> deleteMatch(String matchId) async {
    try {
      final userId = _requireCurrentUserId();

      // Load existing match for slot
      final existingSnap = await _matchesRef.child(matchId).get();
      if (!existingSnap.exists) {
        // Nothing to delete - just remove from user's createdMatchs index
        await _usersRef
            .child(DbPaths.userCreatedMatches(userId))
            .child(matchId)
            .remove();
        // Invalidate cache for the user
        _invalidateCache(userId: userId);
        // Streams will update automatically - no cache clearing needed
        return;
      }
      final existingData = Map<String, dynamic>.from(existingSnap.value as Map);
      final existing = Match.fromJson(existingData);

      // Get slot keys from stored data (preferred) or compute from match
      String? dateKey = existingData['slotDate']?.toString();
      String? fieldKey = existingData['slotField']?.toString();
      String? timeKey = existingData['slotTime']?.toString();

      // Fallback to computing if not stored (legacy matches)
      dateKey ??= _dateKey(existing.dateTime);
      timeKey ??= _timeKey(existing.dateTime);
      fieldKey ??= _fieldKeyForMatch(existing);

      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      // STEP 1: Mark match as inactive so it:
      // - Shows "Cancelled" badge to everyone (invited users)
      // - Hides from "Join a Match" screen (isActive=false filter)
      // - Stays in My Matchs lists so users can see it was cancelled
      // Invalidate cache for the organizer
      _invalidateCache(userId: userId);

      // DO NOT remove from createdMatchs/joinedMatchs yet - let users decide when to remove
      final Map<String, Object?> updates = {
        // Mark match inactive instead of deleting so invitees see "Cancelled"
        '${DbPaths.matches}/$matchId/isActive': false,
        '${DbPaths.matches}/$matchId/updatedAt': nowMs,
        '${DbPaths.matches}/$matchId/updatedBy': userId,
        '${DbPaths.matches}/$matchId/canceledAt': nowMs,
        // Free the slot
        'slots/$dateKey/$fieldKey/$timeKey': null,
      };

      await _database.ref().update(updates);
      // Streams will update automatically - no cache clearing needed

      // Send notifications to all players (excluding organizer)
      try {
        NumberedLogger.i(
            'Sending match cancelled notification for match $matchId');
        await _notificationService.sendMatchCancelledNotification(matchId);
        NumberedLogger.i(
            'Successfully queued match cancelled notification for match $matchId');
      } catch (e, st) {
        NumberedLogger.e('Error sending match cancelled notification: $e');
        NumberedLogger.d('Stack trace: $st');
        // Don't fail the cancellation if notification fails
      }

      // Remove calendar event for this match (if it's in any user's calendar)
      // Note: Calendar removal happens per-user, so we can't remove from all users' calendars here
      // The CalendarSyncService provider will handle syncing for the current user
      // This is a best-effort sync for the match data
      try {
        NumberedLogger.i(
            'Removing calendar event for cancelled match $matchId');
        await CalendarService.removeMatchFromCalendar(matchId);
        NumberedLogger.i(
            'Successfully removed calendar event for match $matchId');
      } catch (e, st) {
        NumberedLogger.w(
            'Error removing calendar event for cancelled match: $e');
        NumberedLogger.d('Stack trace: $st');
        // Don't fail the cancellation if calendar removal fails (calendar sync is best-effort)
      }
    } catch (e, st) {
      NumberedLogger.e('Error deleting match: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'match_delete_fail');
      rethrow;
    }
  }

  // Remove match from user's createdMatchs index (hides it from organizer view)
  Future<void> removeFromMyCreated(String matchId) async {
    try {
      final userId = _requireCurrentUserId();

      await _usersRef
          .child(DbPaths.userCreatedMatches(userId))
          .child(matchId)
          .remove();

      // Streams will update automatically - no cache clearing needed
    } catch (e, st) {
      NumberedLogger.e('Error removing match from created: $e');
      CrashlyticsHelper.recordError(e, st,
          reason: 'match_remove_from_created_fail');
      rethrow;
    }
  }

  // Remove match from user's joinedMatchs index (hides it from joined matches list)
  Future<void> removeFromMyJoined(String matchId) async {
    try {
      final userId = _requireCurrentUserId();

      await _usersRef
          .child(DbPaths.userJoinedMatches(userId))
          .child(matchId)
          .remove();

      // Streams will update automatically - no cache clearing needed
    } catch (e, st) {
      NumberedLogger.e('Error removing match from joined: $e');
      CrashlyticsHelper.recordError(e, st,
          reason: 'match_remove_from_joined_fail');
      rethrow;
    }
  }

  // Get matches for the current user (both organized and joined)
  // Short-term caching for performance (30s default) while maintaining real-time consistency
  Future<List<Match>> getMyMatches({Duration? ttl}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return [];
      }

      // Check cache first
      final cacheKey = 'myMatches_$userId';
      final cached = _matchesCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }

      final matchesMap = <String, Match>{};
      final now = DateTime.now();

      // 1. Fetch matches organized by the user
      final organizedSnapshot = await _matchesRef
          .orderByChild('organizerId')
          .equalTo(userId)
          .limitToFirst(_maxMyMatches)
          .get();

      if (organizedSnapshot.exists) {
        final data = Map<dynamic, dynamic>.from(organizedSnapshot.value as Map);
        for (final entry in data.values) {
          try {
            final match = Match.fromJson(Map<String, dynamic>.from(entry));
            // Include upcoming matches (active or cancelled) so users can see cancellation status
            if (match.dateTime.isAfter(now)) {
              matchesMap[match.id] = match;
            }
          } catch (e) {
            NumberedLogger.w('Error parsing organized match: $e');
          }
        }
      }

      // 2. Fetch matches the user joined (from joinedMatchs index)
      final joinedMatchsSnapshot =
          await _usersRef.child(DbPaths.userJoinedMatches(userId)).get();

      if (joinedMatchsSnapshot.exists) {
        final joinedData =
            Map<dynamic, dynamic>.from(joinedMatchsSnapshot.value as Map);
        final matchIds = joinedData.keys.map((k) => k.toString()).toList();

        // Batch fetch all joined matches
        final matchFutures = matchIds.map((id) => _matchesRef.child(id).get());
        final matchSnapshots = await Future.wait(matchFutures);

        for (final matchSnapshot in matchSnapshots) {
          if (matchSnapshot.exists) {
            try {
              final match = Match.fromJson(
                  Map<String, dynamic>.from(matchSnapshot.value as Map));
              // Include upcoming matches (active or cancelled), and ensure user is actually in players list
              if (match.dateTime.isAfter(now) &&
                  match.players.contains(userId)) {
                matchesMap[match.id] = match;
              }
            } catch (e) {
              NumberedLogger.w('Error parsing joined match: $e');
            }
          }
        }
      }

      // Convert to list and sort by date (earliest first)
      final matchesList = matchesMap.values.toList();
      matchesList.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      // Cache the result
      _matchesCache[cacheKey] = CachedData(
        matchesList,
        DateTime.now(),
        expiry: ttl ?? _defaultCacheTTL,
      );

      return matchesList;
    } catch (e) {
      NumberedLogger.e('Error getting my matches: $e');
      return [];
    }
  }

  // Get matches that the user can join
  // Note: No caching - direct Firebase query for real-time consistency (matches old behavior)
  Future<List<Match>> getJoinableMatches({Duration? ttl}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return [];
      }

      // Fetch from Firebase with limit
      final snapshot = await _matchesRef
          .orderByChild('isActive')
          .equalTo(true)
          .limitToFirst(_maxJoinableMatches)
          .get();

      final matches = <Match>[];
      if (snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        for (final entry in data.values) {
          try {
            final entryMap = Map<String, dynamic>.from(entry);
            final match = Match.fromJson(entryMap);

            // Filter out matches organized by the current user
            if (match.organizerId == userId) {
              continue;
            }

            // For private matches, only include if user has been invited
            final isPublic = entryMap['isPublic'] is bool
                ? entryMap['isPublic'] as bool
                : ((entryMap['isPublic'] ?? 1) == 1);

            if (!isPublic) {
              // Check if user has an invite for this private match
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
                  // Private match and user not invited - exclude it
                  continue;
                }
              } else {
                // Private match with no invites structure - exclude it
                continue;
              }
            }

            matches.add(match);
          } catch (e) {
            NumberedLogger.w('Error parsing match: $e');
          }
        }
      }

      return matches;
    } catch (e) {
      NumberedLogger.e('Error getting joinable matches: $e');
      return [];
    }
  }

  // Watch joinable matches (reactive)
  Stream<List<Match>> watchJoinableMatches() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    return _matchesRef.orderByChild('isActive').equalTo(true).onValue.map((e) {
      if (!e.snapshot.exists) return <Match>[];
      final map = Map<dynamic, dynamic>.from(e.snapshot.value as Map);
      final list = <Match>[];
      for (final entry in map.values) {
        try {
          final entryMap = Map<String, dynamic>.from(entry);
          final g = Match.fromJson(entryMap);
          if (!g.isActive) continue;
          if (!g.dateTime.isAfter(DateTime.now())) continue;
          if (g.organizerId == userId) continue;

          // For private matches, only include if user has been invited
          final isPublic = entryMap['isPublic'] is bool
              ? entryMap['isPublic'] as bool
              : ((entryMap['isPublic'] ?? 1) == 1);

          if (!isPublic) {
            // Check if user has an invite for this private match
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
                // Private match and user not invited - exclude it
                continue;
              }
            } else {
              // Private match with no invites structure - exclude it
              continue;
            }
          }

          list.add(g);
        } catch (e) {
          NumberedLogger.w('Error parsing match in watchJoinableMatches: $e');
        }
      }
      list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      return list;
    });
  }

  // Get invited matches for the current user
  // Short-term caching for performance (30s default) while maintaining real-time consistency
  Future<List<Match>> getInvitedMatchesForCurrentUser({Duration? ttl}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return [];
      }

      // Check cache first
      final cacheKey = 'invitedMatches_$userId';
      final cached = _matchesCache[cacheKey];
      if (cached != null && !cached.isExpired) {
        return cached.data;
      }

      // Fetch from Firebase
      final snapshot =
          await _usersRef.child(DbPaths.userMatchInvites(userId)).get();

      final matches = <Match>[];
      if (snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        NumberedLogger.d(
            'Raw invite data for $userId: ${data.keys.length} entries');

        // Collect pending invite matchIds first
        final matchIds = <String>[];
        for (final entry in data.entries) {
          final matchId = entry.key.toString();
          final inviteData = entry.value;

          if (inviteData is! Map) {
            NumberedLogger.w(
                'Invite data for $matchId is not a Map: $inviteData');
            continue;
          }

          final inviteMap = Map<dynamic, dynamic>.from(inviteData);
          final status = inviteMap['status']?.toString();

          NumberedLogger.d('Match $matchId: status=$status');

          if (status == 'pending') {
            matchIds.add(matchId);
            NumberedLogger.d('Added pending match $matchId to list');
          } else {
            NumberedLogger.d(
                'Skipping match $matchId (status=$status, not pending)');
          }
        }

        NumberedLogger.d(
            'Found ${matchIds.length} pending invites out of ${data.length} total');

        // Batch fetch all matches in parallel to avoid N+1 query pattern
        final matchFutures = matchIds.map((id) => _matchesRef.child(id).get());
        final matchSnapshots = await Future.wait(matchFutures);

        for (final matchSnapshot in matchSnapshots) {
          if (matchSnapshot.exists) {
            try {
              final match = Match.fromJson(
                  Map<String, dynamic>.from(matchSnapshot.value as Map));
              // Only include active upcoming matches - cancelled matches should disappear
              if (match.isUpcoming && match.isActive) {
                matches.add(match);
              }
            } catch (e) {
              NumberedLogger.w('Error parsing invited match: $e');
            }
          }
        }
      }

      NumberedLogger.i('Fetched ${matches.length} invited matches for $userId');

      // Cache the result
      _matchesCache[cacheKey] = CachedData(
        matches,
        DateTime.now(),
        expiry: ttl ?? _defaultCacheTTL,
      );

      return matches;
    } catch (e) {
      NumberedLogger.e('Error getting invited matches: $e');
      return [];
    }
  }

  /// Validates that user indexes and match documents are consistent.
  /// Returns a list of human-readable issues; empty if healthy.
  Future<List<String>> validateUserMatchIndexes({String? userId}) async {
    final issues = <String>[];
    final uid = userId ?? _currentUserId;
    if (uid == null) return issues;

    try {
      // 1) createdMatchs index must reference existing matches
      final createdIdx =
          await _usersRef.child(DbPaths.userCreatedMatches(uid)).get();
      if (createdIdx.exists) {
        final map = Map<dynamic, dynamic>.from(createdIdx.value as Map);
        for (final matchId in map.keys) {
          final snap = await _matchesRef.child(matchId.toString()).get();
          if (!snap.exists) {
            issues.add('Orphan createdMatchs index: $matchId');
          }
        }
      }

      // 2) joinedMatchs index must reference existing matches and contain the user in players
      final joinedIdx =
          await _usersRef.child(DbPaths.userJoinedMatches(uid)).get();
      if (joinedIdx.exists) {
        final map = Map<dynamic, dynamic>.from(joinedIdx.value as Map);
        for (final matchId in map.keys) {
          final snap = await _matchesRef.child(matchId.toString()).get();
          if (!snap.exists) {
            issues.add('Orphan joinedMatchs index: $matchId');
            continue;
          }
          try {
            final match =
                Match.fromJson(Map<String, dynamic>.from(snap.value as Map));
            if (!match.players.contains(uid)) {
              issues.add(
                  'joinedMatchs mismatch: $matchId missing user in players');
            }
          } catch (e) {
            NumberedLogger.w('Corrupt match json for $matchId: $e');
            issues.add('Corrupt match json for $matchId');
          }
        }
      }

      // 3) invites pointing to non-existing matches
      final invitesIdx =
          await _usersRef.child(DbPaths.userMatchInvites(uid)).get();
      if (invitesIdx.exists) {
        final map = Map<dynamic, dynamic>.from(invitesIdx.value as Map);
        for (final matchId in map.keys) {
          final snap = await _matchesRef.child(matchId.toString()).get();
          if (!snap.exists) {
            issues.add('Invite to non-existing match: $matchId');
          }
        }
      }
    } catch (e) {
      NumberedLogger.e('validateUserMatchIndexes error: $e');
    }

    return issues;
  }

  /// Opportunistic self-healing for simple inconsistencies
  /// Only removes obviously broken indexes; never mutates match docs here.
  Future<int> fixSimpleInconsistencies({String? userId}) async {
    int fixes = 0;
    final uid = userId ?? _currentUserId;
    if (uid == null) return fixes;

    try {
      // Remove createdMatchs entries whose match does not exist
      final createdIdx =
          await _usersRef.child(DbPaths.userCreatedMatches(uid)).get();
      if (createdIdx.exists) {
        final map = Map<dynamic, dynamic>.from(createdIdx.value as Map);
        for (final matchId in map.keys) {
          final exists =
              (await _matchesRef.child(matchId.toString()).get()).exists;
          if (!exists) {
            await _usersRef
                .child(DbPaths.userCreatedMatches(uid))
                .child(matchId.toString())
                .remove();
            fixes++;
          }
        }
      }

      // Remove joinedMatchs entries whose match does not exist
      final joinedIdx =
          await _usersRef.child(DbPaths.userJoinedMatches(uid)).get();
      if (joinedIdx.exists) {
        final map = Map<dynamic, dynamic>.from(joinedIdx.value as Map);
        for (final matchId in map.keys) {
          final exists =
              (await _matchesRef.child(matchId.toString()).get()).exists;
          if (!exists) {
            await _usersRef
                .child(DbPaths.userJoinedMatches(uid))
                .child(matchId.toString())
                .remove();
            fixes++;
          }
        }
      }

      // Remove invites that point to non-existing matches
      final invitesIdx =
          await _usersRef.child(DbPaths.userMatchInvites(uid)).get();
      if (invitesIdx.exists) {
        final map = Map<dynamic, dynamic>.from(invitesIdx.value as Map);
        for (final matchId in map.keys) {
          final exists =
              (await _matchesRef.child(matchId.toString()).get()).exists;
          if (!exists) {
            await _usersRef
                .child(DbPaths.userMatchInvites(uid))
                .child(matchId.toString())
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
  // Uses watchInvitedMatches() to ensure real-time updates when matches are cancelled
  Stream<int> watchPendingInvitesCount() {
    return watchInvitedMatches().map((matches) {
      // Count only matches where user hasn't joined yet (excludes matches they accepted)
      final userId = _currentUserId;
      if (userId == null) return 0;

      final filteredMatchs =
          matches.where((g) => !g.players.contains(userId)).toList();
      NumberedLogger.d(
          'Badge count: ${filteredMatchs.length} pending invites (${matches.length} total invited matches)');
      return filteredMatchs.length;
    });
  }

  // Watch a single match for real-time updates
  Stream<Match?> watchMatch(String matchId) {
    return _matchesRef.child(matchId).onValue.map((event) {
      if (!event.snapshot.exists) return null;
      try {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return Match.fromJson(data);
      } catch (e) {
        NumberedLogger.w('Error parsing watched match: $e');
        return null;
      }
    });
  }

  // Watch invite statuses for a match in real-time
  Stream<Map<String, String>> watchMatchInviteStatuses(String matchId) {
    return _matchesRef.child(matchId).child('invites').onValue.map((event) {
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

  // Watch invited matches for the current user in real-time
  // Uses a dedicated pendingInviteIndex to avoid slow unindexed queries
  Stream<List<Match>> watchInvitedMatches() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    final DatabaseReference pendingIndexRef =
        _database.ref('${DbPaths.pendingInviteIndex}/$userId');

    StreamSubscription<DatabaseEvent>? indexSubscription;
    final Map<String, StreamSubscription<DatabaseEvent>> matchSubscriptions =
        {};
    final Map<String, Match> matchesCache = {};

    late StreamController<List<Match>> controller;

    void emitMatchs() {
      final matches = matchesCache.values
          .where((match) => match.isUpcoming && match.isActive)
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      if (!controller.isClosed && controller.hasListener) {
        controller.add(matches);
      }
    }

    Future<void> handleIndexEvent(DatabaseEvent event) async {
      final Set<String> pendingMatchIds = {};
      if (event.snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        data.forEach((key, value) {
          final status = value?.toString() ?? '';
          if (status == 'pending') {
            pendingMatchIds.add(key.toString());
          }
        });
      }

      await _ensurePendingInviteIndexForUser(userId, pendingMatchIds);

      final List<String> toRemove = matchSubscriptions.keys
          .where((id) => !pendingMatchIds.contains(id))
          .toList();
      for (final matchId in toRemove) {
        await matchSubscriptions[matchId]?.cancel();
        matchSubscriptions.remove(matchId);
        matchesCache.remove(matchId);
      }

      for (final matchId in pendingMatchIds) {
        if (matchSubscriptions.containsKey(matchId)) {
          continue;
        }

        final sub = _matchesRef.child(matchId).onValue.listen(
          (matchEvent) {
            if (!matchEvent.snapshot.exists) {
              matchesCache.remove(matchId);
              emitMatchs();
              return;
            }

            try {
              final matchMap = Map<String, dynamic>.from(
                  matchEvent.snapshot.value as Map<dynamic, dynamic>);
              final match = Match.fromJson(matchMap);

              final invites = matchMap['invites'];
              bool isPending = false;
              if (invites is Map) {
                final userInvite = invites[userId];
                if (userInvite is Map) {
                  isPending = (userInvite['status']?.toString() ?? 'pending') ==
                      'pending';
                } else if (userInvite != null) {
                  isPending = userInvite.toString() == 'pending';
                }
              }

              if (isPending && match.isUpcoming && match.isActive) {
                matchesCache[matchId] = match;
              } else {
                matchesCache.remove(matchId);
              }
            } catch (e) {
              NumberedLogger.w('Error parsing invited match $matchId: $e');
              matchesCache.remove(matchId);
            }

            emitMatchs();
          },
          onError: (error) {
            NumberedLogger.e('Stream error for invited match $matchId: $error');
            matchesCache.remove(matchId);
            emitMatchs();
          },
        );

        matchSubscriptions[matchId] = sub;
      }

      emitMatchs();
    }

    controller = StreamController<List<Match>>.broadcast(
      onListen: () {
        NumberedLogger.d('🔍 Watching pendingInviteIndex for user: $userId');
        controller.add(<Match>[]);
        indexSubscription = pendingIndexRef.onValue.listen(
          (event) {
            unawaited(handleIndexEvent(event).catchError((error) {
              NumberedLogger.e('Error handling index event: $error');
            }));
          },
          onError: (error) {
            NumberedLogger.e('Error watching pending invite index: $error');
          },
        );
      },
      onCancel: () async {
        // Cancel index subscription
        await indexSubscription?.cancel();
        indexSubscription = null;

        // Cancel all match subscriptions in parallel
        final subscriptionFutures = <Future>[];
        for (final sub in matchSubscriptions.values) {
          subscriptionFutures.add(sub.cancel());
        }
        await Future.wait(subscriptionFutures);
        matchSubscriptions.clear();
        matchesCache.clear();
      },
    );

    return controller.stream.transform(_distinctMatchesTransformer());
  }

  Future<void> _ensurePendingInviteIndexForUser(
      String userId, Set<String> pendingMatchIds) async {
    try {
      final invitesSnapshot =
          await _usersRef.child(DbPaths.userMatchInvites(userId)).get();
      if (!invitesSnapshot.exists) {
        return;
      }

      final invitesData =
          Map<dynamic, dynamic>.from(invitesSnapshot.value as Map);
      final Map<String, Object?> updates = {};

      invitesData.forEach((matchId, inviteValue) {
        final id = matchId.toString();
        if (pendingMatchIds.contains(id)) {
          return;
        }

        if (inviteValue is Map) {
          final inviteMap = Map<dynamic, dynamic>.from(inviteValue);
          final status = inviteMap['status']?.toString() ?? 'pending';
          if (status == 'pending') {
            updates['${DbPaths.pendingInviteIndex}/$userId/$id'] = 'pending';
            pendingMatchIds.add(id);
          }
        }
      });

      if (updates.isNotEmpty) {
        await _database.ref().update(updates);
      }
    } catch (e) {
      NumberedLogger.w(
          'Unable to backfill pending invite index for user $userId: $e');
    }
  }

  // Watch matches organized by current user for real-time updates
  Stream<List<Match>> watchMyMatches() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    final now = DateTime.now();

    // Stream 1: Watch organized matches by organizerId (captures all match data changes)
    // This will emit whenever ANY match organized by this user changes (cancellation, updates, etc.)
    final organizedMatchsStream = _matchesRef
        .orderByChild('organizerId')
        .equalTo(userId)
        .onValue
        .asyncMap((event) async {
      final matchesMap = <String, Match>{};

      // Get current createdMatchs index to filter
      final createdIndexSnapshot =
          await _usersRef.child(DbPaths.userCreatedMatches(userId)).get();
      final Set<String> createdMatchIds = {};
      if (createdIndexSnapshot.exists) {
        final createdData =
            Map<dynamic, dynamic>.from(createdIndexSnapshot.value as Map);
        createdMatchIds.addAll(createdData.keys.map((k) => k.toString()));
      }

      if (event.snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        for (final entry in data.values) {
          try {
            final match = Match.fromJson(Map<String, dynamic>.from(entry));
            // Only include if:
            // 1. Match is in userCreatedMatches index (respects removal)
            // 2. Match is upcoming (includes cancelled matches)
            if (createdMatchIds.contains(match.id) &&
                match.dateTime.isAfter(now)) {
              matchesMap[match.id] = match;
            }
          } catch (e) {
            NumberedLogger.w('Error parsing organized match: $e');
          }
        }
      }

      return matchesMap;
    });

    // Stream 1b: Also watch userCreatedMatches index to trigger re-filtering when matches are removed
    // When index changes, we need to re-emit organized matches with updated filter
    final createdIndexWatchStream = _usersRef
        .child(DbPaths.userCreatedMatches(userId))
        .onValue
        .asyncMap((event) async {
      // Get current organized matches and re-filter by index
      final organizedSnapshot =
          await _matchesRef.orderByChild('organizerId').equalTo(userId).get();

      final matchesMap = <String, Match>{};
      final Set<String> createdMatchIds = {};

      if (event.snapshot.exists) {
        final createdData =
            Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        createdMatchIds.addAll(createdData.keys.map((k) => k.toString()));
      }

      if (organizedSnapshot.exists) {
        final data = Map<dynamic, dynamic>.from(organizedSnapshot.value as Map);
        for (final entry in data.values) {
          try {
            final match = Match.fromJson(Map<String, dynamic>.from(entry));
            if (createdMatchIds.contains(match.id) &&
                match.dateTime.isAfter(now)) {
              matchesMap[match.id] = match;
            }
          } catch (e) {
            NumberedLogger.w(
                'Error parsing organized match from index watch: $e');
          }
        }
      }

      return matchesMap;
    });

    // Stream 2: Watch joined matches index AND fetch their current data
    // This handles both index changes (add/remove) and initial state
    final joinedMatchsStream = _usersRef
        .child(DbPaths.userJoinedMatches(userId))
        .onValue
        .asyncMap((event) async {
      final matchesMap = <String, Match>{};

      if (!event.snapshot.exists) return matchesMap;

      final joinedData =
          Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final joinedIds = joinedData.keys.map((k) => k.toString()).toList();

      // Fetch current state of all joined matches
      for (final matchId in joinedIds) {
        try {
          final matchSnapshot = await _matchesRef.child(matchId).get();
          if (!matchSnapshot.exists || matchSnapshot.value == null) continue;
          final match = Match.fromJson(
              Map<String, dynamic>.from(matchSnapshot.value as Map));
          // Include upcoming matches (active or cancelled), and ensure user is actually in players list
          if (match.dateTime.isAfter(now) && match.players.contains(userId)) {
            matchesMap[match.id] = match;
          }
        } catch (e) {
          NumberedLogger.w('Error fetching joined match $matchId: $e');
        }
      }

      return matchesMap;
    });

    // Stream 3: Watch individual match data streams for joined matches (catches cancellations/updates)
    // When index changes, we watch each match's data stream to catch real-time updates
    final joinedMatchsDataStreamController =
        StreamController<Map<String, Match>>();
    final joinedMatchSubscriptions = <String, StreamSubscription<Match?>>{};
    final joinedMatchsDataCache = <String, Match>{};

    // Helper to update watched matches when index changes
    void updateWatchedJoinedMatchs(Set<String> matchIds) {
      // Cancel subscriptions for matches no longer in index
      final matchesToRemove = joinedMatchSubscriptions.keys
          .where((id) => !matchIds.contains(id))
          .toList();
      for (final matchId in matchesToRemove) {
        joinedMatchSubscriptions[matchId]?.cancel();
        joinedMatchSubscriptions.remove(matchId);
        joinedMatchsDataCache.remove(matchId);
      }

      // Add subscriptions for new matches
      for (final matchId in matchIds) {
        if (!joinedMatchSubscriptions.containsKey(matchId)) {
          final sub = watchMatch(matchId).listen(
            (match) {
              if (match != null &&
                  match.dateTime.isAfter(now) &&
                  match.players.contains(userId)) {
                joinedMatchsDataCache[matchId] = match;
              } else {
                joinedMatchsDataCache.remove(matchId);
              }
              if (!joinedMatchsDataStreamController.isClosed) {
                joinedMatchsDataStreamController
                    .add(Map<String, Match>.from(joinedMatchsDataCache));
              }
            },
            onError: (e) {
              NumberedLogger.w('Error in match stream for $matchId: $e');
              // For transient errors, log and emit to stream
              // The stream will be recreated when updateWatchedJoinedMatchs is called again
              // This handles network errors and other transient failures gracefully
              if (!joinedMatchsDataStreamController.isClosed) {
                joinedMatchsDataStreamController.addError(e);
              }
            },
          );
          joinedMatchSubscriptions[matchId] = sub;
        }
      }

      // IMPORTANT: Emit update after removing matches so the UI updates immediately
      if (!joinedMatchsDataStreamController.isClosed) {
        joinedMatchsDataStreamController
            .add(Map<String, Match>.from(joinedMatchsDataCache));
      }
    }

    // Cleanup when stream is cancelled - note: joinedIndexWatchSubRef is set below
    final joinedMatchsDataStream = joinedMatchsDataStreamController.stream;

    // Combine all streams
    final controller = StreamController<List<Match>>();
    StreamSubscription<Map<String, Match>>? organizedSub;
    StreamSubscription<Map<String, Match>>? organizedIndexSub;
    StreamSubscription<Map<String, Match>>? joinedIndexSub;
    StreamSubscription<Map<String, Match>>? joinedDataSub;
    StreamSubscription<DatabaseEvent>? joinedIndexWatchSubRef;

    // Track current state
    Map<String, Match> organizedMatchs = {};
    Map<String, Match> joinedMatchs = {};

    void emitCombined() {
      if (controller.isClosed) return;

      // Merge organized and joined matches (organized take precedence)
      final allMatchsMap = <String, Match>{
        ...joinedMatchs,
        ...organizedMatchs, // Organized matches override joined if same ID
      };

      final allMatchs = allMatchsMap.values.toList();
      allMatchs.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      controller.add(allMatchs);
    }

    // Watch organized matches stream (match data changes)
    organizedSub = organizedMatchsStream.listen((matches) {
      organizedMatchs = matches;
      emitCombined();
    }, onError: (e) {
      if (!controller.isClosed) controller.addError(e);
    });

    // Watch created matches index stream (index changes trigger re-filtering)
    organizedIndexSub = createdIndexWatchStream.listen((matches) {
      organizedMatchs = matches;
      emitCombined();
    }, onError: (e) {
      if (!controller.isClosed) controller.addError(e);
    });

    // Watch joined matches index stream (handles add/remove from index)
    joinedIndexSub = joinedMatchsStream.listen((matches) {
      // Update or add matches from index fetch
      for (final entry in matches.entries) {
        joinedMatchs[entry.key] = entry.value;
      }
      // Note: Don't remove matches here - let joinedMatchsDataStream handle removals
      // based on index watch, which will stop emitting for removed matches
      emitCombined();
    }, onError: (e) {
      if (!controller.isClosed) controller.addError(e);
    });

    // Watch individual match data streams for joined matches (handles cancellations/updates)
    joinedDataSub = joinedMatchsDataStream.listen((matches) {
      // Update joined matches with latest data from individual streams
      for (final entry in matches.entries) {
        joinedMatchs[entry.key] = entry.value;
      }
      // Remove matches that are no longer in the cache (removed from index)
      joinedMatchs.removeWhere((key, _) => !matches.containsKey(key));
      emitCombined();
    }, onError: (e) {
      if (!controller.isClosed) controller.addError(e);
    });

    // Store reference to index watch subscription for updating watched matches
    joinedIndexWatchSubRef = _usersRef
        .child(DbPaths.userJoinedMatches(userId))
        .onValue
        .listen((event) {
      if (!event.snapshot.exists) {
        updateWatchedJoinedMatchs({});
        return;
      }
      final joinedData =
          Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final matchIds = joinedData.keys.map((k) => k.toString()).toSet();
      updateWatchedJoinedMatchs(matchIds);
    }, onError: (error) {
      NumberedLogger.e('Error watching joined matches index: $error');
      // On error, try to update with empty set to clear cache
      updateWatchedJoinedMatchs({});
    });

    // Initial fetch to populate data
    Future.microtask(() async {
      // Fetch initial organized matches
      final organizedSnapshot =
          await _matchesRef.orderByChild('organizerId').equalTo(userId).get();
      final createdIndexSnapshot =
          await _usersRef.child(DbPaths.userCreatedMatches(userId)).get();
      final Set<String> createdMatchIds = {};
      if (createdIndexSnapshot.exists) {
        final createdData =
            Map<dynamic, dynamic>.from(createdIndexSnapshot.value as Map);
        createdMatchIds.addAll(createdData.keys.map((k) => k.toString()));
      }
      if (organizedSnapshot.exists) {
        final data = Map<dynamic, dynamic>.from(organizedSnapshot.value as Map);
        for (final entry in data.values) {
          try {
            final match = Match.fromJson(Map<String, dynamic>.from(entry));
            if (createdMatchIds.contains(match.id) &&
                match.dateTime.isAfter(now)) {
              organizedMatchs[match.id] = match;
            }
          } catch (e) {
            NumberedLogger.w('Error parsing initial organized match: $e');
          }
        }
      }

      // Fetch initial joined matches
      final joinedSnapshot =
          await _usersRef.child(DbPaths.userJoinedMatches(userId)).get();
      if (joinedSnapshot.exists) {
        final joinedData =
            Map<dynamic, dynamic>.from(joinedSnapshot.value as Map);
        final joinedIds = joinedData.keys.map((k) => k.toString()).toSet();
        updateWatchedJoinedMatchs(joinedIds);

        for (final matchId in joinedIds) {
          try {
            final matchSnapshot = await _matchesRef.child(matchId).get();
            if (matchSnapshot.exists) {
              final match = Match.fromJson(
                  Map<String, dynamic>.from(matchSnapshot.value as Map));
              if (match.dateTime.isAfter(now) &&
                  match.players.contains(userId)) {
                joinedMatchs[match.id] = match;
              }
            }
          } catch (e) {
            NumberedLogger.w(
                'Error fetching initial joined match $matchId: $e');
          }
        }
      }

      emitCombined();
    });

    controller.onCancel = () async {
      // Cancel all subscriptions to prevent memory leaks
      await organizedSub?.cancel();
      organizedSub = null;
      await organizedIndexSub?.cancel();
      organizedIndexSub = null;
      await joinedIndexSub?.cancel();
      joinedIndexSub = null;
      await joinedDataSub?.cancel();
      joinedDataSub = null;
      await joinedIndexWatchSubRef?.cancel();
      joinedIndexWatchSubRef = null;

      // Cancel all individual match subscriptions
      final subscriptionFutures = <Future>[];
      for (final sub in joinedMatchSubscriptions.values) {
        subscriptionFutures.add(sub.cancel());
      }
      await Future.wait(subscriptionFutures);
      joinedMatchSubscriptions.clear();

      // Close stream controller if not already closed
      if (!joinedMatchsDataStreamController.isClosed) {
        joinedMatchsDataStreamController.close();
      }
    };

    // Use a more lenient distinct that only checks for meaningful changes
    // but still emits when matches are added/removed or player counts change
    return controller.stream.distinct((prev, next) {
      if (prev.length != next.length) return false;

      // Create maps for faster lookup
      final prevMap = {for (var g in prev) g.id: g};
      final nextMap = {for (var g in next) g.id: g};

      for (final matchId in prevMap.keys) {
        final prevMatch =
            prevMap[matchId]!; // Safe: we're iterating over keys that exist
        final nextMatch = nextMap[matchId];

        if (nextMatch == null) return false; // Match was removed

        // Check for meaningful changes
        if (prevMatch.currentPlayers != nextMatch.currentPlayers ||
            prevMatch.players.length != nextMatch.players.length ||
            prevMatch.dateTime != nextMatch.dateTime ||
            prevMatch.location != nextMatch.location ||
            prevMatch.updatedAt != nextMatch.updatedAt ||
            prevMatch.isActive != nextMatch.isActive) {
          return false; // Something meaningful changed
        }
      }

      // Check for new matches
      for (final matchId in nextMap.keys) {
        if (!prevMap.containsKey(matchId)) return false;
      }

      return true; // No meaningful changes
    });
  }

  // Watch historic matches (past matches where user participated)
  Stream<List<Match>> watchHistoricMatches() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value([]);

    final now = DateTime.now();

    // Stream 1: Watch matches organized by the user
    final organizedMatchsStream = _matchesRef
        .orderByChild('organizerId')
        .equalTo(userId)
        .onValue
        .asyncMap((event) async {
      final matchesMap = <String, Match>{};
      // Get current createdMatchs index to filter
      final createdIndexSnapshot =
          await _usersRef.child(DbPaths.userCreatedMatches(userId)).get();
      final Set<String> createdMatchIds = {};
      if (createdIndexSnapshot.exists) {
        final createdData =
            Map<dynamic, dynamic>.from(createdIndexSnapshot.value as Map);
        createdMatchIds.addAll(createdData.keys.map((k) => k.toString()));
      }

      if (event.snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        for (final entry in data.values) {
          try {
            final match = Match.fromJson(Map<String, dynamic>.from(entry));
            // Include historic matches (past matches) where user is organizer
            if (createdMatchIds.contains(match.id) &&
                match.dateTime.isBefore(now)) {
              matchesMap[match.id] = match;
            }
          } catch (e) {
            NumberedLogger.w('Error parsing historic organized match: $e');
          }
        }
      }

      return matchesMap;
    });

    // Stream 2: Watch matches the user joined (from joinedMatchs index)
    final joinedMatchsStream = _usersRef
        .child(DbPaths.userJoinedMatches(userId))
        .onValue
        .asyncMap((event) async {
      final matchesMap = <String, Match>{};

      if (!event.snapshot.exists) return matchesMap;

      final joinedData =
          Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final joinedIds = joinedData.keys.map((k) => k.toString()).toList();

      // Fetch current state of all joined matches
      for (final matchId in joinedIds) {
        try {
          final matchSnapshot = await _matchesRef.child(matchId).get();
          if (!matchSnapshot.exists) continue;
          final match = Match.fromJson(
              Map<String, dynamic>.from(matchSnapshot.value as Map));
          // Include historic matches (past matches) where user is in players list
          if (match.dateTime.isBefore(now) && match.players.contains(userId)) {
            matchesMap[match.id] = match;
          }
        } catch (e) {
          NumberedLogger.w('Error fetching historic joined match $matchId: $e');
        }
      }

      return matchesMap;
    });

    // Combine both streams
    final controller = StreamController<List<Match>>();
    StreamSubscription<Map<String, Match>>? organizedSub;
    StreamSubscription<Map<String, Match>>? joinedSub;

    // Track current state
    Map<String, Match> organizedMatchs = {};
    Map<String, Match> joinedMatchs = {};

    void emitCombined() {
      if (controller.isClosed) return;

      // Merge organized and joined matches (organized take precedence)
      final allMatchsMap = <String, Match>{
        ...joinedMatchs,
        ...organizedMatchs, // Organized matches override joined if same ID
      };

      final allMatchs = allMatchsMap.values.toList();
      // Sort by date descending (most recent first)
      allMatchs.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      controller.add(allMatchs);
    }

    // Watch organized matches stream
    organizedSub = organizedMatchsStream.listen((matches) {
      organizedMatchs = matches;
      emitCombined();
    }, onError: (e) {
      if (!controller.isClosed) controller.addError(e);
    });

    // Watch joined matches stream
    joinedSub = joinedMatchsStream.listen((matches) {
      joinedMatchs = matches;
      emitCombined();
    }, onError: (e) {
      if (!controller.isClosed) controller.addError(e);
    });

    // Initial fetch
    Future.microtask(() async {
      // Fetch initial organized matches
      final organizedSnapshot =
          await _matchesRef.orderByChild('organizerId').equalTo(userId).get();
      final createdIndexSnapshot =
          await _usersRef.child(DbPaths.userCreatedMatches(userId)).get();
      final Set<String> createdMatchIds = {};
      if (createdIndexSnapshot.exists) {
        final createdData =
            Map<dynamic, dynamic>.from(createdIndexSnapshot.value as Map);
        createdMatchIds.addAll(createdData.keys.map((k) => k.toString()));
      }
      if (organizedSnapshot.exists) {
        final data = Map<dynamic, dynamic>.from(organizedSnapshot.value as Map);
        for (final entry in data.values) {
          try {
            final match = Match.fromJson(Map<String, dynamic>.from(entry));
            if (createdMatchIds.contains(match.id) &&
                match.dateTime.isBefore(now)) {
              organizedMatchs[match.id] = match;
            }
          } catch (e) {
            NumberedLogger.w(
                'Error parsing initial historic organized match: $e');
          }
        }
      }

      // Fetch initial joined matches
      final joinedSnapshot =
          await _usersRef.child(DbPaths.userJoinedMatches(userId)).get();
      if (joinedSnapshot.exists) {
        final joinedData =
            Map<dynamic, dynamic>.from(joinedSnapshot.value as Map);
        final joinedIds = joinedData.keys.map((k) => k.toString()).toList();

        for (final matchId in joinedIds) {
          try {
            final matchSnapshot = await _matchesRef.child(matchId).get();
            if (matchSnapshot.exists) {
              final match = Match.fromJson(
                  Map<String, dynamic>.from(matchSnapshot.value as Map));
              if (match.dateTime.isBefore(now) &&
                  match.players.contains(userId)) {
                joinedMatchs[match.id] = match;
              }
            }
          } catch (e) {
            NumberedLogger.w(
                'Error fetching initial historic joined match $matchId: $e');
          }
        }
      }

      emitCombined();
    });

    controller.onCancel = () {
      organizedSub?.cancel();
      joinedSub?.cancel();
    };

    return controller.stream.distinct((prev, next) {
      if (prev.length != next.length) return false;

      // Create maps for faster lookup
      final prevMap = {for (var g in prev) g.id: g};
      final nextMap = {for (var g in next) g.id: g};

      for (final matchId in prevMap.keys) {
        final prevMatch = prevMap[matchId]!;
        final nextMatch = nextMap[matchId];

        if (nextMatch == null) return false; // Match was removed

        // Check for meaningful changes
        if (prevMatch.currentPlayers != nextMatch.currentPlayers ||
            prevMatch.players.length != nextMatch.players.length ||
            prevMatch.dateTime != nextMatch.dateTime ||
            prevMatch.location != nextMatch.location ||
            prevMatch.isActive != nextMatch.isActive) {
          return false; // Something meaningful changed
        }
      }

      // Check for new matches
      for (final matchId in nextMap.keys) {
        if (!prevMap.containsKey(matchId)) return false;
      }

      return true; // No meaningful changes
    });
  }

  // Join a match
  Future<void> joinMatch(String matchId) async {
    try {
      final userId = _requireCurrentUserId();

      // Get the match
      final matchSnapshot = await _matchesRef.child(matchId).get();
      if (!matchSnapshot.exists) {
        throw NotFoundException('Match not found');
      }

      final match =
          Match.fromJson(Map<String, dynamic>.from(matchSnapshot.value as Map));

      // Check if user is already in the match
      if (match.players.contains(userId)) {
        throw AlreadyExistsException('Already joined this match');
      }

      // Check if user already has a match at the same date+time
      final conflictingMatch =
          await _checkUserTimeConflict(userId, match.dateTime);
      if (conflictingMatch != null) {
        NumberedLogger.w(
            'User $userId already has a match at ${match.dateTime} (conflicts with match ${conflictingMatch.id})');
        throw ValidationException('user_already_busy');
      }

      // Allow joining even if match is full - players beyond maxPlayers will be on the bench
      // No restriction - users can join and will be marked as benched if beyond maxPlayers

      // Add user to the match
      final updatedPlayers = List<String>.from(match.players)..add(userId);

      // Prepare atomic updates
      final Map<String, Object?> updates = {};

      // Update the match
      updates['${DbPaths.matches}/$matchId/players'] = updatedPlayers;
      updates['${DbPaths.matches}/$matchId/currentPlayers'] =
          updatedPlayers.length;

      // Update invite status in matches/{matchId}/invites/{uid} if it exists
      final inviteCheckSnapshot =
          await _matchesRef.child(matchId).child('invites').child(userId).get();
      if (inviteCheckSnapshot.exists) {
        updates['${DbPaths.matches}/$matchId/invites/$userId/status'] =
            'accepted';
        updates['${DbPaths.pendingInviteIndex}/$userId/$matchId'] = null;
      }

      // Remove from user's invite list (this will trigger badge update)
      updates['users/$userId/matchInvites/$matchId'] = null;

      // Add match to user's joined matches
      updates['users/$userId/joinedMatchs/$matchId'] = {
        'sport': match.sport,
        'dateTime': match.dateTime.toIso8601String(),
        'location': match.location,
        'maxPlayers': match.maxPlayers,
        'joinedAt': DateTime.now().toIso8601String(),
      };

      // Commit all updates atomically
      await _database.ref().update(updates);

      // Invalidate cache for the user who joined
      _invalidateCache(userId: userId);
      // Also invalidate organizer's cache if different
      if (match.organizerId != userId) {
        _invalidateCache(userId: match.organizerId);
      }

      // Streams will update automatically - no cache clearing needed
    } catch (e, st) {
      NumberedLogger.e('Error joining match: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'match_join_fail');
      rethrow;
    }
  }

  // Leave a match
  Future<void> leaveMatch(String matchId) async {
    try {
      final userId = _requireCurrentUserId();

      // Get the match
      final matchSnapshot = await _matchesRef.child(matchId).get();
      if (!matchSnapshot.exists) {
        throw NotFoundException('Match not found');
      }

      final match =
          Match.fromJson(Map<String, dynamic>.from(matchSnapshot.value as Map));

      // Check if user is in the match
      if (!match.players.contains(userId)) {
        throw NotFoundException('Not in this match');
      }

      // Remove user from the match
      final updatedPlayers = List<String>.from(match.players)..remove(userId);

      // Prepare atomic updates
      final Map<String, Object?> updates = {};

      // Update the match
      updates['${DbPaths.matches}/$matchId/players'] = updatedPlayers;
      updates['${DbPaths.matches}/$matchId/currentPlayers'] =
          updatedPlayers.length;

      // Update invite status to 'left' if invite exists (so organizer sees red cross)
      final inviteCheckSnapshot =
          await _matchesRef.child(matchId).child('invites').child(userId).get();
      if (inviteCheckSnapshot.exists) {
        updates['${DbPaths.matches}/$matchId/invites/$userId/status'] = 'left';
        updates['${DbPaths.pendingInviteIndex}/$userId/$matchId'] = null;
      }

      // Commit updates atomically
      await _database.ref().update(updates);

      // Remove match from user's joined matches
      await _usersRef
          .child(DbPaths.userJoinedMatches(userId))
          .child(matchId)
          .remove();

      // Streams will update automatically - no cache clearing needed
    } catch (e, st) {
      NumberedLogger.e('Error leaving match: $e');
      CrashlyticsHelper.recordError(e, st, reason: 'match_leave_fail');
      rethrow;
    }
  }

  // Accept match invite
  Future<void> acceptMatchInvite(String matchId) async {
    try {
      final userId = _requireCurrentUserId();

      // Check if user has a pending invite for this match
      final inviteSnapshot = await _usersRef
          .child(DbPaths.userMatchInvites(userId))
          .child(matchId)
          .get();

      if (!inviteSnapshot.exists) {
        throw NotFoundException('No pending invite for this match');
      }

      final inviteData = Map<String, dynamic>.from(inviteSnapshot.value as Map);
      if (inviteData['status'] != 'pending') {
        throw ValidationException('Invite is not pending');
      }

      // Join the match (this will also remove the invite)
      await joinMatch(matchId);
    } catch (e) {
      NumberedLogger.e('Error accepting match invite: $e');
      rethrow;
    }
  }

  // Decline match invite
  Future<void> declineMatchInvite(String matchId) async {
    try {
      final userId = _requireCurrentUserId();

      // Prepare atomic updates
      final Map<String, Object?> updates = {};

      // Update invite status to 'declined' if invite exists (so organizer sees red cross)
      final inviteCheckSnapshot =
          await _matchesRef.child(matchId).child('invites').child(userId).get();
      if (inviteCheckSnapshot.exists) {
        updates['${DbPaths.matches}/$matchId/invites/$userId/status'] =
            'declined';
        updates['${DbPaths.pendingInviteIndex}/$userId/$matchId'] = null;
      }

      // Remove from user's invite list (this will trigger badge update)
      updates['users/$userId/matchInvites/$matchId'] = null;

      // Commit all updates atomically
      await _database.ref().update(updates);

      // Streams will update automatically - no cache clearing needed
    } catch (e) {
      NumberedLogger.e('Error declining match invite: $e');
      rethrow;
    }
  }

  // Get invite statuses for a match
  Future<Map<String, String>> getMatchInviteStatuses(String matchId) async {
    try {
      final snapshot = await _matchesRef.child(matchId).child('invites').get();

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
      NumberedLogger.e('Error getting invite statuses for match $matchId: $e');
      return {};
    }
  }

  // Check if current user has a pending invite for a specific match
  // This checks the user's matchInvites path directly for faster detection
  Future<String?> getUserInviteStatusForMatch(String matchId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return null;
      }

      final snapshot = await _usersRef
          .child(DbPaths.userMatchInvites(userId))
          .child(matchId)
          .get();

      if (!snapshot.exists) {
        return null;
      }

      final inviteData = snapshot.value;
      if (inviteData is Map) {
        final inviteMap = Map<dynamic, dynamic>.from(inviteData);
        return inviteMap['status']?.toString();
      } else if (inviteData != null) {
        // Legacy format - just a string
        return inviteData.toString();
      }

      return null;
    } catch (e) {
      NumberedLogger.e(
          'Error checking user invite status for match $matchId: $e');
      return null;
    }
  }

  // Send match invites to friends
  Future<void> sendMatchInvitesToFriends(
      String matchId, List<String> friendUids) async {
    try {
      if (friendUids.isEmpty) return;

      final userId = _requireCurrentUserId();

      NumberedLogger.d(
          'Sending invites for match $matchId to ${friendUids.length} friends');

      // Get match details to include in invites
      final match = await getMatchById(matchId);
      if (match == null) {
        NumberedLogger.e('Match not found when sending invites: $matchId');
        throw NotFoundException('Match not found: $matchId');
      }

      // Verify user is the organizer
      if (match.organizerId != userId) {
        throw AuthException('Only the match organizer can send invites');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final inviteDateString = match.dateTime.toIso8601String();

      // Prepare atomic multi-path update for all invites
      final Map<String, Object?> updates = {};

      for (final friendUid in friendUids) {
        // Write to matches/{matchId}/invites/{uid}: {status: 'pending'}
        final matchInvitePath =
            '${DbPaths.matches}/$matchId/invites/$friendUid';
        updates[matchInvitePath] = {
          'status': 'pending',
        };

        // Write to users/{uid}/matchInvites/{matchId}: {status, ts, organizerId, sport, date}
        final userInvitePath = 'users/$friendUid/matchInvites/$matchId';
        updates[userInvitePath] = {
          'status': 'pending',
          'ts': timestamp,
          'organizerId': match.organizerId,
          'sport': match.sport,
          'date': inviteDateString,
        };

        // Maintain pending invite index for efficient queries
        final pendingIndexPath =
            '${DbPaths.pendingInviteIndex}/$friendUid/$matchId';
        updates[pendingIndexPath] = 'pending';

        NumberedLogger.d(
            'Prepared invite paths: match=$matchInvitePath, user=$userInvitePath');
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

      // Notifications are automatically sent by Cloud Function onMatchInviteCreate
      // when invites are written to /matches/{matchId}/invites/{inviteeUid}
      NumberedLogger.i(
          'Match invites sent to ${friendUids.length} friends for match $matchId. Notifications will be sent automatically by Cloud Function.');
    } catch (e, stackTrace) {
      NumberedLogger.e('Error sending match invites: $e');
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

  /// Get booked time slots for a specific date and field
  ///
  /// Returns a set of booked times in "HH:mm" format.
  /// Verifies slots against active matches to filter out cancelled matches.
  /// Note: Slots are shared across sports for the same field, so this method
  /// returns all booked times for the field regardless of sport.
  Future<Set<String>> getBookedSlots({
    required DateTime date,
    required Map<String, dynamic>? field,
  }) async {
    if (field == null) return <String>{};

    // Compute dateKey = yyyy-MM-dd
    final dateKey = _dateKey(date);

    // Compute fieldKey (prefer id, else lat_lon with underscores, else sanitized name)
    // SECURITY: Sanitize all inputs to prevent path injection
    String fieldKey = _fieldKeyFromMap(field);

    final path = 'slots/$dateKey/$fieldKey';
    NumberedLogger.d(
        '🔍 Loading booked slots: dateKey=$dateKey, fieldKey=$fieldKey, path=$path');

    final times = <String>{};

    // Try to read from Firebase slots
    try {
      final snapshot = await _database.ref(path).get();

      if (snapshot.exists && snapshot.value is Map) {
        final map = Map<dynamic, dynamic>.from(snapshot.value as Map);
        NumberedLogger.d(
            '🔍 Found ${map.keys.length} booked slots in Firebase');
        for (final k in map.keys) {
          var t = k.toString();
          if (t.length == 4) {
            t = '${t.substring(0, 2)}:${t.substring(2)}';
          }
          final normalizedTime = t.trim();
          times.add(normalizedTime);
        }
      }
    } catch (e) {
      NumberedLogger.w('🔍 Firebase slots read failed: $e');
      // Continue to verification/fallback
    }

    // Verify slots against active matches to filter out cancelled matches
    try {
      final myMatches = await getMyMatches();
      final joinable = await getJoinableMatches();
      final all = <Match>[...myMatches, ...joinable];

      final activeMatchTimes = <String>{};
      for (final g in all) {
        // Skip cancelled matches - they've freed their slots
        if (!g.isActive) continue;

        final gDateKey = _dateKey(g.dateTime);
        if (gDateKey != dateKey) continue;

        if (!_isSameField(g, field, fieldKey)) continue;

        final hh = g.dateTime.hour.toString().padLeft(2, '0');
        final mm = g.dateTime.minute.toString().padLeft(2, '0');
        final timeStr = '$hh:$mm';
        activeMatchTimes.add(timeStr);
      }

      // Use active matches as the authoritative source
      times.clear();
      times.addAll(activeMatchTimes);
      NumberedLogger.d(
          '🔍 After verification: ${times.length} valid booked times');
    } catch (e) {
      NumberedLogger.w('🔍 Verification error: $e');
      // If verification fails, keep original times from Firebase
    }

    // Fallback: infer from matches if slots node is empty
    if (times.isEmpty) {
      NumberedLogger.d('🔍 Slots empty, trying fallback from matches...');
      try {
        final myMatches = await getMyMatches();
        final joinable = await getJoinableMatches();
        final all = <Match>[...myMatches, ...joinable];

        for (final g in all) {
          if (!g.isActive) continue;

          final gDateKey = _dateKey(g.dateTime);
          if (gDateKey != dateKey) continue;

          if (!_isSameField(g, field, fieldKey)) continue;

          final hh = g.dateTime.hour.toString().padLeft(2, '0');
          final mm = g.dateTime.minute.toString().padLeft(2, '0');
          final timeStr = '$hh:$mm';
          times.add(timeStr);
        }
        NumberedLogger.d('🔍 Fallback found ${times.length} booked times');
      } catch (e) {
        NumberedLogger.w('🔍 Fallback error: $e');
      }
    }

    return times;
  }

  /// Compute fieldKey from field map (same logic as in screen)
  String _fieldKeyFromMap(Map<String, dynamic> field) {
    final id = field['id']?.toString();
    if (id != null && id.trim().isNotEmpty) {
      // Sanitize field ID to prevent path injection
      var fieldKey = id
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      // Limit length to prevent issues
      if (fieldKey.length > 100) {
        fieldKey = fieldKey.substring(0, 100);
      }
      return fieldKey;
    } else if (field['latitude'] != null && field['longitude'] != null) {
      final lat = safeToDouble(field['latitude']);
      final lon = safeToDouble(field['longitude']);
      if (lat == null || lon == null) {
        final name = (field['name']?.toString() ?? '').toLowerCase();
        final sanitized = name
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'_+'), '_')
            .trim();
        return sanitized.isEmpty ? 'unknown_field' : sanitized;
      }
      final latFixed = lat.toStringAsFixed(5).replaceAll('.', '_');
      final lonFixed = lon.toStringAsFixed(5).replaceAll('.', '_');
      return '$latFixed' '_$lonFixed';
    } else {
      final name = (field['name']?.toString() ?? '').toLowerCase();
      final sanitized = name
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .trim();
      return sanitized.isEmpty ? 'unknown_field' : sanitized;
    }
  }

  /// Check if a match matches the given field
  bool _isSameField(Match match, Map<String, dynamic> field, String fieldKey) {
    String sanitizeName(String s) => s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();

    final gLat = match.latitude;
    final gLon = match.longitude;
    final hasCoords = gLat != null && gLon != null;
    final gKey = hasCoords
        ? '${gLat.toStringAsFixed(5).replaceAll('.', '_')}_${gLon.toStringAsFixed(5).replaceAll('.', '_')}'
        : sanitizeName(match.location);

    if (gKey == fieldKey) return true;

    if (hasCoords && field['latitude'] != null && field['longitude'] != null) {
      final sLat = safeToDouble(field['latitude']);
      final sLon = safeToDouble(field['longitude']);
      if (sLat == null || sLon == null) {
        return sanitizeName(match.location) ==
            sanitizeName(field['name']?.toString() ?? '');
      }
      if (areCoordinatesVeryClose(
        lat1: gLat,
        lon1: gLon,
        lat2: sLat,
        lon2: sLon,
      )) {
        return true;
      }
    }

    return sanitizeName(match.location) ==
        sanitizeName(field['name']?.toString() ?? '');
  }

  // Cache invalidation methods (no-op - no caching to match old fast behavior)
  // Kept for API compatibility but doesn't do anything since we're not caching
  void invalidateAllCache() {
    // No-op: no cache in use to match old real-time behavior
  }

  void clearExpiredCache() {
    // No-op: no cache in use to match old real-time behavior
  }

  // Custom distinct transformer for match lists
  StreamTransformer<List<Match>, List<Match>> _distinctMatchesTransformer() {
    List<Match>? lastValue;
    return StreamTransformer<List<Match>, List<Match>>.fromHandlers(
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

        for (final matchId in prevMap.keys) {
          final prevMatch = prevMap[matchId]!;
          final nextMatch = nextMap[matchId];

          if (nextMatch == null) {
            NumberedLogger.d('🔄 Distinct: Match $matchId was removed');
            lastValue = next;
            sink.add(next);
            return;
          }

          // Check for meaningful changes (especially isActive for cancellations)
          if (prevMatch.isActive != nextMatch.isActive ||
              prevMatch.currentPlayers != nextMatch.currentPlayers ||
              prevMatch.players.length != nextMatch.players.length ||
              prevMatch.dateTime != nextMatch.dateTime ||
              prevMatch.location != nextMatch.location ||
              prevMatch.address != nextMatch.address ||
              prevMatch.maxPlayers != nextMatch.maxPlayers ||
              prevMatch.updatedAt != nextMatch.updatedAt) {
            NumberedLogger.d(
                '🔄 Distinct: Match $matchId changed - isActive: ${prevMatch.isActive}->${nextMatch.isActive}');
            lastValue = next;
            sink.add(next);
            return;
          }
        }

        // Check for new matches
        for (final matchId in nextMap.keys) {
          if (!prevMap.containsKey(matchId)) {
            NumberedLogger.d('🔄 Distinct: New match $matchId added');
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
