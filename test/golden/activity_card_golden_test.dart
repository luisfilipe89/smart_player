import 'package:flutter_test/flutter_test.dart';
import 'package:alchemist/alchemist.dart';
import 'package:move_young/widgets/sports/activity_card.dart';
import '../helpers/golden_test_helper.dart';

void main() {
  group('ActivityCard Golden Tests', () {
    goldenTest(
      'ActivityCard with soccer activity',
      fileName: 'activity_card_soccer',
      builder: () => goldenMaterialAppWrapper(
        ActivityCard(
          title: 'Soccer',
          imageUrl: 'assets/images/soccer.webp',
          calories: '500 kcal/h',
          onTap: () {},
        ),
      ),
    );

    goldenTest(
      'ActivityCard with basketball activity',
      fileName: 'activity_card_basketball',
      builder: () => goldenMaterialAppWrapper(
        ActivityCard(
          title: 'Basketball',
          imageUrl: 'assets/images/basketball.jpg',
          calories: '600 kcal/h',
          onTap: () {},
        ),
      ),
    );

    goldenTest(
      'ActivityCard with tennis activity',
      fileName: 'activity_card_tennis',
      builder: () => goldenMaterialAppWrapper(
        ActivityCard(
          title: 'Tennis',
          imageUrl: 'assets/images/tennis.jpg',
          calories: '550 kcal/h',
          onTap: () {},
        ),
      ),
    );
  });
}
