// lib/providers/services/accessibility_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/providers/infrastructure/shared_preferences_provider.dart';
import 'accessibility_service_instance.dart';

// AccessibilityService provider with dependency injection
final accessibilityServiceProvider =
    Provider<AccessibilityServiceInstance>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AccessibilityServiceInstance(prefs);
});

// High contrast mode provider (reactive)
final highContrastModeProvider = StreamProvider<bool>((ref) {
  final accessibilityService = ref.watch(accessibilityServiceProvider);
  return accessibilityService.highContrastStream;
});

// High contrast mode boolean provider (simplified)
final isHighContrastEnabledProvider = Provider<bool>((ref) {
  final highContrastAsync = ref.watch(highContrastModeProvider);
  return highContrastAsync.when(
    data: (isEnabled) => isEnabled,
    loading: () => false,
    error: (_, __) => false,
  );
});

// Accessibility actions provider (for toggle operations)
final accessibilityActionsProvider = Provider<AccessibilityActions>((ref) {
  final accessibilityService = ref.watch(accessibilityServiceProvider);
  return AccessibilityActions(accessibilityService);
});

// Helper class for accessibility actions
class AccessibilityActions {
  final AccessibilityServiceInstance _accessibilityService;

  AccessibilityActions(this._accessibilityService);

  Future<void> setHighContrastEnabled(bool enabled) =>
      _accessibilityService.setHighContrastEnabled(enabled);

  Future<bool> isHighContrastEnabled() =>
      _accessibilityService.isHighContrastEnabled();
}
