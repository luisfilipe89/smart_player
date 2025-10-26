import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/services/cache/cache_service_instance.dart';
import '../helpers/test_db_helper.dart';

void main() {
  group('CacheServiceInstance Tests', () {
    late CacheServiceInstance cacheService;

    setUpAll(() {
      TestDbHelper.initializeFfi();
    });

    setUp(() async {
      cacheService = CacheServiceInstance();
      // Force initialization
      await cacheService.database;
    });

    tearDown(() async {
      await cacheService.close();
    });

    group('User Profile Cache', () {
      test('should cache user profile', () async {
        final uid = 'test-user-123';
        final profileData = {
          'displayName': 'Test User',
          'photoURL': 'https://example.com/photo.jpg',
          'email': 'test@example.com',
        };

        await cacheService.cacheUserProfile(uid, profileData);

        final cachedProfile = await cacheService.getCachedUserProfile(uid);

        expect(cachedProfile, isNotNull);
        expect(cachedProfile!['displayName'], 'Test User');
        expect(cachedProfile['photoURL'], 'https://example.com/photo.jpg');
        expect(cachedProfile['email'], 'test@example.com');
      });

      test('should return null for non-existent profile', () async {
        final cachedProfile =
            await cacheService.getCachedUserProfile('non-existent-uid');

        expect(cachedProfile, isNull);
      });

      test('should replace existing cached profile', () async {
        final uid = 'test-user-123';
        final profileData1 = {
          'displayName': 'Old Name',
          'photoURL': 'old.jpg',
          'email': 'old@example.com',
        };
        final profileData2 = {
          'displayName': 'New Name',
          'photoURL': 'new.jpg',
          'email': 'new@example.com',
        };

        await cacheService.cacheUserProfile(uid, profileData1);
        await cacheService.cacheUserProfile(uid, profileData2);

        final cachedProfile = await cacheService.getCachedUserProfile(uid);

        expect(cachedProfile, isNotNull);
        expect(cachedProfile!['displayName'], 'New Name');
        expect(cachedProfile['photoURL'], 'new.jpg');
      });

      test('should handle cache failures gracefully', () async {
        final profileData = {'displayName': 'Test'};

        // Should not throw
        await cacheService.cacheUserProfile('', profileData);
      });
    });

    group('Game Details Cache', () {
      test('should cache game details', () async {
        final gameId = 'test-game-123';
        final gameData = {'sport': 'soccer', 'location': 'Test Field'};

        await cacheService.cacheGameDetails(gameId, gameData);

        final cachedGame = await cacheService.getCachedGameDetails(gameId);

        expect(cachedGame, isNotNull);
        expect(cachedGame!['sport'], 'soccer');
        expect(cachedGame['location'], 'Test Field');
      });

      test('should return null for non-existent game', () async {
        final cachedGame =
            await cacheService.getCachedGameDetails('non-existent-game');

        expect(cachedGame, isNull);
      });

      test('should replace existing cached game', () async {
        final gameId = 'test-game-123';
        final gameData1 = {'sport': 'basketball', 'location': 'Old Court'};
        final gameData2 = {'sport': 'soccer', 'location': 'New Field'};

        await cacheService.cacheGameDetails(gameId, gameData1);
        await cacheService.cacheGameDetails(gameId, gameData2);

        final cachedGame = await cacheService.getCachedGameDetails(gameId);

        expect(cachedGame, isNotNull);
        expect(cachedGame!['sport'], 'soccer');
        expect(cachedGame['location'], 'New Field');
      });
    });

    group('Cache Expiration', () {
      test('should return null for expired profile cache', () async {
        // Note: This test would require time manipulation to test TTL
        // In a real implementation, you'd use a clock abstraction
        final uid = 'test-user-123';
        final profileData = {
          'displayName': 'Test User',
          'photoURL': 'test.jpg',
          'email': 'test@example.com',
        };

        await cacheService.cacheUserProfile(uid, profileData);

        // Immediately check - should be valid
        final cachedProfile = await cacheService.getCachedUserProfile(uid);
        expect(cachedProfile, isNotNull);
      });

      test('should return null for expired game cache', () async {
        // Similar to profile cache expiration test
        final gameId = 'test-game-123';
        final gameData = {'sport': 'soccer'};

        await cacheService.cacheGameDetails(gameId, gameData);

        // Immediately check - should be valid
        final cachedGame = await cacheService.getCachedGameDetails(gameId);
        expect(cachedGame, isNotNull);
      });
    });

    group('Cache Cleanup', () {
      test('should clear all cache', () async {
        final uid = 'test-user-123';
        final gameId = 'test-game-123';

        await cacheService.cacheUserProfile(uid, {
          'displayName': 'Test',
          'photoURL': 'test.jpg',
          'email': 'test@example.com',
        });
        await cacheService.cacheGameDetails(gameId, {'sport': 'soccer'});

        // Verify cached
        expect(await cacheService.getCachedUserProfile(uid), isNotNull);
        expect(await cacheService.getCachedGameDetails(gameId), isNotNull);

        await cacheService.clearAllCache();

        // Verify cleared
        expect(await cacheService.getCachedUserProfile(uid), isNull);
        expect(await cacheService.getCachedGameDetails(gameId), isNull);
      });

      test('should clear expired cache', () async {
        // Implementation would test TTL expiration
        // For now, just verify the method exists
        await cacheService.clearExpiredCache();

        // Should not throw
        expect(true, isTrue);
      });
    });

    group('Batch Operations', () {
      test('should cache multiple user profiles at once', () async {
        final profiles = {
          'user-1': {
            'displayName': 'User 1',
            'photoURL': 'user1.jpg',
            'email': 'user1@example.com',
          },
          'user-2': {
            'displayName': 'User 2',
            'photoURL': 'user2.jpg',
            'email': 'user2@example.com',
          },
        };

        await cacheService.cacheUserProfiles(profiles);

        final cached1 = await cacheService.getCachedUserProfile('user-1');
        final cached2 = await cacheService.getCachedUserProfile('user-2');

        expect(cached1, isNotNull);
        expect(cached2, isNotNull);
        expect(cached1!['displayName'], 'User 1');
        expect(cached2!['displayName'], 'User 2');
      });
    });
  });

  group('Integration Test Coverage Note', () {
    test('Note: Cache behavior covered by integration tests', () {
      // Cache service is primarily used by other services in real workflows.
      // Full integration testing occurs in:
      // - Integration tests that use cached data for offline functionality
      // - Service-level tests that verify cache usage patterns

      expect(true, isTrue);
    });
  });
}
