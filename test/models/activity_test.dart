import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/models/core/activity.dart';
import '../helpers/test_data.dart';

void main() {
  group('Activity Model Tests', () {
    test('should create activity with required fields', () {
      const activity = TestData.sampleActivity;

      expect(activity.key, 'soccer');
      expect(activity.image, 'assets/images/soccer.webp');
      expect(activity.kcalPerHour, 500);
    });

    test('should create different activity', () {
      const activity = TestData.sampleActivity2;

      expect(activity.key, 'basketball');
      expect(activity.image, 'assets/images/basketball.jpg');
      expect(activity.kcalPerHour, 600);
    });

    test('should have correct properties', () {
      const activity = Activity(
        key: 'tennis',
        image: 'assets/images/tennis.jpg',
        kcalPerHour: 400,
      );

      expect(activity.key, 'tennis');
      expect(activity.image, 'assets/images/tennis.jpg');
      expect(activity.kcalPerHour, 400);
    });
  });
}
