import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:move_young/utils/logger.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_interface.dart';

/// Instance-based NotificationService for use with Riverpod dependency injection
class NotificationServiceInstance implements INotificationService {
  final FirebaseMessaging _messaging;
  final FirebaseDatabase _db;
  final FlutterLocalNotificationsPlugin _local;

  StreamSubscription? _authStateSubscription;
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSubscription;
  bool _isRequestingPermissions =
      false; // Guard to prevent concurrent permission requests
  bool _isInitialized = false; // Guard to prevent multiple initializations

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

  static const AndroidNotificationChannel _channelMatches =
      AndroidNotificationChannel(
    'smartplayer_matches',
    'Matches',
    description: 'Match invites and updates',
    importance: Importance.high,
  );

  NotificationServiceInstance(
    this._messaging,
    this._db,
    this._local,
  );

  Future<void> initialize({
    Function(Map<String, dynamic>)? onDeepLinkNavigation,
  }) async {
    // Prevent multiple initializations
    if (_isInitialized) {
      NumberedLogger.d('Notification service already initialized, skipping');
      return;
    }

    _onDeepLinkNavigation = onDeepLinkNavigation;

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
          // Parse JSON payload and handle navigation
          try {
            final payloadMap =
                jsonDecode(response.payload!) as Map<String, dynamic>;
            _onDeepLinkNavigation?.call(payloadMap);
          } catch (e) {
            // Payload is not valid JSON, skip
            NumberedLogger.d(
                'Invalid notification payload format: ${response.payload}');
          }
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
          ?.createNotificationChannel(_channelMatches);
    }

    // Request permissions (non-blocking - don't await to avoid blocking startup)
    // Defer permission requests to avoid blocking UI
    unawaited(_requestPermissions());

    // Setup Firebase messaging
    await _setupFirebaseMessaging();

    _isInitialized = true;
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;

    // Prevent concurrent permission requests
    if (_isRequestingPermissions) {
      NumberedLogger.d('Permission request already in progress, skipping');
      return;
    }

    try {
      _isRequestingPermissions = true;

      // Check current permission status first to avoid unnecessary requests
      try {
        final currentSettings = await _messaging.getNotificationSettings();
        if (currentSettings.authorizationStatus ==
                AuthorizationStatus.authorized ||
            currentSettings.authorizationStatus ==
                AuthorizationStatus.provisional) {
          _isRequestingPermissions = false;
          NumberedLogger.d('Notification permission already granted');
          return;
        }
      } catch (e) {
        // Continue if we can't check status
        NumberedLogger.d('Could not check permission status: $e');
      }

      // Add a delay to ensure system is ready and avoid conflicts
      await Future.delayed(const Duration(milliseconds: 1000));

      // Request notification permissions (non-blocking)
      _messaging
          .requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      )
          .then((NotificationSettings settings) {
        _isRequestingPermissions = false;
        if (settings.authorizationStatus == AuthorizationStatus.authorized) {
          NumberedLogger.i('User granted permission');
        } else if (settings.authorizationStatus ==
            AuthorizationStatus.provisional) {
          NumberedLogger.i('User granted provisional permission');
        } else {
          NumberedLogger.w('User declined or has not accepted permission');
        }
      }).catchError((e) {
        _isRequestingPermissions = false;
        // Ignore "already in progress" errors silently
        final errorStr = e.toString();
        if (!errorStr.contains('permissionRequestInProgress') &&
            !errorStr.contains('already running')) {
          NumberedLogger.w('Error requesting notification permission: $e');
        }
      });

