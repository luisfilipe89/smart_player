import 'package:firebase_database/firebase_database.dart';
import 'package:move_young/services/auth_service.dart';

class ProfileSettingsService {
  ProfileSettingsService._();

  static final FirebaseDatabase _db = FirebaseDatabase.instance;

  static const String _pathVisibility = 'settings/profile/visibility';
  static const String _pathShowOnline = 'settings/profile/showOnline';
  static const String _pathAllowFriendRequests =
      'settings/profile/allowFriendRequests';

  static Stream<String> visibilityStream(String uid) {
    return _db
        .ref('users/$uid/$_pathVisibility')
        .onValue
        .map((e) => (e.snapshot.value as String?) ?? 'public')
        .asBroadcastStream();
  }

  static Future<String> getVisibility(String uid) async {
    final snap = await _db.ref('users/$uid/$_pathVisibility').get();
    return (snap.value as String?) ?? 'public';
  }

  static Future<void> setVisibility(String visibility) async {
    final uid = AuthService.currentUserId;
    if (uid == null) return;
    await _db.ref('users/$uid/$_pathVisibility').set(visibility);
  }

  static Stream<bool> showOnlineStream(String uid) {
    return _db
        .ref('users/$uid/$_pathShowOnline')
        .onValue
        .map((e) => (e.snapshot.value as bool?) ?? true)
        .asBroadcastStream();
  }

  static Future<bool> getShowOnline(String uid) async {
    final snap = await _db.ref('users/$uid/$_pathShowOnline').get();
    return (snap.value as bool?) ?? true;
  }

  static Future<void> setShowOnline(bool showOnline) async {
    final uid = AuthService.currentUserId;
    if (uid == null) return;
    await _db.ref('users/$uid/$_pathShowOnline').set(showOnline);
  }

  static Stream<bool> allowFriendRequestsStream(String uid) {
    return _db
        .ref('users/$uid/$_pathAllowFriendRequests')
        .onValue
        .map((e) => (e.snapshot.value as bool?) ?? true)
        .asBroadcastStream();
  }

  static Future<bool> getAllowFriendRequests(String uid) async {
    final snap = await _db.ref('users/$uid/$_pathAllowFriendRequests').get();
    return (snap.value as bool?) ?? true;
  }

  static Future<void> setAllowFriendRequests(bool allowFriendRequests) async {
    final uid = AuthService.currentUserId;
    if (uid == null) return;
    await _db
        .ref('users/$uid/$_pathAllowFriendRequests')
        .set(allowFriendRequests);
  }
}
