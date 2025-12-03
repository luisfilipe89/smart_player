/// Field data processing utilities for normalizing and transforming field data.
///
/// Extracts business logic from UI components to improve separation of concerns.
library;

import 'package:move_young/utils/type_converters.dart';
import 'package:move_young/utils/geolocation_utils.dart';

/// Processes and normalizes raw field data from external sources (e.g., Overpass API).
///
/// Handles:
/// - Address normalization and shortening
/// - Coordinate parsing and validation
/// - Name extraction and fallback logic
/// - Field data structure standardization
class FieldDataProcessor {
  /// Shortens an address string by taking the part before the first comma.
  ///
  /// Returns null if the input is null or empty.
  /// Returns the original text if no comma is found.
  static String? shortenAddress(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final commaIndex = text.indexOf(',');
    if (commaIndex == -1) return text;
    final shortened = text.substring(0, commaIndex).trim();
    return shortened.isNotEmpty ? shortened : text;
  }

  /// Normalizes raw field data into a standardized format.
  ///
  /// Handles various input formats and normalizes them to a consistent structure
  /// with standardized keys and data types.
  ///
  /// Returns a list of normalized field maps with:
  /// - Standardized keys (name, address, latitude, longitude, etc.)
  /// - Validated coordinates
  /// - Processed address variants
  /// - Lighting information as boolean
  static List<Map<String, dynamic>> normalizeFields(
    List<Map<String, dynamic>> rawFields,
  ) {
    return rawFields
        .map<Map<String, dynamic>>((f) {
          // Extract address variants
          final address =
              f['address_short'] ?? f['addr:street'] ?? f['address'];
          final rawAddressMicroShort =
              f['address_micro_short'] ?? f['addressMicroShort'];
          final rawAddressSuperShort =
              f['address_super_short'] ?? f['addressSuperShort'];
          final condensedAddressSuperShort =
              shortenAddress(rawAddressSuperShort) ?? shortenAddress(address);

          // Extract and process name
          final rawName = f['name']?.toString().trim();
          final isNameAnAddress = rawName != null &&
              rawName.isNotEmpty &&
              rawAddressSuperShort != null &&
              rawAddressSuperShort.toString().trim().isNotEmpty &&
              rawName == rawAddressSuperShort.toString().trim();

          // Determine the best name to use (prefer actual name over address)
          final candidateName =
              (rawName != null && rawName.isNotEmpty && !isNameAnAddress)
                  ? rawName
                  : (rawAddressMicroShort != null &&
                          rawAddressMicroShort.toString().trim().isNotEmpty)
                      ? rawAddressMicroShort.toString().trim()
                      : (condensedAddressSuperShort ??
                          rawAddressSuperShort?.toString().trim());

          final name = (candidateName != null &&
                  candidateName.toString().trim().isNotEmpty)
              ? candidateName.toString().trim()
              : 'Unnamed Field';

          // Extract and normalize coordinates
          final lat = f['lat'] ?? f['latitude'];
          final lon = f['lon'] ?? f['longitude'];
          final latDouble = safeToDouble(lat);
          final lonDouble = safeToDouble(lon);

          // Extract lighting information
          final lit = f['lit'] ?? f['lighting'];
          final hasLighting =
              (lit == true) || (lit?.toString().toLowerCase() == 'yes');

          // Build normalized field map
          return {
            'id': f['id'],
            'name': name,
            'address': address,
            if (rawAddressMicroShort != null &&
                rawAddressMicroShort.toString().trim().isNotEmpty)
              'addressMicroShort': rawAddressMicroShort.toString().trim(),
            if (condensedAddressSuperShort != null)
              'addressSuperShort': condensedAddressSuperShort,
            if (rawAddressSuperShort != null &&
                rawAddressSuperShort.toString().trim().isNotEmpty)
              'addressSuperShortFull': rawAddressSuperShort.toString().trim(),
            'latitude': latDouble ?? lat,
            'longitude': lonDouble ?? lon,
            'surface': f['surface'],
            'lighting': hasLighting,
          };
        })
        .where((m) => m['latitude'] != null && m['longitude'] != null)
        .toList();
  }

  /// Finds a matching field from a list of fields by various criteria.
  ///
  /// Tries matching in order:
  /// 1. By field ID (most reliable)
  /// 2. By name (case-insensitive)
  /// 3. By coordinate proximity (within ~11 meters)
  ///
  /// Returns the matching field map, or an empty map if no match is found.
  static Map<String, dynamic> findMatchingField(
    Map<String, dynamic>? selectedField,
    List<Map<String, dynamic>> fields,
  ) {
    if (selectedField == null || selectedField.isEmpty) {
      return <String, dynamic>{};
    }

    final String selName = (selectedField['name'] as String?) ?? '';
    final String? selFieldId = selectedField['id']?.toString();
    final double? selLat = safeToDouble(selectedField['latitude']);
    final double? selLon = safeToDouble(selectedField['longitude']);

    // Try to match by fieldId first (most reliable)
    Map<String, dynamic>? match;
    if (selFieldId != null && selFieldId.isNotEmpty) {
      match = fields.firstWhere(
        (f) {
          final fId = f['id']?.toString();
          return fId != null && fId == selFieldId;
        },
        orElse: () => <String, dynamic>{},
      );
    }

    // If no match by ID, try by name
    if ((match == null || match.isEmpty) && selName.isNotEmpty) {
      match = fields.firstWhere(
        (f) {
          final fName = (f['name'] as String?) ?? '';
          return fName == selName ||
              fName.toLowerCase().trim() == selName.toLowerCase().trim();
        },
        orElse: () => <String, dynamic>{},
      );
    }

    // If still no match and we have coordinates, try matching by proximity
    if ((match == null || match.isEmpty) && selLat != null && selLon != null) {
      match = fields.firstWhere(
        (f) {
          return areCoordinatesNearbyFromMap(
            refLat: selLat,
            refLon: selLon,
            field: f,
          );
        },
        orElse: () => <String, dynamic>{},
      );
    }

    return match ?? <String, dynamic>{};
  }
}
