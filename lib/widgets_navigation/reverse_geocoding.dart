import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:easy_localization/easy_localization.dart';

Future<String> getNearestStreetName(double lat, double lon) async {
  final url = Uri.parse(
    'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json',
  );

  final response = await http.get(url, headers: {
    'User-Agent': 'MoveYoungApp/1.0 (luisfccfigueiredo@gmail.com)' // Required
  });

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final address = data['address'];
    return address['road'] ??
        address['pedestrian'] ??
        address['neighbourhood'] ??
        address['suburb'] ??
        'Unnamed Location';
  } else {
    return 'unnamed_location'.tr();
  }
}
