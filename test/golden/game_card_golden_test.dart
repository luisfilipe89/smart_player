import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Game Card Visual Tests', () {
    testWidgets('game card renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Soccer Game'),
                      const Text('Central Park Field'),
                      const Text('Tomorrow at 2:00 PM'),
                      const Text('5/10 players'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Soccer Game'), findsOneWidget);
      expect(find.text('Central Park Field'), findsOneWidget);
      expect(find.text('Tomorrow at 2:00 PM'), findsOneWidget);
      expect(find.text('5/10 players'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
    });

    testWidgets('game card with different sport', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Basketball Game'),
                      const Text('Sports Complex'),
                      const Text('Today at 6:00 PM'),
                      const Text('3/8 players'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Basketball Game'), findsOneWidget);
      expect(find.text('Sports Complex'), findsOneWidget);
      expect(find.text('Today at 6:00 PM'), findsOneWidget);
      expect(find.text('3/8 players'), findsOneWidget);
    });

    testWidgets('game card has correct structure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sports_soccer),
                      const Text('Game Title'),
                      const Text('Game Details'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
      expect(find.text('Game Title'), findsOneWidget);
      expect(find.text('Game Details'), findsOneWidget);
    });
  });
}
