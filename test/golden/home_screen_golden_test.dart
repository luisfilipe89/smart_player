import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import '../helpers/golden_test_helper.dart';

/// Simplified home screen widget for golden tests
class TestHomeScreen extends StatelessWidget {
  const TestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MoveYoung'),
        backgroundColor: Colors.blue[600],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_soccer,
              size: 80,
              color: Colors.blue[600],
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome to MoveYoung!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Your sports activity organizer',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  group('Home Screen Golden Tests', () {
    testGoldens('home screen renders correctly', (tester) async {
      await tester.pumpWidgetBuilder(
        const TestHomeScreen(),
        surfaceSize: goldenSurfaceSize(),
        wrapper: (child) => MaterialApp(home: child),
      );

      await screenMatchesGolden(tester, 'home_screen_basic');
    });
  });
}
