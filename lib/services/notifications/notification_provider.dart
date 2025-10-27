// lib/providers/services/notification_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_service_instance.dart';
import 'package:move_young/providers/infrastructure/firebase_providers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:move_young/screens/main_scaffold.dart';
import 'package:move_young/routes/deep_links.dart';
import 'package:move_young/routes/route_registry.dart';

// Flutter Local Notifications plugin provider
final flutterLocalNotificationsProvider =
    Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

// NotificationService provider with dependency injection
final notificationServiceProvider =
    Provider<NotificationServiceInstance>((ref) {
  final firebaseMessaging = ref.watch(firebaseMessagingProvider);
  final firebaseDatabase = ref.watch(firebaseDatabaseProvider);
  final flutterLocalNotifications =
      ref.watch(flutterLocalNotificationsProvider);

  return NotificationServiceInstance(
    firebaseMessaging,
    firebaseDatabase,
    flutterLocalNotifications,
  );
});

// Deep link dispatcher using a simple provider to route events
final deepLinkDispatcherProvider = Provider<DeepLinkDispatcher>((ref) {
  return DeepLinkDispatcher(ref, DeepLinkParser());
});

class DeepLinkDispatcher {
  final Ref _ref;
  final DeepLinkParser _parser;
  DeepLinkDispatcher(this._ref, this._parser);

  void dispatch(Map<String, dynamic> payload) {
    try {
      final intent = _parser.parseFcmData(payload);
      if (intent == null) return;
      _routeIntent(intent);
    } catch (_) {}
  }

  void dispatchUri(String uri) {
    final intent = _parser.parseUri(uri);
    if (intent == null) return;
    _routeIntent(intent);
  }

  void _routeIntent(RouteIntent intent) {
    final controller = _ref.read(mainScaffoldControllerProvider);
    if (controller == null) return;
    if (intent is FriendsIntent) {
      controller.switchToTab(kTabFriends, popToRoot: true);
    } else if (intent is AgendaIntent) {
      controller.switchToTab(kTabAgenda, popToRoot: true);
    } else if (intent is DiscoverGamesIntent) {
      controller.switchToTab(kTabJoin, popToRoot: true);
    } else if (intent is MyGamesIntent) {
      controller.openMyGames(
        initialTab: intent.initialTab,
        highlightGameId: intent.highlightGameId,
        popToRoot: true,
      );
    } else {
      controller.switchToTab(kTabHome, popToRoot: true);
    }
  }
}

// FCM Token provider (reactive)
final fcmTokenProvider = FutureProvider.autoDispose<String?>((ref) async {
  final notificationService = ref.watch(notificationServiceProvider);
  return await notificationService.getToken();
});

// Helper class for notification actions
class NotificationActions {
  final NotificationServiceInstance _notificationService;

  NotificationActions(this._notificationService);

  Future<void> initialize({
    Function(String? payload)? onNotificationTap,
    Function(Map<String, dynamic>)? onDeepLinkNavigation,
  }) =>
      _notificationService.initialize(
        onNotificationTap: onNotificationTap,
        onDeepLinkNavigation: onDeepLinkNavigation,
      );

  Future<void> subscribeToTopic(String topic) =>
      _notificationService.subscribeToTopic(topic);
  Future<void> unsubscribeFromTopic(String topic) =>
      _notificationService.unsubscribeFromTopic(topic);
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) =>
      _notificationService.showLocalNotification(
        id: id,
        title: title,
        body: body,
        payload: payload,
      );
  Future<void> showGameReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) =>
      _notificationService.showGameReminder(
        id: id,
        title: title,
        body: body,
        scheduledTime: scheduledTime,
        payload: payload,
      );
  Future<void> sendFriendRequestNotification(String toUid, String fromUid) =>
      _notificationService.sendFriendRequestNotification(toUid, fromUid);
  Future<void> sendGameInviteNotification(String toUid, String gameId) =>
      _notificationService.sendGameInviteNotification(toUid, gameId);
  Future<void> sendGameReminderNotification(String gameId, DateTime gameTime) =>
      _notificationService.sendGameReminderNotification(gameId, gameTime);
  Future<void> cancelNotification(int id) =>
      _notificationService.cancelNotification(id);
  Future<void> cancelAllNotifications() =>
      _notificationService.cancelAllNotifications();
}

// Notification actions provider (for notification operations)
final notificationActionsProvider = Provider<NotificationActions>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return NotificationActions(notificationService);
});
