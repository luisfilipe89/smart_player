import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/config/_config.dart';

/// Environment configuration
enum Environment {
  development,
  staging,
  production,
}

/// App configuration
class AppConfig {
  final Environment environment;
  final String apiBaseUrl;
  final String firebaseProjectId;
  final bool enableLogging;
  final bool enableCrashReporting;
  final bool enableAnalytics;
  final Map<String, bool> featureFlags;

  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.firebaseProjectId,
    required this.enableLogging,
    required this.enableCrashReporting,
    required this.enableAnalytics,
    required this.featureFlags,
  });

  bool get isDevelopment => environment == Environment.development;
  bool get isStaging => environment == Environment.staging;
  bool get isProduction => environment == Environment.production;

  bool isFeatureEnabled(String feature) {
    return featureFlags[feature] ?? false;
  }
}

// Config provider
final configProvider = Provider<AppConfig>((ref) {
  return _getConfig();
});

/// Get configuration based on environment
AppConfig _getConfig() {
  if (kDebugMode) {
    return const AppConfig(
      environment: Environment.development,
      apiBaseUrl: 'https://dev-api.moveyoung.com',
      firebaseProjectId: 'moveyoung-dev',
      enableLogging: true,
      enableCrashReporting: false,
      enableAnalytics: false,
      featureFlags: {
        'friends': true,
        'games': true,
        'notifications': true,
        'offline_mode': true,
        'debug_mode': true,
      },
    );
  } else if (kProfileMode) {
    return const AppConfig(
      environment: Environment.staging,
      apiBaseUrl: 'https://staging-api.moveyoung.com',
      firebaseProjectId: 'moveyoung-staging',
      enableLogging: true,
      enableCrashReporting: true,
      enableAnalytics: true,
      featureFlags: {
        'friends': true,
        'games': true,
        'notifications': true,
        'offline_mode': true,
        'debug_mode': false,
      },
    );
  } else {
    return const AppConfig(
      environment: Environment.production,
      apiBaseUrl: 'https://api.moveyoung.com',
      firebaseProjectId: 'moveyoung-prod',
      enableLogging: false,
      enableCrashReporting: true,
      enableAnalytics: true,
      featureFlags: {
        'friends': true,
        'games': true,
        'notifications': true,
        'offline_mode': true,
        'debug_mode': false,
      },
    );
  }
}

// Sport characteristics provider
final sportCharacteristicsProvider = Provider<SportCharacteristics>((ref) {
  return SportCharacteristics();
});

// Sport display provider
final sportDisplayProvider = Provider<SportDisplayRegistry>((ref) {
  return SportDisplayRegistry();
});

// Sport filters provider
final sportFiltersProvider = Provider<SportFiltersRegistry>((ref) {
  return SportFiltersRegistry();
});
