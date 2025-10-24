import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/models/game.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages here if needed
  debugPrint('Background message received: ${message.messageId}');
}

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseDatabase _db = FirebaseDatabase.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static StreamSubscription? _authStateSubscription;

  // Navigation callback for handling notification taps
  static Function(String? payload)? _onNotificationTap;

  // Global navigation handler for deep linking
  static Function(Map<String, dynamic>)? _onDeepLinkNavigation;

  // Notification channels
  static const AndroidNotificationChannel _channelDefault =
      AndroidNotificationChannel(
    'smartplayer_default',
    'General',
    description: 'General notifications',
    importance: Importance.defaultImportance,
  );

  static const AndroidNotificationChannel _channelFriends =
      AndroidNotificationChannel(
    'smartplayer_friends',
    'Friends',
    description: 'Friend requests and updates',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _channelGames =
      AndroidNotificationChannel(
    'smartplayer_games',
    'Games',
    description: 'Game invites and updates',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _channelReminders =
      AndroidNotificationChannel(
    'smartplayer_reminders',
    'Reminders',
    description: 'Game reminders',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> initialize(
      {Function(String? payload)? onNotificationTap,
      Function(Map<String, dynamic>)? onDeepLinkNavigation}) async {
    _onNotificationTap = onNotificationTap;
    _onDeepLinkNavigation = onDeepLinkNavigation;

    // Initialize timezone data for scheduled notifications
    try {
      tz.initializeTimeZones();
    } catch (_) {
      // Already initialized
    }

    // Local notifications init with tap handling
    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _onNotificationTap?.call(response.payload);
        }
      },
    );

    // Create all notification channels
    final androidImplementation = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(_channelDefault);
      await androidImplementation.createNotificationChannel(_channelFriends);
      await androidImplementation.createNotificationChannel(_channelGames);
      await androidImplementation.createNotificationChannel(_channelReminders);
    }

    // Ask permission (iOS) and request Android 13+ notification permission
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // On Android 13+ an explicit runtime permission is required
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await permission_handler.Permission.notification.request();
      } catch (_) {}
    }

    // On iOS, ensure notifications are shown when app is in foreground
    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}
    await _saveCurrentToken();
    _messaging.onTokenRefresh.listen((token) => _saveToken(token));

    // Keep FCM token in sync with authentication state (saves right after login)
    try {
      await _authStateSubscription?.cancel();
      _authStateSubscription =
          AuthService.authStateChanges.listen((user) async {
        if (user != null) {
          await _saveCurrentToken();
        }
      });
    } catch (_) {}

    // Foreground messages → show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final n = message.notification;
      if (n == null) return;

      // Check if notifications are enabled
      final enabled = await isNotificationsEnabled();
      if (!enabled) return;

      // Determine channel based on notification type
      final notifType = message.data['type'] ?? 'default';
      String channelId = 'smartplayer_default';
      String channelName = 'General';

      if (notifType.contains('friend')) {
        channelId = 'smartplayer_friends';
        channelName = 'Friends';
      } else if (notifType.contains('game') || notifType.contains('invite')) {
        channelId = 'smartplayer_games';
        channelName = 'Games';
      } else if (notifType.contains('reminder')) {
        channelId = 'smartplayer_reminders';
        channelName = 'Reminders';
      }

      await _local.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: jsonEncode(message.data),
      );
    });

    // Handle notification taps when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _onNotificationTap?.call(jsonEncode(message.data));
    });

    // Check for initial message (app opened from terminated state)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _onNotificationTap?.call(jsonEncode(initialMessage.data));
    }
  }

  // Handle deep link navigation from notifications
  static void handleDeepLinkNavigation(Map<String, dynamic> data) {
    _onDeepLinkNavigation?.call(data);
  }

  // Public helper to force-sync current device token to the signed-in user
  static Future<void> syncFcmToken() async {
    await _saveCurrentToken();
  }

  static Future<void> _saveCurrentToken() async {
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
  }

  static Future<void> _saveToken(String token) async {
    final uid = AuthService.currentUserId;
    if (uid == null) return;
    await _db.ref('users/$uid/fcmTokens/$token').set(true);
  }

  // Schedule game reminders (30 min and 1 hour before game)
  static Future<void> scheduleGameReminder(Game game) async {
    try {
      final enabled = await isNotificationsEnabled();
      if (!enabled) return;

      final now = DateTime.now();
      final gameTime = game.dateTime;

      // Schedule 1 hour reminder
      final oneHourBefore = gameTime.subtract(const Duration(hours: 1));
      if (oneHourBefore.isAfter(now)) {
        await _scheduleNotification(
          id: '${game.id}_1h'.hashCode,
          title: 'Game Starting Soon',
          body: '${game.sport} at ${game.location} starts in 1 hour!',
          scheduledDate: oneHourBefore,
          payload: jsonEncode({
            'type': 'game_reminder',
            'gameId': game.id,
            'route': '/my-games',
          }),
        );
      }

      // Schedule 30 min reminder
      final thirtyMinBefore = gameTime.subtract(const Duration(minutes: 30));
      if (thirtyMinBefore.isAfter(now)) {
        await _scheduleNotification(
          id: '${game.id}_30m'.hashCode,
          title: 'Game Starting Soon',
          body: '${game.sport} at ${game.location} starts in 30 minutes!',
          scheduledDate: thirtyMinBefore,
          payload: jsonEncode({
            'type': 'game_reminder',
            'gameId': game.id,
            'route': '/my-games',
          }),
        );
      }
    } catch (e) {
      debugPrint('Error scheduling game reminder: $e');
    }
  }

  // Cancel game reminders
  static Future<void> cancelGameReminders(String gameId) async {
    try {
      await _local.cancel('${gameId}_1h'.hashCode);
      await _local.cancel('${gameId}_30m'.hashCode);
    } catch (e) {
      debugPrint('Error cancelling game reminders: $e');
    }
  }

  // Schedule a notification at a specific time
  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(
        scheduledDate,
        tz.local,
      );

      await _local.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'smartplayer_reminders',
            'Reminders',
            channelDescription: 'Game reminders',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  // Notification preferences
  static Future<bool> isNotificationsEnabled() async {
    final uid = AuthService.currentUserId;
    if (uid == null) return true; // Default to enabled for guests

    try {
      final snapshot =
          await _db.ref('users/$uid/settings/notifications/enabled').get();
      return snapshot.value != false; // Default to true
    } catch (_) {
      return true;
    }
  }

  static Future<void> setNotificationsEnabled(bool value) async {
    final uid = AuthService.currentUserId;
    if (uid == null) return;
    await _db.ref('users/$uid/settings/notifications/enabled').set(value);
  }

  static Stream<bool> notificationsEnabledStream() {
    final uid = AuthService.currentUserId;
    if (uid == null) return Stream.value(true);

    return _db
        .ref('users/$uid/settings/notifications/enabled')
        .onValue
        .map((e) => e.snapshot.value != false)
        .asBroadcastStream();
  }

  // Legacy preference methods (kept for compatibility)
  static Stream<bool> prefStream(String uid, String key,
      {bool defaultValue = true}) {
    return _db
        .ref('users/$uid/settings/notifications/$key')
        .onValue
        .map((e) => e.snapshot.value != false)
        .asBroadcastStream();
  }

  static Future<void> setPref(String key, bool value) async {
    final uid = AuthService.currentUserId;
    if (uid == null) return;
    await _db.ref('users/$uid/settings/notifications/$key').set(value);
  }

  // Write notification data to database (for server-side FCM triggers)
  static Future<void> writeNotificationData({
    required String recipientUid,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    try {
      debugPrint(
          '🔔 [DEBUG] writeNotificationData called - recipient: $recipientUid, type: $type, data: $data');
      final notificationId = DateTime.now().millisecondsSinceEpoch.toString();

      // Write to notification_requests path instead of directly to user's notifications
      // This allows the client to write, and a Cloud Function will process it
      final requestRef = _db.ref('notification_requests/$notificationId');
      await requestRef.set({
        'recipientUid': recipientUid,
        'type': type,
        'data': data,
        'timestamp': ServerValue.timestamp,
        'read': false,
      });
      debugPrint(
          '🔔 [DEBUG] Notification request written successfully to RTDB');
    } catch (e) {
      debugPrint('🔔 [DEBUG] Error writing notification request: $e');
      debugPrint('Error writing notification request: $e');
    }
  }

  // Category preference methods
  static Future<bool> isCategoryEnabled(String category) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_$category') ?? true;
  }

  static Future<void> setCategoryEnabled(String category, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_$category', enabled);
  }

  /// Dispose resources and cleanup subscriptions
  static Future<void> dispose() async {
    await _authStateSubscription?.cancel();
    _authStateSubscription = null;
  }
}
