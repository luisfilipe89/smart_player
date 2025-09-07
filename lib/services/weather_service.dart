// lib/services/weather_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WeatherService {
  static const _cacheDuration = Duration(hours: 6);

  // OpenWeatherMap API configuration
  static const String _apiKey =
      'b34985774d1368cef8b4947bfb8cc7de'; // Replace with your API key
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  static const String _oneCallUrl = '$_baseUrl/onecall';

  // Weather condition types
  static const String sunny = 'sunny';
  static const String cloudy = 'cloudy';
  static const String rainy = 'rainy';
  static const String night = 'night';
  static const String partlyCloudy = 'partly_cloudy';
  static const String overcast = 'overcast';
  static const String thunderstorm = 'thunderstorm';
  static const String snow = 'snow';
  static const String fog = 'fog';

  // Weather data models
  static Map<String, dynamic> _parseWeatherCondition(
      int weatherId, String time) {
    final hour = int.parse(time.split(':')[0]);
    final isNight = hour >= 19 || hour < 7;

    // Map OpenWeatherMap condition codes to our conditions
    String condition;
    IconData icon;
    Color color;

    if (weatherId >= 200 && weatherId < 300) {
      // Thunderstorm
      condition = thunderstorm;
      icon = Icons.flash_on;
      color = const Color(0xFF6A4C93);
    } else if (weatherId >= 300 && weatherId < 400) {
      // Drizzle
      condition = rainy;
      icon = Icons.grain;
      color = const Color(0xFF007AFF);
    } else if (weatherId >= 500 && weatherId < 600) {
      // Rain
      condition = rainy;
      icon = Icons.grain;
      color = const Color(0xFF007AFF);
    } else if (weatherId >= 600 && weatherId < 700) {
      // Snow
      condition = snow;
      icon = Icons.ac_unit;
      color = const Color(0xFF8E8E93);
    } else if (weatherId >= 700 && weatherId < 800) {
      // Atmosphere (fog, mist, etc.)
      condition = fog;
      icon = Icons.foggy;
      color = const Color(0xFF8E8E93);
    } else if (weatherId == 800) {
      // Clear sky
      condition = isNight ? night : sunny;
      icon = isNight ? Icons.nightlight_round : Icons.wb_sunny;
      color = isNight ? const Color(0xFF5856D6) : const Color(0xFFFF9500);
    } else if (weatherId == 801) {
      // Few clouds
      condition = isNight ? night : partlyCloudy;
      icon = isNight ? Icons.nightlight_round : Icons.wb_cloudy;
      color = isNight ? const Color(0xFF5856D6) : const Color(0xFF8E8E93);
    } else if (weatherId >= 802 && weatherId <= 804) {
      // Cloudy to overcast
      condition = isNight ? night : (weatherId == 804 ? overcast : cloudy);
      icon = isNight ? Icons.nightlight_round : Icons.cloud;
      color = isNight ? const Color(0xFF5856D6) : const Color(0xFF8E8E93);
    } else {
      // Default
      condition = isNight ? night : sunny;
      icon = isNight ? Icons.nightlight_round : Icons.wb_sunny;
      color = isNight ? const Color(0xFF5856D6) : const Color(0xFFFF9500);
    }

    return {
      'condition': condition,
      'icon': icon,
      'color': color,
    };
  }

  // Get weather icon for a specific time and condition (iOS-style)
  static IconData getWeatherIcon(String time, [String? condition]) {
    final hour = int.parse(time.split(':')[0]);
    final isNight = hour >= 19 || hour < 7;

    // If condition is provided, use it; otherwise fall back to time-based logic
    if (condition != null) {
      switch (condition) {
        case sunny:
          return isNight ? Icons.nightlight_round : Icons.wb_sunny;
        case partlyCloudy:
          return isNight ? Icons.nightlight_round : Icons.wb_cloudy;
        case cloudy:
        case overcast:
          return isNight ? Icons.nightlight_round : Icons.cloud;
        case rainy:
          return Icons.grain;
        case thunderstorm:
          return Icons.flash_on;
        case snow:
          return Icons.ac_unit;
        case fog:
          return Icons.foggy;
        case night:
          return Icons.nightlight_round;
        default:
          return isNight ? Icons.nightlight_round : Icons.wb_sunny;
      }
    }

    // Fallback to time-based logic if no condition provided
    if (isNight) {
      return Icons.nightlight_round;
    }

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
      case partlyCloudy:
        return const Color(0xFF8E8E93); // iOS grey
      case cloudy:
      case overcast:
        return const Color(0xFF8E8E93); // iOS grey
      case rainy:
        return const Color(0xFF007AFF); // iOS blue
      case thunderstorm:
        return const Color(0xFF6A4C93); // Purple
      case snow:
        return const Color(0xFF8E8E93); // iOS grey
      case fog:
        return const Color(0xFF8E8E93); // iOS grey
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
    final cacheKey =
        'weather_${date.toIso8601String().split('T')[0]}_${latitude}_$longitude';

    if (!bypassCache) {
      final cached = await _getCachedData(cacheKey);
      if (cached != null) return cached;
    }

    try {
      // Check if API key is configured
      if (_apiKey == 'YOUR_API_KEY_HERE') {
        print('Weather API key not configured. Using fallback data.');
        return <String, String>{}; // Return empty map instead of dummy data
      }

      print('🌤️ Weather API key found: ${_apiKey.substring(0, 8)}...');

      // Call OpenWeatherMap One Call API
      final url =
          '$_oneCallUrl?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric&exclude=minutely,alerts';
      print('🌐 Calling weather API: $url');

      final response = await http.get(Uri.parse(url));
      print('📡 Weather API response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final weatherData = <String, String>{};

        // Get hourly forecast for the selected date
        final hourlyForecast = data['hourly'] as List<dynamic>;
        final targetDate = DateTime(date.year, date.month, date.day);

        for (final hourData in hourlyForecast) {
          final hourDateTime = DateTime.fromMillisecondsSinceEpoch(
            (hourData['dt'] as int) * 1000,
          );

          // Check if this hour is on our target date and within our time range (9-21)
          if (hourDateTime.year == targetDate.year &&
              hourDateTime.month == targetDate.month &&
              hourDateTime.day == targetDate.day &&
              hourDateTime.hour >= 9 &&
              hourDateTime.hour <= 21) {
            final time = '${hourDateTime.hour.toString().padLeft(2, '0')}:00';
            final weather = hourData['weather'][0] as Map<String, dynamic>;
            final weatherId = weather['id'] as int;

            final parsed = _parseWeatherCondition(weatherId, time);
            weatherData[time] = parsed['condition'] as String;
          }
        }

        // If no data found for the date, use current day's data
        if (weatherData.isEmpty) {
          final currentDate = DateTime.now();
          if (date.year == currentDate.year &&
              date.month == currentDate.month &&
              date.day == currentDate.day) {
            // Use today's hourly data
            for (int i = 0; i < hourlyForecast.length && i < 13; i++) {
              final hourData = hourlyForecast[i];
              final hourDateTime = DateTime.fromMillisecondsSinceEpoch(
                (hourData['dt'] as int) * 1000,
              );

              if (hourDateTime.hour >= 9 && hourDateTime.hour <= 21) {
                final time =
                    '${hourDateTime.hour.toString().padLeft(2, '0')}:00';
                final weather = hourData['weather'][0] as Map<String, dynamic>;
                final weatherId = weather['id'] as int;

                final parsed = _parseWeatherCondition(weatherId, time);
                weatherData[time] = parsed['condition'] as String;
              }
            }
          }
        }

        // If still no data, return empty
        if (weatherData.isEmpty) {
          print('⚠️ No weather data found for selected date');
          return <String, String>{}; // Return empty map instead of dummy data
        }

        print(
            '✅ Weather data parsed successfully: ${weatherData.length} hours');
        await _cacheData(cacheKey, weatherData);
        return weatherData;
      } else {
        print('One Call API error: ${response.statusCode} - ${response.body}');
        print('Trying basic weather API as fallback...');
        return await _getBasicWeatherData(latitude, longitude);
      }
    } catch (e) {
      print('Error fetching weather: $e');
      return <String, String>{}; // Return empty map instead of dummy data
    }
  }

  // Basic weather API fallback when One Call API fails
  static Future<Map<String, String>> _getBasicWeatherData(
      double latitude, double longitude) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/weather?lat=$latitude&lon=$longitude&appid=$_apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final weatherId = data['weather'][0]['id'] as int;
        final conditionData = _parseWeatherCondition(weatherId, '12:00');
        final condition = conditionData['condition'] as String;

        print('✅ Basic weather API successful: $condition');

        // Create weather data for all hours with the same condition
        final weatherData = <String, String>{};
        for (int hour = 9; hour <= 21; hour++) {
          final time = '${hour.toString().padLeft(2, '0')}:00';
          weatherData[time] = condition;
        }

        return weatherData;
      } else {
        print('Basic weather API error: ${response.statusCode}');
        return <String, String>{}; // Return empty map instead of dummy data
      }
    } catch (e) {
      print('Basic weather API error: $e');
      return <String, String>{}; // Return empty map instead of dummy data
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
