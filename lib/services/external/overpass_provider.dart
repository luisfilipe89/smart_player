import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'overpass_service_instance.dart';
import 'package:move_young/providers/infrastructure/shared_preferences_provider.dart';

// Overpass service provider (constructed even if SharedPreferences not ready)
final overpassServiceProvider = Provider<OverpassServiceInstance>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  // OverpassServiceInstance accepts nullable SharedPreferences
  final prefs = prefsAsync.valueOrNull;
  return OverpassServiceInstance(prefs);
});

// Overpass actions provider
final overpassActionsProvider = Provider<OverpassActions>((ref) {
  final overpassService = ref.watch(overpassServiceProvider);
  return OverpassActions(overpassService);
});

class OverpassActions {
  // ignore: unused_field
  final OverpassServiceInstance _overpassService;

  OverpassActions(this._overpassService);

  Future<List<Map<String, dynamic>>> fetchFields({
    required String areaName,
    required String sportType,
    bool bypassCache = false,
  }) async {
    // Overpass disabled: return empty to ensure no network call even if referenced
    // Note: _overpassService is kept for potential future use
    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> fetchMultipleFields({
    required String areaName,
    required List<String> sportTypes,
    bool bypassCache = false,
  }) async {
    // Overpass disabled
    // Note: _overpassService is kept for potential future use
    return <Map<String, dynamic>>[];
  }
}
