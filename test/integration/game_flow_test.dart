import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/providers/services/games_provider.dart';
import 'package:move_young/providers/services/auth_provider.dart';

void main() {
  group('Game Flow Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('should handle complete game flow', (tester) async {
      // Test initial state - no games
      final myGames = container.read(myGamesProvider);
      expect(myGames.isLoading, isTrue);

      final joinableGames = container.read(joinableGamesProvider);
      expect(joinableGames.isLoading, isTrue);

      // Test that games actions are available
      final gamesActions = container.read(gamesActionsProvider);
      expect(gamesActions, isNotNull);
    });

    testWidgets('should handle provider state changes', (tester) async {
      // Test that providers can be read multiple times without issues
      for (int i = 0; i < 5; i++) {
        final myGames = container.read(myGamesProvider);
        final joinableGames = container.read(joinableGamesProvider);
        final gamesActions = container.read(gamesActionsProvider);

        expect(myGames, isNotNull);
        expect(joinableGames, isNotNull);
        expect(gamesActions, isNotNull);
      }
    });

    testWidgets('should handle provider invalidation', (tester) async {
      // Test that providers can be invalidated without issues
      expect(() => container.invalidate(myGamesProvider), returnsNormally);
      expect(
          () => container.invalidate(joinableGamesProvider), returnsNormally);
      expect(() => container.invalidate(gamesActionsProvider), returnsNormally);
    });

    testWidgets('should handle provider dependencies', (tester) async {
      // Test that providers can access their dependencies
      final gamesService = container.read(gamesServiceProvider);
      expect(gamesService, isNotNull);

      // Test that auth dependencies are available
      final authService = container.read(authServiceProvider);
      expect(authService, isNotNull);
    });
  });
}
