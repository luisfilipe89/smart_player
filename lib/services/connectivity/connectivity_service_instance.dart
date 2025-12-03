import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:move_young/utils/logger.dart';

/// Instance-based ConnectivityService for use with Riverpod dependency injection
class ConnectivityServiceInstance {
  final Connectivity _connectivity = Connectivity();
  bool _hasConnection = true;
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Stream that emits true when connected, false when disconnected
  Stream<bool> get isConnected => _connectionController.stream;

  /// Current connection status (cached)
  bool get hasConnection => _hasConnection;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial connectivity
    await checkConnectivity();

    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        if (results.isNotEmpty) {
          _updateConnectionStatus(results.first);
        }
      },
      onError: (error) {
        NumberedLogger.w('ConnectivityService: Error in connectivity stream: $error');
      },
    );
  }

  /// One-time connectivity check
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isNotEmpty) {
        return _updateConnectionStatus(results.first);
      }
      return false;
    } catch (e) {
      NumberedLogger.w('ConnectivityService: Error checking connectivity: $e');
      return false;
    }
  }

  /// Update connection status based on connectivity result
  bool _updateConnectionStatus(ConnectivityResult result) {
    final wasConnected = _hasConnection;
    _hasConnection = result != ConnectivityResult.none;

    // Only emit if status changed
    if (wasConnected != _hasConnection) {
      if (!_connectionController.isClosed) {
        _connectionController.add(_hasConnection);
      }
      NumberedLogger.d(
          'ConnectivityService: Connection status changed to ${_hasConnection ? "connected" : "disconnected"}');
    }

    return _hasConnection;
  }

  /// Check if we have internet connectivity (not just network interface)
  Future<bool> hasInternetConnection() async {
    try {
      // This is a simplified check - in production you might want to ping a reliable server
      final results = await _connectivity.checkConnectivity();
      return results.first != ConnectivityResult.none;
    } catch (e) {
      NumberedLogger.w(
          'ConnectivityService: Error checking internet connection: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionController.close();
  }
}
