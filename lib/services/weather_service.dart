// lib/services/weather_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WeatherService {
  static const _cacheDuration = Duration(hours: 6);

  // Weather condition types
  static const String sunny = 'sunny';
  static const String cloudy = 'cloudy';
  static const String rainy = 'rainy';
  static const String night = 'night';

  // Get weather icon for a specific time (iOS-style)
  static IconData getWeatherIcon(String time) {
    final hour = int.parse(time.split(':')[0]);

    // Determine if it's night time (after 19:00 or before 7:00)
    if (hour >= 19 || hour < 7) {
      return Icons.nightlight_round; // Moon icon for night
    }

    // Day time weather based on hour (simplified logic)
    if (hour >= 9 && hour <= 11) {
      return Icons.wb_sunny; // Morning sun
    } else if (hour >= 12 && hour <= 14) {
      return Icons.wb_sunny; // Midday sun
    } else if (hour >= 15 && hour <= 16) {
      return Icons.cloud; // Afternoon clouds
    } else if (hour >= 17 && hour <= 18) {
      return Icons.grain; // Rain icon for evening
    } else {
      return Icons.wb_sunny; // Default to sunny
    }
  }

  // Get weather condition for a specific time
  static String getWeatherCondition(String time) {
    final hour = int.parse(time.split(':')[0]);

    if (hour >= 19 || hour < 7) {
      return night;
    } else if (hour >= 9 && hour <= 11) {
      return sunny; // Morning sun
    } else if (hour >= 12 && hour <= 14) {
      return sunny; // Midday sun
    } else if (hour >= 15 && hour <= 16) {
      return cloudy; // Afternoon clouds
    } else if (hour >= 17 && hour <= 18) {
      return rainy; // Evening rain
    } else {
      return sunny;
    }
  }

  // Get weather color based on condition (iOS-style)
  static Color getWeatherColor(String condition) {
    switch (condition) {
      case sunny:
        return const Color(0xFFFF9500); // iOS orange
      case cloudy:
        return const Color(0xFF8E8E93); // iOS grey
      case rainy:
        return const Color(0xFF007AFF); // iOS blue
      case night:
        return const Color(0xFF5856D6); // iOS purple
      default:
        return const Color(0xFFFF9500); // iOS orange
    }
  }

  // Fetch weather data for a specific date and location
  static Future<Map<String, String>> fetchWeatherForDate({
    required DateTime date,
    required double latitude,
    required double longitude,
    bool bypassCache = false,
  }) async {
    final cacheKey = 'weather___';

    if (!bypassCache) {
      final cached = await _getCachedData(cacheKey);
      if (cached != null) return cached;
    }

    try {
      // For now, return mock weather data
      // In a real implementation, you would call a weather API here
      final weatherData = <String, String>{};

      // Generate mock weather for each hour
      for (int hour = 9; hour <= 21; hour++) {
        final time = ':00';
        weatherData[time] = getWeatherCondition(time);
      }

      // Cache the data
      await _cacheData(cacheKey, weatherData);

      return weatherData;
    } catch (e) {
      // Return default weather data on error
      final weatherData = <String, String>{};
      for (int hour = 9; hour <= 21; hour++) {
        final time = ':00';
        weatherData[time] = sunny; // Default to sunny
      }
      return weatherData;
    }
  }

  // Cache weather data
  static Future<void> _cacheData(String key, Map<String, String> data) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': DateTime.now().add(_cacheDuration).millisecondsSinceEpoch,
      'data': data,
    };
    await prefs.setString(key, jsonEncode(entry));
  }

  // Get cached weather data
  static Future<Map<String, String>?> _getCachedData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(key);
    if (jsonString == null) return null;

    final Map<String, dynamic> json = jsonDecode(jsonString);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (json['expiry'] < now) return null;

    return Map<String, String>.from(json['data']);
  }
}
