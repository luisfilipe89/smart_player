import 'package:firebase_database/firebase_database.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/db/db_paths.dart';

class ProfileSettingsService {
  ProfileSettingsService._();

  static final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Deprecated hardcoded path constants (kept for reference). All code uses DbPaths.
  // ignore: unused_field
  static const String _pathVisibility = 'settings/profile/visibility';
  // ignore: unused_field
  static const String _pathShowOnline = 'settings/profile/showOnline';
  // ignore: unused_field
  static const String _pathAllowFriendRequests =
      'settings/profile/allowFriendRequests';
  // ignore: unused_field
  static const String _pathShareEmail = 'settings/profile/shareEmail';

  static Stream<String> visibilityStream(String uid) {
    return _db
        .ref(DbPaths.userVisibility(uid))
        .onValue
        .map((e) => (e.snapshot.value as String?) ?? 'public')
        .asBroadcastStream();
  }

  static Future<String> getVisibility(String uid) async {
    final snap = await _db.ref(DbPaths.userVisibility(uid)).get();
    return (snap.value as String?) ?? 'public';
  }

  static Future<void> setVisibility(String visibility) async {
    final uid = AuthService.currentUserId;
    if (uid == null) return;
    await _db.ref(DbPaths.userVisibility(uid)).set(visibility);
  }

  static Stream<bool> showOnlineStream(String uid) {
    return _db
        .ref(DbPaths.userShowOnline(uid))
        .onValue
        .map((e) => (e.snapshot.value as bool?) ?? true)
        .asBroadcastStream();
  }

  static Future<bool> getShowOnline(String uid) async {
    final snap = await _db.ref(DbPaths.userShowOnline(uid)).get();
    return (snap.value as bool?) ?? true;
  }

  static Future<void> setShowOnline(bool showOnline) async {
    final uid = AuthService.currentUserId;
    if (uid == null) return;
    await _db.ref(DbPaths.userShowOnline(uid)).set(showOnline);
  }

  static Stream<bool> allowFriendRequestsStream(String uid) {
    return _db
        .ref(DbPaths.userAllowFriendRequests(uid))
        .onValue
        .map((e) => (e.snapshot.value as bool?) ?? true)
        .asBroadcastStream();
  }

  static Future<bool> getAllowFriendRequests(String uid) async {
    final snap = await _db.ref(DbPaths.userAllowFriendRequests(uid)).get();
    return (snap.value as bool?) ?? true;
  }

  static Future<void> setAllowFriendRequests(bool allowFriendRequests) async {
    final uid = AuthService.currentUserId;
    if (uid == null) return;
    await _db
        .ref(DbPaths.userAllowFriendRequests(uid))
        .set(allowFriendRequests);
  }

  static Stream<bool> shareEmailStream(String uid) {
    return _db
        .ref(DbPaths.userShareEmail(uid))
        .onValue
        .map((e) => (e.snapshot.value as bool?) ?? true)
        .asBroadcastStream();
  }

  static Future<bool> getShareEmail(String uid) async {
    final snap = await _db.ref(DbPaths.userShareEmail(uid)).get();
    return (snap.value as bool?) ?? true;
  }

  static Future<void> setShareEmail(bool shareEmail) async {
    final uid = AuthService.currentUserId;
    if (uid == null) return;
    await _db.ref(DbPaths.userShareEmail(uid)).set(shareEmail);
  }

  static Stream<Map<String, dynamic>> settingsStream(String uid) {
    return _db.ref(DbPaths.userSettingsProfileRoot(uid)).onValue.map((e) {
      final data = e.snapshot.value as Map<dynamic, dynamic>?;
      return {
        'visibility': data?['visibility'] as String? ?? 'public',
        'showOnline': data?['showOnline'] as bool? ?? true,
        'allowFriendRequests': data?['allowFriendRequests'] as bool? ?? true,
        'shareEmail': data?['shareEmail'] as bool? ?? true,
      };
    }).asBroadcastStream();
  }
}
