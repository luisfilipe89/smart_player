// lib/services/overpass_service_instance.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:move_young/utils/logger.dart';

class OverpassServiceInstance {
  final SharedPreferences? _prefs;

  static const _cacheDuration = Duration(days: 90);

  // Try these mirrors in order if one is unreachable or rate-limited.
  static const _endpoints = <String>[
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.nchc.org.tw/api/interpreter',
    'https://overpass.osm.ch/api/interpreter',
  ];

  static const _headers = <String, String>{
    'Content-Type': 'application/x-www-form-urlencoded',
    'User-Agent': 'move_young/1.0 (+contact@example.com)', // optional but nice
  };

  OverpassServiceInstance(this._prefs);

  /// Fetch fields for a single sport within a named area (e.g., "s-Hertogenbosch").
  /// Pass [sportType] exactly as OSM uses it (e.g., "tennis", "beachvolleyball").
  /// If [bypassCache] is true, ignores cached data and refetches.
  Future<List<Map<String, dynamic>>> fetchFields({
    required String areaName, // pass WITHOUT quotes: "s-Hertogenbosch"
    required String sportType, // e.g., "tennis", "beachvolleyball"
    bool bypassCache = false,
  }) async {
    final cacheKey = 'fields_${areaName}_$sportType';

    if (!bypassCache) {
      final cached = await _getCachedData(cacheKey);
      if (cached != null) return cached;
    }

    // Primary query using the provided area name
    final areaSel = _areaSelector(areaName);
    final String primaryQuery = _buildSportQuery(areaSel, sportType);
    NumberedLogger.d('🔍 Overpass Query (primary):\n$primaryQuery');

    String body;
    List<Map<String, dynamic>> parsed = const [];
    try {
      body = await _postOverpass(primaryQuery);
      parsed = _parseOverpassData(body);
    } catch (e) {
      NumberedLogger.e('Failed primary Overpass query: $e');
    }

    NumberedLogger.d(
        '🔍 Overpass Response (primary): ${parsed.length} elements found');

    // Second attempt: add country for disambiguation (e.g., “, Netherlands”)
    if (parsed.isEmpty) {
      final areaSelWithCountry = _areaSelectorWithCountry(areaName);
      if (areaSelWithCountry != areaSel) {
        final String countryQuery =
            _buildSportQuery(areaSelWithCountry, sportType);
        NumberedLogger.d(
            '🔍 Overpass Query (country disambiguation):\n$countryQuery');
        try {
          final body2 = await _postOverpass(countryQuery);
          parsed = _parseOverpassData(body2);
        } catch (e) {
          NumberedLogger.e('Failed country Overpass query: $e');
        }
        NumberedLogger.d(
            '🔍 Overpass Response (country): ${parsed.length} elements found');
      }
    }

    // Third attempt: broader search for any pitches/stadiums in the area, then
    // filter locally by sport tag or name synonyms (voetbal/football/soccer)
    if (parsed.isEmpty) {
      final areaSel3 = _areaSelectorWithCountry(areaName);
      final wideQuery = '''
[out:json][timeout:25];
$areaSel3
(
  nwr["leisure"="pitch"](area.searchArea);
  nwr["leisure"="stadium"](area.searchArea);
);
out center tags qt;
''';
      NumberedLogger.d('🔍 Overpass Query (wide, filter locally):\n$wideQuery');
      try {
        final body3 = await _postOverpass(wideQuery);
        final wide = _parseOverpassData(body3);
        final wanted = sportType.toLowerCase();
        final filtered = wide.where((m) {
          final tags = (m['tags'] as Map<String, dynamic>?);
          final sport = tags?['sport']?.toString().toLowerCase();
          final name = tags?['name']?.toString().toLowerCase() ?? '';
          if (sport == wanted) {
            return true;
          }
          // NL synonyms and generic terms commonly used
          if (name.contains('voetbal') ||
              name.contains('soccer') ||
              name.contains('football')) {
            return true;
          }
          return false;
        }).toList();
        parsed = filtered;
      } catch (e) {
        NumberedLogger.e('❌ Failed Overpass wide query: $e');
      }
      NumberedLogger.d(
          '🔍 Overpass Response (wide filtered): ${parsed.length} elements found');
    }

    // Final fallback: radius search around Den Bosch center
    if (parsed.isEmpty) {
      const double fallbackLat = 51.6978;
      const double fallbackLon = 5.3037;
      const int radiusMeters = 15000; // 15km

      final fallbackQuery = '''
      [out:json][timeout:25];
      (
        nwr(around:$radiusMeters,$fallbackLat,$fallbackLon)["sport"="$sportType"];
        nwr(around:$radiusMeters,$fallbackLat,$fallbackLon)["leisure"="pitch"]["sport"="$sportType"];
        nwr(around:$radiusMeters,$fallbackLat,$fallbackLon)["leisure"="stadium"]["sport"="$sportType"];
      );
      out center tags qt;
      ''';
      NumberedLogger.d('🔍 Overpass Fallback Query (radius):\n$fallbackQuery');
      try {
        final fbBody = await _postOverpass(fallbackQuery);
        parsed = _parseOverpassData(fbBody);
      } catch (e) {
        NumberedLogger.e('❌ Failed Overpass fallback (radius): $e');
      }
      NumberedLogger.d(
          '🔍 Overpass Fallback Response: ${parsed.length} elements found');
    }

    // Only cache if we actually got something
    if (parsed.isNotEmpty) {
      await _cacheData(cacheKey, parsed);
    }
    return parsed;
  }

