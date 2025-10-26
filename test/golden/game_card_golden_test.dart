import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

void main() {
  group('Game Card Golden Tests', () {
    testGoldens('game card matches golden', (tester) async {
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

      await screenMatchesGolden(tester, 'game_card');
    });

    testGoldens('game card with different sport', (tester) async {
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

      await screenMatchesGolden(tester, 'game_card_basketball');
    });
  });
}
