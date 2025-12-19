import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/matches/models/match.dart';
import 'package:move_young/services/calendar/calendar_service.dart';
import 'package:move_young/features/matches/services/match_provider.dart';

/// Service to sync calendar events when matches are updated or cancelled
class CalendarSyncService {
  /// Sync calendar event for a specific match
  /// This should be called when a match is updated or cancelled
  static Future<void> syncMatchCalendarEvent(Match match) async {
    try {
      // Check if match is in calendar
      final isInCalendar = await CalendarService.isMatchInCalendar(match.id);
      if (!isInCalendar) {
        // Match not in calendar, nothing to sync
        return;
      }

      // Check if match is cancelled
      if (!match.isActive) {
        // Match is cancelled, remove from calendar
        developer.log('Match ${match.id} is cancelled, removing from calendar',
            name: 'CalendarSyncService');
        await CalendarService.removeMatchFromCalendar(match.id);
        return;
      }

      // Match is active, update calendar event
      // Note: We always update to ensure calendar is in sync with latest match data
      developer.log('Syncing calendar event for match ${match.id}',
          name: 'CalendarSyncService');
      final success = await CalendarService.updateMatchInCalendar(match);
      if (success) {
        developer.log(
            'Calendar event updated successfully for match ${match.id}',
            name: 'CalendarSyncService');
      } else {
        developer.log('Failed to update calendar event for match ${match.id}',
            name: 'CalendarSyncService');
      }
    } catch (e, stackTrace) {
      developer.log('Error syncing calendar event for match ${match.id}: $e',
          name: 'CalendarSyncService', error: e, stackTrace: stackTrace);
    }
  }
}

/// Provider that watches matches and syncs calendar events
/// This provider automatically syncs calendar events when matches change
final calendarSyncProvider = Provider.autoDispose<void>((ref) {
  // Watch user's matches stream
  final myMatchesAsync = ref.watch(myMatchesProvider);

  myMatchesAsync.whenData((matches) async {
    // Get all matches in calendar
    final matchesInCalendar = await CalendarService.getAllMatchesInCalendar();

    if (matchesInCalendar.isEmpty) {
      return;
    }

    // Create a set of match IDs from user's matches for quick lookup
    final myMatchIds = matches.map((m) => m.id).toSet();
    final calendarMatchIds = matchesInCalendar.toSet();

    // Sync each match that's both in user's matches and in calendar
    for (final match in matches) {
      if (calendarMatchIds.contains(match.id)) {
        await CalendarSyncService.syncMatchCalendarEvent(match);
      }
    }

    // Clean up orphaned calendar events (matches in calendar but not in user's matches)
    // This handles cases where matches were cancelled/removed but calendar events weren't cleaned up
    final orphanedMatchIds = calendarMatchIds.difference(myMatchIds);
    if (orphanedMatchIds.isNotEmpty) {
      developer.log(
          'Found ${orphanedMatchIds.length} orphaned calendar events, removing...',
          name: 'CalendarSyncService');
      for (final matchId in orphanedMatchIds) {
        try {
          developer.log('Removing orphaned calendar event for match $matchId',
              name: 'CalendarSyncService');
          await CalendarService.removeMatchFromCalendar(matchId);
        } catch (e) {
          developer.log('Error removing orphaned calendar event $matchId: $e',
              name: 'CalendarSyncService', error: e);
        }
      }
    }
  });

  // Return void (provider doesn't need to return anything)
});
