// lib/services/overpass_service_instance.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OverpassServiceInstance {
  final SharedPreferences _prefs;

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

    final areaSel = _areaSelector(areaName);

    final query = '''
    [out:json][timeout:25];
    $areaSel
    (
      nwr["sport"="$sportType"]["access"!="private"]["access"!="no"](area.searchArea);
      ${sportType == 'beachvolleyball' ? '''
      nwr["sport"="volleyball"]["surface"="sand"]["access"!="private"]["access"!="no"](area.searchArea);
      ''' : ''}
    );
    out center tags qt;
    ''';

    final body = await _postOverpass(query);
    final parsed = _parseOverpassData(body);

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
    final startsWithQuote =
        areaName.startsWith('"') || areaName.startsWith("'");
    final endsWithQuote = areaName.endsWith('"') || areaName.endsWith("'");
    final alreadyQuoted = startsWithQuote && endsWithQuote;

    // Always wrap with double quotes unless caller passed a fully quoted string already
    final value = alreadyQuoted ? areaName : '"$areaName"';
    return 'area["name"=$value]->.searchArea;';
  }

  // Rotate through mirrors with timeout. Throws the last error if all fail.
  Future<String> _postOverpass(String query) async {
    Exception? lastError;
    for (final url in _endpoints) {
      try {
        final resp = await http.post(Uri.parse(url),
            headers: _headers,
            body: {'data': query}).timeout(const Duration(seconds: 45));
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
    final entry = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': DateTime.now().add(_cacheDuration).millisecondsSinceEpoch,
      'data': data,
    };
    await _prefs.setString(key, jsonEncode(entry));
  }

  Future<List<Map<String, dynamic>>?> _getCachedData(String key) async {
    final jsonString = _prefs.getString(key);
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
