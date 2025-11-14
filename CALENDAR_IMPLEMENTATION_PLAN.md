# Calendar Feature Implementation Plan

## Overview
This document outlines how to implement the calendar feature that allows users to add games to their device calendar.

## Quick Summary

**Goal**: Allow users to add games to their device calendar (Google Calendar, Apple Calendar, etc.)

**Approach**: 
1. Use `device_calendar` Flutter package (supports create, update, delete) - **RECOMMENDED**
   - OR use `add_2_calendar` for simpler implementation (no update/delete support)
2. Create a `CalendarService` class to handle calendar operations
3. Track calendar event IDs locally (SQLite/SharedPreferences)
4. Listen to game updates/cancellations and sync calendar events
5. Add "Add to Calendar" button in game detail screens
6. Handle permissions automatically (package handles this)
7. Provide user feedback (SnackBar on success/error)

**Key Challenge**: When organizer edits or cancels a game, calendar events need to be updated/deleted automatically.

**Solution**: Use `device_calendar` package which supports updating and deleting events, and track event IDs locally to maintain sync.

**Key Files to Modify**:
- `pubspec.yaml` - Add package dependency
- `android/app/src/main/AndroidManifest.xml` - Add calendar permissions
- `ios/Runner/Info.plist` - Add calendar permission description
- `lib/services/calendar/calendar_service.dart` - New service file
- `lib/db/calendar_events_db.dart` - New database table for tracking calendar events (optional)
- `assets/translations/en.json` - Add translation keys
- `assets/translations/nl.json` - Add translation keys
- `lib/screens/games/game_detail_screen.dart` - Add calendar button
- `lib/screens/games/games_my_screen.dart` - Add calendar button
- `lib/services/games/cloud_games_service_instance.dart` - Listen to game updates (optional enhancement)

**Estimated Time**: 
- Simple implementation (add only): 2-3 hours
- Full implementation (with sync): 4-6 hours (including testing)

## Important: Handling Game Updates and Cancellations

**⚠️ Critical Limitation**: The original `add_2_calendar` package does NOT support updating or deleting calendar events. Once an event is added, the app loses connection to it.

**Problem**: When an organizer edits or cancels a game:
- Calendar events become out of sync
- Users don't know the event changed
- Calendar events remain with old/incorrect information

**Solution Options**:

### Option 1: Use `device_calendar` Package (RECOMMENDED)
- **Pros**: Full CRUD support (create, read, update, delete)
- **Pros**: Can track event IDs and maintain sync
- **Pros**: Automatically update/delete events when games change
- **Cons**: More complex setup
- **Cons**: Requires more permissions
- **Best for**: Production app with automatic sync

### Option 2: Use `add_2_calendar` + Notification System
- **Pros**: Simpler implementation
- **Pros**: Less permissions required
- **Cons**: No automatic updates/deletes
- **Cons**: Requires manual user action
- **Best for**: MVP or simple implementation
- **Implementation**: Track which games user added to calendar, show notification when game changes, user manually updates calendar

### Option 3: Hybrid Approach
- Use `device_calendar` for automatic sync
- Fallback to `add_2_calendar` if permissions denied
- Show notifications when calendar events are updated/deleted

## Recommended Package

### Primary Option: `device_calendar` (RECOMMENDED for full sync)
- **Package**: `device_calendar` (supports full CRUD operations)
- **Pub.dev**: https://pub.dev/packages/device_calendar
- **Platform Support**: Android, iOS, Web (limited)
- **Features**: 
  - Create, read, update, delete calendar events
  - Get event IDs for tracking
  - Support for title, description, location, start/end time
  - Timezone handling
  - Alarm/reminder support
  - Recurring events support
  - Attendees support

### Alternative Option: `add_2_calendar` (Simple, no sync)
- **Package**: `add_2_calendar` (simpler, but no update/delete)
- **Pub.dev**: https://pub.dev/packages/add_2_calendar
- **Platform Support**: Android, iOS, Web
- **Features**: 
  - Add events to device calendar (only)
  - Support for title, description, location, start/end time
  - Timezone handling
  - Alarm/reminder support
