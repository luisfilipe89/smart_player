import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_service_instance.dart';

/// ConnectivityService provider with dependency injection
final connectivityServiceProvider =
    Provider<ConnectivityServiceInstance>((ref) {
  return ConnectivityServiceInstance();
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
