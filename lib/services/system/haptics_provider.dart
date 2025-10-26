// lib/providers/services/haptics_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'haptics_service_instance.dart';
import 'package:move_young/providers/infrastructure/shared_preferences_provider.dart';

// HapticsService provider with dependency injection
final hapticsServiceProvider = Provider<HapticsServiceInstance?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs != null ? HapticsServiceInstance(prefs) : null;
});

// Haptics enabled state provider (reactive)
final hapticsEnabledProvider = StreamProvider<bool>((ref) {
  final hapticsService = ref.watch(hapticsServiceProvider);
  if (hapticsService == null) {
    // Return a stream that emits true if service is not available (default enabled)
    return Stream.value(true);
  }
  return hapticsService.enabledStream;
});

// Haptics enabled boolean provider (simplified)
final isHapticsEnabledProvider = Provider<bool>((ref) {
  final hapticsEnabledAsync = ref.watch(hapticsEnabledProvider);
  return hapticsEnabledAsync.when(
    data: (isEnabled) => isEnabled,
    loading: () => true, // Default to enabled during loading
    error: (_, __) => true, // Default to enabled on error
  );
});

// Haptics actions provider (for haptic feedback operations)
final hapticsActionsProvider = Provider<HapticsActions?>((ref) {
  final hapticsService = ref.watch(hapticsServiceProvider);
  if (hapticsService == null) {
    return null;
  }
  return HapticsActions(hapticsService);
});

// Helper class for haptics actions
class HapticsActions {
  final HapticsServiceInstance _hapticsService;

  HapticsActions(this._hapticsService);

  Future<void> lightImpact() => _hapticsService.lightImpact();
  Future<void> selectionClick() => _hapticsService.selectionClick();
  Future<void> mediumImpact() => _hapticsService.mediumImpact();
  Future<void> heavyImpact() => _hapticsService.heavyImpact();
  Future<void> setEnabled(bool enabled) => _hapticsService.setEnabled(enabled);
  Future<bool> isEnabled() => _hapticsService.isEnabled();
}