- **Limitation**: Cannot update or delete events after creation
- **Best for**: MVP or when automatic sync is not required

## Implementation Steps

### 1. Add Package Dependency

**Option A: Using `device_calendar` (Recommended for full sync)**
Add to `pubspec.yaml`:
```yaml
dependencies:
  device_calendar: ^7.0.0  # Check for latest version
  sqflite: ^2.3.0  # For storing calendar event IDs (optional but recommended)
```

**Option B: Using `add_2_calendar` (Simple, no sync)**
Add to `pubspec.yaml`:
```yaml
dependencies:
  add_2_calendar: ^2.1.0  # Check for latest version
  shared_preferences: ^2.5.0  # For tracking which games were added (optional)
```

### 2. Platform Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`)
Add calendar permissions:
```xml
<uses-permission android:name="android.permission.READ_CALENDAR" />
<uses-permission android:name="android.permission.WRITE_CALENDAR" />
```

#### iOS (`ios/Runner/Info.plist`)
Add calendar usage description:
```xml
<key>NSCalendarsUsageDescription</key>
<string>We need access to your calendar to add game events so you don't miss them.</string>
```

### 3. Create Calendar Service

Create a new service file: `lib/services/calendar/calendar_service.dart`

**Option A: Using `device_calendar` (Recommended - supports sync)**

