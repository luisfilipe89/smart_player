import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class LocalFieldsService {
  const LocalFieldsService();

  Future<List<Map<String, dynamic>>?> loadFields({
    required String areaName,
    required String sportType,
  }) async {
    final slug = _slugArea(areaName);
    final primaryPath = 'assets/fields/den_bosch_fields.json';
    final fallbackPath = 'assets/fields/$slug.fields.json';

    String? raw;
    try {
      raw = await rootBundle.loadString(primaryPath);
    } catch (_) {
      // ignore and try fallback
    }
    if (raw == null) {
      try {
        raw = await rootBundle.loadString(fallbackPath);
      } catch (_) {
        return null;
      }
    }

    final decoded = jsonDecode(raw);

    List<Map<String, dynamic>> items = [];

    if (decoded is Map<String, dynamic> && decoded.containsKey('elements')) {
      // Overpass-style JSON -> normalize and filter by sport
      final elements = (decoded['elements'] as List?)?.cast<dynamic>() ?? [];
      items = elements
          .map<Map<String, dynamic>>((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final tags = Map<String, dynamic>.from(m['tags'] ?? {});
            final type = (m['type'] ?? '').toString();
            final idRaw = m['id'];
            final id = idRaw != null ? idRaw.toString() : '';
            final num? nLat = m['lat'] as num?;
            final num? nLon = m['lon'] as num?;
            final Map<String, dynamic>? center =
                m['center'] as Map<String, dynamic>?;
            final num? cLat = center != null ? center['lat'] as num? : null;
            final num? cLon = center != null ? center['lon'] as num? : null;
            final double? lat = (nLat ?? cLat)?.toDouble();
            final double? lon = (nLon ?? cLon)?.toDouble();
            if (lat == null || lon == null) return {};
            return {
              'id': id.isNotEmpty ? (type.isNotEmpty ? '$type:$id' : id) : null,
              'name': tags['name'] ?? 'Unnamed Field',
              'lat': lat,
              'lon': lon,
              'surface': tags['surface'],
              'lit': tags['lit'],
              'addr:street': tags['addr:street'],
              'tags': tags,
            };
          })
          .where((m) => m.isNotEmpty)
          .toList();

      // Keep only requested sport
      items = items.where((m) {
        final tags = (m['tags'] as Map<String, dynamic>?);
        final sport = tags?['sport']?.toString();
        final leisure = tags?['leisure']?.toString();
        if (sport == sportType) return true;
        // Optional: allow sports centres/venues tagged with same sport
        if (leisure == 'sports_centre' && sport == sportType) return true;
        if ((leisure == 'pitch' || leisure == 'stadium') && sport == sportType)
          return true;
        return false;
      }).toList();
    } else if (decoded is Map<String, dynamic> && decoded[sportType] is List) {
      // Pre-normalized schema keyed by sport
      final list = (decoded[sportType] as List).cast<dynamic>();
      items = list.map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final lat = m['lat'];
        final lon = m['lon'];
        return {
          ...m,
          'lat': lat is num ? lat.toDouble() : double.tryParse('$lat'),
          'lon': lon is num ? lon.toDouble() : double.tryParse('$lon'),
          'tags': Map<String, dynamic>.from(m['tags'] ?? {}),
        };
      }).toList();
    } else {
      return null;
    }

    return items.where((e) => e['lat'] != null && e['lon'] != null).toList();
  }

  String _slugArea(String areaName) {
    final lower = areaName.toLowerCase();
    final dashed = lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
    return dashed;
  }
}
