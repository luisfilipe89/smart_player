import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class LocalFieldsService {
  const LocalFieldsService();

  Future<List<Map<String, dynamic>>?> loadFields({
    required String areaName,
    required String sportType,
  }) async {
    // `areaName` kept for API compatibility; current GeoJSON is not area-specific.
    // ignore: unused_local_variable
    final _ = areaName;
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
          final coords = _extractLatLon(map['geometry']);
          if (coords == null) {
            return const <String, dynamic>{};
          }

          return {
            'id': id,
            'name': properties['name'] ?? 'Unnamed Field',
            'lat': coords.$1,
            'lon': coords.$2,
            'surface': properties['surface'],
            'lit': properties['lit'],
            'addr:street': properties['addr:street'],
            'address_short': properties['address_short'],
            'address_super_short': properties['address_super_short'],
            'address_display_name': properties['address_display_name'],
            'tags': properties,
          };
        })
        .where((m) => m.isNotEmpty)
        .toList();

    return items
        .where((m) {
          final tags = m['tags'] as Map<String, dynamic>?;
          final sport = tags?['sport']?.toString();
          final leisure = tags?['leisure']?.toString();
          if (sport == sportType) {
            return true;
          }
          if (leisure == 'sports_centre' && sport == sportType) {
            return true;
          }
          if ((leisure == 'pitch' || leisure == 'stadium') &&
              sport == sportType) {
            return true;
          }
          return false;
        })
        .where((e) => e['lat'] != null && e['lon'] != null)
        .toList();
  }

  List<String> _resolveAssetCandidates(String sportType) {
    final normalized = sportType.toLowerCase();
    const defaultAssets = <String>[
      'assets/fields/football_fields_with_addresses.geojson',
    ];

    const sportAssets = <String, List<String>>{
      'soccer': defaultAssets,
      'football': defaultAssets,
      'basketball': <String>[
        'assets/fields/basketball_fields_with_addresses.geojson',
      ],
      'beachvolleyball': <String>[
        'assets/fields/beachvolleyball_with_addresses.geojson',
      ],
      'table_tennis': <String>[
        'assets/fields/table_tennis_with_addresses.geojson',
      ],
      'boules': <String>[
        'assets/fields/boules_with_addresses.geojson',
      ],
      'skateboard': <String>[
        'assets/fields/skateboard_with_addresses.geojson',
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

    if (type == 'MultiPolygon' &&
        coordinates is List &&
        coordinates.isNotEmpty) {
      for (final polygon in coordinates) {
        final result =
            _extractLatLon({'type': 'Polygon', 'coordinates': polygon});
        if (result != null) {
          return result;
        }
      }
    }

    if (type == 'LineString' && coordinates is List && coordinates.isNotEmpty) {
      final first = coordinates.first;
      if (first is List && first.length >= 2) {
        final lon = _toDouble(first[0]);
        final lat = _toDouble(first[1]);
        if (lat != null && lon != null) {
          return (lat, lon);
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
