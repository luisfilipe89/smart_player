import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:move_young/firebase_options.dart';
import 'package:move_young/services/calendar/calendar_service.dart';

/// Centralized bootstrap utility to initialize platform services in order.
class AppBootstrap {
  /// Initializes only critical Firebase services synchronously.
  /// Returns immediately after Firebase core is initialized.
  /// Non-critical services are deferred to initializeDeferred().
  static Future<void> initialize() async {
    // Only initialize Firebase core - this is critical for app functionality
    await _initFirebase();

    // Enable Crashlytics immediately for error reporting
    // This is lightweight and should be available early
    unawaited(_initCrashlytics());
  }

  /// Initializes non-critical Firebase services after first frame.
  /// Call this from addPostFrameCallback to avoid blocking startup.
  /// Note: Background message handler is registered in main() before Firebase init
  /// (Firebase requirement), but the background FlutterEngine creation happens lazily.
  static Future<void> initializeDeferred() async {
    // AppCheck and Analytics - non-critical for first frame
    unawaited(_initAppCheck());
    unawaited(_initAnalytics());

    // Optionally pre-warm SharedPreferences
    unawaited(_warmSharedPreferences());

    // Initialize CalendarService - non-critical, can be deferred
    unawaited(_initCalendarService());
  }

  static Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {}
  }

  static Future<void> _initAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
        webProvider: ReCaptchaV3Provider('auto'),
      );
    } catch (_) {}
  }

  static Future<void> _initCrashlytics() async {
    try {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    } catch (_) {}
  }

  static Future<void> _initAnalytics() async {
    try {
      // Firebase Analytics is automatically initialized when Firebase.initializeApp() is called
      // Defer logAppOpen() to avoid blocking startup - it's just a metric
      // This will be called after first frame for better startup performance
      await Future.delayed(const Duration(milliseconds: 500));
      await FirebaseAnalytics.instance.logAppOpen();
    } catch (_) {
      // Analytics initialization is optional and may fail in some environments
    }
  }

  static Future<void> _warmSharedPreferences() async {
    try {
      await SharedPreferences.getInstance();
    } catch (_) {}
  }

  static Future<void> _initCalendarService() async {
    try {
      await CalendarService.initialize();
    } catch (_) {
      // Calendar service initialization is optional and may fail
      // if permissions are not granted or calendar is not available
    }
  }
}
