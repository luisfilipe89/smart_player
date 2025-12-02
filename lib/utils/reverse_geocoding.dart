import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';

/// Gets the nearest street name for given coordinates using OpenStreetMap Nominatim.
///
/// Performs reverse geocoding to convert latitude/longitude coordinates
/// into a human-readable street name. Falls back to pedestrian paths,
/// neighbourhoods, or suburbs if no road name is available.
///
/// [lat] - Latitude coordinate
/// [lon] - Longitude coordinate
///
/// Returns the street name, or a localized "Unnamed Location" string if
/// geocoding fails or no address is found.
///
/// Note: Requires a User-Agent header per Nominatim usage policy.
Future<String> getNearestStreetName(double lat, double lon) async {
  final url = Uri.parse(
    'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json',
  );

  final response = await http.get(url, headers: {
    'User-Agent':
        'MoveYoungApp/1.0 (luisfccfigueiredo@gmail.com)' // Required by Nominatim
  });

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final address = data['address'];
    // Try road first, then fallback to other address components
    return address['road'] ??
        address['pedestrian'] ??
        address['neighbourhood'] ??
        address['suburb'] ??
        'Unnamed Location';
  } else {
    return 'unnamed_location'.tr();
  }
}
