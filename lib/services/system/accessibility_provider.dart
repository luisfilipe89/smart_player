// lib/providers/services/accessibility_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/providers/infrastructure/shared_preferences_provider.dart';
import 'accessibility_service_instance.dart';

// AccessibilityService provider with dependency injection
final accessibilityServiceProvider =
    Provider<AccessibilityServiceInstance?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  if (prefs == null) {
    return null;
  }

  final service = AccessibilityServiceInstance(prefs);
  // Initialize asynchronously but don't await - this will populate the stream
  // Wrap in try-catch to handle any initialization errors gracefully
  service.initialize().catchError((error) {
    debugPrint('Accessibility service initialization error: $error');
  });
  return service;
});

// High contrast mode provider (reactive)
final highContrastModeProvider = StreamProvider<bool>((ref) {
  final accessibilityService = ref.watch(accessibilityServiceProvider);
  if (accessibilityService == null) {
    // Return a stream that emits false if service is not available
    return Stream.value(false);
  }
  return accessibilityService.highContrastStream;
});

// High contrast mode boolean provider (simplified)
final isHighContrastEnabledProvider = Provider<bool>((ref) {
  try {
    final highContrastAsync = ref.watch(highContrastModeProvider);
    return highContrastAsync.when(
      data: (isEnabled) => isEnabled,
      loading: () => false,
      error: (error, stack) {
        // Log error but return false to allow app to continue
        debugPrint('High contrast provider error: $error');
        return false;
      },
    );
  } catch (e) {
    // If provider access fails entirely, return false
    debugPrint('isHighContrastEnabledProvider error: $e');
    return false;
  }
});

// Accessibility actions provider (for toggle operations)
final accessibilityActionsProvider = Provider<AccessibilityActions?>((ref) {
  final accessibilityService = ref.watch(accessibilityServiceProvider);
  if (accessibilityService == null) {
    return null;
  }
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
