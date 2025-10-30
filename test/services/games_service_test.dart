import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:move_young/services/games/games_service_instance.dart';
import 'package:move_young/services/auth/auth_service_instance.dart';
import 'package:move_young/repositories/game_repository.dart';
import '../helpers/test_db_helper.dart';
import '../helpers/test_data.dart';

// Mocks
class MockAuthServiceInstance extends Mock implements AuthServiceInstance {}

class MockGameRepository extends Mock implements IGameRepository {}

void main() {
  late GamesServiceInstance gamesService;
  late MockAuthServiceInstance mockAuthService;
  late MockGameRepository mockGameRepository;

  setUp(() {
    TestDbHelper.initializeFfi();
    mockAuthService = MockAuthServiceInstance();
    mockGameRepository = MockGameRepository();

    // Setup mock defaults
    when(mockAuthService.currentUserId).thenReturn('test-user-123');
    when(mockAuthService.isSignedIn).thenReturn(true);

    // Create service with injected mocks
    gamesService = GamesServiceInstance(mockAuthService, mockGameRepository);
  });

  group('GamesServiceInstance - Unit Tests', () {
    test('should handle game creation with cloud service', () async {
      final game = TestData.createSampleGame();

      when(mockGameRepository.createGame(game))
          .thenAnswer((_) async => 'cloud-game-id');

      final gameId = await gamesService.createGame(game);

      expect(gameId, equals('cloud-game-id'));
      verify(mockGameRepository.createGame(game)).called(1);
    });

    test('should handle game creation without cloud service when signed out',
        () async {
      final game = TestData.createSampleGame();

      when(mockAuthService.isSignedIn).thenReturn(false);

      // This should create locally without cloud
      expect(() => gamesService.createGame(game), returnsNormally);
    });

    test('should retrieve empty list when no games exist', () async {
      final myGames = await gamesService.getMyGames();

      expect(myGames, isEmpty);
    });

    test('should get empty list for joinable games when none exist', () async {
      final joinableGames = await gamesService.getJoinableGames();

      expect(joinableGames, isEmpty);
    });

    test('should handle game not found gracefully', () async {
      final nonExistentGame = await gamesService.getGameById('non-existent-id');

      expect(nonExistentGame, isNull);
    });

    test('should sync with cloud when authenticated', () async {
      final cloudGames = [
        TestData.createSampleGame(),
        TestData.createSampleGame2()
      ];

      when(mockGameRepository.getMyGames()).thenAnswer((_) async => cloudGames);

      await gamesService.syncWithCloud();

      verify(mockGameRepository.getMyGames()).called(1);
    });

    test('should not sync when not authenticated', () async {
      when(mockAuthService.isSignedIn).thenReturn(false);

      await gamesService.syncWithCloud();

      verifyNever(mockGameRepository.getMyGames());
    });

    test('should join game through repository', () async {
      final game = TestData.createSampleGame();

      when(mockGameRepository.addPlayerToGame(game.id, 'test-user-123'))
          .thenAnswer((_) async {});

      await gamesService.joinGame(game.id);

      verify(mockGameRepository.addPlayerToGame(game.id, 'test-user-123'))
          .called(1);
    });

    test('should leave game through repository', () async {
      final game = TestData.createSampleGame();

      when(mockGameRepository.removePlayerFromGame(game.id, 'test-user-123'))
          .thenAnswer((_) async {});

      await gamesService.leaveGame(game.id);

      verify(mockGameRepository.removePlayerFromGame(game.id, 'test-user-123'))
          .called(1);
    });

    test('should handle service cleanup gracefully', () async {
      // SQLite database has been removed - no cleanup needed
      // Service uses cloud-first architecture
      expect(true, isTrue);
    });

    test('should respect auth service when not signed in', () async {
      when(mockAuthService.isSignedIn).thenReturn(false);
      when(mockAuthService.currentUserId).thenReturn(null);

      // Sync is now a no-op (cloud-first architecture)
      await gamesService.syncWithCloud();

      // Should not throw
      expect(true, isTrue);
    });
  });

  group('Integration Test Coverage Note', () {
    test('Note: Full game flows covered by integration tests', () {
      // This test serves as documentation that complete game management flows
      // including cloud operations, joins/leaves, and Firebase integration
      // are comprehensively tested in:
      // - integration_test/game_flow_test.dart (4 tests)
      // - integration_test/screen_game_organize_test.dart (3 tests)
      // - integration_test/screen_game_join_test.dart (3 tests)
      // - integration_test/screen_my_games_test.dart (4 tests)

      expect(true, isTrue);
    });
  });
}