```dart
import 'dart:developer' as developer;
import 'package:device_calendar/device_calendar.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/db/calendar_events_db.dart'; // For tracking event IDs

class CalendarService {
  static DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();
  static CalendarEventsDb? _db;

  /// Initialize the calendar service
  static Future<void> initialize() async {
    _db = await CalendarEventsDb.instance();
  }

  /// Request calendar permissions
  static Future<bool> requestPermissions() async {
    try {
      final permissions = await _deviceCalendarPlugin.hasPermissions();
      if (permissions?.isGranted ?? false) {
        return true;
      }
      final result = await _deviceCalendarPlugin.requestPermissions();
      return result?.isGranted ?? false;
    } catch (e) {
      developer.log('Error requesting calendar permissions: $e',
          name: 'CalendarService');
      return false;
    }
  }

  /// Get default calendar
  static Future<Calendar?> _getDefaultCalendar() async {
    try {
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult?.isSuccess ?? false) {
        final calendars = calendarsResult!.data ?? [];
        // Find default calendar or first writable calendar
        return calendars.firstWhere(
          (cal) => cal.isDefault ?? false,
          orElse: () => calendars.firstWhere(
            (cal) => cal.isReadOnly == false,
            orElse: () => calendars.first,
          ),
        );
      }
      return null;
    } catch (e) {
      developer.log('Error getting default calendar: $e',
          name: 'CalendarService');
      return null;
    }
  }

  /// Add a game to the device calendar
  /// Returns event ID if successful, null otherwise
  static Future<String?> addGameToCalendar(Game game) async {
    try {
      // Request permissions
      final hasPermissions = await requestPermissions();
      if (!hasPermissions) {
        developer.log('Calendar permissions not granted',
            name: 'CalendarService');
        return null;
      }

      // Get default calendar
      final calendar = await _getDefaultCalendar();
      if (calendar == null) {
        developer.log('No calendar available', name: 'CalendarService');
        return null;
      }

      // Calculate end time (default: 1.5 hours after start)
      final endTime = game.dateTime.add(const Duration(hours: 1, minutes: 30));

      // Build location string
      String location = game.location;
      if (game.address != null && game.address!.isNotEmpty) {
        location = game.address!;
        if (game.location.isNotEmpty && game.location != game.address) {
          location = '${game.location}, ${game.address}';
        }
      }

      // Build description
      final descriptionParts = <String>[];
      if (game.description.isNotEmpty) {
        descriptionParts.add(game.description);
      }
      descriptionParts.add('Sport: ${game.sport.toUpperCase()}');
      descriptionParts.add('Players: ${game.currentPlayers}/${game.maxPlayers}');
      if (game.equipment != null && game.equipment!.isNotEmpty) {
        descriptionParts.add('Equipment: ${game.equipment}');
      }
      if (game.cost != null && game.cost! > 0) {
        descriptionParts.add('Cost: €${game.cost!.toStringAsFixed(2)}');
      }
      if (game.organizerName.isNotEmpty) {
        descriptionParts.add('Organized by: ${game.organizerName}');
      }
      descriptionParts.add('Game ID: ${game.id}');

      final description = descriptionParts.join('\n\n');

      // Create event
      final event = Event(calendar.id);
      event.title = '${game.sport.toUpperCase()} Game - ${game.location}';
      event.description = description;
      event.location = location;
      event.start = game.dateTime;
      event.end = endTime;
      event.reminders = [
        Reminder(
          minutes: 15, // 15 minutes before
        ),
      ];

      // Add to calendar
      final createEventResult = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      if (createEventResult?.isSuccess ?? false) {
        final eventId = createEventResult!.data;
        developer.log('Game ${game.id} added to calendar with event ID: $eventId',
            name: 'CalendarService');

        // Store event ID for tracking
        await _db?.insertCalendarEvent(game.id, eventId, calendar.id);

        return eventId;
      } else {
        developer.log('Failed to add game ${game.id} to calendar: ${createEventResult?.errors}',
            name: 'CalendarService');
        return null;
      }
    } catch (e, stackTrace) {
      developer.log('Error adding game to calendar: $e',
          name: 'CalendarService', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Update a calendar event when game is edited
  static Future<bool> updateGameInCalendar(Game game) async {
    try {
      // Get stored event ID
      final eventInfo = await _db?.getCalendarEvent(game.id);
      if (eventInfo == null) {
        developer.log('No calendar event found for game ${game.id}',
            name: 'CalendarService');
        return false;
      }

      // Get calendar
      final calendar = await _getDefaultCalendar();
      if (calendar == null) {
        return false;
      }

      // Get existing event
      final retrieveEventResult = await _deviceCalendarPlugin.retrieveEvent(
        eventInfo.calendarId,
        eventInfo.eventId,
      );
      if (retrieveEventResult?.isSuccess != true || retrieveEventResult?.data == null) {
        developer.log('Event not found in calendar: ${eventInfo.eventId}',
            name: 'CalendarService');
        // Event might have been deleted by user, remove from tracking
        await _db?.deleteCalendarEvent(game.id);
        return false;
      }

      final event = retrieveEventResult!.data!;

      // Update event details
      final endTime = game.dateTime.add(const Duration(hours: 1, minutes: 30));
      String location = game.address ?? game.location;
      if (game.address != null && game.location != game.address) {
        location = '${game.location}, ${game.address}';
      }

      // Build description (same as addGameToCalendar)
      final descriptionParts = <String>[];
      if (game.description.isNotEmpty) {
        descriptionParts.add(game.description);
      }
      descriptionParts.add('Sport: ${game.sport.toUpperCase()}');
      descriptionParts.add('Players: ${game.currentPlayers}/${game.maxPlayers}');
      if (game.equipment != null && game.equipment!.isNotEmpty) {
        descriptionParts.add('Equipment: ${game.equipment}');
      }
      if (game.cost != null && game.cost! > 0) {
        descriptionParts.add('Cost: €${game.cost!.toStringAsFixed(2)}');
      }
      if (game.organizerName.isNotEmpty) {
        descriptionParts.add('Organized by: ${game.organizerName}');
      }
      descriptionParts.add('Game ID: ${game.id}');

      event.title = '${game.sport.toUpperCase()} Game - ${game.location}';
      event.description = descriptionParts.join('\n\n');
      event.location = location;
      event.start = game.dateTime;
      event.end = endTime;

      // Update event
      final updateResult = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      if (updateResult?.isSuccess ?? false) {
        developer.log('Game ${game.id} calendar event updated successfully',
            name: 'CalendarService');
        return true;
      } else {
        developer.log('Failed to update calendar event: ${updateResult?.errors}',
            name: 'CalendarService');
        return false;
      }
    } catch (e, stackTrace) {
      developer.log('Error updating game in calendar: $e',
          name: 'CalendarService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Remove calendar event when game is cancelled
  static Future<bool> removeGameFromCalendar(String gameId) async {
    try {
      // Get stored event ID
      final eventInfo = await _db?.getCalendarEvent(gameId);
      if (eventInfo == null) {
        developer.log('No calendar event found for game $gameId',
            name: 'CalendarService');
        return false;
      }

      // Delete event from calendar
      final deleteResult = await _deviceCalendarPlugin.deleteEvent(
        eventInfo.calendarId,
        eventInfo.eventId,
      );

      if (deleteResult?.isSuccess ?? false) {
        developer.log('Game $gameId calendar event deleted successfully',
            name: 'CalendarService');
        // Remove from tracking
        await _db?.deleteCalendarEvent(gameId);
        return true;
      } else {
        developer.log('Failed to delete calendar event: ${deleteResult?.errors}',
            name: 'CalendarService');
        // Remove from tracking anyway (event might have been deleted by user)
        await _db?.deleteCalendarEvent(gameId);
        return false;
      }
    } catch (e, stackTrace) {
      developer.log('Error removing game from calendar: $e',
          name: 'CalendarService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Check if game is added to calendar
  static Future<bool> isGameInCalendar(String gameId) async {
    final eventInfo = await _db?.getCalendarEvent(gameId);
    return eventInfo != null;
  }
}
```

