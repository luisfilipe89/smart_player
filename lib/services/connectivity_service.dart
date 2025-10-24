import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service for monitoring network connectivity status
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  static final Connectivity _connectivity = Connectivity();
  static bool _hasConnection = true;
  static final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  /// Stream that emits true when connected, false when disconnected
  static Stream<bool> get isConnected => _connectionController.stream;

  /// Current connection status (cached)
  static bool get hasConnection => _hasConnection;

  /// Initialize connectivity monitoring
  static Future<void> initialize() async {
    // Check initial connectivity
    await checkConnectivity();

    // Listen to connectivity changes
    _connectivity.onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _updateConnectionStatus(results.first);
    });
  }

  /// One-time connectivity check
  static Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _updateConnectionStatus(results.first);
    } catch (e) {
      debugPrint('ConnectivityService: Error checking connectivity: $e');
      return false;
    }
  }

  /// Update connection status based on connectivity result
  static bool _updateConnectionStatus(ConnectivityResult result) {
    final wasConnected = _hasConnection;
    _hasConnection = result != ConnectivityResult.none;

    // Only emit if status changed
    if (wasConnected != _hasConnection) {
      _connectionController.add(_hasConnection);
      debugPrint(
          'ConnectivityService: Connection status changed to ${_hasConnection ? "connected" : "disconnected"}');
    }

    return _hasConnection;
  }

  /// Check if we have internet connectivity (not just network interface)
  static Future<bool> hasInternetConnection() async {
    try {
      // This is a simplified check - in production you might want to ping a reliable server
      final results = await _connectivity.checkConnectivity();
      return results.first != ConnectivityResult.none;
    } catch (e) {
      debugPrint('ConnectivityService: Error checking internet connection: $e');
      return false;
    }
  }

  /// Dispose resources
  static void dispose() {
    _connectionController.close();
  }
}
