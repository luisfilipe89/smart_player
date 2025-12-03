/// Utility functions for time slot operations.
///
/// Handles time slot overlap detection and time format conversions.
/// Games always last 1 hour, so overlap checks consider 1-hour windows.
library;

/// Converts a time string in HH:mm format to minutes since midnight.
///
/// Returns 0 if the format is invalid.
/// Example: "10:30" -> 630 (10 * 60 + 30)
int timeStringToMinutes(String timeStr) {
  final parts = timeStr.split(':');
  if (parts.length < 2) return 0;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return 0;
  return hour * 60 + minute;
}

/// Converts a time key in HHmm format to minutes since midnight.
///
/// Returns 0 if the format is invalid.
/// Example: "1030" -> 630 (10 * 60 + 30)
int timeKeyToMinutes(String timeKey) {
  // timeKey format is HHmm (e.g., "1030" for 10:30)
  if (timeKey.length == 4) {
    final hourStr = timeKey.substring(0, 2);
    final minuteStr = timeKey.substring(2, 4);
    final hour = int.tryParse(hourStr);
    final minute = int.tryParse(minuteStr);
    if (hour != null &&
        minute != null &&
        hour >= 0 &&
        hour < 24 &&
        minute >= 0 &&
        minute < 60) {
      return hour * 60 + minute;
    }
  }
  // Fallback: return 0 for invalid format
  return 0;
}

/// Converts minutes since midnight to a time string in HH:mm format.
///
/// Example: 630 -> "10:30"
String minutesToTimeString(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
}

/// Converts minutes since midnight to a time key in HHmm format.
///
/// Example: 630 -> "1030"
String minutesToTimeKey(int minutes) {
  final hours = minutes ~/ 60;
  final mins = minutes % 60;
  return '${hours.toString().padLeft(2, '0')}${mins.toString().padLeft(2, '0')}';
}

/// Checks if two 1-hour time slots overlap.
///
/// Games always last 1 hour, so we check if the 1-hour windows overlap.
/// Works with both HH:mm and HHmm formats.
///
/// Two intervals overlap if: start1 < end2 && start2 < end1
/// Each slot is a 1-hour window: [start, start+60)
bool timeSlotsOverlap(String time1, String time2) {
  // Try HHmm format first (timeKey), then HH:mm format (timeString)
  int minutes1;
  int minutes2;

  if (time1.length == 4 && !time1.contains(':')) {
    minutes1 = timeKeyToMinutes(time1);
  } else {
    minutes1 = timeStringToMinutes(time1);
  }

  if (time2.length == 4 && !time2.contains(':')) {
    minutes2 = timeKeyToMinutes(time2);
  } else {
    minutes2 = timeStringToMinutes(time2);
  }

  // Each slot is a 1-hour window: [start, start+60)
  final start1 = minutes1;
  final end1 = minutes1 + 60;
  final start2 = minutes2;
  final end2 = minutes2 + 60;

  // Two intervals overlap if: start1 < end2 && start2 < end1
  return start1 < end2 && start2 < end1;
}

/// Checks if a time slot conflicts with any booked time.
///
/// Returns true if the time overlaps with any time in the bookedTimes set.
/// Works with both HH:mm and HHmm formats.
bool isTimeSlotBooked(String time, Set<String> bookedTimes) {
  for (final bookedTime in bookedTimes) {
    if (timeSlotsOverlap(time, bookedTime)) {
      return true;
    }
  }
  return false;
}

/// Parses a time string (HH:mm format) and returns the hour and minute.
///
/// Returns a record with (hour, minute) if parsing succeeds, null otherwise.
/// Example: "10:30" -> (10, 30)
/// Example: "09:00" -> (9, 0)
({int hour, int minute})? parseTimeString(String timeStr) {
  final parts = timeStr.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour >= 24 || minute < 0 || minute >= 60) return null;
  return (hour: hour, minute: minute);
}

/// Extracts the hour component from a time string (HH:mm format).
///
/// Returns the hour as a string, or null if parsing fails.
/// Example: "10:30" -> "10"
/// Example: "09:00" -> "09"
String? extractHourFromTimeString(String timeStr) {
  final parsed = parseTimeString(timeStr);
  return parsed?.hour.toString().padLeft(2, '0');
}

/// Checks if a time string (HH:mm) represents a time in the future compared to now.
///
/// Returns true if the time is after the current time, false otherwise.
/// Returns false if the time string is invalid.
bool isTimeInFuture(String timeStr, DateTime now) {
  final parsed = parseTimeString(timeStr);
  if (parsed == null) return false;

  final timeHour = parsed.hour;
  final timeMinute = parsed.minute;
  final currentHour = now.hour;
  final currentMinute = now.minute;

  return timeHour > currentHour ||
      (timeHour == currentHour && timeMinute > currentMinute);
}
