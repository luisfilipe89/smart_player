import 'package:move_young/models/core/game.dart';
import 'package:move_young/models/core/activity.dart';

/// Test data and sample objects for testing
class TestData {
  // Sample Game data
  static Game createSampleGame() {
    return Game(
      id: 'test-game-1',
      sport: 'soccer',
      dateTime: DateTime.now().add(const Duration(days: 1)),
      location: 'Test Field',
      maxPlayers: 10,
      currentPlayers: 5,
      organizerId: 'test-organizer',
      organizerName: 'Test Organizer',
      description: 'A test game for testing purposes',
      isPublic: true,
      createdAt: DateTime.now(),
    );
  }

  static Game createSampleGame2() {
    return Game(
      id: 'test-game-2',
      sport: 'basketball',
      dateTime: DateTime.now().add(const Duration(days: 2)),
      location: 'Test Court',
      maxPlayers: 8,
      currentPlayers: 3,
      organizerId: 'test-organizer-2',
      organizerName: 'Test Organizer 2',
      description: 'Another test game',
      isPublic: false,
      createdAt: DateTime.now(),
    );
  }

  // Sample Activity data
  static const Activity sampleActivity = Activity(
    key: 'soccer',
    image: 'assets/images/soccer.webp',
    kcalPerHour: 500,
  );

  static const Activity sampleActivity2 = Activity(
    key: 'basketball',
    image: 'assets/images/basketball.jpg',
    kcalPerHour: 600,
  );

  // Sample Friend data
  static Map<String, dynamic> sampleFriend = {
    'uid': 'friend-123',
    'displayName': 'Test Friend',
    'email': 'friend@test.com',
    'photoURL': 'https://example.com/photo.jpg',
    'isOnline': true,
    'lastSeen': DateTime.now().millisecondsSinceEpoch,
  };

  static Map<String, dynamic> sampleFriendRequest = {
    'uid': 'requester-456',
    'displayName': 'Test Requester',
    'email': 'requester@test.com',
    'photoURL': 'https://example.com/requester.jpg',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'status': 'pending',
  };
}
