import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

/// Standard device size for golden tests (iPhone 11 Pro)
const standardPhoneSize = Size(414, 896);

/// Standard padding to apply to golden tests
const standardPadding = EdgeInsets.all(16);

/// Helper to wrap widget with MaterialApp for golden tests
Widget goldenMaterialAppWrapper(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3), // AppColors.primary
        brightness: Brightness.light,
      ),
      cardTheme: CardThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
    home: Scaffold(
      body: SafeArea(
        child: child,
      ),
    ),
  );
}

/// Helper to get standard device configuration for golden tests
Device phoneConfig() {
  return Device.phone;
}

/// Helper to get surface size for golden tests
Size goldenSurfaceSize() {
  return standardPhoneSize;
}
