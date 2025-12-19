import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// NotificationSettingsService for managing notification preferences
class NotificationSettingsService {
  final SharedPreferences _prefs;
  
  // Preference keys
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyFriendRequests = 'notifications_friend_requests';
  static const String _keyMatchInvites = 'notifications_match_invites';
  static const String _keyMatchUpdates = 'notifications_match_updates';

  // Default values
  bool _notificationsEnabled = true;
  bool _friendRequests = true;
  bool _matchInvites = true;
  bool _matchUpdates = true;
  
  final StreamController<Map<String, bool>> _settingsController =
      StreamController<Map<String, bool>>.broadcast();

  NotificationSettingsService(this._prefs);

  /// Initialize the service and load saved preferences
  Future<void> initialize() async {
    try {
      _notificationsEnabled = _prefs.getBool(_keyNotificationsEnabled) ?? true;
      _friendRequests = _prefs.getBool(_keyFriendRequests) ?? true;
      _matchInvites = _prefs.getBool(_keyMatchInvites) ?? true;
      _matchUpdates = _prefs.getBool(_keyMatchUpdates) ?? true;
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
      'friendRequests': _friendRequests,
      'matchInvites': _matchInvites,
      'matchUpdates': _matchUpdates,
    };
  }

  /// Get notifications enabled state
  bool get notificationsEnabled => _notificationsEnabled;

  /// Get friend requests enabled state
  bool get friendRequests => _friendRequests;

  /// Get match invites enabled state
  bool get matchInvites => _matchInvites;

  /// Get match updates enabled state
  bool get matchUpdates => _matchUpdates;

  /// Check if a specific notification type is enabled
  bool isNotificationTypeEnabled(String type) {
    if (!_notificationsEnabled) return false;
    
    switch (type) {
      case 'friend_requests':
        return _friendRequests;
      case 'match_invites':
        return _matchInvites;
      case 'match_updates':
        return _matchUpdates;
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

  /// Set match invites enabled state
  Future<void> setMatchInvites(bool value) async {
    _matchInvites = value;
    try {
      await _prefs.setBool(_keyMatchInvites, value);
      _emitSettings();
    } catch (e) {
      _emitSettings();
    }
  }

  /// Set match updates enabled state
  Future<void> setMatchUpdates(bool value) async {
    _matchUpdates = value;
    try {
      await _prefs.setBool(_keyMatchUpdates, value);
      _emitSettings();
    } catch (e) {
      _emitSettings();
    }
  }

  /// Set a specific notification category
  Future<void> setCategory(String category, bool value) async {
    switch (category) {
      case 'friend_requests':
        await setFriendRequests(value);
        break;
      case 'match_invites':
        await setMatchInvites(value);
        break;
      case 'match_updates':
        await setMatchUpdates(value);
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

