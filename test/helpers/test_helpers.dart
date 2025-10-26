import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

/// Common test setup utilities and helper functions
class TestHelpers {
  /// Creates a ProviderContainer with common test overrides
  static ProviderContainer createTestContainer({
    List<Override> overrides = const [],
  }) {
    return ProviderContainer(
      overrides: [
        // Add common test overrides here
        ...overrides,
      ],
    );
  }

  /// Creates a test widget with ProviderScope
  static Widget createTestWidget({
    required Widget child,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: child,
    );
  }
}
