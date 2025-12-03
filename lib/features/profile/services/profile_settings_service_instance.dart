import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/db/db_paths.dart';
import 'package:move_young/models/infrastructure/service_error.dart';

/// Instance-based ProfileSettingsService with dependency injection
class ProfileSettingsServiceInstance {
  final FirebaseDatabase _database;
  final FirebaseAuth _auth;

  ProfileSettingsServiceInstance(this._database, this._auth);

  /// Get visibility stream for a user
  Stream<String> visibilityStream(String uid) {
    return _database
        .ref(DbPaths.userVisibility(uid))
        .onValue
        .map((e) => (e.snapshot.value as String?) ?? 'public')
        .asBroadcastStream();
  }

  /// Get current visibility setting
  Future<String> getVisibility(String uid) async {
    final snap = await _database.ref(DbPaths.userVisibility(uid)).get();
    return (snap.value as String?) ?? 'public';
  }

  /// Set visibility setting
  Future<bool> setVisibility(String visibility) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AuthException('User not authenticated');
    }
    await _database.ref(DbPaths.userVisibility(uid)).set(visibility);
    return true;
  }

  /// Get show online status stream
  Stream<bool> showOnlineStream(String uid) {
    return _database
        .ref(DbPaths.userShowOnline(uid))
        .onValue
        .map((e) => (e.snapshot.value as bool?) ?? true)
        .asBroadcastStream();
  }

  /// Get current show online setting
  Future<bool> getShowOnline(String uid) async {
    final snap = await _database.ref(DbPaths.userShowOnline(uid)).get();
    return (snap.value as bool?) ?? true;
  }

  /// Set show online setting
  Future<bool> setShowOnline(bool showOnline) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AuthException('User not authenticated');
    }
    await _database.ref(DbPaths.userShowOnline(uid)).set(showOnline);
    return true;
  }

  /// Get allow friend requests stream
  Stream<bool> allowFriendRequestsStream(String uid) {
    return _database
        .ref(DbPaths.userAllowFriendRequests(uid))
        .onValue
        .map((e) => (e.snapshot.value as bool?) ?? true)
        .asBroadcastStream();
  }

  /// Get current allow friend requests setting
  Future<bool> getAllowFriendRequests(String uid) async {
    final snap =
        await _database.ref(DbPaths.userAllowFriendRequests(uid)).get();
    return (snap.value as bool?) ?? true;
  }

  /// Set allow friend requests setting
  Future<bool> setAllowFriendRequests(bool allow) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AuthException('User not authenticated');
    }
    await _database.ref(DbPaths.userAllowFriendRequests(uid)).set(allow);
    return true;
  }

  /// Get share email stream
  Stream<bool> shareEmailStream(String uid) {
    return _database
        .ref(DbPaths.userShareEmail(uid))
        .onValue
        .map((e) => (e.snapshot.value as bool?) ?? false)
        .asBroadcastStream();
  }

  /// Get current share email setting
  Future<bool> getShareEmail(String uid) async {
    final snap = await _database.ref(DbPaths.userShareEmail(uid)).get();
    return (snap.value as bool?) ?? false;
  }

  /// Set share email setting
  Future<bool> setShareEmail(bool share) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const AuthException('User not authenticated');
    }
    await _database.ref(DbPaths.userShareEmail(uid)).set(share);
    return true;
  }

  /// Get combined settings stream
  Stream<Map<String, dynamic>> settingsStream(String uid) {
    return _database.ref(DbPaths.userSettingsProfileRoot(uid)).onValue.map((e) {
      final data = e.snapshot.value as Map<dynamic, dynamic>?;
      return {
        'visibility': data?['visibility'] as String? ?? 'public',
        'showOnline': data?['showOnline'] as bool? ?? true,
        'allowFriendRequests': data?['allowFriendRequests'] as bool? ?? true,
        'shareEmail': data?['shareEmail'] as bool? ?? true,
      };
    }).asBroadcastStream();
  }

  /// Get user profile stream
  Stream<Map<String, dynamic>?> userProfileStream(String uid) {
    return _database.ref(DbPaths.userProfile(uid)).onValue.map((e) {
      if (!e.snapshot.exists) return null;
      return Map<String, dynamic>.from(e.snapshot.value as Map);
    });
  }

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final snap = await _database.ref(DbPaths.userProfile(uid)).get();
    if (!snap.exists) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  }

  /// Update user profile data
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _database.ref(DbPaths.userProfile(uid)).update(data);
  }
}
