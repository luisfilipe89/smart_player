import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Helper functions for pumping widgets in tests
class PumpApp {
  /// Pumps a widget with basic setup
  static Future<void> pumpWidget(
    WidgetTester tester,
    Widget widget, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: widget,
        ),
      ),
    );
  }

  /// Pumps a widget for golden tests
  static Future<void> pumpWidgetForGolden(
    WidgetTester tester,
    Widget widget, {
    Size? surfaceSize,
    List<Override> overrides = const [],
  }) async {
    await tester.binding.setSurfaceSize(surfaceSize ?? const Size(400, 800));
    await pumpWidget(tester, widget, overrides: overrides);
  }

  /// Pumps a widget with high contrast theme
  static Future<void> pumpWidgetWithHighContrast(
    WidgetTester tester,
    Widget widget, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            // Add high contrast theme properties here
          ),
          home: widget,
        ),
      ),
    );
  }
}
