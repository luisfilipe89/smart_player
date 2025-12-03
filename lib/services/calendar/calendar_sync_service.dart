import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/games/models/game.dart';
import 'package:move_young/services/calendar/calendar_service.dart';
import 'package:move_young/features/games/services/games_provider.dart';

/// Service to sync calendar events when games are updated or cancelled
class CalendarSyncService {
  /// Sync calendar event for a specific game
  /// This should be called when a game is updated or cancelled
  static Future<void> syncGameCalendarEvent(Game game) async {
    try {
      // Check if game is in calendar
      final isInCalendar = await CalendarService.isGameInCalendar(game.id);
      if (!isInCalendar) {
        // Game not in calendar, nothing to sync
        return;
      }

      // Check if game is cancelled
      if (!game.isActive) {
        // Game is cancelled, remove from calendar
        developer.log('Game ${game.id} is cancelled, removing from calendar',
            name: 'CalendarSyncService');
        await CalendarService.removeGameFromCalendar(game.id);
        return;
      }

      // Game is active, update calendar event
      // Note: We always update to ensure calendar is in sync with latest game data
      developer.log('Syncing calendar event for game ${game.id}',
          name: 'CalendarSyncService');
      final success = await CalendarService.updateGameInCalendar(game);
      if (success) {
        developer.log('Calendar event updated successfully for game ${game.id}',
            name: 'CalendarSyncService');
      } else {
        developer.log('Failed to update calendar event for game ${game.id}',
            name: 'CalendarSyncService');
      }
    } catch (e, stackTrace) {
      developer.log('Error syncing calendar event for game ${game.id}: $e',
          name: 'CalendarSyncService', error: e, stackTrace: stackTrace);
    }
  }
}

/// Provider that watches games and syncs calendar events
/// This provider automatically syncs calendar events when games change
final calendarSyncProvider = Provider.autoDispose<void>((ref) {
  // Watch user's games stream
  final myGamesAsync = ref.watch(myGamesProvider);

  myGamesAsync.whenData((games) async {
    // Get all games in calendar
    final gamesInCalendar = await CalendarService.getAllGamesInCalendar();

    if (gamesInCalendar.isEmpty) {
      return;
    }

    // Create a set of game IDs from user's games for quick lookup
    final myGameIds = games.map((g) => g.id).toSet();
    final calendarGameIds = gamesInCalendar.toSet();

    // Sync each game that's both in user's games and in calendar
    for (final game in games) {
      if (calendarGameIds.contains(game.id)) {
        await CalendarSyncService.syncGameCalendarEvent(game);
      }
    }

    // Clean up orphaned calendar events (games in calendar but not in user's games)
    // This handles cases where games were cancelled/removed but calendar events weren't cleaned up
    final orphanedGameIds = calendarGameIds.difference(myGameIds);
    if (orphanedGameIds.isNotEmpty) {
      developer.log(
          'Found ${orphanedGameIds.length} orphaned calendar events, removing...',
          name: 'CalendarSyncService');
      for (final gameId in orphanedGameIds) {
        try {
          developer.log('Removing orphaned calendar event for game $gameId',
              name: 'CalendarSyncService');
          await CalendarService.removeGameFromCalendar(gameId);
        } catch (e) {
          developer.log('Error removing orphaned calendar event $gameId: $e',
              name: 'CalendarSyncService', error: e);
        }
      }
    }
  });

  // Return void (provider doesn't need to return anything)
});
