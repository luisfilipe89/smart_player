import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/services/connectivity/connectivity_service_instance.dart';
import 'package:move_young/utils/logger.dart';

/// ConnectivityService provider with dependency injection
final connectivityServiceProvider =
    Provider<ConnectivityServiceInstance>((ref) {
  final service = ConnectivityServiceInstance();
  // Initialize asynchronously but don't await - this will populate the stream
  // Wrap in try-catch to handle any initialization errors gracefully
  service.initialize().catchError((error) {
    NumberedLogger.w('Connectivity service initialization error: $error');
  });
  return service;
});

/// Connectivity status provider (reactive stream)
final connectivityStatusProvider = StreamProvider.autoDispose<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.isConnected;
});

/// Connectivity actions provider
final connectivityActionsProvider = Provider<ConnectivityActions>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return ConnectivityActions(connectivityService);
});

/// Helper class for connectivity actions
class ConnectivityActions {
  final ConnectivityServiceInstance _connectivityService;

  ConnectivityActions(this._connectivityService);

  Future<bool> hasInternetConnection() =>
      _connectivityService.hasInternetConnection();
}
