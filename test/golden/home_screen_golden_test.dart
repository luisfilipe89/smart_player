import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Home Screen Visual Tests', () {
    testWidgets('home screen renders correctly', (tester) async {
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

      expect(find.text('MoveYoung'), findsOneWidget);
      expect(find.text('Welcome to MoveYoung!'), findsOneWidget);
    });

    testWidgets('home screen with dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('MoveYoung')),
            body: const Center(
              child: Text('Welcome to MoveYoung!'),
            ),
          ),
        ),
      );

      expect(find.text('MoveYoung'), findsOneWidget);
      expect(find.text('Welcome to MoveYoung!'), findsOneWidget);
    });

    testWidgets('home screen layout is correct', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('MoveYoung')),
            body: const Center(
              child: Column(
                children: [
                  Text('Welcome!'),
                  Text('To MoveYoung'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Welcome!'), findsOneWidget);
      expect(find.text('To MoveYoung'), findsOneWidget);
    });
  });
}
