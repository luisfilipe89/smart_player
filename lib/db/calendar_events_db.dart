import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:developer' as developer;

class CalendarEventInfo {
  final String matchId;
  final String eventId;
  final String calendarId;

  CalendarEventInfo({
    required this.matchId,
    required this.eventId,
    required this.calendarId,
  });

  Map<String, dynamic> toMap() {
    return {
      'matchId': matchId,
      'eventId': eventId,
      'calendarId': calendarId,
    };
  }

  factory CalendarEventInfo.fromMap(Map<String, dynamic> map) {
    return CalendarEventInfo(
      matchId: map['matchId'] as String,
      eventId: map['eventId'] as String,
      calendarId: map['calendarId'] as String,
    );
  }
}

class CalendarEventsDb {
  static Database? _database;
  static CalendarEventsDb? _instance;

  CalendarEventsDb._();

  /// Get singleton instance of CalendarEventsDb
  static Future<CalendarEventsDb> instance() async {
    if (_instance == null) {
      _instance = CalendarEventsDb._();
      await _instance!._initDatabase();
    }
    return _instance!;
  }

  Future<void> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'calendar_events.db');

      _database = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE calendar_events (
              matchId TEXT PRIMARY KEY,
              eventId TEXT NOT NULL,
              calendarId TEXT NOT NULL
            )
          ''');
          // Create index on matchId for faster queries (matchId is already PRIMARY KEY, but explicit index helps)
          await db.execute('''
            CREATE INDEX IF NOT EXISTS idx_matchId ON calendar_events(matchId)
          ''');
          developer.log('Calendar events table created',
              name: 'CalendarEventsDb');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // Add index for existing databases
            await db.execute('''
              CREATE INDEX IF NOT EXISTS idx_matchId ON calendar_events(matchId)
            ''');
            developer.log('Calendar events database upgraded to version 2',
                name: 'CalendarEventsDb');
          }
        },
      );
      developer.log('Calendar events database initialized',
          name: 'CalendarEventsDb');
    } catch (e, stackTrace) {
      developer.log('Error initializing calendar events database: $e',
          name: 'CalendarEventsDb', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Insert or update a calendar event
  /// Returns true if successful, false otherwise
  Future<bool> insertCalendarEvent(
      String matchId, String eventId, String calendarId) async {
    if (_database == null) {
      developer.log('Database not initialized', name: 'CalendarEventsDb');
      return false;
    }

    try {
      await _database!.insert(
        'calendar_events',
        CalendarEventInfo(
          matchId: matchId,
          eventId: eventId,
          calendarId: calendarId,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      developer.log('Calendar event inserted: matchId=$matchId, eventId=$eventId',
          name: 'CalendarEventsDb');
      return true;
    } catch (e, stackTrace) {
      developer.log('Error inserting calendar event: $e',
          name: 'CalendarEventsDb', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get calendar event info for a match
  /// Returns null if not found or on error
  Future<CalendarEventInfo?> getCalendarEvent(String matchId) async {
    if (_database == null) {
      developer.log('Database not initialized', name: 'CalendarEventsDb');
      return null;
    }

    try {
      final maps = await _database!.query(
        'calendar_events',
        where: 'matchId = ?',
        whereArgs: [matchId],
      );
      if (maps.isNotEmpty) {
        return CalendarEventInfo.fromMap(maps.first);
      }
      return null;
    } catch (e, stackTrace) {
      developer.log('Error getting calendar event: $e',
          name: 'CalendarEventsDb', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Delete a calendar event
  /// Returns true if successful, false otherwise
  Future<bool> deleteCalendarEvent(String matchId) async {
    if (_database == null) {
      developer.log('Database not initialized', name: 'CalendarEventsDb');
      return false;
    }

    try {
      final count = await _database!.delete(
        'calendar_events',
        where: 'matchId = ?',
        whereArgs: [matchId],
      );
      if (count > 0) {
        developer.log('Calendar event deleted: matchId=$matchId',
            name: 'CalendarEventsDb');
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      developer.log('Error deleting calendar event: $e',
          name: 'CalendarEventsDb', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get all match IDs that have calendar events
  /// Returns empty list on error
  Future<List<String>> getAllMatchIds() async {
    if (_database == null) {
      developer.log('Database not initialized', name: 'CalendarEventsDb');
      return [];
    }

    try {
      final maps = await _database!.query('calendar_events');
      final matchIds = maps.map((map) => map['matchId'] as String).toList();
      developer.log('Retrieved ${matchIds.length} calendar events',
          name: 'CalendarEventsDb');
      return matchIds;
    } catch (e, stackTrace) {
      developer.log('Error getting all match IDs: $e',
          name: 'CalendarEventsDb', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Get all calendar event info
  /// Returns empty list on error
  Future<List<CalendarEventInfo>> getAllCalendarEvents() async {
    if (_database == null) {
      developer.log('Database not initialized', name: 'CalendarEventsDb');
      return [];
    }

    try {
      final maps = await _database!.query('calendar_events');
      final events = maps.map((map) => CalendarEventInfo.fromMap(map)).toList();
      return events;
    } catch (e, stackTrace) {
      developer.log('Error getting all calendar events: $e',
          name: 'CalendarEventsDb', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Close the database connection
  /// Note: This will reset the singleton instance
  Future<void> close() async {
    try {
      await _database?.close();
      _instance = null;
      _database = null;
      developer.log('Calendar events database closed',
          name: 'CalendarEventsDb');
    } catch (e, stackTrace) {
      developer.log('Error closing calendar events database: $e',
          name: 'CalendarEventsDb', error: e, stackTrace: stackTrace);
      // Reset instance even if close fails
      _instance = null;
      _database = null;
    }
  }
}
