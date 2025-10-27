import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences provider for dependency injection
/// Starts as null and is initialized manually after platform channels are ready
final sharedPreferencesProvider =
    StateProvider<SharedPreferences?>((ref) => null);

/// Helper to initialize SharedPreferences after platform channels are ready
Future<void> initializeSharedPreferences(WidgetRef ref) async {
  try {
    debugPrint('Initializing SharedPreferences...');
    // Wait to ensure platform channels are ready
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    ref.read(sharedPreferencesProvider.notifier).state = prefs;
    debugPrint('SharedPreferences initialized successfully');
  } catch (e) {
    debugPrint('Failed to get SharedPreferences: $e');
    // Retry once after a longer delay
    try {
      await Future.delayed(const Duration(milliseconds: 2000));
      final prefs = await SharedPreferences.getInstance();
      ref.read(sharedPreferencesProvider.notifier).state = prefs;
      debugPrint('SharedPreferences initialized on retry');
    } catch (e2) {
      debugPrint('Failed to initialize SharedPreferences (retry): $e2');
      // Leave as null - app will continue without persisted settings
    }
  }
}
