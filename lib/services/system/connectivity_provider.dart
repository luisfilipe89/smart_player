// lib/providers/services/connectivity_provider.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connectivity_service_instance.dart';

// Connectivity instance provider
final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

// ConnectivityService provider with dependency injection
final connectivityServiceProvider =
    Provider<ConnectivityServiceInstance>((ref) {
  final connectivity = ref.watch(connectivityProvider);
  return ConnectivityServiceInstance(connectivity);
});

// Connection status provider (reactive)
final connectionStatusProvider = StreamProvider.autoDispose<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.isConnected;
});

// Has connection provider (reactive)
final hasConnectionProvider = Provider.autoDispose<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.hasConnection;
});

// Internet connection provider (reactive)
final hasInternetConnectionProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return await connectivityService.hasInternetConnection();
});

// Helper class for connectivity actions
class ConnectivityActions {
  final ConnectivityServiceInstance _connectivityService;

  ConnectivityActions(this._connectivityService);

  Future<void> initialize() => _connectivityService.initialize();
  Future<bool> checkConnectivity() => _connectivityService.checkConnectivity();
  Future<bool> hasInternetConnection() =>
      _connectivityService.hasInternetConnection();
}

// Connectivity actions provider (for connectivity operations)
final connectivityActionsProvider = Provider<ConnectivityActions>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return ConnectivityActions(connectivityService);
});
