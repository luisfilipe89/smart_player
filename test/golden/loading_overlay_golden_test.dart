import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:move_young/widgets/common/loading_overlay.dart';
import '../helpers/golden_test_helper.dart';

void main() {
  group('LoadingOverlay Golden Tests', () {
    testGoldens('LoadingOverlay with spinner only', (tester) async {
      await tester.pumpWidgetBuilder(
        const LoadingOverlay(
          isLoading: true,
          child: Scaffold(
            body: Center(
              child: Text('Content behind overlay'),
            ),
          ),
        ),
        surfaceSize: goldenSurfaceSize(),
        wrapper: goldenMaterialAppWrapper,
      );

      await screenMatchesGolden(tester, 'loading_overlay_spinner_only');
    });

    testGoldens('LoadingOverlay with message', (tester) async {
      await tester.pumpWidgetBuilder(
        const LoadingOverlay(
          isLoading: true,
          message: 'Loading data...',
          child: Scaffold(
            body: Center(
              child: Text('Content behind overlay'),
            ),
          ),
        ),
        surfaceSize: goldenSurfaceSize(),
        wrapper: goldenMaterialAppWrapper,
      );

      await screenMatchesGolden(tester, 'loading_overlay_with_message');
    });

    testGoldens('LoadingOverlay with long message', (tester) async {
      await tester.pumpWidgetBuilder(
        const LoadingOverlay(
          isLoading: true,
          message: 'Synchronizing with server, please wait...',
          child: Scaffold(
            body: Center(
              child: Text('Content behind overlay'),
            ),
          ),
        ),
        surfaceSize: goldenSurfaceSize(),
        wrapper: goldenMaterialAppWrapper,
      );

      await screenMatchesGolden(tester, 'loading_overlay_long_message');
    });

    testGoldens('LoadingOverlay when not loading', (tester) async {
      await tester.pumpWidgetBuilder(
        const LoadingOverlay(
          isLoading: false,
          child: Scaffold(
            body: Center(
              child: Text('Content visible without overlay'),
            ),
          ),
        ),
        surfaceSize: goldenSurfaceSize(),
        wrapper: goldenMaterialAppWrapper,
      );

      await screenMatchesGolden(tester, 'loading_overlay_not_loading');
    });
  });
}
