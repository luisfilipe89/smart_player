import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
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

/// Current connection status provider
final hasConnectionProvider = Provider.autoDispose<bool>((ref) {
  final connectivityAsync = ref.watch(connectivityStatusProvider);
  return connectivityAsync.when(
    data: (isConnected) => isConnected,
    loading: () => true, // Assume connected while loading
    error: (_, __) => false,
  );
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

  Future<void> initialize() => _connectivityService.initialize();
  Future<bool> checkConnectivity() => _connectivityService.checkConnectivity();
  Future<bool> hasInternetConnection() =>
      _connectivityService.hasInternetConnection();
  void dispose() => _connectivityService.dispose();
}
