import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_settings_service.dart';
import 'package:move_young/providers/infrastructure/shared_preferences_provider.dart';
import 'package:move_young/providers/infrastructure/firebase_providers.dart';

// NotificationSettingsService provider with dependency injection
final notificationSettingsServiceProvider =
    Provider<NotificationSettingsService?>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  final firebaseDatabase = ref.watch(firebaseDatabaseProvider);
  final firebaseAuth = ref.watch(firebaseAuthProvider);

  return prefsAsync.when(
    data: (prefs) {
      final service =
          NotificationSettingsService(prefs, firebaseDatabase, firebaseAuth);
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
      'matchInvites': true,
      'matchUpdates': true,
    });
  }
  return service.settingsStream;
});

// Notification settings actions provider (for notification operations)
final notificationSettingsActionsProvider =
    Provider<NotificationSettingsActions?>((ref) {
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
  bool get matchInvites => _service.matchInvites;
  bool get matchUpdates => _service.matchUpdates;
  bool isNotificationTypeEnabled(String type) =>
      _service.isNotificationTypeEnabled(type);

  Future<void> setNotificationsEnabled(bool value) =>
      _service.setNotificationsEnabled(value);
  Future<void> setFriendRequests(bool value) =>
      _service.setFriendRequests(value);
  Future<void> setMatchInvites(bool value) => _service.setMatchInvites(value);
  Future<void> setMatchUpdates(bool value) => _service.setMatchUpdates(value);
  Future<void> setCategory(String category, bool value) =>
      _service.setCategory(category, value);
}
