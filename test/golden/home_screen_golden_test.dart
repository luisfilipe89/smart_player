import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

void main() {
  group('Home Screen Golden Tests', () {
    testGoldens('home screen matches golden', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('MoveYoung')),
            body: const Center(
              child: Text('Welcome to MoveYoung!'),
            ),
          ),
        ),
      );

      await screenMatchesGolden(tester, 'home_screen');
    });

    testGoldens('home screen with high contrast theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            // Add high contrast properties
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('MoveYoung')),
            body: const Center(
              child: Text('Welcome to MoveYoung!'),
            ),
          ),
        ),
      );

      await screenMatchesGolden(tester, 'home_screen_high_contrast');
    });
  });
}
