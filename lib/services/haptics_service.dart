import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HapticsService {
  static const String _prefsKey = 'haptics_enabled';

  static bool _enabledCache = true;
  static bool _loaded = false;

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabledCache = prefs.getBool(_prefsKey) ?? true;
      _loaded = true;
    } catch (e) {
      // If SharedPreferences fails to initialize, use default value
      _enabledCache = true;
      _loaded = true;
    }
  }

  static bool get enabled => _enabledCache;

  static Future<bool> isEnabled() async {
    if (_loaded) return _enabledCache;
    await initialize();
    return _enabledCache;
  }

  static Future<void> setEnabled(bool value) async {
    _enabledCache = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (e) {
      // If SharedPreferences fails, just update the cache
    }
  }

  static Future<void> lightImpact() async {
    if (await isEnabled()) {
      HapticFeedback.lightImpact();
    }
  }

  static Future<void> selectionClick() async {
    if (await isEnabled()) {
      HapticFeedback.selectionClick();
    }
  }

  static Future<void> mediumImpact() async {
    if (await isEnabled()) {
      HapticFeedback.mediumImpact();
    }
  }

  static Future<void> heavyImpact() async {
    if (await isEnabled()) {
      HapticFeedback.heavyImpact();
    }
  }
}
