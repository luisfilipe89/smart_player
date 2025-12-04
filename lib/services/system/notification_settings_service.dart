import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// NotificationSettingsService for managing notification preferences
class NotificationSettingsService {
  final SharedPreferences _prefs;
  
  // Preference keys
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyGameReminders = 'notifications_game_reminders';
  static const String _keyFriendRequests = 'notifications_friend_requests';
  static const String _keyGameInvites = 'notifications_game_invites';
  static const String _keyGameUpdates = 'notifications_game_updates';

  // Default values
  bool _notificationsEnabled = true;
  bool _gameReminders = true;
  bool _friendRequests = true;
  bool _gameInvites = true;
  bool _gameUpdates = true;
  
  final StreamController<Map<String, bool>> _settingsController =
      StreamController<Map<String, bool>>.broadcast();

  NotificationSettingsService(this._prefs);

  /// Initialize the service and load saved preferences
  Future<void> initialize() async {
    try {
      _notificationsEnabled = _prefs.getBool(_keyNotificationsEnabled) ?? true;
      _gameReminders = _prefs.getBool(_keyGameReminders) ?? true;
      _friendRequests = _prefs.getBool(_keyFriendRequests) ?? true;
      _gameInvites = _prefs.getBool(_keyGameInvites) ?? true;
      _gameUpdates = _prefs.getBool(_keyGameUpdates) ?? true;
      _emitSettings();
    } catch (e) {
      // If SharedPreferences fails, use default values
      _emitSettings();
    }
  }

  /// Get all notification settings
  Map<String, bool> getSettings() {
    return {
      'notificationsEnabled': _notificationsEnabled,
      'gameReminders': _gameReminders,
      'friendRequests': _friendRequests,
      'gameInvites': _gameInvites,
      'gameUpdates': _gameUpdates,
    };
  }

  /// Get notifications enabled state
  bool get notificationsEnabled => _notificationsEnabled;

  /// Get game reminders enabled state
  bool get gameReminders => _gameReminders;

  /// Get friend requests enabled state
  bool get friendRequests => _friendRequests;

  /// Get game invites enabled state
  bool get gameInvites => _gameInvites;

  /// Get game updates enabled state
  bool get gameUpdates => _gameUpdates;

  /// Check if a specific notification type is enabled
  bool isNotificationTypeEnabled(String type) {
    if (!_notificationsEnabled) return false;
    
    switch (type) {
      case 'game_reminders':
        return _gameReminders;
      case 'friend_requests':
        return _friendRequests;
      case 'game_invites':
        return _gameInvites;
      case 'game_updates':
        return _gameUpdates;
      default:
        return true;
    }
  }

  /// Set notifications enabled state
  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    try {
      await _prefs.setBool(_keyNotificationsEnabled, value);
      _emitSettings();
    } catch (e) {
      _emitSettings();
    }
  }

  /// Set game reminders enabled state
  Future<void> setGameReminders(bool value) async {
    _gameReminders = value;
    try {
      await _prefs.setBool(_keyGameReminders, value);
      _emitSettings();
    } catch (e) {
      _emitSettings();
    }
  }

  /// Set friend requests enabled state
  Future<void> setFriendRequests(bool value) async {
    _friendRequests = value;
    try {
      await _prefs.setBool(_keyFriendRequests, value);
      _emitSettings();
    } catch (e) {
      _emitSettings();
    }
  }

  /// Set game invites enabled state
  Future<void> setGameInvites(bool value) async {
    _gameInvites = value;
    try {
      await _prefs.setBool(_keyGameInvites, value);
      _emitSettings();
    } catch (e) {
      _emitSettings();
    }
  }

  /// Set game updates enabled state
  Future<void> setGameUpdates(bool value) async {
    _gameUpdates = value;
    try {
      await _prefs.setBool(_keyGameUpdates, value);
      _emitSettings();
    } catch (e) {
      _emitSettings();
    }
  }

  /// Set a specific notification category
  Future<void> setCategory(String category, bool value) async {
    switch (category) {
      case 'game_reminders':
        await setGameReminders(value);
        break;
      case 'friend_requests':
        await setFriendRequests(value);
        break;
      case 'game_invites':
        await setGameInvites(value);
        break;
      case 'game_updates':
        await setGameUpdates(value);
        break;
    }
  }

  /// Stream of settings changes
  Stream<Map<String, bool>> get settingsStream => _settingsController.stream;

  /// Emit current settings to stream
  void _emitSettings() {
    if (!_settingsController.isClosed) {
      _settingsController.add(getSettings());
    }
  }

  /// Dispose resources
  void dispose() {
    _settingsController.close();
  }
}

