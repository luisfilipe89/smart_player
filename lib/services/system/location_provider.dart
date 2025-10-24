import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service_instance.dart';

/// LocationService provider with dependency injection
final locationServiceProvider = Provider<LocationServiceInstance>((ref) {
  return LocationServiceInstance();
});

/// Location permission provider (reactive)
final locationPermissionProvider = FutureProvider<LocationPermission>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.checkPermission();
});

/// Location service enabled provider (reactive)
final locationServiceEnabledProvider = FutureProvider<bool>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.isServiceEnabled();
});

/// Current position provider (reactive)
final currentPositionProvider = FutureProvider<Position>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.getCurrentPosition();
});

/// Location actions provider
final locationActionsProvider = Provider<LocationActions>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return LocationActions(locationService);
});

/// Helper class for location actions
class LocationActions {
  final LocationServiceInstance _locationService;

  LocationActions(this._locationService);

  Future<bool> isServiceEnabled() => _locationService.isServiceEnabled();
  Future<LocationPermission> checkPermission() =>
      _locationService.checkPermission();
  Future<LocationPermission> requestPermissionIfNeeded() =>
      _locationService.requestPermissionIfNeeded();
  Future<void> openSettings() => _locationService.openSettings();
  Future<Position> getCurrentPosition(
          {LocationAccuracy accuracy = LocationAccuracy.high}) =>
      _locationService.getCurrentPosition(accuracy: accuracy);
  String mapError(Object error) => _locationService.mapError(error);
}