**Option B: Using `add_2_calendar` (Simple - no sync support)**

```dart
import 'dart:developer' as developer;
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:move_young/models/core/game.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CalendarService {
  static const String _prefsKey = 'calendar_games';
  static SharedPreferences? _prefs;

  /// Initialize the calendar service
  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Add a game to the device calendar
  /// Returns true if successful, false otherwise
  static Future<bool> addGameToCalendar(Game game) async {
    try {
      // Calculate end time (default: 1.5 hours after start)
      final endTime = game.dateTime.add(const Duration(hours: 1, minutes: 30));

      // Build location string
      String location = game.address ?? game.location;
      if (game.address != null && game.location != game.address) {
        location = '${game.location}, ${game.address}';
      }

      // Build description
      final descriptionParts = <String>[];
      if (game.description.isNotEmpty) {
        descriptionParts.add(game.description);
      }
      descriptionParts.add('Sport: ${game.sport.toUpperCase()}');
      descriptionParts.add('Players: ${game.currentPlayers}/${game.maxPlayers}');
      if (game.equipment != null && game.equipment!.isNotEmpty) {
        descriptionParts.add('Equipment: ${game.equipment}');
      }
      if (game.cost != null && game.cost! > 0) {
        descriptionParts.add('Cost: €${game.cost!.toStringAsFixed(2)}');
      }
      if (game.organizerName.isNotEmpty) {
        descriptionParts.add('Organized by: ${game.organizerName}');
      }
      descriptionParts.add('Game ID: ${game.id}');

      final description = descriptionParts.join('\n\n');

      // Create event
      final event = Event(
        title: '${game.sport.toUpperCase()} Game - ${game.location}',
        description: description,
        location: location,
        startDate: game.dateTime,
        endDate: endTime,
        iosParams: IOSParams(
          reminder: const Duration(minutes: 15),
        ),
        androidParams: AndroidParams(
          emailInvites: [],
        ),
      );

      // Add to calendar
      final result = await Add2Calendar.addEvent2Cal(event);

      if (result) {
        developer.log('Game ${game.id} added to calendar successfully',
            name: 'CalendarService');
        // Track that this game was added (for notification purposes)
        await _trackGameAdded(game.id);
        return true;
      } else {
        developer.log('Failed to add game ${game.id} to calendar',
            name: 'CalendarService');
        return false;
      }
    } catch (e, stackTrace) {
      developer.log('Error adding game to calendar: $e',
          name: 'CalendarService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Track that a game was added to calendar
  static Future<void> _trackGameAdded(String gameId) async {
    final gameIds = await getGamesInCalendar();
    gameIds.add(gameId);
    await _prefs?.setStringList(_prefsKey, gameIds.toList());
  }

  /// Get list of game IDs that were added to calendar
  static Future<Set<String>> getGamesInCalendar() async {
    final gameIds = _prefs?.getStringList(_prefsKey) ?? [];
    return gameIds.toSet();
  }

  /// Check if game is added to calendar
  static Future<bool> isGameInCalendar(String gameId) async {
    final gameIds = await getGamesInCalendar();
    return gameIds.contains(gameId);
  }

  /// Remove game from tracking (when user manually deletes from calendar)
  static Future<void> removeGameFromTracking(String gameId) async {
    final gameIds = await getGamesInCalendar();
    gameIds.remove(gameId);
    await _prefs?.setStringList(_prefsKey, gameIds.toList());
  }

  // Note: updateGameInCalendar and removeGameFromCalendar are NOT available
  // with add_2_calendar package. User must manually update/delete calendar events.
}
```