      // Request local notification permissions for Android (with delay to avoid conflicts)
      if (Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 1200));
        if (!_isRequestingPermissions) {
          // Only request if Firebase permission request completed
          final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
              _local.resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

          androidImplementation
              ?.requestNotificationsPermission()
              .catchError((e) {
            NumberedLogger.d(
                'Error requesting Android notification permission: $e');
            return null;
          });
        }
      }
    } catch (e) {
      _isRequestingPermissions = false;
      // Ignore "already in progress" errors silently
      final errorStr = e.toString();
      if (!errorStr.contains('permissionRequestInProgress') &&
          !errorStr.contains('already running')) {
        NumberedLogger.w('Error in permission request: $e');
      }
    }
  }

  Future<void> _setupFirebaseMessaging() async {
    // Handle foreground messages
    _onMessageSubscription = FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        NumberedLogger.i('Got a message whilst in the foreground!');
        NumberedLogger.d('Message data: ${message.data}');

        if (message.notification != null) {
          NumberedLogger.d(
              'Message also contained a notification: ${message.notification}');

          // Show local notification when app is in foreground
          // This ensures users see the notification even when app is open
          // Store the message data as JSON payload so we can handle tap later
          final payload = jsonEncode(message.data);
          await showLocalNotification(
            id: message.hashCode
                .abs(), // Use absolute value to ensure positive ID
            title: message.notification?.title ?? 'SMARTPLAYER',
            body: message.notification?.body ?? 'You have a new notification',
            payload: payload,
            channel: _channelMatches, // Use matches channel for match invites
          );
        }
        // DO NOT navigate automatically - only navigate when user taps the notification
      },
      onError: (error) {
        NumberedLogger.e(
            'Error in Firebase Messaging onMessage stream: $error');
      },
    );

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle notification taps when app is in background
    _onMessageOpenedAppSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(
      (RemoteMessage message) {
        NumberedLogger.i('A new onMessageOpenedApp event was published!');
        _handleNotificationTap(message);
      },
      onError: (error) {
        NumberedLogger.e(
            'Error in Firebase Messaging onMessageOpenedApp stream: $error');
      },
    );

    // Handle notification taps when app is terminated
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Handle match invites with type 'discover' (navigate to Join a Match screen)
    if (message.data.containsKey('matchId') &&
        message.data['type'] == 'discover') {
      _onDeepLinkNavigation?.call({
        'type': 'discover',
        'matchId': message.data['matchId'],
      });
    } else if (message.data.containsKey('matchId')) {
      // Fallback for other match-related notifications
      _onDeepLinkNavigation?.call({
        'type': 'match',
        'matchId': message.data['matchId'],
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
    // Use provided channel or default to matches channel for better visibility
    final channelId = channel?.id ?? _channelMatches.id;
    final channelName = channel?.name ?? 'Matches';
    final channelDescription =
        channel?.description ?? 'Match invites and updates';

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high, // Use high importance for match invites
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _local.show(id, title, body, platformChannelSpecifics,
        payload: payload);
  }

  @override
  Future<void> sendFriendRequestNotification(
      String toUid, String fromUid) async {
    // Notification is now handled automatically by Cloud Function
    // onFriendRequestCreate when /users/{toUid}/friendRequests/received/{fromUid} is created
    // No action needed here - the friend request write in friends_service will trigger it
    NumberedLogger.i('Friend request notification will be sent by Cloud Function for $toUid');
  }

  @override
  Future<void> sendFriendAcceptedNotification(
      String toUid, String fromUid) async {
    // Notification is now handled automatically by Cloud Function
    // onFriendAcceptCreate when /users/{toUid}/friends/{fromUid} is created
    // No action needed here - the friend accept write in friends_service will trigger it
    NumberedLogger.i('Friend accepted notification will be sent by Cloud Function for $toUid');
  }

  @override
  Future<void> sendFriendRemovedNotification({
    required String removedUserUid,
    required String removerUid,
  }) async {
    // Notification is now handled automatically by Cloud Function
    // onFriendRemoveCreate when /users/{uid}/friends/{friendUid} is deleted
    // No action needed here - the friend removal write in friends_service will trigger it
    NumberedLogger.i('Friend removed notification will be sent by Cloud Function for $removedUserUid');
  }

  @override
  Future<void> sendMatchEditedNotification(String matchId) async {
    // Notification is now handled automatically by Cloud Function
    // onMatchUpdate when match is edited (detects lastOrganizerEditAt change)
    // No action needed here - the match update will trigger it
    NumberedLogger.i('Match edited notification will be sent by Cloud Function for match $matchId');
  }

  @override
  Future<void> sendMatchCancelledNotification(String matchId) async {
    // Notification is now handled automatically by Cloud Function
    // onMatchUpdate when match is cancelled (detects isActive=false)
    // No action needed here - the match update will trigger it
    NumberedLogger.i('Match cancelled notification will be sent by Cloud Function for match $matchId');
  }

  Future<void> dispose() async {
    await _authStateSubscription?.cancel();
    await _onMessageSubscription?.cancel();
    await _onMessageOpenedAppSubscription?.cancel();
  }
}

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages here if needed
  NumberedLogger.d('Background message received: ${message.messageId}');
}
