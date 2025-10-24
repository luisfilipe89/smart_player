import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AccessibilityService {
  AccessibilityService._();

  static const String _keyHighContrast = 'accessibility_high_contrast';
  static final StreamController<bool> _highContrastController =
      StreamController<bool>.broadcast();

  /// Get the current high contrast setting
  static Future<bool> isHighContrastEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyHighContrast) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Set the high contrast setting
  static Future<void> setHighContrastEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHighContrast, enabled);
      _highContrastController.add(enabled);
    } catch (e) {
      // If SharedPreferences fails, just update the stream
      _highContrastController.add(enabled);
    }
  }

  /// Stream of high contrast setting changes
  static Stream<bool> highContrastStream() {
    return _highContrastController.stream;
  }

  /// Initialize the stream with current value
  static Future<void> initialize() async {
    try {
      final currentValue = await isHighContrastEnabled();
      _highContrastController.add(currentValue);
    } catch (e) {
      // If initialization fails, use default value
      _highContrastController.add(false);
    }
  }

  /// Dispose the controller
  static void dispose() {
    _highContrastController.close();
  }
}
