/// Geolocation utilities for distance calculations and coordinate operations.
///
/// Provides reusable functions for common geolocation operations,
/// reducing code duplication and ensuring consistent behavior.
library;

import 'package:geolocator/geolocator.dart';
import 'package:move_young/utils/type_converters.dart';

/// Default proximity threshold in degrees (~11 meters at equator).
///
/// Used for checking if two coordinates are close enough to be considered the same location.
const double defaultProximityThreshold = 0.0001;

/// High precision proximity threshold in degrees (~1.1 meters at equator).
///
/// Used for more precise coordinate matching.
const double highPrecisionProximityThreshold = 0.00001;

/// Calculates the distance between two coordinates in meters.
///
/// Returns `null` if either coordinate is invalid or the distance calculation fails.
///
/// Example:
/// ```dart
/// final distance = calculateDistanceMeters(
///   startLat: 52.3676,
///   startLon: 4.9041,
///   endLat: 52.3702,
///   endLon: 4.8952,
/// );
/// // Returns distance in meters, or null if invalid
/// ```
double? calculateDistanceMeters({
  required double startLat,
  required double startLon,
  required double endLat,
  required double endLon,
}) {
  try {
    final distance = Geolocator.distanceBetween(
      startLat,
      startLon,
      endLat,
      endLon,
    );
    // Validate result
    if (!distance.isFinite || distance < 0) {
      return null;
    }
    return distance;
  } catch (e) {
    return null;
  }
}

/// Calculates the distance between two coordinates, with optional max distance filter.
///
/// Returns `null` if:
/// - Either coordinate is invalid
/// - Distance exceeds [maxDistanceMeters] (if provided)
/// - Distance calculation fails
///
/// Example:
/// ```dart
/// final distance = calculateDistanceMetersWithMax(
///   startLat: userLat,
///   startLon: userLon,
///   endLat: fieldLat,
///   endLon: fieldLon,
///   maxDistanceMeters: 500000, // 500 km
/// );
/// ```
double? calculateDistanceMetersWithMax({
  required double startLat,
  required double startLon,
  required double endLat,
  required double endLon,
  double? maxDistanceMeters,
}) {
  final distance = calculateDistanceMeters(
    startLat: startLat,
    startLon: startLon,
    endLat: endLat,
    endLon: endLon,
  );

  if (distance == null) return null;

  if (maxDistanceMeters != null && distance > maxDistanceMeters) {
    return null;
  }

  return distance;
}

/// Checks if two coordinates are within the specified proximity threshold.
///
/// Uses coordinate difference (in degrees) rather than actual distance calculation
/// for performance when checking many coordinates.
///
/// [threshold] defaults to [defaultProximityThreshold] (~11 meters).
///
/// Example:
/// ```dart
/// final isNearby = areCoordinatesNearby(
///   lat1: 52.3676,
///   lon1: 4.9041,
///   lat2: 52.3677,
///   lon2: 4.9042,
///   threshold: defaultProximityThreshold,
/// );
/// ```
bool areCoordinatesNearby({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
  double threshold = defaultProximityThreshold,
}) {
  final latDiff = (lat1 - lat2).abs();
  final lonDiff = (lon1 - lon2).abs();
  return latDiff < threshold && lonDiff < threshold;
}

/// Checks if two coordinates are very close (high precision check).
///
/// Uses [highPrecisionProximityThreshold] (~1.1 meters) for precise matching.
///
/// Example:
/// ```dart
/// final isVeryClose = areCoordinatesVeryClose(
///   lat1: game.latitude!,
///   lon1: game.longitude!,
///   lat2: field['latitude'],
///   lon2: field['longitude'],
/// );
/// ```
bool areCoordinatesVeryClose({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  return areCoordinatesNearby(
    lat1: lat1,
    lon1: lon1,
    lat2: lat2,
    lon2: lon2,
    threshold: highPrecisionProximityThreshold,
  );
}

/// Formats distance in meters to a human-readable string.
///
/// Returns:
/// - Distance in km with appropriate decimal places if >= 1 km
/// - Distance in meters if < 1 km
///
/// Example:
/// ```dart
/// formatDistance(1500); // "1.5 km away"
/// formatDistance(500); // "500 m away"
/// formatDistance(0); // "0 m away"
/// ```
String formatDistance(double distanceMeters, {String suffix = ' away'}) {
  if (distanceMeters < 1000) {
    return '${distanceMeters.toInt()} m$suffix';
  }

  final distanceKm = distanceMeters / 1000;
  // Use 1 decimal place if < 10 km, otherwise no decimals
  final formattedKm = distanceKm < 10
      ? distanceKm.toStringAsFixed(1)
      : distanceKm.toStringAsFixed(0);

  return '$formattedKm km$suffix';
}

/// Formats distance from a nullable value, returning a default if null.
///
/// Example:
/// ```dart
/// formatDistanceOrNull(null); // "Unknown distance"
/// formatDistanceOrNull(1500); // "1.5 km away"
/// ```
String formatDistanceOrNull(
  double? distanceMeters, {
  String defaultText = 'Unknown distance',
  String suffix = ' away',
}) {
  if (distanceMeters == null) {
    return defaultText;
  }
  return formatDistance(distanceMeters, suffix: suffix);
}

/// Calculates distance from dynamic coordinate values.
///
/// Safely extracts coordinates from maps and calculates distance.
/// Returns `null` if coordinates are missing or invalid.
///
/// Example:
/// ```dart
/// final distance = calculateDistanceFromMap(
///   startLat: userPosition.latitude,
///   startLon: userPosition.longitude,
///   endField: {'latitude': 52.3676, 'longitude': 4.9041},
/// );
/// ```
double? calculateDistanceFromMap({
  required double startLat,
  required double startLon,
  required Map<String, dynamic> endField,
  double? maxDistanceMeters,
}) {
  final endLat = safeToDouble(endField['latitude'] ?? endField['lat']);
  final endLon = safeToDouble(endField['longitude'] ?? endField['lon']);

  if (endLat == null || endLon == null) {
    return null;
  }

  return calculateDistanceMetersWithMax(
    startLat: startLat,
    startLon: startLon,
    endLat: endLat,
    endLon: endLon,
    maxDistanceMeters: maxDistanceMeters,
  );
}

/// Checks if coordinates from a map are nearby a reference point.
///
/// Safely extracts coordinates and checks proximity.
///
/// Example:
/// ```dart
/// final isNearby = areCoordinatesNearbyFromMap(
///   refLat: selectedField['latitude'],
///   refLon: selectedField['longitude'],
///   field: {'latitude': 52.3676, 'longitude': 4.9041},
/// );
/// ```
bool areCoordinatesNearbyFromMap({
  required double refLat,
  required double refLon,
  required Map<String, dynamic> field,
  double threshold = defaultProximityThreshold,
}) {
  final fieldLat = safeToDouble(field['latitude'] ?? field['lat']);
  final fieldLon = safeToDouble(field['longitude'] ?? field['lon']);

  if (fieldLat == null || fieldLon == null) {
    return false;
  }

  return areCoordinatesNearby(
    lat1: refLat,
    lon1: refLon,
    lat2: fieldLat,
    lon2: fieldLon,
    threshold: threshold,
  );
}
