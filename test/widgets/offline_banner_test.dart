import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Offline Banner Widget Tests', () {
    testWidgets('should render offline banner when offline', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              isOffline: true,
              child: const Text('App Content'),
            ),
          ),
        ),
      );

      expect(find.text('App Content'), findsOneWidget);
      expect(find.text('You are offline'), findsOneWidget);
    });

    testWidgets('should hide offline banner when online', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              isOffline: false,
              child: const Text('App Content'),
            ),
          ),
        ),
      );

      expect(find.text('App Content'), findsOneWidget);
      expect(find.text('You are offline'), findsNothing);
    });

    testWidgets('should render child widget correctly', (tester) async {
      const childWidget = Text('Test Content');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              isOffline: false,
              child: childWidget,
            ),
          ),
        ),
      );

      expect(find.text('Test Content'), findsOneWidget);
    });
  });
}

// Simple OfflineBanner widget for testing
class OfflineBanner extends StatelessWidget {
  final bool isOffline;
  final Widget child;

  const OfflineBanner({
    super.key,
    required this.isOffline,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isOffline)
          Container(
            color: Colors.red,
            padding: const EdgeInsets.all(8.0),
            child: const Text('You are offline'),
          ),
        Expanded(child: child),
      ],
    );
  }
}
