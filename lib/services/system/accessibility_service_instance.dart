// lib/services/accessibility_service_instance.dart
// import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:move_young/utils/logger.dart';

/// Instance-based AccessibilityService for use with Riverpod dependency injection
class AccessibilityServiceInstance {
  final SharedPreferences _prefs;

  static const String _keyHighContrast = 'accessibility_high_contrast';
  final StreamController<bool> _highContrastController =
      StreamController<bool>.broadcast();

  AccessibilityServiceInstance(this._prefs);

  /// Get the current high contrast setting
  Future<bool> isHighContrastEnabled() async {
    try {
      return _prefs.getBool(_keyHighContrast) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Set the high contrast setting
  Future<void> setHighContrastEnabled(bool enabled) async {
    try {
      await _prefs.setBool(_keyHighContrast, enabled);
      _highContrastController.add(enabled);
    } catch (e) {
      // If SharedPreferences fails, just update the stream
      _highContrastController.add(enabled);
    }
  }

  /// Stream of high contrast setting changes
  Stream<bool> get highContrastStream => _highContrastController.stream;

  /// Initialize the stream with current value
  Future<void> initialize() async {
    try {
      final currentValue = await isHighContrastEnabled();
      if (!_highContrastController.isClosed) {
        _highContrastController.add(currentValue);
      }
    } catch (e) {
      // If initialization fails, use default value
      NumberedLogger.w('AccessibilityService initialize error: $e');
      if (!_highContrastController.isClosed) {
        _highContrastController.add(false);
      }
    }
  }

  /// Dispose the controller
  void dispose() {
    _highContrastController.close();
  }
}
