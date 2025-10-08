// lib/services/friends_service.dart
import 'dart:async';

import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert' show utf8;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FriendsService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;
  static FirebaseDatabase get _db => FirebaseDatabase.instance;

  static DatabaseReference _userRef(String uid) => _db.ref('users/$uid');

  // Ensure per-user indexes exist for discovery by contacts (email)
  static Future<void> ensureUserIndexes() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final String uid = user.uid;

    final Map<String, Object?> updates = {};

    // Index by lowercase email if present
    final String? email = user.email?.trim();
    if (email != null && email.isNotEmpty) {
      final String emailLower = email.toLowerCase();
      // Use hashed index to avoid invalid chars and storing raw email as key
      final String emailHash = crypto.sha256
          .convert(utf8.encode(emailLower))
          .toString();
      updates['usersByEmailHash/$emailHash'] = uid;
    }

    // Minimal public profile for list rendering
    final String displayName = (user.displayName?.trim().isNotEmpty == true)
        ? user.displayName!.trim()
        : _deriveNameFromEmail(user.email);
    updates['users/$uid/profile/displayName'] = displayName;
    if (user.photoURL != null && user.photoURL!.isNotEmpty) {
      updates['users/$uid/profile/photoURL'] = user.photoURL;
    }

    if (updates.isEmpty) return;
    await _db.ref().update(updates);
  }

  static String _deriveNameFromEmail(String? email) {
    if (email == null || email.isEmpty) return 'User';
    final String prefix = email.split('@').first;
    final String cleaned = prefix.replaceAll(RegExp(r"[^A-Za-z]"), '');
    if (cleaned.isEmpty) return prefix;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  // Streams
  static Stream<List<String>> friendsStream(String uid) {
    return _userRef(uid).child('friends').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        return data.keys.cast<String>().toList()..sort();
      }
      return <String>[];
    });
  }

  static Stream<List<String>> receivedRequestsStream(String uid) {
    return _userRef(uid).child('friendRequests/received').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        return data.keys.cast<String>().toList()..sort();
      }
      return <String>[];
    });
  }

  static Stream<List<String>> sentRequestsStream(String uid) {
    return _userRef(uid).child('friendRequests/sent').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is Map) {
        return data.keys.cast<String>().toList()..sort();
      }
      return <String>[];
    });
  }

  // Actions
  static Future<bool> sendFriendRequestToUid(String toUid) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final String fromUid = user.uid;
    if (fromUid == toUid) return false;
    // Respect privacy toggle: if receiver disallows requests, block
    final allowSnap = await _db
        .ref('users/$toUid/settings/allowRequests')
        .get();
    if (allowSnap.exists && allowSnap.value == false) {
      return false;
    }
    // De-duplicate and blocklist checks
    if (!await _canSendRequest(fromUid: fromUid, toUid: toUid)) {
      return false;
    }
    if (await isBlockedBetween(fromUid, toUid)) {
      return false;
    }
    // Rate-limit: max 10/hour per user (client-side)
    final allowed = await _checkAndBumpRateLimit(fromUid);
    if (!allowed) return false;

    final Map<String, Object?> updates = {
      'users/$fromUid/friendRequests/sent/$toUid': true,
      'users/$toUid/friendRequests/received/$fromUid': true,
    };
    await _db.ref().update(updates);
    return true;
  }

  static Future<bool> _canSendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    final refs = [
      _db.ref('users/$fromUid/friends/$toUid'),
      _db.ref('users/$fromUid/friendRequests/sent/$toUid'),
      _db.ref('users/$toUid/friendRequests/received/$fromUid'),
      _db.ref('users/$toUid/friends/$fromUid'),
    ];
    final snaps = await Future.wait(refs.map((r) => r.get()));
    // If any exists, block
    for (final s in snaps) {
      if (s.exists) return false;
    }
    return true;
  }

  static const int _rateLimitWindowMs = 60 * 60 * 1000; // 1 hour
  static const int _rateLimitMaxRequests = 10;

  static Future<bool> _checkAndBumpRateLimit(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'friends_req_times_$uid';
      final now = DateTime.now().millisecondsSinceEpoch;
      final List<String> raw = prefs.getStringList(key) ?? <String>[];
      final List<int> times = raw
          .map((e) => int.tryParse(e) ?? 0)
          .where((t) => t > 0)
          .toList();
      // purge old
      final cutoff = now - _rateLimitWindowMs;
      final recent = times.where((t) => t >= cutoff).toList();
      if (recent.length >= _rateLimitMaxRequests) return false;
      recent.add(now);
      await prefs.setStringList(key, recent.map((e) => e.toString()).toList());
      return true;
    } catch (_) {
      // On prefs failure, allow rather than block
      return true;
    }
  }

  static Future<bool> acceptFriendRequest(String fromUid) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final String myUid = user.uid;

    final Map<String, Object?> updates = {
      'users/$myUid/friends/$fromUid': true,
      'users/$fromUid/friends/$myUid': true,
      'users/$myUid/friendRequests/received/$fromUid': null,
      'users/$fromUid/friendRequests/sent/$myUid': null,
    };
    await _db.ref().update(updates);
    return true;
  }

  static Future<bool> declineFriendRequest(String fromUid) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final String myUid = user.uid;
    final Map<String, Object?> updates = {
      'users/$myUid/friendRequests/received/$fromUid': null,
      'users/$fromUid/friendRequests/sent/$myUid': null,
    };
    await _db.ref().update(updates);
    return true;
  }

  // Blocking
  static Future<void> blockUser(String otherUid) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final String myUid = user.uid;
    await _db.ref('users/$myUid/blocks/$otherUid').set(true);
    // Optional: clean up any pending requests between users
    final Map<String, Object?> updates = {
      'users/$myUid/friendRequests/sent/$otherUid': null,
      'users/$myUid/friendRequests/received/$otherUid': null,
      'users/$otherUid/friendRequests/sent/$myUid': null,
      'users/$otherUid/friendRequests/received/$myUid': null,
    };
    await _db.ref().update(updates);
  }

  static Future<void> unblockUser(String otherUid) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final String myUid = user.uid;
    await _db.ref('users/$myUid/blocks/$otherUid').remove();
  }

  static Stream<List<String>> blockedUsersStream(String uid) {
    return _db.ref('users/$uid/blocks').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is Map) return data.keys.cast<String>().toList()..sort();
      return <String>[];
    });
  }

  // User privacy settings
  static Future<void> setAllowRequests(bool allow) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.ref('users/$uid/settings/allowRequests').set(allow);
  }

  static Stream<bool> allowRequestsStream(String uid) {
    return _db
        .ref('users/$uid/settings/allowRequests')
        .onValue
        .map((e) => e.snapshot.value != false);
  }

  // Report user audit trail
  static Future<void> reportUser({
    required String targetUid,
    required String reason,
  }) async {
    final reporter = _auth.currentUser?.uid;
    if (reporter == null || reporter == targetUid) return;
    final id = const Uuid().v4();
    await _db.ref('reports/$id').set({
      'reporter': reporter,
      'target': targetUid,
      'reason': reason,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<bool> isBlockedBetween(String a, String b) async {
    final snaps = await Future.wait([
      _db.ref('users/$a/blocks/$b').get(),
      _db.ref('users/$b/blocks/$a').get(),
    ]);
    return snaps.any((s) => s.exists);
  }

  static Future<bool> removeFriend(String friendUid) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final String myUid = user.uid;
    final Map<String, Object?> updates = {
      'users/$myUid/friends/$friendUid': null,
      'users/$friendUid/friends/$myUid': null,
    };
    await _db.ref().update(updates);
    return true;
  }

  static Future<String?> searchUidByEmail(String email) async {
    final String emailLower = email.trim().toLowerCase();
    if (emailLower.isEmpty) return null;
    final String emailHash = crypto.sha256
        .convert(utf8.encode(emailLower))
        .toString();
    final DataSnapshot snap = await _db
        .ref('usersByEmailHash/$emailHash')
        .get();
    if (!snap.exists) return null;
    return snap.value?.toString();
  }

  // QR token flow
  static Future<String?> generateFriendToken({
    Duration ttl = const Duration(minutes: 10),
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final String token = const Uuid().v4();
    final int expMs = DateTime.now().add(ttl).millisecondsSinceEpoch;
    await _db.ref('friendTokens/$token').set({
      'ownerUid': user.uid,
      'exp': expMs,
    });
    return token;
  }

  static Future<bool> consumeFriendToken(String token) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    // Normalize token in case a full URL or text was scanned
    final String normalized = _normalizeToken(token);
    final DatabaseReference tokenRef = _db.ref('friendTokens/$normalized');
    final DataSnapshot snap = await tokenRef.get();
    if (!snap.exists) return false;
    final Map data = (snap.value as Map);
    final String ownerUid = data['ownerUid']?.toString() ?? '';
    final int exp = int.tryParse(data['exp']?.toString() ?? '') ?? 0;
    if (ownerUid.isEmpty) return false;
    if (DateTime.now().millisecondsSinceEpoch > exp) {
      // Expired token
      await tokenRef.remove();
      return false;
    }

    // Send request to the owner (respect dedup/rate-limit)
    final ok = await sendFriendRequestToUid(ownerUid);
    if (ok) {
      await tokenRef.remove();
    }
    return ok;
  }

  // Extract UUID token from arbitrary strings like
  // "moveyoung://friend?token=<uuid>" or plain <uuid>
  static String _normalizeToken(String raw) {
    final RegExp uuidPattern = RegExp(
      r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}",
    );
    final match = uuidPattern.firstMatch(raw);
    if (match != null) return match.group(0)!;
    // Try query param token=
    final uri = Uri.tryParse(raw);
    if (uri != null) {
      final t = uri.queryParameters['token'];
      if (t != null && t.isNotEmpty) {
        final m = uuidPattern.firstMatch(t);
        if (m != null) return m.group(0)!;
        return t;
      }
    }
    return raw.trim();
  }

  // Helpers to read minimal profile for a uid
  static Future<String> fetchDisplayName(String uid) async {
    final DataSnapshot snap = await _db
        .ref('users/$uid/profile/displayName')
        .get();
    if (!snap.exists) return 'User';
    final String name = snap.value?.toString() ?? 'User';
    if (name.trim().isEmpty) return 'User';
    return name;
  }

  static Future<String?> fetchPhotoURL(String uid) async {
    final DataSnapshot snap = await _db
        .ref('users/$uid/profile/photoURL')
        .get();
    if (!snap.exists) return null;
    final String url = snap.value?.toString() ?? '';
    return url.isEmpty ? null : url;
  }

  static Future<Map<String, String?>> fetchMinimalProfile(String uid) async {
    final DataSnapshot snap = await _db.ref('users/$uid/profile').get();
    if (!snap.exists || snap.value is! Map) {
      return {'displayName': 'User', 'photoURL': null};
    }
    final Map data = snap.value as Map;
    final String name = (data['displayName']?.toString() ?? '').trim();
    final String url = (data['photoURL']?.toString() ?? '').trim();
    return {
      'displayName': name.isEmpty ? 'User' : name,
      'photoURL': url.isEmpty ? null : url,
    };
  }

  // Mutual friends count between current user and other user
  static Future<int> fetchMutualFriendsCount(String otherUid) async {
    final me = _auth.currentUser?.uid;
    if (me == null || me == otherUid) return 0;
    final meRef = _db.ref('users/$me/friends');
    final otherRef = _db.ref('users/$otherUid/friends');
    final snaps = await Future.wait([meRef.get(), otherRef.get()]);
    final a = snaps[0].value is Map
        ? (snaps[0].value as Map).keys.cast<String>().toSet()
        : <String>{};
    final b = snaps[1].value is Map
        ? (snaps[1].value as Map).keys.cast<String>().toSet()
        : <String>{};
    a.remove(otherUid);
    b.remove(me);
    return a.intersection(b).length;
  }
}
