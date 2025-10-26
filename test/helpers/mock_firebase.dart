import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Generate mocks for Firebase services used in tests
/// Run: flutter pub run build_runner build --delete-conflicting-outputs
@GenerateMocks([
  FirebaseAuth,
  FirebaseDatabase,
  User,
  DatabaseReference,
  DataSnapshot,
  Query,
  FirebaseMessaging,
  RemoteMessage,
])
void main() {}

/// Helper class for creating mock Firebase data structures
class MockFirebaseHelper {
  /// Create a mock DataSnapshot with the given value
  static Map<String, dynamic> createSnapshot({
    required dynamic value,
    required String path,
  }) {
    return {
      'value': value,
      'key': path.split('/').last,
      'path': path,
      'exists': value != null,
    };
  }

  /// Create a mock user map
  static Map<String, dynamic> createUserMap({
    required String uid,
    String? email,
    String? displayName,
    String? photoURL,
    bool? isAnonymous,
  }) {
    return {
      'uid': uid,
      if (email != null) 'email': email,
      if (displayName != null) 'displayName': displayName,
      if (photoURL != null) 'photoURL': photoURL,
      if (isAnonymous != null) 'isAnonymous': isAnonymous,
    };
  }

  /// Create a mock game data map for Firebase
  static Map<String, dynamic> createGameMap({
    required String id,
    required String sport,
    required DateTime dateTime,
    required String location,
    required int maxPlayers,
    int currentPlayers = 0,
    required String organizerId,
    required String organizerName,
    bool isPublic = true,
  }) {
    return {
      'id': id,
      'sport': sport,
      'dateTime': dateTime.toIso8601String(),
      'location': location,
      'maxPlayers': maxPlayers,
      'currentPlayers': currentPlayers,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'isPublic': isPublic,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  /// Create a mock friend request data map
  static Map<String, dynamic> createFriendRequestMap({
    required String fromUid,
    required String toUid,
    String status = 'pending',
    DateTime? timestamp,
  }) {
    return {
      'fromUid': fromUid,
      'toUid': toUid,
      'status': status,
      'timestamp': (timestamp ?? DateTime.now()).millisecondsSinceEpoch,
    };
  }
}
