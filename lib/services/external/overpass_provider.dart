import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'overpass_service_instance.dart';
import 'package:move_young/providers/infrastructure/shared_preferences_provider.dart';

// Overpass service provider
final overpassServiceProvider = Provider<OverpassServiceInstance?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs != null ? OverpassServiceInstance(prefs) : null;
});

// Overpass actions provider
final overpassActionsProvider = Provider<OverpassActions?>((ref) {
  final overpassService = ref.watch(overpassServiceProvider);
  if (overpassService == null) {
    return null;
  }
  return OverpassActions(overpassService);
});

class OverpassActions {
  final OverpassServiceInstance _overpassService;

  OverpassActions(this._overpassService);

  Future<List<Map<String, dynamic>>> fetchFields({
    required String areaName,
    required String sportType,
    bool bypassCache = false,
  }) async {
    return await _overpassService.fetchFields(
      areaName: areaName,
      sportType: sportType,
      bypassCache: bypassCache,
    );
  }

  Future<List<Map<String, dynamic>>> fetchMultipleFields({
    required String areaName,
    required List<String> sportTypes,
    bool bypassCache = false,
  }) async {
    return await _overpassService.fetchMultipleFields(
      areaName: areaName,
      sportTypes: sportTypes,
      bypassCache: bypassCache,
    );
  }
}
