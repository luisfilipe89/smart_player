import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:move_young/widgets/sports/activity_card.dart';
import '../helpers/golden_test_helper.dart';

void main() {
  group('ActivityCard Golden Tests', () {
    testGoldens('ActivityCard with soccer activity', (tester) async {
      await tester.pumpWidgetBuilder(
        ActivityCard(
          title: 'Soccer',
          imageUrl: 'assets/images/soccer.webp',
          calories: '500 kcal/h',
          onTap: () {},
        ),
        surfaceSize: goldenSurfaceSize(),
        wrapper: goldenMaterialAppWrapper,
      );

      await screenMatchesGolden(tester, 'activity_card_soccer');
    });

    testGoldens('ActivityCard with basketball activity', (tester) async {
      await tester.pumpWidgetBuilder(
        ActivityCard(
          title: 'Basketball',
          imageUrl: 'assets/images/basketball.jpg',
          calories: '600 kcal/h',
          onTap: () {},
        ),
        surfaceSize: goldenSurfaceSize(),
        wrapper: goldenMaterialAppWrapper,
      );

      await screenMatchesGolden(tester, 'activity_card_basketball');
    });

    testGoldens('ActivityCard with tennis activity', (tester) async {
      await tester.pumpWidgetBuilder(
        ActivityCard(
          title: 'Tennis',
          imageUrl: 'assets/images/tennis.jpg',
          calories: '550 kcal/h',
          onTap: () {},
        ),
        surfaceSize: goldenSurfaceSize(),
        wrapper: goldenMaterialAppWrapper,
      );

      await screenMatchesGolden(tester, 'activity_card_tennis');
    });
  });
}
