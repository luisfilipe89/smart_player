import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/services/games/games_provider.dart';

void main() {
  group('Games Provider Structure Tests', () {
    test('GamesActions class should exist', () {
      expect(GamesActions, isNotNull);
    });

    test('gamesServiceProvider should exist', () {
      expect(gamesServiceProvider, isNotNull);
    });

    test('myGamesProvider should exist', () {
      expect(myGamesProvider, isNotNull);
    });

    test('joinableGamesProvider should exist', () {
      expect(joinableGamesProvider, isNotNull);
    });

    test('gameByIdProvider should exist', () {
      expect(gameByIdProvider, isNotNull);
    });

    test('gamesActionsProvider should exist', () {
      expect(gamesActionsProvider, isNotNull);
    });
  });
}
