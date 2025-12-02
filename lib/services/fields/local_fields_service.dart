import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class LocalFieldsService {
  const LocalFieldsService();

  Future<List<Map<String, dynamic>>?> loadFields({
    required String sportType,
  }) async {
    final assetCandidates = _resolveAssetCandidates(sportType);

    String? raw;
    for (final path in assetCandidates) {
      raw = await _tryLoad(path);
      if (raw != null) {
        break;
      }
    }
    if (raw == null) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final features =
        (decoded['features'] as List?)?.cast<dynamic>() ?? const <dynamic>[];

    final items = features
        .map<Map<String, dynamic>>((feature) {
          final map = Map<String, dynamic>.from(feature as Map);
          final properties =
              Map<String, dynamic>.from(map['properties'] as Map? ?? const {});
          final id = (map['id'] ?? properties['@id'])?.toString();

          // Prefer pre-calculated coordinates from properties (added by reverse geocoding script)
          // Fallback to extracting from geometry for backward compatibility
          double? lat;
          double? lon;

          if (properties['lat'] != null && properties['lon'] != null) {
            // Use pre-calculated coordinates
            lat = _toDouble(properties['lat']);
            lon = _toDouble(properties['lon']);
          } else {
            // Fallback: extract from geometry (for files without pre-calculated coordinates)
            final coords = _extractLatLon(map['geometry']);
            if (coords != null) {
              lat = coords.$1;
              lon = coords.$2;
            }
          }

          if (lat == null || lon == null) {
            return const <String, dynamic>{};
          }

          final rawName =
              properties['name'] ?? properties['address_super_short'];
          final resolvedName = (rawName is String && rawName.trim().isNotEmpty)
              ? rawName.trim()
              : (rawName is! String &&
                      rawName != null &&
                      rawName.toString().trim().isNotEmpty)
                  ? rawName.toString().trim()
                  : 'Unnamed Field';

          return {
            'id': id,
            'name': resolvedName,
            'lat': lat,
            'lon': lon,
            'surface': properties['surface'],
            'lit': properties['lit'],
            'addr:street': properties['addr:street'],
            'address_short': properties['address_short'],
            'address_super_short': properties['address_super_short'],
            'address_micro_short': properties['address_micro_short'],
            'address_display_name': properties['address_display_name'],
            'tags': properties,
          };
        })
        .where((m) => m.isNotEmpty)
        .toList();

    // Since each GeoJSON file is already sport-specific, we can be lenient with filtering
    // Just ensure we have valid coordinates and optionally verify sport matches
    final normalizedSportType = sportType.toLowerCase();
    final normalizedForMatching =
        normalizedSportType == 'football' ? 'soccer' : normalizedSportType;

    final filtered = items.where((m) {
      // First check: must have valid coordinates
      if (m['lat'] == null || m['lon'] == null) {
        return false;
      }

      // Second check: verify sport matches (but be lenient since file is already filtered)
      final tags = m['tags'] as Map<String, dynamic>?;
      final sport = tags?['sport']?.toString().toLowerCase();

      // If sport is specified, it should match (with soccer/football equivalence)
      if (sport != null) {
        if (sport == normalizedForMatching) {
          return true;
        }
        // Handle soccer/football equivalence
        if ((normalizedSportType == 'soccer' && sport == 'football') ||
            (normalizedSportType == 'football' && sport == 'soccer')) {
          return true;
        }
        // If sport doesn't match, skip it
        return false;
      }

      // If no sport specified but has coordinates, include it (file is already filtered)
      return true;
    }).toList();

    return filtered;
  }

  List<String> _resolveAssetCandidates(String sportType) {
    final normalized = sportType.toLowerCase();
    const defaultAssets = <String>[
      'assets/fields/output/football.geojson',
    ];

    const sportAssets = <String, List<String>>{
      'soccer': defaultAssets,
      'football': defaultAssets,
      'basketball': <String>[
        'assets/fields/output/basketball.geojson',
      ],
      'beachvolleyball': <String>[
        'assets/fields/output/beachvolleyball.geojson',
      ],
      'table_tennis': <String>[
        'assets/fields/output/tabletennis.geojson',
      ],
      'boules': <String>[
        'assets/fields/output/boules.geojson',
      ],
      'skateboard': <String>[
        'assets/fields/output/skateboard.geojson',
      ],
      'swimming': <String>[
        'assets/fields/output/swimming.geojson',
      ],
    };

    return sportAssets[normalized] ?? defaultAssets;
  }

  Future<String?> _tryLoad(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (_) {
      return null;
    }
  }

  (double, double)? _extractLatLon(dynamic geometry) {
    if (geometry is! Map) {
      return null;
    }
    final type = geometry['type']?.toString();
    final coordinates = geometry['coordinates'];

    if (type == 'Point' && coordinates is List && coordinates.length >= 2) {
      final lon = _toDouble(coordinates[0]);
      final lat = _toDouble(coordinates[1]);
      if (lat != null && lon != null) {
        return (lat, lon);
      }
      return null;
    }

    if (type == 'Polygon' && coordinates is List && coordinates.isNotEmpty) {
      final firstRing = coordinates.first;
      if (firstRing is List && firstRing.isNotEmpty) {
        double sumLat = 0;
        double sumLon = 0;
        int count = 0;
        for (final point in firstRing) {
          if (point is List && point.length >= 2) {
            final lon = _toDouble(point[0]);
            final lat = _toDouble(point[1]);
            if (lat != null && lon != null) {
              sumLat += lat;
              sumLon += lon;
              count++;
            }
          }
        }
        if (count > 0) {
          return (sumLat / count, sumLon / count);
        }
      }
    }

    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}