### 4. Add Translation Keys

Add to `assets/translations/en.json`:
```json
"add_to_calendar": "Add to Calendar",
"calendar_event_added": "Game added to calendar",
"calendar_event_added_error": "Failed to add game to calendar",
"calendar_permission_required": "Calendar permission is required to add events",
```

Add to `assets/translations/nl.json`:
```json
"add_to_calendar": "Toevoegen aan kalender",
"calendar_event_added": "Spel toegevoegd aan kalender",
"calendar_event_added_error": "Kon spel niet toevoegen aan kalender",
"calendar_permission_required": "Kalendertoegang is vereist om evenementen toe te voegen",
```

### 5. Update Game Detail Screen

Update `lib/screens/games/game_detail_screen.dart` to include an "Add to Calendar" button:

```dart
import 'package:move_young/services/calendar/calendar_service.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

// Convert to ConsumerWidget to access haptics
class GameDetailScreen extends ConsumerWidget {
  final Game game;
  const GameDetailScreen({super.key, required this.game});

  // ... existing methods ...

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sportColor = _colorForSport(game.sport);
    return Scaffold(
      appBar: AppBar(
        title: Text(game.sport.toUpperCase()),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          // Add calendar button in app bar
          IconButton(
            tooltip: 'add_to_calendar'.tr(),
            icon: const Icon(Icons.event),
            onPressed: () async {
              ref.read(hapticsActionsProvider)?.selectionClick();
              final success = await CalendarService.addGameToCalendar(game);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success 
                        ? 'calendar_event_added'.tr() 
                        : 'calendar_event_added_error'.tr(),
                    ),
                    backgroundColor: success ? AppColors.green : AppColors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
      // ... rest of existing UI ...
    );
  }
}
```

Alternatively, add action buttons below description (similar to Agenda screen):

```dart
// Add after description in body
if (game.description.isNotEmpty)
  Text(game.description, style: AppTextStyles.body),
const SizedBox(height: AppHeights.big),
// Action buttons row
Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    IconButton(
      tooltip: 'add_to_calendar'.tr(),
      icon: const Icon(Icons.event),
      onPressed: () async {
        ref.read(hapticsActionsProvider)?.selectionClick();
        final success = await CalendarService.addGameToCalendar(game);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success 
                  ? 'calendar_event_added'.tr() 
                  : 'calendar_event_added_error'.tr(),
              ),
              backgroundColor: success ? AppColors.green : AppColors.red,
            ),
          );
        }
      },
    ),
    // Add other action buttons (directions, share) if needed
  ],
),
```

### 6. Update Games My Screen

Update `lib/screens/games/games_my_screen.dart`:

1. **Add import at top:**
```dart
import 'package:move_young/services/calendar/calendar_service.dart';
```

2. **Add method following existing pattern (around line 461):**
```dart
  Future<void> _addToCalendar(Game game) async {
    try {
      ref.read(hapticsActionsProvider)?.selectionClick();
      final success = await CalendarService.addGameToCalendar(game);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success 
                ? 'calendar_event_added'.tr() 
                : 'calendar_event_added_error'.tr(),
            ),
            backgroundColor: success ? AppColors.green : AppColors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error adding game to calendar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('calendar_event_added_error'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }
```

