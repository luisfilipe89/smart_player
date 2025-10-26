import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alchemist/alchemist.dart';
import 'package:move_young/widgets/common/loading_overlay.dart';
import '../helpers/golden_test_helper.dart';

void main() {
  group('LoadingOverlay Golden Tests', () {
    goldenTest(
      'LoadingOverlay with spinner only',
      fileName: 'loading_overlay_spinner_only',
      builder: () => goldenMaterialAppWrapper(
        const LoadingOverlay(
          isLoading: true,
          child: Scaffold(
            body: Center(
              child: Text('Content behind overlay'),
            ),
          ),
        ),
      ),
    );

    goldenTest(
      'LoadingOverlay with message',
      fileName: 'loading_overlay_with_message',
      builder: () => goldenMaterialAppWrapper(
        const LoadingOverlay(
          isLoading: true,
          message: 'Loading data...',
          child: Scaffold(
            body: Center(
              child: Text('Content behind overlay'),
            ),
          ),
        ),
      ),
    );

    goldenTest(
      'LoadingOverlay with long message',
      fileName: 'loading_overlay_long_message',
      builder: () => goldenMaterialAppWrapper(
        const LoadingOverlay(
          isLoading: true,
          message: 'Synchronizing with server, please wait...',
          child: Scaffold(
            body: Center(
              child: Text('Content behind overlay'),
            ),
          ),
        ),
      ),
    );

    goldenTest(
      'LoadingOverlay when not loading',
      fileName: 'loading_overlay_not_loading',
      builder: () => goldenMaterialAppWrapper(
        const LoadingOverlay(
          isLoading: false,
          child: Scaffold(
            body: Center(
              child: Text('Content visible without overlay'),
            ),
          ),
        ),
      ),
    );
  });
}
