import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';

/// Instance-based LocationService for use with Riverpod dependency injection
class LocationServiceInstance {
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
  /// Automatically disabled on emulators to prevent crashes.
  Future<Position> getCurrentPosition(
      {LocationAccuracy accuracy = LocationAccuracy.high}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationException('location_services_disabled'.tr());
      }

      final permission = await requestPermissionIfNeeded();
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        throw LocationException('location_denied'.tr());
      }

      // Try to get position with very short timeout first to detect emulators
      // Emulators typically fail immediately or hang
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: accuracy,
            timeLimit:
                const Duration(seconds: 2), // Short timeout to detect emulators
          ),
        ).timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            // Timeout likely means emulator - throw emulator-specific error
            throw LocationException('location_emulator_not_supported'.tr());
          },
        );
      } on TimeoutException {
        // Timeout = likely emulator
        throw LocationException('location_emulator_not_supported'.tr());
      } catch (e) {
        // If it fails immediately or with platform error, likely emulator
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('platform') ||
            errorMsg.contains('methodchannel') ||
            errorMsg.contains('not implemented') ||
            errorMsg.contains('unavailable')) {
          throw LocationException('location_emulator_not_supported'.tr());
        }
        rethrow; // Re-throw other errors
      }
    } on LocationException {
      rethrow; // Re-throw LocationException as-is
    } catch (e) {
      // Catch all other errors and treat as emulator issue if it's a platform error
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('platform') ||
          errorMsg.contains('methodchannel') ||
          errorMsg.contains('not implemented') ||
          errorMsg.contains('unavailable') ||
          errorMsg.contains('timeout')) {
        throw LocationException('location_emulator_not_supported'.tr());
      }
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
