import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_settings_service.dart';
import 'package:move_young/providers/infrastructure/shared_preferences_provider.dart';

// NotificationSettingsService provider with dependency injection
final notificationSettingsServiceProvider = Provider<NotificationSettingsService?>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  return prefsAsync.when(
    data: (prefs) {
      final service = NotificationSettingsService(prefs);
      // Dispose service when provider is disposed to prevent memory leaks
      ref.onDispose(() => service.dispose());
      return service;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

// Notification settings stream provider (reactive)
final notificationSettingsProvider = StreamProvider<Map<String, bool>>((ref) {
  final service = ref.watch(notificationSettingsServiceProvider);
  if (service == null) {
    // Return default settings if service is not available
    return Stream.value({
      'notificationsEnabled': true,
      'friendRequests': true,
      'gameInvites': true,
      'gameUpdates': true,
    });
  }
  return service.settingsStream;
});

// Notification settings actions provider (for notification operations)
final notificationSettingsActionsProvider = Provider<NotificationSettingsActions?>((ref) {
  final service = ref.watch(notificationSettingsServiceProvider);
  if (service == null) {
    return null;
  }
  return NotificationSettingsActions(service);
});

// Helper class for notification settings actions
class NotificationSettingsActions {
  final NotificationSettingsService _service;

  NotificationSettingsActions(this._service);

  Future<void> initialize() => _service.initialize();
  Map<String, bool> getSettings() => _service.getSettings();
  bool get notificationsEnabled => _service.notificationsEnabled;
  bool get friendRequests => _service.friendRequests;
  bool get gameInvites => _service.gameInvites;
  bool get gameUpdates => _service.gameUpdates;
  bool isNotificationTypeEnabled(String type) => _service.isNotificationTypeEnabled(type);
  
  Future<void> setNotificationsEnabled(bool value) => _service.setNotificationsEnabled(value);
  Future<void> setFriendRequests(bool value) => _service.setFriendRequests(value);
  Future<void> setGameInvites(bool value) => _service.setGameInvites(value);
  Future<void> setGameUpdates(bool value) => _service.setGameUpdates(value);
  Future<void> setCategory(String category, bool value) => _service.setCategory(category, value);
}




