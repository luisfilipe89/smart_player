import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'weather_service_instance.dart';
import 'package:move_young/providers/infrastructure/shared_preferences_provider.dart';

// Weather service provider
final weatherServiceProvider = Provider<WeatherServiceInstance>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  // WeatherServiceInstance accepts nullable SharedPreferences
  final prefs = prefsAsync.valueOrNull;
  return WeatherServiceInstance(prefs);
});

// Weather actions provider
final weatherActionsProvider = Provider<WeatherActions>((ref) {
  final weatherService = ref.watch(weatherServiceProvider);
  return WeatherActions(weatherService);
});

class WeatherActions {
  final WeatherServiceInstance _weatherService;

  WeatherActions(this._weatherService);

  Future<Map<String, String>> fetchWeatherForDate({
    required DateTime date,
    required double latitude,
    required double longitude,
    bool bypassCache = false,
  }) async {
    return await _weatherService.fetchWeatherForDate(
      date: date,
      latitude: latitude,
      longitude: longitude,
      bypassCache: bypassCache,
    );
  }

  // Expose static methods through instance
  String getWeatherCondition(String time) =>
      _weatherService.getWeatherCondition(time);
  Color getWeatherColor(String condition) =>
      _weatherService.getWeatherColor(condition);
  IconData getWeatherIcon(String time, [String? condition]) =>
      _weatherService.getWeatherIcon(time, condition);
}
