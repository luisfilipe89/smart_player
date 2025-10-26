import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sync Status Indicator Widget Tests', () {
    testWidgets('should show syncing indicator when syncing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlobalSyncStatusBanner(
              isSyncing: true,
              child: const Text('App Content'),
            ),
          ),
        ),
      );

      expect(find.text('App Content'), findsOneWidget);
      expect(find.text('Syncing...'), findsOneWidget);
    });

    testWidgets('should show sync error when sync fails', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlobalSyncStatusBanner(
              isSyncing: false,
              hasError: true,
              child: const Text('App Content'),
            ),
          ),
        ),
      );

      expect(find.text('App Content'), findsOneWidget);
      expect(find.text('Sync failed'), findsOneWidget);
    });

    testWidgets('should hide indicator when sync is complete', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlobalSyncStatusBanner(
              isSyncing: false,
              hasError: false,
              child: const Text('App Content'),
            ),
          ),
        ),
      );

      expect(find.text('App Content'), findsOneWidget);
      expect(find.text('Syncing...'), findsNothing);
      expect(find.text('Sync failed'), findsNothing);
    });
  });
}

// Simple GlobalSyncStatusBanner widget for testing
class GlobalSyncStatusBanner extends StatelessWidget {
  final bool isSyncing;
  final bool hasError;
  final Widget child;

  const GlobalSyncStatusBanner({
    super.key,
    required this.isSyncing,
    this.hasError = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isSyncing)
          Container(
            color: Colors.blue,
            padding: const EdgeInsets.all(8.0),
            child: const Text('Syncing...'),
          ),
        if (hasError)
          Container(
            color: Colors.red,
            padding: const EdgeInsets.all(8.0),
            child: const Text('Sync failed'),
          ),
        Expanded(child: child),
      ],
    );
  }
}
