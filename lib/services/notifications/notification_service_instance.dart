// lib/services/notification_service_instance.dart
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:move_young/utils/logger.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'notification_interface.dart';

/// Instance-based NotificationService for use with Riverpod dependency injection
class NotificationServiceInstance implements INotificationService {
  final FirebaseMessaging _messaging;
  final FirebaseDatabase _db;
  final FlutterLocalNotificationsPlugin _local;

  StreamSubscription? _authStateSubscription;

  // Navigation callback for handling notification taps
  Function(String? payload)? _onNotificationTap;

  // Global navigation handler for deep linking
  Function(Map<String, dynamic>)? _onDeepLinkNavigation;

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

  NotificationServiceInstance(
    this._messaging,
    this._db,
    this._local,
  );

  Future<void> initialize({
    Function(String? payload)? onNotificationTap,
    Function(Map<String, dynamic>)? onDeepLinkNavigation,
  }) async {
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

    // Create notification channels for Android
    if (!kIsWeb && Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channelDefault);
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channelFriends);
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channelGames);
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channelReminders);
    }

    // Request permissions
    await _requestPermissions();

    // Setup Firebase messaging
    await _setupFirebaseMessaging();
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;

    // Request notification permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      NumberedLogger.i('User granted permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      NumberedLogger.i('User granted provisional permission');
    } else {
      NumberedLogger.w('User declined or has not accepted permission');
    }

    // Request local notification permissions for Android
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      NumberedLogger.i('Got a message whilst in the foreground!');
      NumberedLogger.d('Message data: ${message.data}');

      if (message.notification != null) {
        NumberedLogger.d(
            'Message also contained a notification: ${message.notification}');
      }
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      NumberedLogger.i('A new onMessageOpenedApp event was published!');
      _handleNotificationTap(message);
    });

    // Handle notification taps when app is terminated
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    if (message.data.containsKey('gameId')) {
      _onDeepLinkNavigation?.call({
        'type': 'game',
        'gameId': message.data['gameId'],
      });
    } else if (message.data.containsKey('friendId')) {
      _onDeepLinkNavigation?.call({
        'type': 'friend',
        'friendId': message.data['friendId'],
      });
    }
  }

  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      NumberedLogger.e('Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      NumberedLogger.i('Subscribed to topic: $topic');
    } catch (e) {
      NumberedLogger.e('Error subscribing to topic $topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      NumberedLogger.i('Unsubscribed from topic: $topic');
    } catch (e) {
      NumberedLogger.e('Error unsubscribing from topic $topic: $e');
    }
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    AndroidNotificationChannel? channel,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'smartplayer_default',
      'General',
      channelDescription: 'General notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _local.show(id, title, body, platformChannelSpecifics,
        payload: payload);
  }

  Future<void> showGameReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'smartplayer_reminders',
      'Reminders',
      channelDescription: 'Game reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _local.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      platformChannelSpecifics,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> sendFriendRequestNotification(
      String toUid, String fromUid) async {
    try {
      // Write a message for Cloud Functions to pick up and send FCM
      // functions path: /mail/notifications/...
      await _db.ref('mail/notifications').push().set({
        'type': 'friend_request',
        'toUid': toUid,
        'fromUid': fromUid,
        'ts': DateTime.now().toIso8601String(),
      });
      NumberedLogger.i('Queued friend request notification to $toUid');
    } catch (e) {
      NumberedLogger.e('Error sending friend request notification: $e');
    }
  }

  @override
  Future<void> sendGameInviteNotification(String toUid, String gameId) async {
    try {
      await _db.ref('mail/notifications').push().set({
        'type': 'game_invite',
        'toUid': toUid,
        'gameId': gameId,
        'ts': DateTime.now().toIso8601String(),
      });
      NumberedLogger.i('Queued game invite notification to $toUid');
    } catch (e) {
      NumberedLogger.e('Error sending game invite notification: $e');
    }
  }

  @override
  Future<void> sendGameReminderNotification(
      String gameId, DateTime gameTime) async {
    try {
      await _db.ref('mail/notifications').push().set({
        'type': 'game_reminder',
        'gameId': gameId,
        'scheduled': gameTime.toIso8601String(),
        'ts': DateTime.now().toIso8601String(),
      });
      NumberedLogger.i('Queued game reminder for game $gameId');
    } catch (e) {
      NumberedLogger.e('Error sending game reminder notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await _local.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _local.cancelAll();
  }

  /// Check if notifications are enabled
  Future<bool> isNotificationsEnabled() async {
    // This would typically check user preferences
    // For now, return true as default
    return true;
  }

  /// Check if a specific notification category is enabled
  Future<bool> isCategoryEnabled(String category) async {
    // This would typically check user preferences for the category
    // For now, return true as default
    return true;
  }

  /// Set notifications enabled/disabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    // This would typically save user preferences
    // Implementation would go here
  }

  /// Set a specific notification category enabled/disabled
  Future<void> setCategoryEnabled(String category, bool enabled) async {
    // This would typically save user preferences for the category
    // Implementation would go here
  }

  Future<void> dispose() async {
    await _authStateSubscription?.cancel();
  }
}

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages here if needed
  NumberedLogger.d('Background message received: ${message.messageId}');
}