3. **Add calendar button in action row (around line 1178, after directions button):**
```dart
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _addToCalendar(game),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 6),
                                textStyle: AppTextStyles.small,
                                iconSize: 16,
                                foregroundColor: AppColors.primary,
                                side:
                                    const BorderSide(color: AppColors.primary),
                              ),
                              icon: const Icon(Icons.event, size: 16),
                              label: Text('add_to_calendar'.tr()),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _shareGameLink(game),
                              // ... existing share button code ...
                            ),
                          ),
```

**Note**: If space is limited, you might want to replace the "Share" button with calendar, or add calendar as an icon button instead of a full button.

### 7. Create Calendar Events Database (For Option A: device_calendar)

Create a new database file: `lib/db/calendar_events_db.dart`

```dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class CalendarEventInfo {
  final String gameId;
  final String eventId;
  final String calendarId;

  CalendarEventInfo({
    required this.gameId,
    required this.eventId,
    required this.calendarId,
  });

  Map<String, dynamic> toMap() {
    return {
      'gameId': gameId,
      'eventId': eventId,
      'calendarId': calendarId,
    };
  }

  factory CalendarEventInfo.fromMap(Map<String, dynamic> map) {
    return CalendarEventInfo(
      gameId: map['gameId'] as String,
      eventId: map['eventId'] as String,
      calendarId: map['calendarId'] as String,
    );
  }
}

class CalendarEventsDb {
  static Database? _database;
  static CalendarEventsDb? _instance;

  CalendarEventsDb._();
  
  static Future<CalendarEventsDb> instance() async {
    if (_instance == null) {
      _instance = CalendarEventsDb._();
      await _instance!._initDatabase();
    }
    return _instance!;
  }

  Future<void> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'calendar_events.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE calendar_events (
            gameId TEXT PRIMARY KEY,
            eventId TEXT NOT NULL,
            calendarId TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> insertCalendarEvent(String gameId, String eventId, String calendarId) async {
    await _database?.insert(
      'calendar_events',
      CalendarEventInfo(
        gameId: gameId,
        eventId: eventId,
        calendarId: calendarId,
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<CalendarEventInfo?> getCalendarEvent(String gameId) async {
    final maps = await _database?.query(
      'calendar_events',
      where: 'gameId = ?',
      whereArgs: [gameId],
    );
    if (maps != null && maps.isNotEmpty) {
      return CalendarEventInfo.fromMap(maps.first);
    }
    return null;
  }

  Future<void> deleteCalendarEvent(String gameId) async {
    await _database?.delete(
      'calendar_events',
      where: 'gameId = ?',
      whereArgs: [gameId],
    );
  }

  Future<List<String>> getAllGameIds() async {
    final maps = await _database?.query('calendar_events');
    if (maps != null) {
      return maps.map((map) => map['gameId'] as String).toList();
    }
    return [];
  }
}
```

### 8. Sync Calendar Events When Games Change (For Option A: device_calendar)

Create a listener service: `lib/services/calendar/calendar_sync_service.dart`

```dart
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/services/calendar/calendar_service.dart';
import 'package:move_young/services/games/games_provider.dart';

/// Service to sync calendar events when games are updated or cancelled
class CalendarSyncService {
  /// Listen to game updates and sync calendar events
  /// This should be called when user opens the app or when games are updated
  static Future<void> syncCalendarEventsForGame(Game game, WidgetRef ref) async {
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

      // Game is active, update calendar event if details changed
      // Note: This is a simple implementation. You might want to check
      // if the game was actually edited (check updatedAt or lastOrganizerEditAt)
      developer.log('Syncing calendar event for game ${game.id}',
          name: 'CalendarSyncService');
      await CalendarService.updateGameInCalendar(game);
    } catch (e, stackTrace) {
      developer.log('Error syncing calendar event: $e',
          name: 'CalendarSyncService', error: e, stackTrace: stackTrace);
    }
  }

  /// Sync all calendar events for user's games
  static Future<void> syncAllCalendarEvents(WidgetRef ref) async {
    try {
      // Get all games that user has added to calendar
      final gamesInCalendar = await CalendarService.getAllGamesInCalendar();
      
      for (final gameId in gamesInCalendar) {
        // Get game from provider
        final gameAsync = ref.read(gameByIdProvider(gameId));
        gameAsync.whenData((game) async {
          if (game != null) {
            await syncCalendarEventsForGame(game, ref);
          }
        });
      }
    } catch (e, stackTrace) {
      developer.log('Error syncing all calendar events: $e',
          name: 'CalendarSyncService', error: e, stackTrace: stackTrace);
    }
  }
}
```

