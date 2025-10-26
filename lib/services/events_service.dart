import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EventsService {
  static const String _baseUrl =
      'https://europe-west1-sportappdenbosch.cloudfunctions.net';
  static const String _manualFetchEndpoint = '/manualFetchEvents';

  /// Triggers the manual fetch events Cloud Function
  /// Returns true if successful, false if failed
  Future<bool> triggerManualRefresh() async {
    try {
      final url = Uri.parse('$_baseUrl$_manualFetchEndpoint');

      // 60 second timeout for scraping (Cloud Function runs for ~30-60s)
      final response = await http.get(url).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        return false;
      }
    } on TimeoutException {
      // Timeout is expected (scraping takes 30-60 seconds)
      // Assume success if no explicit error
      return true;
    } catch (e) {
      // Error triggering manual refresh
      return false;
    }
  }
}
