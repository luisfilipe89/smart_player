import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:move_young/services/auth_service.dart';

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseDatabase _db = FirebaseDatabase.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channelDefault =
      AndroidNotificationChannel(
    'smartplayer_default',
    'General',
    description: 'General notifications',
    importance: Importance.defaultImportance,
  );

  static Future<void> initialize() async {
    // Local notifications init
    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _local.initialize(initSettings);
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channelDefault);

    // Ask permission (iOS) and get token
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _saveCurrentToken();
    _messaging.onTokenRefresh.listen((token) => _saveToken(token));

    // Foreground messages → show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final n = message.notification;
      if (n == null) return;
      _local.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'smartplayer_default',
            'General',
            channelDescription: 'General notifications',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: message.data['route'],
      );
    });
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

  // Notification preferences (saved under users/$uid/settings/notifications)
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
}
