/// Type conversion utilities for safe conversion between dynamic types.
///
/// These utilities handle common conversion patterns used throughout the codebase,
/// reducing code duplication and improving type safety.
library;

/// Safely converts a dynamic value to a double.
///
/// Handles multiple input types:
/// - `num` types (int, double) → converts to double
/// - `String` → attempts to parse as double
/// - `null` → returns null
/// - Other types → returns null
///
/// Example:
/// ```dart
/// final lat = safeToDouble(field['latitude']); // Returns double? or null
/// final distance = safeToDouble(data['distance']) ?? 0.0; // With default
/// ```
double? safeToDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

/// Safely converts a dynamic value to a double, with a default fallback.
///
/// If conversion fails or value is null, returns [defaultValue].
///
/// Example:
/// ```dart
/// final distance = safeToDoubleWithDefault(field['distance'], 0.0);
/// ```
double safeToDoubleWithDefault(dynamic value, double defaultValue) {
  return safeToDouble(value) ?? defaultValue;
}

/// Safely converts a dynamic value to an int.
///
/// Handles multiple input types:
/// - `num` types → converts to int (truncates if double)
/// - `String` → attempts to parse as int
/// - `null` → returns null
/// - Other types → returns null
///
/// Example:
/// ```dart
/// final count = safeToInt(data['count']); // Returns int? or null
/// ```
int? safeToInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

/// Safely converts a dynamic value to an int, with a default fallback.
///
/// If conversion fails or value is null, returns [defaultValue].
///
/// Example:
/// ```dart
/// final maxPlayers = safeToIntWithDefault(data['maxPlayers'], 10);
/// ```
int safeToIntWithDefault(dynamic value, int defaultValue) {
  return safeToInt(value) ?? defaultValue;
}

/// Safely converts a dynamic value to a String.
///
/// Handles multiple input types:
/// - `String` → returns as-is
/// - `num` types → converts to string representation
/// - `null` → returns null
/// - Other types → returns `toString()` result
///
/// Example:
/// ```dart
/// final name = safeToString(data['name']); // Returns String? or null
/// ```
String? safeToString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num) return value.toString();
  return value.toString();
}

/// Safely converts a dynamic value to a String, with a default fallback.
///
/// If conversion fails or value is null, returns [defaultValue].
///
/// Example:
/// ```dart
/// final name = safeToStringWithDefault(data['name'], 'Unknown');
/// ```
String safeToStringWithDefault(dynamic value, String defaultValue) {
  return safeToString(value) ?? defaultValue;
}
