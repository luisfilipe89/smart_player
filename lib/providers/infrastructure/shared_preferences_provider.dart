import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences instance initialized early in main()
/// This ensures platform channels are ready before first access
SharedPreferences? _earlyInitializedPrefs;

/// Wait for platform channels to be ready
/// Uses multiple frame callbacks to ensure plugin registration completes
/// This is more reliable than checking the channel directly
Future<void> _waitForPlatformChannels() async {
  // Wait for first frame to ensure WidgetsFlutterBinding is ready
  await Future.delayed(const Duration(milliseconds: 100));

  // Wait for second frame to ensure all plugins are registered
  // Plugin registration happens during first frame, so second frame should be safe
  await Future.delayed(const Duration(milliseconds: 200));

  // Additional buffer for slow devices or plugin registration delays
  await Future.delayed(const Duration(milliseconds: 300));

  debugPrint(
      '[SharedPreferences] Platform channel wait complete (600ms total)');
}

/// Initialize SharedPreferences synchronously in main() before runApp()
/// This ensures platform channels are ready and plugin is registered
Future<SharedPreferences?> initializeSharedPreferencesEarly() async {
  if (_earlyInitializedPrefs != null) {
    return _earlyInitializedPrefs;
  }

  try {
    debugPrint('[SharedPreferences] Early initialization in main()...');

    // Wait for platform channels to be fully ready
    await _waitForPlatformChannels();

    final prefs = await SharedPreferences.getInstance();
    _earlyInitializedPrefs = prefs;
    debugPrint('[SharedPreferences] Early initialization successful');
    return prefs;
  } catch (e) {
    debugPrint('[SharedPreferences] Early initialization failed: $e');
    // Retry with longer wait
    try {
      debugPrint('[SharedPreferences] Retrying after longer delay...');
      await Future.delayed(const Duration(milliseconds: 2000));
      await _waitForPlatformChannels();
      final prefs = await SharedPreferences.getInstance();
      _earlyInitializedPrefs = prefs;
      debugPrint(
          '[SharedPreferences] Early initialization successful on retry');
      return prefs;
    } catch (e2) {
      debugPrint(
          '[SharedPreferences] Early initialization retry also failed: $e2');
      // Don't throw - let FutureProvider handle retry later
      return null;
    }
  }
}

/// SharedPreferences provider for dependency injection
/// Uses FutureProvider to handle async initialization automatically
/// Tries to use early-initialized instance first, falls back to lazy init
final sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((ref) async {
  // If already initialized early, use that
  if (_earlyInitializedPrefs != null) {
    debugPrint('[SharedPreferences] Using early-initialized instance');
    return _earlyInitializedPrefs!;
  }

  // Otherwise, try to initialize now (shouldn't happen if early init worked)
  try {
    debugPrint('[SharedPreferences] Lazy initialization...');
    await Future.delayed(const Duration(milliseconds: 200));
    final prefs = await SharedPreferences.getInstance();
    _earlyInitializedPrefs = prefs;
    debugPrint('[SharedPreferences] Lazy initialization successful');
    return prefs;
  } catch (e) {
    debugPrint('[SharedPreferences] Lazy initialization failed: $e');
    // Retry once
    try {
      await Future.delayed(const Duration(milliseconds: 1000));
      final prefs = await SharedPreferences.getInstance();
      _earlyInitializedPrefs = prefs;
      debugPrint('[SharedPreferences] Lazy initialization successful on retry');
      return prefs;
    } catch (e2) {
      debugPrint(
          '[SharedPreferences] Lazy initialization retry also failed: $e2');
      // Re-throw to let Riverpod handle the error state
      rethrow;
    }
  }
});

/// Helper to get SharedPreferences synchronously if available
/// Returns null if still loading or on error
/// For most cases, prefer watching sharedPreferencesProvider directly
SharedPreferences? getSharedPreferencesSync(WidgetRef ref) {
  final asyncValue = ref.read(sharedPreferencesProvider);
  return asyncValue.valueOrNull;
}