  /// Fetch fields for multiple sports within a named area.
  Future<List<Map<String, dynamic>>> fetchMultipleFields({
    required String areaName,
    required List<String> sportTypes, // e.g., ["soccer","basketball","tennis"]
    bool bypassCache = false,
  }) async {
    final cacheKey = 'multi_${areaName}_${sportTypes.join("_")}';

    if (!bypassCache) {
      final cached = await _getCachedData(cacheKey);
      if (cached != null) return cached;
    }

    final areaSel = _areaSelector(areaName);
    final sportFilters = sportTypes.map((sport) => '''
  nwr["sport"="$sport"]["access"!="private"]["access"!="no"](area.searchArea);
''').join();

    final query = '''
[out:json][timeout:25];
$areaSel
(
$sportFilters
);
out center tags qt;
''';

    final body = await _postOverpass(query);
    final parsed = _parseOverpassData(body);

    if (parsed.isNotEmpty) {
      await _cacheData(cacheKey, parsed);
    }
    return parsed;
  }

  // ---------- Internals ----------

  // Builds an area selector. Accepts plain names (preferred) or already-quoted.
  String _areaSelector(String areaName) {
    // Use Overpass geocodeArea macro for robust area lookup
    // Match user's expected form: {{geocodeArea:'s-Hertogenbosch'}}->.searchArea;
    final startsWithQuote =
        areaName.startsWith("'") || areaName.startsWith('"');
    final endsWithQuote = areaName.endsWith("'") || areaName.endsWith('"');
    final alreadyQuoted = startsWithQuote && endsWithQuote;
    final value = alreadyQuoted ? areaName : "'$areaName'";
    return '{{geocodeArea:$value}}->.searchArea;';
  }

  // Add a country disambiguator if none is present (e.g., “, Netherlands”).
  String _areaSelectorWithCountry(String areaName) {
    if (areaName.contains(',')) {
      return _areaSelector(areaName);
    }
    return _areaSelector('$areaName, Netherlands');
  }

  String _buildSportQuery(String areaSel, String sportType) {
    return '''
[out:json][timeout:25];
$areaSel
(
  nwr["sport"="$sportType"](area.searchArea);
  nwr["leisure"="pitch"]["sport"="$sportType"](area.searchArea);
  nwr["leisure"="stadium"]["sport"="$sportType"](area.searchArea);
);
out center tags qt;
''';
  }

  // Rotate through mirrors with timeout. Throws the last error if all fail.
  Future<String> _postOverpass(String query) async {
    Exception? lastError;
    for (final url in _endpoints) {
      try {
        NumberedLogger.d('🔌 Overpass POST -> $url');
        final resp = await http.post(
          Uri.parse(url),
          headers: _headers,
          body: {'data': query},
        ).timeout(const Duration(seconds: 20));
        if (resp.statusCode == 200) return resp.body;

        final head =
            resp.body.length > 500 ? resp.body.substring(0, 500) : resp.body;
        lastError =
            Exception('Overpass error ${resp.statusCode} at $url\n$head');
      } on SocketException catch (e) {
        lastError = e;
      } on TimeoutException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }
    throw lastError ?? Exception('All Overpass endpoints failed');
  }

  // Parse Overpass JSON and normalize lat/lon for nodes and ways/relations.
  List<Map<String, dynamic>> _parseOverpassData(String responseBody) {
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final elements = (data['elements'] as List).cast<Map<String, dynamic>>();

    return elements
        .map<Map<String, dynamic>>((e) {
          final tags = Map<String, dynamic>.from(e['tags'] ?? {});
          final String elementType = (e['type'] ?? '').toString();
          final String elementId = (e['id'] ?? '').toString();
          final num? nLat = e['lat'] as num?;
          final num? nLon = e['lon'] as num?;
          final num? cLat =
              e['center'] != null ? e['center']['lat'] as num? : null;
          final num? cLon =
              e['center'] != null ? e['center']['lon'] as num? : null;
          final double? lat = (nLat ?? cLat)?.toDouble();
          final double? lon = (nLon ?? cLon)?.toDouble();

          if (lat == null || lon == null) {
            return {}; // skip items without coords
          }

          return {
            'id': elementId.isNotEmpty
                ? '${elementType.isNotEmpty ? '$elementType:' : ''}$elementId'
                : null,
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
  }

  // --------- Simple key/value cache (SharedPreferences) ---------

  Future<void> _cacheData(String key, List<Map<String, dynamic>> data) async {
    if (_prefs == null) return; // caching disabled when prefs unavailable
    final entry = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': DateTime.now().add(_cacheDuration).millisecondsSinceEpoch,
      'data': data,
    };
    await _prefs!.setString(key, jsonEncode(entry));
  }

  Future<List<Map<String, dynamic>>?> _getCachedData(String key) async {
    if (_prefs == null) return null; // no cache
    final jsonString = _prefs!.getString(key);
    if (jsonString == null) return null;

    final Map<String, dynamic> json = jsonDecode(jsonString);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (json['expiry'] < now) return null;

    final List<dynamic> rawData = json['data'];
    return rawData
        .map<Map<String, dynamic>>((item) {
          final map = Map<String, dynamic>.from(item);
          final lat = map['lat'];
          final lon = map['lon'];
          return {
            ...map,
            'lat':
                lat is num ? lat.toDouble() : double.tryParse(lat.toString()),
            'lon':
                lon is num ? lon.toDouble() : double.tryParse(lon.toString()),
          };
        })
        .where((e) => e['lat'] != null && e['lon'] != null)
        .toList();
  }
}
