import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/services/notifications/notification_service_instance.dart';
import 'package:move_young/providers/infrastructure/firebase_providers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:move_young/navigation/main_scaffold.dart';
import 'package:move_young/navigation/deep_links.dart';
import 'package:move_young/navigation/route_registry.dart';

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

  // Queue to hold intents until MainScaffold controller is ready
  final List<RouteIntent> _pendingIntents = <RouteIntent>[];
  bool _isDraining = false;

  void dispatch(Map<String, dynamic> payload) {
    try {
      final intent = _parser.parseFcmData(payload);
      if (intent == null) {
        _showDeepLinkError('Invalid notification data');
        return;
      }
      _routeOrQueue(intent);
    } catch (e) {
      _showDeepLinkError('Failed to process notification: $e');
    }
  }

  void dispatchUri(String uri) {
    try {
      final intent = _parser.parseUri(uri);
      if (intent == null) {
        _showDeepLinkError('Invalid link format');
        return;
      }
      _routeOrQueue(intent);
    } catch (e) {
      _showDeepLinkError('Failed to process link: $e');
    }
  }

  void _showDeepLinkError(String message) {
    // Log the error - UI feedback will be handled in screens when game/user not found
    // Screens will validate game existence and show appropriate errors
  }

  void _routeOrQueue(RouteIntent intent) {
    final controller = _ref.read(mainScaffoldControllerProvider);
    if (controller == null) {
      _pendingIntents.add(intent);
      _scheduleDrain();
      return;
    }
    _routeIntent(controller, intent);
  }

  void _scheduleDrain() {
    if (_isDraining) return;
    _isDraining = true;
    // Drain after next frame when controller is likely to be set
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      _isDraining = false;
      final controller = _ref.read(mainScaffoldControllerProvider);
      if (controller == null || _pendingIntents.isEmpty) return;
      final intents = List<RouteIntent>.from(_pendingIntents);
      _pendingIntents.clear();
      for (final intent in intents) {
        _routeIntent(controller, intent);
      }
    });
  }

  void _routeIntent(MainScaffoldController controller, RouteIntent intent) {
    if (intent is FriendsIntent) {
      controller.switchToTab(kTabFriends, popToRoot: true);
    } else if (intent is AgendaIntent) {
      controller.switchToTab(kTabAgenda, popToRoot: true);
    } else if (intent is DiscoverGamesIntent) {
      controller.openJoinScreen(intent.highlightGameId);
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
    Function(Map<String, dynamic>)? onDeepLinkNavigation,
  }) =>
      _notificationService.initialize(
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
  Future<void> sendFriendRequestNotification(String toUid, String fromUid) =>
      _notificationService.sendFriendRequestNotification(toUid, fromUid);
  Future<void> sendFriendAcceptedNotification(String toUid, String fromUid) =>
      _notificationService.sendFriendAcceptedNotification(toUid, fromUid);
  Future<void> sendGameReminderNotification(String gameId, DateTime gameTime) =>
      _notificationService.sendGameReminderNotification(gameId, gameTime);
  Future<void> sendFriendRemovedNotification({
    required String removedUserUid,
    required String removerUid,
  }) =>
      _notificationService.sendFriendRemovedNotification(
        removedUserUid: removedUserUid,
        removerUid: removerUid,
      );
  Future<void> sendGameEditedNotification(String gameId) =>
      _notificationService.sendGameEditedNotification(gameId);
  Future<void> sendGameCancelledNotification(String gameId) =>
      _notificationService.sendGameCancelledNotification(gameId);
}

// Notification actions provider (for notification operations)
final notificationActionsProvider = Provider<NotificationActions>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return NotificationActions(notificationService);
});
