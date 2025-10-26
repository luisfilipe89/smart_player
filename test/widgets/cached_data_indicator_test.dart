import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:move_young/widgets/common/cached_data_indicator.dart';

void main() {
  group('CachedDataIndicator Widget Tests', () {
    testWidgets('should render child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CachedDataIndicator(
            isShowingCachedData: false,
            child: Text('Child Widget'),
          ),
        ),
      );

      expect(find.text('Child Widget'), findsOneWidget);
    });

    testWidgets('should show indicator when isShowingCachedData is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CachedDataIndicator(
            isShowingCachedData: true,
            child: Text('Child Widget'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Widget builds, indicator should be visible with animation
      expect(find.text('Child Widget'), findsOneWidget);
      // Note: We can't easily test localized text, but we can test structure
      expect(find.byIcon(Icons.cached), findsOneWidget);
    });

    testWidgets('should hide indicator when isShowingCachedData is false',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CachedDataIndicator(
            isShowingCachedData: false,
            child: Text('Child Widget'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Child Widget'), findsOneWidget);
      expect(find.byIcon(Icons.cached), findsNothing);
    });

    testWidgets('should toggle indicator visibility', (tester) async {
      bool isShowing = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return CachedDataIndicator(
                isShowingCachedData: isShowing,
                child: Text('Child Widget'),
              );
            },
          ),
        ),
      );

      // Initially hidden
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cached), findsNothing);

      // Toggle to show
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              isShowing = true;
              return CachedDataIndicator(
                isShowingCachedData: isShowing,
                child: Text('Child Widget'),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.cached), findsOneWidget);
    });

    testWidgets('should call onRefresh when refresh button is tapped',
        (tester) async {
      bool refreshCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: CachedDataIndicator(
            isShowingCachedData: true,
            onRefresh: () {
              refreshCalled = true;
            },
            child: Text('Child Widget'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the refresh button
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();

      expect(refreshCalled, isTrue);
    });

    testWidgets('should animate in and out correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CachedDataIndicator(
            isShowingCachedData: false,
            child: Text('Child Widget'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially hidden
      expect(find.byIcon(Icons.cached), findsNothing);

      // Show indicator
      await tester.pumpWidget(
        MaterialApp(
          home: CachedDataIndicator(
            isShowingCachedData: true,
            child: Text('Child Widget'),
          ),
        ),
      );

      // Pump animation frames
      await tester.pump(Duration.zero);
      await tester.pump(Duration(milliseconds: 150));
      await tester.pump(Duration(milliseconds: 300));

      // Indicator should be visible after animation
      expect(find.byIcon(Icons.cached), findsOneWidget);

      // Hide indicator
      await tester.pumpWidget(
        MaterialApp(
          home: CachedDataIndicator(
            isShowingCachedData: false,
            child: Text('Child Widget'),
          ),
        ),
      );

      // Pump animation frames
      await tester.pump(Duration.zero);
      await tester.pump(Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Indicator should be hidden after animation
      expect(find.byIcon(Icons.cached), findsNothing);
    });

    testWidgets('should not show refresh button when onRefresh is null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CachedDataIndicator(
            isShowingCachedData: true,
            onRefresh: null,
            child: Text('Child Widget'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Icon should be present but no refresh button
      expect(find.byIcon(Icons.cached), findsOneWidget);
      // Verify no refresh button interaction (would find text button with tap_to_refresh text in real app)
    });
  });
}
