import 'dart:developer' as developer;
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:move_young/features/matches/models/match.dart';
import 'package:move_young/features/agenda/models/event_model.dart' as agenda;
import 'package:move_young/db/calendar_events_db.dart';

class CalendarService {
  static final DeviceCalendarPlugin _deviceCalendarPlugin =
      DeviceCalendarPlugin();
  static CalendarEventsDb? _db;
  static bool _timezoneInitialized = false;

  /// Initialize the calendar service
  static Future<void> initialize() async {
    try {
      _db = await CalendarEventsDb.instance();

      // Initialize timezone database for device_calendar v4 (requires TZDateTime)
      if (!_timezoneInitialized) {
        try {
          tz_data.initializeTimeZones();
          tz.setLocalLocation(
              tz.getLocation('Europe/Amsterdam')); // Default location
          _timezoneInitialized = true;
          developer.log('Timezone database initialized',
              name: 'CalendarService');
        } catch (e) {
          developer.log('Error initializing timezone database: $e',
              name: 'CalendarService', error: e);
          // Continue anyway - UTC fallback will be used
        }
      }

      developer.log('CalendarService initialized', name: 'CalendarService');
    } catch (e) {
      developer.log('Error initializing CalendarService: $e',
          name: 'CalendarService', error: e);
    }
  }

  /// Request calendar permissions
  static Future<bool> requestPermissions() async {
    try {
      final permissionsResult = await _deviceCalendarPlugin.hasPermissions();
      if (permissionsResult.isSuccess && permissionsResult.data == true) {
        return true;
      }
      final result = await _deviceCalendarPlugin.requestPermissions();
      return result.isSuccess && result.data == true;
    } catch (e) {
      developer.log('Error requesting calendar permissions: $e',
          name: 'CalendarService', error: e);
      return false;
    }
  }

  /// Get default calendar
  static Future<Calendar?> _getDefaultCalendar() async {
    try {
      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (calendarsResult.isSuccess && calendarsResult.data != null) {
        final calendars = calendarsResult.data!;
        if (calendars.isEmpty) {
          developer.log('No calendars available', name: 'CalendarService');
          return null;
        }
        // Find default calendar or first writable calendar
        try {
          return calendars.firstWhere(
            (cal) => cal.isDefault == true,
          );
        } catch (_) {
          // No default calendar, find first writable
          try {
            return calendars.firstWhere(
              (cal) => cal.isReadOnly == false,
            );
          } catch (_) {
            // Fallback to first calendar
            return calendars.first;
          }
        }
      }
      return null;
    } catch (e) {
      developer.log('Error getting default calendar: $e',
          name: 'CalendarService', error: e);
      return null;
    }
  }

  /// Build location string from match
  static String _buildLocation(Match match) {
    String location = match.location;
    if (match.address != null && match.address!.isNotEmpty) {
      location = match.address!;
      if (match.location.isNotEmpty && match.location != match.address) {
        location = '${match.location}, ${match.address}';
      }
    }
    return location;
  }

  /// Build description from match
  static String _buildDescription(Match match) {
    final descriptionParts = <String>[];

    // Add match description if available
    if (match.description.isNotEmpty) {
      descriptionParts.add(match.description);
    }

    // Add metadata
    descriptionParts.add('Sport: ${match.sport.toUpperCase()}');
    descriptionParts
        .add('Players: ${match.currentPlayers}/${match.maxPlayers}');

    // Add optional fields
    if (match.equipment != null && match.equipment!.isNotEmpty) {
      descriptionParts.add('Equipment: ${match.equipment}');
    }
    if (match.cost != null && match.cost! > 0) {
      descriptionParts.add('Cost: €${match.cost!.toStringAsFixed(2)}');
    }
    if (match.organizerName.isNotEmpty) {
      descriptionParts.add('Organized by: ${match.organizerName}');
    }
    descriptionParts.add('Match ID: ${match.id}');

    return descriptionParts.join('\n\n');
  }

