// lib/services/haptics_service_instance.dart
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Instance-based HapticsService for use with Riverpod dependency injection
class HapticsServiceInstance {
  final SharedPreferences _prefs;
  static const String _prefsKey = 'haptics_enabled';

  bool _enabledCache = true;
  bool _loaded = false;
  final StreamController<bool> _enabledController =
      StreamController<bool>.broadcast();

  HapticsServiceInstance(this._prefs);

  /// Initialize the haptics service
  Future<void> initialize() async {
    try {
      _enabledCache = _prefs.getBool(_prefsKey) ?? true;
      _loaded = true;
      _enabledController.add(_enabledCache);
    } catch (e) {
      // If SharedPreferences fails to initialize, use default value
      _enabledCache = true;
      _loaded = true;
      _enabledController.add(_enabledCache);
    }
  }

  /// Get current enabled state
  bool get enabled => _enabledCache;

  /// Get enabled state (async for consistency)
  Future<bool> isEnabled() async {
    if (_loaded) return _enabledCache;
    await initialize();
    return _enabledCache;
  }

  /// Set enabled state
  Future<void> setEnabled(bool value) async {
    _enabledCache = value;
    try {
      await _prefs.setBool(_prefsKey, value);
      _enabledController.add(value);
    } catch (e) {
      // If SharedPreferences fails, just update the cache and stream
      _enabledController.add(value);
    }
  }

  /// Stream of enabled state changes
  Stream<bool> get enabledStream => _enabledController.stream;

  /// Light impact haptic feedback
  Future<void> lightImpact() async {
    if (await isEnabled()) {
      HapticFeedback.lightImpact();
    }
  }

  /// Selection click haptic feedback
  Future<void> selectionClick() async {
    if (await isEnabled()) {
      HapticFeedback.selectionClick();
    }
  }

  /// Medium impact haptic feedback
  Future<void> mediumImpact() async {
    if (await isEnabled()) {
      HapticFeedback.mediumImpact();
    }
  }

  /// Heavy impact haptic feedback
  Future<void> heavyImpact() async {
    if (await isEnabled()) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Dispose resources
  void dispose() {
    _enabledController.close();
  }
}
