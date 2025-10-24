import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';

/// Centralized location/service handling to avoid duplicated flows.
class LocationService {
  const LocationService();

  /// Checks whether location services are enabled on the device.
  Future<bool> isServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Checks current permission state.
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  /// Requests permission if needed. Returns the final state.
  Future<LocationPermission> requestPermissionIfNeeded() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Shortcut to open both app and location settings.
  Future<void> openSettings() async {
    await Geolocator.openAppSettings();
    await Geolocator.openLocationSettings();
  }

  /// Get current position with unified flow and error messages.
  /// Returns either a Position or throws a LocationException with a localized message key.
  Future<Position> getCurrentPosition(
      {LocationAccuracy accuracy = LocationAccuracy.high}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException('location_services_disabled'.tr());
    }

    final permission = await requestPermissionIfNeeded();
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw LocationException('location_denied'.tr());
    }

    try {
      return Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy),
      );
    } catch (_) {
      throw LocationException('failed_location'.tr());
    }
  }

  /// Map an arbitrary error coming from geolocation calls into a user-friendly string.
  String mapError(Object error) {
    if (error is LocationException) return error.message;
    final message = error.toString();
    if (message.contains('deniedForever') || message.contains('denied')) {
      return 'location_denied'.tr();
    }
    return 'failed_location'.tr();
  }
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  @override
  String toString() => message;
}