  /// Add a match to the device calendar
  /// Returns event ID if successful, null otherwise
  static Future<String?> addMatchToCalendar(Match match) async {
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
      final endTime = match.dateTime.add(const Duration(hours: 1, minutes: 30));

      // Build location and description
      final location = _buildLocation(match);
      final description = _buildDescription(match);

      // Convert DateTime to TZDateTime (device_calendar v4 requires TZDateTime)
      // Use local timezone or UTC as fallback
      tz.TZDateTime startTZ;
      tz.TZDateTime endTZ;
      try {
        final local = tz.local;
        startTZ = tz.TZDateTime.from(match.dateTime, local);
        endTZ = tz.TZDateTime.from(endTime, local);
      } catch (e) {
        // Fallback to UTC if local timezone not available
        final utc = tz.UTC;
        startTZ = tz.TZDateTime.from(match.dateTime, utc);
        endTZ = tz.TZDateTime.from(endTime, utc);
      }

      // Create event
      final event = Event(calendar.id);
      event.title = '${match.sport.toUpperCase()} Match - ${match.location}';
      event.description = description;
      event.location = location;
      event.start = startTZ;
      event.end = endTZ;
      event.reminders = [
        Reminder(
          minutes: 15, // 15 minutes before
        ),
      ];

      // Add to calendar
      final createEventResult =
          await _deviceCalendarPlugin.createOrUpdateEvent(event);
      if (createEventResult != null &&
          createEventResult.isSuccess &&
          createEventResult.data != null) {
        final eventId = createEventResult.data!;
        if (eventId.isEmpty) {
          developer.log('Event ID is empty for match ${match.id}',
              name: 'CalendarService');
          return null;
        }
        developer.log(
            'Match ${match.id} added to calendar with event ID: $eventId',
            name: 'CalendarService');

        // Store event ID for tracking
        try {
          final calendarId = calendar.id;
          if (calendarId != null && calendarId.isNotEmpty) {
            final success =
                await _db?.insertCalendarEvent(match.id, eventId, calendarId) ??
                    false;
            if (!success) {
              developer.log('Failed to store calendar event ID in database',
                  name: 'CalendarService');
            }
          } else {
            developer.log('Calendar ID is null or empty',
                name: 'CalendarService');
            return eventId; // Return eventId even if we can't store it
          }
        } catch (e) {
          developer.log('Error storing calendar event ID: $e',
              name: 'CalendarService', error: e);
        }

        return eventId;
      } else {
        developer.log(
            'Failed to add match ${match.id} to calendar: ${createEventResult?.errors ?? "Unknown error"}',
            name: 'CalendarService');
        return null;
      }
    } catch (e, stackTrace) {
      developer.log('Error adding match to calendar: $e',
          name: 'CalendarService', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Update a calendar event when match is edited
  static Future<bool> updateMatchInCalendar(Match match) async {
    try {
      // Get stored event ID
      final eventInfo = await _db?.getCalendarEvent(match.id);
      if (eventInfo == null) {
        developer.log('No calendar event found for match ${match.id}',
            name: 'CalendarService');
        return false;
      }

      // Get calendar
      final calendar = await _getDefaultCalendar();
      if (calendar == null) {
        return false;
      }

      // Get existing event - retrieve events from calendar around the match date
      // We need to retrieve events in a date range to find the event
      final retrieveEventsResult = await _deviceCalendarPlugin.retrieveEvents(
        eventInfo.calendarId,
        RetrieveEventsParams(
          startDate: match.dateTime.subtract(const Duration(days: 1)),
          endDate: match.dateTime.add(const Duration(days: 1)),
        ),
      );
      if (!retrieveEventsResult.isSuccess ||
          retrieveEventsResult.data == null) {
        developer.log(
            'Failed to retrieve events from calendar: ${eventInfo.eventId}',
            name: 'CalendarService');
        // Event might have been deleted by user, remove from tracking
        await _db?.deleteCalendarEvent(match.id);
        return false;
      }

      // Find the event by ID
      final events = retrieveEventsResult.data!;
      Event event;
      try {
        event = events.firstWhere(
          (e) => e.eventId == eventInfo.eventId,
        );
      } catch (_) {
        // Event not found
        developer.log('Event not found in calendar: ${eventInfo.eventId}',
            name: 'CalendarService');
        // Event might have been deleted by user, remove from tracking
        await _db?.deleteCalendarEvent(match.id);
        return false;
      }

      // Update event details
      final endTime = match.dateTime.add(const Duration(hours: 1, minutes: 30));
      final location = _buildLocation(match);
      final description = _buildDescription(match);

      // Convert DateTime to TZDateTime (device_calendar v4 requires TZDateTime)
      tz.TZDateTime startTZ;
      tz.TZDateTime endTZ;
      try {
        final local = tz.local;
        startTZ = tz.TZDateTime.from(match.dateTime, local);
        endTZ = tz.TZDateTime.from(endTime, local);
      } catch (e) {
        // Fallback to UTC if local timezone not available
        final utc = tz.UTC;
        startTZ = tz.TZDateTime.from(match.dateTime, utc);
        endTZ = tz.TZDateTime.from(endTime, utc);
      }

      event.title = '${match.sport.toUpperCase()} Match - ${match.location}';
      event.description = description;
      event.location = location;
      event.start = startTZ;
      event.end = endTZ;

      // Update event
      final updateResult =
          await _deviceCalendarPlugin.createOrUpdateEvent(event);
      if (updateResult != null && updateResult.isSuccess) {
        developer.log('Match ${match.id} calendar event updated successfully',
            name: 'CalendarService');
        return true;
      } else {
        developer.log(
            'Failed to update calendar event: ${updateResult?.errors ?? "Unknown error"}',
            name: 'CalendarService');
        return false;
      }
    } catch (e, stackTrace) {
      developer.log('Error updating match in calendar: $e',
          name: 'CalendarService', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Remove calendar event when match is cancelled
  static Future<bool> removeMatchFromCalendar(String matchId) async {
    try {
      // Ensure CalendarService is initialized before attempting to remove event
      if (_db == null) {
        await initialize();
      }

      // Get stored event ID
      final eventInfo = await _db?.getCalendarEvent(matchId);
      if (eventInfo == null) {
        developer.log('No calendar event found for match $matchId',
            name: 'CalendarService');
        return false;
      }

      // Delete event from calendar
      final deleteResult = await _deviceCalendarPlugin.deleteEvent(
        eventInfo.calendarId,
        eventInfo.eventId,
      );

      if (deleteResult.isSuccess) {
        developer.log('Match $matchId calendar event deleted successfully',
            name: 'CalendarService');
        // Remove from tracking
        await _db?.deleteCalendarEvent(matchId);
        return true;
      } else {
        developer.log('Failed to delete calendar event: ${deleteResult.errors}',
            name: 'CalendarService');
        // Remove from tracking anyway (event might have been deleted by user)
        await _db?.deleteCalendarEvent(matchId);
        return false;
      }
    } catch (e, stackTrace) {
      developer.log('Error removing match from calendar: $e',
          name: 'CalendarService', error: e, stackTrace: stackTrace);
      // Remove from tracking on error (event might have been deleted by user)
      await _db?.deleteCalendarEvent(matchId);
      return false;
    }
  }

  /// Check if match is added to calendar
  static Future<bool> isMatchInCalendar(String matchId) async {
    try {
      final eventInfo = await _db?.getCalendarEvent(matchId);
      return eventInfo != null;
    } catch (e) {
      developer.log('Error checking if match is in calendar: $e',
          name: 'CalendarService', error: e);
      return false;
    }
  }

  /// Get all match IDs that are in calendar
  static Future<List<String>> getAllMatchesInCalendar() async {
    try {
      return await _db?.getAllMatchIds() ?? [];
    } catch (e) {
      developer.log('Error getting all matches in calendar: $e',
          name: 'CalendarService', error: e);
      return [];
    }
  }

  // --------------------------------------------
  // Event (Agenda) Calendar Methods
  // Use event title as identifier (prefixed with "event_")
  // --------------------------------------------

  /// Get event identifier for database storage
  static String _getEventId(String eventTitle) {
    return 'event_$eventTitle';
  }

  /// Build description from agenda event
  static String _buildEventDescription(agenda.Event event) {
    final descriptionParts = <String>[];

    // Add event details
    descriptionParts.add('Target Group: ${event.targetGroup}');
    descriptionParts.add('Cost: ${event.cost}');
    descriptionParts.add('Date/Time: ${event.dateTime}');

    // Add URL if available
    if (event.url != null && event.url!.isNotEmpty) {
      descriptionParts.add('More info: ${event.url}');
    }

    return descriptionParts.join('\n\n');
  }

  /// Parse dateTime string to DateTime, or return default
  static DateTime _parseEventDateTime(String dateTimeStr) {
    // Try to parse common date formats
    final now = DateTime.now();

    // Try ISO format first
    final isoParsed = DateTime.tryParse(dateTimeStr);
    if (isoParsed != null) return isoParsed;

    // For now, use today's date with a default time (18:00)
    // Since event dateTime strings are often descriptive (e.g., "Every Monday")
    return DateTime(now.year, now.month, now.day, 18, 0);
  }

  /// Add an agenda event to the device calendar
  /// Returns event ID if successful, null otherwise
  static Future<String?> addEventToCalendar(agenda.Event event) async {
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

      // Parse dateTime or use default
      final startDateTime = _parseEventDateTime(event.dateTime);
      // Default duration: 2 hours for events
      final endDateTime = startDateTime.add(const Duration(hours: 2));

      // Build description
      final description = _buildEventDescription(event);

      // Convert DateTime to TZDateTime
      tz.TZDateTime startTZ;
      tz.TZDateTime endTZ;
      try {
        final local = tz.local;
        startTZ = tz.TZDateTime.from(startDateTime, local);
        endTZ = tz.TZDateTime.from(endDateTime, local);
      } catch (e) {
        // Fallback to UTC if local timezone not available
        final utc = tz.UTC;
        startTZ = tz.TZDateTime.from(startDateTime, utc);
        endTZ = tz.TZDateTime.from(endDateTime, utc);
      }

      // Create calendar event
      final calendarEvent = Event(calendar.id);
      calendarEvent.title = event.title;
      calendarEvent.description = description;
      calendarEvent.location = event.location;
      calendarEvent.start = startTZ;
      calendarEvent.end = endTZ;
      calendarEvent.reminders = [
        Reminder(
          minutes: 15, // 15 minutes before
        ),
      ];

      // Add to calendar
      final createEventResult =
          await _deviceCalendarPlugin.createOrUpdateEvent(calendarEvent);
      if (createEventResult != null &&
          createEventResult.isSuccess &&
          createEventResult.data != null) {
        final eventId = createEventResult.data!;
        if (eventId.isEmpty) {
          developer.log('Event ID is empty for event ${event.title}',
              name: 'CalendarService');
          return null;
        }
        developer.log(
            'Event ${event.title} added to calendar with event ID: $eventId',
            name: 'CalendarService');

        // Store event ID for tracking (use prefixed title as identifier)
        try {
          final calendarId = calendar.id;
          if (calendarId != null && calendarId.isNotEmpty) {
            final eventIdentifier = _getEventId(event.title);
            final success = await _db?.insertCalendarEvent(
                    eventIdentifier, eventId, calendarId) ??
                false;
            if (!success) {
              developer.log('Failed to store calendar event ID in database',
                  name: 'CalendarService');
            }
          } else {
            developer.log('Calendar ID is null or empty',
                name: 'CalendarService');
            return eventId; // Return eventId even if we can't store it
          }
        } catch (e) {
          developer.log('Error storing calendar event ID: $e',
              name: 'CalendarService', error: e);
        }

        return eventId;
      } else {
        developer.log(
            'Failed to add event ${event.title} to calendar: ${createEventResult?.errors ?? "Unknown error"}',
            name: 'CalendarService');
        return null;
      }
    } catch (e, stackTrace) {
      developer.log('Error adding event to calendar: $e',
          name: 'CalendarService', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Remove agenda event from calendar
  static Future<bool> removeEventFromCalendar(String eventTitle) async {
    try {
      final eventIdentifier = _getEventId(eventTitle);
      // Get stored event ID
      final eventInfo = await _db?.getCalendarEvent(eventIdentifier);
      if (eventInfo == null) {
        developer.log('No calendar event found for event $eventTitle',
            name: 'CalendarService');
        return false;
      }

      // Delete event from calendar
      final deleteResult = await _deviceCalendarPlugin.deleteEvent(
        eventInfo.calendarId,
        eventInfo.eventId,
      );

      if (deleteResult.isSuccess) {
        developer.log('Event $eventTitle calendar event deleted successfully',
            name: 'CalendarService');
        // Remove from tracking
        await _db?.deleteCalendarEvent(eventIdentifier);
        return true;
      } else {
        developer.log('Failed to delete calendar event: ${deleteResult.errors}',
            name: 'CalendarService');
        // Remove from tracking anyway (event might have been deleted by user)
        await _db?.deleteCalendarEvent(eventIdentifier);
        return false;
      }
    } catch (e, stackTrace) {
      developer.log('Error removing event from calendar: $e',
          name: 'CalendarService', error: e, stackTrace: stackTrace);
      // Remove from tracking on error (event might have been deleted by user)
      final eventIdentifier = _getEventId(eventTitle);
      await _db?.deleteCalendarEvent(eventIdentifier);
      return false;
    }
  }

  /// Check if agenda event is added to calendar
  static Future<bool> isEventInCalendar(String eventTitle) async {
    try {
      final eventIdentifier = _getEventId(eventTitle);
      final eventInfo = await _db?.getCalendarEvent(eventIdentifier);
      return eventInfo != null;
    } catch (e) {
      developer.log('Error checking if event is in calendar: $e',
          name: 'CalendarService', error: e);
      return false;
    }
  }
}
