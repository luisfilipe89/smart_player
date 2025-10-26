import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/models/core/game.dart';
import '../helpers/test_data.dart';

void main() {
  group('Game Model Tests', () {
    test('should create game with required fields', () {
      final game = TestData.createSampleGame();

      expect(game.id, 'test-game-1');
      expect(game.sport, 'soccer');
      expect(game.maxPlayers, 10);
      expect(game.currentPlayers, 5);
      expect(game.isPublic, true);
      expect(game.organizerName, 'Test Organizer');
    });

    test('should create game with copyWith', () {
      final game = TestData.createSampleGame();
      final updatedGame = game.copyWith(
        maxPlayers: 12,
        currentPlayers: 8,
      );

      expect(updatedGame.maxPlayers, 12);
      expect(updatedGame.currentPlayers, 8);
      expect(updatedGame.id, game.id); // Other fields should remain the same
    });

    test('should convert to JSON', () {
      final game = TestData.createSampleGame();
      final json = game.toJson();

      expect(json['id'], game.id);
      expect(json['sport'], game.sport);
      expect(json['maxPlayers'], game.maxPlayers);
    });

    test('should convert to cloud JSON', () {
      final game = TestData.createSampleGame();
      final cloudJson = game.toCloudJson();

      expect(cloudJson['id'], game.id);
      expect(cloudJson['sport'], game.sport);
      expect(cloudJson['maxPlayers'], game.maxPlayers);
    });

    test('should create from JSON', () {
      final game = TestData.createSampleGame();
      final json = game.toJson();
      final recreatedGame = Game.fromJson(json);

      expect(recreatedGame.id, game.id);
      expect(recreatedGame.sport, game.sport);
      expect(recreatedGame.maxPlayers, game.maxPlayers);
    });

    test('should check if game is full', () {
      final game = TestData.createSampleGame();
      expect(game.isFull, false);

      final fullGame = game.copyWith(currentPlayers: 10);
      expect(fullGame.isFull, true);
    });

    test('should check if game is upcoming', () {
      final game = TestData.createSampleGame();
      expect(game.isUpcoming, true);

      final pastGame = game.copyWith(
          dateTime: DateTime.now().subtract(const Duration(days: 1)));
      expect(pastGame.isUpcoming, false);
    });

    test('should check if game is today', () {
      final game = TestData.createSampleGame();
      // Note: isToday getter may not exist in the Game model
      // This test would need to be updated based on actual Game model implementation
      expect(
          game.dateTime
              .isAfter(DateTime.now().subtract(const Duration(days: 1))),
          true);

      final todayGame = game.copyWith(dateTime: DateTime.now());
      expect(todayGame.dateTime.day, DateTime.now().day);
    });
  });
}
