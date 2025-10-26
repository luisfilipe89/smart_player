import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/models/core/activity.dart';
import '../helpers/test_data.dart';

void main() {
  group('Activity Card Widget Tests', () {
    testWidgets('should render activity card with correct data',
        (tester) async {
      const activity = TestData.sampleActivity;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityCard(
              activity: activity,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('soccer'), findsOneWidget);
      expect(find.text('500 kcal/h'), findsOneWidget);
    });

    testWidgets('should call onTap when tapped', (tester) async {
      bool tapped = false;
      const activity = TestData.sampleActivity;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityCard(
              activity: activity,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActivityCard));
      await tester.pumpAndSettle();

      expect(tapped, true);
    });

    testWidgets('should show different activity data', (tester) async {
      const activity = TestData.sampleActivity2;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityCard(
              activity: activity,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('basketball'), findsOneWidget);
      expect(find.text('600 kcal/h'), findsOneWidget);
    });
  });
}

// Simple ActivityCard widget for testing
class ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback? onTap;

  const ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(activity.key),
              Text('${activity.kcalPerHour} kcal/h'),
            ],
          ),
        ),
      ),
    );
  }
}