**Alternative: Listen to game streams directly**

Update `lib/services/games/games_provider.dart` or create a game stream listener:

```dart
// In games_provider.dart or a new calendar_sync_provider.dart
final calendarSyncProvider = StreamProvider<void>((ref) async* {
  // Listen to user's games stream
  final joinedGamesAsync = ref.watch(joinedGamesProvider);
  
  await for (final games in joinedGamesAsync.stream) {
    // Sync calendar events for each game
    for (final game in games) {
      await CalendarSyncService.syncCalendarEventsForGame(game, ref);
    }
  }
});
```

**Note**: You'll need to add `getAllGamesInCalendar()` method to `CalendarService`:

```dart
/// Get all game IDs that are in calendar
static Future<List<String>> getAllGamesInCalendar() async {
  return await _db?.getAllGameIds() ?? [];
}
```

### 9. Handle Permissions (Optional Enhancement)

The `add_2_calendar` package handles permissions automatically:
- **iOS**: Permissions are requested automatically when adding events (via Info.plist description)
- **Android**: Permissions are requested automatically when needed (API 23+)

If you want explicit permission handling (optional), you can check permissions first:

```dart
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

static Future<bool> requestCalendarPermission() async {
  if (Platform.isAndroid) {
    final status = await Permission.calendarFullAccess.status;
    if (status.isDenied) {
      final result = await Permission.calendarFullAccess.request();
      return result.isGranted;
    }
    return status.isGranted;
  }
  // iOS handles permissions automatically via Info.plist
  // The add_2_calendar package will request permission when needed
  return true;
}
```

**Note**: Android 14+ (API 33+) requires `READ_CALENDAR` and `WRITE_CALENDAR` permissions. The package should handle this automatically, but you may need to update your Android manifest for newer Android versions.

## Game Data Mapping

| Game Field | Calendar Event Field | Notes |
|------------|---------------------|-------|
| `sport` + `location` | `title` | Format: "SOCCER Game - Field Name" |
| `dateTime` | `startDate` | Already in DateTime format |
| `dateTime + duration` | `endDate` | Default: 1.5 hours after start |
| `location` + `address` | `location` | Combine if both available |
| `description` + metadata | `description` | Include sport, players, equipment, cost, organizer |
| - | `reminder` | 15 minutes before (configurable) |

## UI Placement Options

