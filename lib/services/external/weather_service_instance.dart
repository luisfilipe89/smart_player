// lib/services/weather_service_instance.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:move_young/utils/logger.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WeatherServiceInstance {
  final SharedPreferences? _prefs;

  static const _cacheDuration =
      Duration(hours: 2); // Shorter cache for more accurate data

  // Open-Meteo API configuration
  static const String _knmiUrl = 'https://api.open-meteo.com/v1/forecast';

  // Weather condition types
  static const String sunny = 'sunny';
  static const String cloudy = 'cloudy';
  static const String rainy = 'rainy';
  static const String lightRain = 'light_rain';
  static const String moderateRain = 'moderate_rain';
  static const String heavyRain = 'heavy_rain';
  static const String drizzle = 'drizzle';
  static const String night = 'night';
  static const String partlyCloudy = 'partly_cloudy';
  static const String overcast = 'overcast';
  static const String thunderstorm = 'thunderstorm';
  static const String snow = 'snow';
  static const String fog = 'fog';

  WeatherServiceInstance(this._prefs);

  // Parse KNMI weather data to our conditions
  Map<String, dynamic> _parseKNMIWeatherData({
    required String time,
    required double precipitation,
    required double cloudCover,
    required double temperature,
    required bool isDaytime,
  }) {
    final hour = int.parse(time.split(':')[0]);
    final isNight = !isDaytime || hour >= 19 || hour < 7;

    String condition;
    IconData icon;
    Color color;

    // Determine condition based on precipitation and cloud cover
    // Be more conservative about rain detection to avoid "blue suns"
    if (precipitation > 0.2) {
      // Increased threshold from 0 to 0.2mm
      // Rain conditions based on precipitation intensity
      if (precipitation < 1.0) {
        // Increased from 0.5
        condition = drizzle;
        icon = Icons.grain;
        color = const Color(0xFF5AC8FA); // Light blue for drizzle
      } else if (precipitation < 3.0) {
        // Increased from 2.0
        condition = lightRain;
        icon = Icons.grain;
        color = const Color(0xFF5AC8FA);
      } else if (precipitation < 7.0) {
        // Increased from 5.0
        condition = moderateRain;
        icon = Icons.umbrella;
        color = const Color(0xFF007AFF);
      } else {
        condition = heavyRain;
        icon = Icons.umbrella;
        color = const Color(0xFF0047AB);
      }
    } else if (cloudCover > 80) {
      // Overcast
      condition = isNight ? night : overcast;
      icon = isNight ? Icons.nightlight_round : Icons.cloud_queue;
      color = isNight ? const Color(0xFF5856D6) : const Color(0xFF8E8E93);
    } else if (cloudCover > 50) {
      // Cloudy
      condition = isNight ? night : cloudy;
      icon = isNight ? Icons.nightlight_round : Icons.cloud;
      color = isNight ? const Color(0xFF5856D6) : const Color(0xFF8E8E93);
    } else if (cloudCover > 30) {
      // Increased from 20 to be more generous with sunny
      // Partly cloudy
      condition = isNight ? night : partlyCloudy;
      icon = isNight ? Icons.nightlight_round : Icons.wb_cloudy;
      color = isNight ? const Color(0xFF5856D6) : const Color(0xFF8E8E93);
    } else {
      // Clear/Sunny - be more generous with sunny conditions
      condition = isNight ? night : sunny;
      icon = isNight ? Icons.nightlight_round : Icons.wb_sunny;
      color = isNight
          ? const Color(0xFF5856D6)
          : const Color(0xFFFF9500); // Orange for sunny
    }

    // Fallback: If we're in daytime hours and have very low precipitation,
    // default to sunny to avoid "blue suns"
    if (!isNight && precipitation <= 0.1 && cloudCover <= 40) {
      condition = sunny;
      icon = Icons.wb_sunny;
      color = const Color(0xFFFF9500); // Orange for sunny
    }

    // Debug logging for weather conditions
    NumberedLogger.d(
        'Weather parsed - Time: $time, Precip: $precipitation, Clouds: $cloudCover, IsDay: $isDaytime, Condition: $condition, Color: ${color.toARGB32().toRadixString(16)}');

    return {
      'condition': condition,
      'icon': icon,
      'color': color,
    };
  }

  // Get weather icon for a specific time and condition (iOS-style)
  IconData getWeatherIcon(String time, [String? condition]) {
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
          return isNight ? Icons.nightlight_round : Icons.cloud;
        case overcast:
          return isNight ? Icons.nightlight_round : Icons.cloud_queue;
        case lightRain:
        case drizzle:
          return Icons.grain;
        case moderateRain:
        case heavyRain:
        case rainy:
          return Icons.umbrella;
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
  String getWeatherCondition(String time) {
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
  Color getWeatherColor(String condition) {
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
      case lightRain:
        return const Color(0xFF5AC8FA); // Light blue
      case moderateRain:
        return const Color(0xFF007AFF); // iOS blue
      case heavyRain:
        return const Color(0xFF0047AB); // Dark blue
      case drizzle:
        return const Color(0xFF5AC8FA); // Light blue
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

  // Fetch weather data for a specific date and location using KNMI
  Future<Map<String, String>> fetchWeatherForDate({
    required DateTime date,
    required double latitude,
    required double longitude,
    bool bypassCache = false,
  }) async {
    final cacheKey =
        'openmeteo_weather_${date.toIso8601String().split('T')[0]}_${latitude}_$longitude';

    if (!bypassCache) {
      final cached = await _getCachedData(cacheKey);
      if (cached != null) return cached;
    }

    try {
      // Calculate date range for API call
      final startDate = date.toIso8601String().split('T')[0];
      final endDate =
          date.add(const Duration(days: 1)).toIso8601String().split('T')[0];

      // Build Open-Meteo API URL with required parameters
      final url = Uri.parse(_knmiUrl).replace(queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'start_date': startDate,
        'end_date': endDate,
        'hourly': 'precipitation,cloud_cover,temperature_2m,is_day',
        'timezone': 'Europe/Amsterdam',
      });

      NumberedLogger.d('🌤️ Fetching Open-Meteo weather data: $url');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final weatherData = <String, String>{};

        // Parse hourly data
        final hourly = data['hourly'] as Map<String, dynamic>;
        final times = hourly['time'] as List<dynamic>;
        final precipitation = hourly['precipitation'] as List<dynamic>;
        final cloudCover = hourly['cloud_cover'] as List<dynamic>;
        final temperature = hourly['temperature_2m'] as List<dynamic>;
        final isDay = hourly['is_day'] as List<dynamic>;

        // Find data for our target date
        for (int i = 0; i < times.length; i++) {
          final timeString = times[i] as String;
          final hourDateTime = DateTime.parse(timeString);

          // Check if this hour is on our target date and within our time range (9-21)
          if (hourDateTime.year == date.year &&
              hourDateTime.month == date.month &&
              hourDateTime.day == date.day &&
              hourDateTime.hour >= 9 &&
              hourDateTime.hour <= 21) {
            final time = '${hourDateTime.hour.toString().padLeft(2, '0')}:00';
            final precip = (precipitation[i] as num).toDouble();
            final clouds = (cloudCover[i] as num).toDouble();
            final temp = (temperature[i] as num).toDouble();
            final isDaytime = (isDay[i] as num) == 1;

            final parsed = _parseKNMIWeatherData(
              time: time,
              precipitation: precip,
              cloudCover: clouds,
              temperature: temp,
              isDaytime: isDaytime,
            );

            weatherData[time] = parsed['condition'] as String;
          }
        }

        // If no hourly data found, try daily data
        if (weatherData.isEmpty) {
          final daily = data['daily'] as Map<String, dynamic>?;
          if (daily != null) {
            final dailyTimes = daily['time'] as List<dynamic>;
            final dailyPrecipitation =
                daily['precipitation_sum'] as List<dynamic>;
            final dailyCloudCover = daily['cloud_cover_mean'] as List<dynamic>;
            final dailyTemperature =
                daily['temperature_2m_mean'] as List<dynamic>;

            // Find the day that matches our target date
            for (int i = 0; i < dailyTimes.length; i++) {
              final dayTimeString = dailyTimes[i] as String;
              final dayDateTime = DateTime.parse(dayTimeString);

              if (dayDateTime.year == date.year &&
                  dayDateTime.month == date.month &&
                  dayDateTime.day == date.day) {
                final precip = (dailyPrecipitation[i] as num).toDouble();
                final clouds = (dailyCloudCover[i] as num).toDouble();
                final temp = (dailyTemperature[i] as num).toDouble();

                // Create weather data for all hours using daily data
                for (int hour = 9; hour <= 21; hour++) {
                  final time = '${hour.toString().padLeft(2, '0')}:00';
                  final isDaytime = hour >= 7 && hour <= 19;

                  final parsed = _parseKNMIWeatherData(
                    time: time,
                    precipitation: precip /
                        13, // Distribute daily precipitation across hours
                    cloudCover: clouds,
                    temperature: temp,
                    isDaytime: isDaytime,
                  );

                  weatherData[time] = parsed['condition'] as String;
                }
                break;
              }
            }
          }
        }

        // Cache and return data
        if (weatherData.isNotEmpty) {
          await _cacheData(cacheKey, weatherData);
          NumberedLogger.d(
              '🌤️ Open-Meteo weather data fetched successfully: ${weatherData.length} hours');
          NumberedLogger.d('🌤️ Weather data: $weatherData');
        } else {
          NumberedLogger.w('No Open-Meteo weather data found for date: $date');
          NumberedLogger.d('API Response: ${response.body}');
        }

        return weatherData;
      } else {
        NumberedLogger.w(
            '🌤️ Open-Meteo API error: ${response.statusCode} - ${response.body}');
        return <String, String>{};
      }
    } catch (e) {
      NumberedLogger.e('🌤️ Error fetching Open-Meteo weather data: $e');
      return <String, String>{};
    }
  }

  // Cache weather data
  Future<void> _cacheData(String key, Map<String, String> data) async {
    if (_prefs == null) return; // Cache disabled when prefs unavailable
    final entry = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiry': DateTime.now().add(_cacheDuration).millisecondsSinceEpoch,
      'data': data,
    };
    await _prefs!.setString(key, jsonEncode(entry));
  }

  // Get cached weather data
  Future<Map<String, String>?> _getCachedData(String key) async {
    if (_prefs == null) return null; // No cache
    final jsonString = _prefs!.getString(key);
    if (jsonString == null) return null;

    final Map<String, dynamic> json = jsonDecode(jsonString);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (json['expiry'] < now) return null;

    return Map<String, String>.from(json['data']);
  }
}
