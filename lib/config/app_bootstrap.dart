import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

/// Centralized bootstrap utility to initialize platform services in order.
class AppBootstrap {
  /// Initializes Firebase, AppCheck, Crashlytics, background messaging,
  /// and optionally pre-warms SharedPreferences and Local Notifications.
  static Future<void> initialize({
    bool initializeLocalNotifications = false,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) async {
    // Firebase core
    await _initFirebase();

    // Background messaging handler registration
    _registerBackgroundMessaging();

    // AppCheck and Crashlytics
    await _initAppCheck();
    await _initCrashlytics();

    // Optionally pre-warm SharedPreferences
    unawaited(_warmSharedPreferences());

    // Optionally pre-initialize local notifications
    if (initializeLocalNotifications && localNotifications != null) {
      unawaited(_warmLocalNotifications(localNotifications));
    }
  }

  static Future<void> _initFirebase() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (_) {}
  }

  static void _registerBackgroundMessaging() {
    try {
      FirebaseMessaging.onBackgroundMessage((RemoteMessage message) async {
        // Minimal safe logging; avoid heavy work here
        debugPrint('BG message: \\${message.messageId}');
      });
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

  static Future<void> _warmSharedPreferences() async {
    try {
      await SharedPreferences.getInstance();
    } catch (_) {}
  }

  static Future<void> _warmLocalNotifications(
      FlutterLocalNotificationsPlugin plugin) async {
    try {
      await plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ));
    } catch (_) {}
  }
}


