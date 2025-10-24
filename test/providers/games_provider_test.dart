import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/providers/services/games_provider.dart';
// import 'package:move_young/models/game.dart';

void main() {
  group('Games Provider Tests', () {
    testWidgets('gamesServiceProvider should create GamesServiceInstance',
        (tester) async {
      final container = ProviderContainer();

      final gamesService = container.read(gamesServiceProvider);
      expect(gamesService, isNotNull);

      container.dispose();
    });

    testWidgets('myGamesProvider should handle loading state', (tester) async {
      final container = ProviderContainer();

      final asyncValue = container.read(myGamesProvider);
      expect(asyncValue.isLoading, isTrue);

      container.dispose();
    });

    testWidgets('joinableGamesProvider should handle loading state',
        (tester) async {
      final container = ProviderContainer();

      final asyncValue = container.read(joinableGamesProvider);
      expect(asyncValue.isLoading, isTrue);

      container.dispose();
    });

    testWidgets('gameByIdProvider should handle loading state', (tester) async {
      final container = ProviderContainer();

      final asyncValue = container.read(gameByIdProvider('test-game-id'));
      expect(asyncValue.isLoading, isTrue);

      container.dispose();
    });

    testWidgets('gamesActionsProvider should create GamesActions',
        (tester) async {
      final container = ProviderContainer();

      final gamesActions = container.read(gamesActionsProvider);
      expect(gamesActions, isNotNull);

      container.dispose();
    });
  });
}
