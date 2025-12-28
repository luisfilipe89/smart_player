import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/db/db_paths.dart';
import 'dart:async';

/// NotificationSettingsService for managing notification preferences
/// Syncs with Firebase for cross-device support, with local storage as fallback
class NotificationSettingsService {
  final SharedPreferences _prefs;
  final FirebaseDatabase _database;
  final FirebaseAuth _auth;

  // Preference keys for local storage
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

  NotificationSettingsService(this._prefs, this._database, this._auth);

  /// Initialize the service and load saved preferences
  /// Tries Firebase first, falls back to local storage, then defaults
  Future<void> initialize() async {
    try {
      final uid = _auth.currentUser?.uid;

      if (uid != null) {
        // Try to load from Firebase first
        try {
          final settingsSnap = await _database
              .ref(DbPaths.userSettingsNotificationsRoot(uid))
              .once();

          if (settingsSnap.snapshot.exists) {
            final data = settingsSnap.snapshot.value as Map<dynamic, dynamic>?;
            if (data != null) {
              _notificationsEnabled = data['enabled'] as bool? ?? true;
              _friendRequests = data['friendRequests'] as bool? ?? true;
              _matchInvites = data['matchInvites'] as bool? ?? true;
              _matchUpdates = data['matchUpdates'] as bool? ?? true;

              // Sync to local storage for offline support
              await _syncToLocal();
              _emitSettings();
              return;
            }
          }
        } catch (e) {
          // Firebase failed, fall back to local storage
        }
      }

      // Fall back to local storage
      _notificationsEnabled = _prefs.getBool(_keyNotificationsEnabled) ?? true;
      _friendRequests = _prefs.getBool(_keyFriendRequests) ?? true;
      _matchInvites = _prefs.getBool(_keyMatchInvites) ?? true;
      _matchUpdates = _prefs.getBool(_keyMatchUpdates) ?? true;

      // If we have a user and local values exist, sync to Firebase
      if (uid != null) {
        await _syncToFirebase();
      }

      _emitSettings();
    } catch (e) {
      // If everything fails, use default values
      _emitSettings();
    }
  }

  /// Sync current settings to local storage
  Future<void> _syncToLocal() async {
    try {
      await _prefs.setBool(_keyNotificationsEnabled, _notificationsEnabled);
      await _prefs.setBool(_keyFriendRequests, _friendRequests);
      await _prefs.setBool(_keyMatchInvites, _matchInvites);
      await _prefs.setBool(_keyMatchUpdates, _matchUpdates);
    } catch (e) {
      // Ignore local storage errors
    }
  }

  /// Sync current settings to Firebase
  Future<void> _syncToFirebase() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _database.ref(DbPaths.userSettingsNotificationsRoot(uid)).set({
        'enabled': _notificationsEnabled,
        'friendRequests': _friendRequests,
        'matchInvites': _matchInvites,
        'matchUpdates': _matchUpdates,
      });
    } catch (e) {
      // Ignore Firebase errors - local storage will be used
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
      await _syncToLocal();
      await _syncToFirebase();
      _emitSettings();
    } catch (e) {
      _emitSettings();
    }
  }

  /// Set friend requests enabled state
  Future<void> setFriendRequests(bool value) async {
    _friendRequests = value;
    try {
      await _syncToLocal();
      await _syncToFirebase();
      _emitSettings();
    } catch (e) {
      _emitSettings();
    }
  }

  /// Set match invites enabled state
  Future<void> setMatchInvites(bool value) async {
    _matchInvites = value;
    try {
      await _syncToLocal();
      await _syncToFirebase();
      _emitSettings();
    } catch (e) {
      _emitSettings();
    }
  }

  /// Set match updates enabled state
  Future<void> setMatchUpdates(bool value) async {
    _matchUpdates = value;
    try {
      await _syncToLocal();
      await _syncToFirebase();
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
