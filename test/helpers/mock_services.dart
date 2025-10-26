import 'package:mockito/mockito.dart';
import 'package:move_young/services/auth/auth_service_instance.dart';
import 'package:move_young/services/games/games_service_instance.dart';
import 'package:move_young/services/friends/friends_service_instance.dart';
import 'package:move_young/services/cache/cache_service_instance.dart';
import 'package:move_young/services/connectivity/connectivity_service_instance.dart';
import 'package:move_young/services/notifications/notification_service_instance.dart';

// Mock Auth Service
class MockAuthServiceInstance extends Mock implements AuthServiceInstance {}

// Mock Games Service
class MockGamesServiceInstance extends Mock implements GamesServiceInstance {}

// Mock Friends Service
class MockFriendsServiceInstance extends Mock
    implements FriendsServiceInstance {}

// Mock Cache Service
class MockCacheServiceInstance extends Mock implements CacheServiceInstance {}

// Mock Connectivity Service
class MockConnectivityServiceInstance extends Mock
    implements ConnectivityServiceInstance {}

// Mock Notification Service
class MockNotificationServiceInstance extends Mock
    implements NotificationServiceInstance {}

// Mock Service Factory
class MockServiceFactory {
  static MockAuthServiceInstance createMockAuthService() {
    return MockAuthServiceInstance();
  }

  static MockGamesServiceInstance createMockGamesService() {
    return MockGamesServiceInstance();
  }

  static MockFriendsServiceInstance createMockFriendsService() {
    return MockFriendsServiceInstance();
  }

  static MockCacheServiceInstance createMockCacheService() {
    return MockCacheServiceInstance();
  }

  static MockConnectivityServiceInstance createMockConnectivityService() {
    return MockConnectivityServiceInstance();
  }

  static MockNotificationServiceInstance createMockNotificationService() {
    return MockNotificationServiceInstance();
  }
}