### Option 1: Action Button Row (Recommended)
Add alongside existing "Directions" and "Share" buttons in:
- `GamesMyScreen` (for user's games)
- `GamesJoinScreen` (for browsable games)
- `GameDetailScreen` (detailed view)

### Option 2: Icon Button
Add as an icon button in the app bar or action row (similar to favorite/share in Agenda screen)

### Option 3: Menu Item
Add to a context menu or overflow menu (less discoverable)

## Error Handling

Handle common errors:
- Permission denied: Show message to user
- Calendar not available: Show appropriate message
- Network issues: Not applicable (local calendar)
- Invalid date/time: Validate before adding

## Testing Checklist

- [ ] Add game to calendar on Android
- [ ] Add game to calendar on iOS
- [ ] Verify event appears in device calendar app
- [ ] Check event details (title, location, description, time)
- [ ] Test with games that have addresses
- [ ] Test with games that don't have addresses
- [ ] Test permission handling
- [ ] Test error scenarios
- [ ] Verify translations (EN/NL)

## Syncing Calendar Events When Games Change

### For Option A: device_calendar (Automatic Sync)

1. **Track Calendar Events**: Store event IDs in local database when games are added
2. **Listen to Game Updates**: Watch game streams for changes
3. **Update Calendar Events**: When game is edited, update corresponding calendar event
4. **Delete Calendar Events**: When game is cancelled, delete corresponding calendar event
5. **Handle Edge Cases**: 
   - User manually deletes calendar event (remove from tracking)
   - Calendar permissions revoked (handle gracefully)
   - Event not found in calendar (remove from tracking)

### For Option B: add_2_calendar (Manual Sync)

1. **Track Games Added**: Store game IDs in SharedPreferences when added to calendar
2. **Show Notifications**: When game is edited/cancelled, show notification to user
3. **User Action Required**: User must manually update/delete calendar event
4. **Provide Instructions**: Show message explaining how to update calendar event

### Implementation Strategy

**Option A (Recommended)**: Full automatic sync
- Use `device_calendar` package
- Store event IDs in local database
- Listen to game update/cancellation streams
- Automatically update/delete calendar events
- Show notification when calendar event is updated/deleted

**Option B (Simple)**: Notification-based
- Use `add_2_calendar` package
- Track which games were added
- When game changes, show notification
- User manually updates calendar event
- Less complex, but requires user action

## Future Enhancements

1. **Customizable Duration**: Let users set game duration
2. **Reminder Options**: Allow users to choose reminder time (5min, 15min, 1hr before)
3. **Recurring Games**: Support for recurring games (weekly, etc.)
4. **Sync Updates**: ✅ Update calendar event if game details change (Option A only)
5. **Remove from Calendar**: ✅ Allow users to remove games from calendar (Option A only)
6. **Multiple Calendars**: Let users choose which calendar to add to
7. **Player Invites**: Add all players to calendar event (requires email addresses)
8. **Batch Operations**: Sync multiple calendar events at once
9. **Offline Support**: Queue calendar sync operations when offline
10. **Conflict Resolution**: Handle cases where calendar event was manually edited

## Notes

- The `add_2_calendar` package handles platform-specific implementations automatically
- iOS permissions are requested automatically when the feature is used (via Info.plist description)
- Android permissions are requested automatically at runtime (API 23+) when needed
- The package returns a boolean indicating success/failure
- Events are added to the default calendar on the device
- The package uses native calendar APIs (EventKit on iOS, Calendar Provider on Android)
- Events sync automatically with the user's calendar app (Google Calendar, Apple Calendar, etc.)

## Package Details

### `add_2_calendar` Package
- **Latest Version**: Check pub.dev for latest (likely ~2.1.0+)
- **Platform Support**: Android, iOS, Web (limited)
- **Dependencies**: None (uses platform channels)
- **License**: MIT

### Alternative Packages
- `calendar_event_linker`: Alternative package with similar functionality
- `table_calendar`: For displaying calendar UI (not for adding events)

## Implementation Checklist

### Basic Implementation (Add Only)
- [ ] Add calendar package to `pubspec.yaml` (choose Option A or B)
- [ ] Add Android permissions to `AndroidManifest.xml`
- [ ] Add iOS permission description to `Info.plist`
- [ ] Create `CalendarService` class
- [ ] Add translation keys (EN/NL)
- [ ] Update `GameDetailScreen` with calendar button
- [ ] Update `GamesMyScreen` with calendar button
- [ ] Test on Android device
- [ ] Test on iOS device
- [ ] Verify event appears in device calendar app
- [ ] Test error handling (permission denied, etc.)
- [ ] Verify translations

### Full Implementation (With Sync) - Option A only
- [ ] Create `CalendarEventsDb` database class
- [ ] Update `CalendarService` to store event IDs
- [ ] Add `updateGameInCalendar()` method
- [ ] Add `removeGameFromCalendar()` method
- [ ] Create `CalendarSyncService` to listen to game updates
- [ ] Integrate sync service with game streams
- [ ] Test calendar event updates when game is edited
- [ ] Test calendar event deletion when game is cancelled
- [ ] Handle edge cases (event not found, permissions revoked, etc.)
- [ ] Test notification when calendar event is updated/deleted
- [ ] Verify sync works when app is reopened

