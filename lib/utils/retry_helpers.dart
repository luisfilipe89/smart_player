import 'dart:async';
import 'dart:math';
import '../services/connectivity_service.dart';

/// Helper utilities for implementing retry mechanisms with exponential backoff
class RetryHelpers {
  /// Executes a function with retry logic and exponential backoff
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    Duration maxDelay = const Duration(seconds: 30),
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt <= maxRetries) {
      try {
        return await operation();
      } catch (error) {
        attempt++;

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(error)) {
          rethrow;
        }

        // If this was the last attempt, rethrow the error
        if (attempt > maxRetries) {
          rethrow;
        }

        // Wait before retrying with exponential backoff
        await Future.delayed(delay);

        // Calculate next delay with exponential backoff
        delay = Duration(
          milliseconds: min(
            (delay.inMilliseconds * backoffMultiplier).round(),
            maxDelay.inMilliseconds,
          ),
        );
      }
    }

    // This should never be reached, but just in case
    throw Exception('Retry logic failed unexpectedly');
  }

  /// Default retry condition for network-related errors
  static bool defaultShouldRetry(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('socket') ||
        errorString.contains('unavailable');
  }

  /// Retry condition for HTTP errors (retry on 5xx, don't retry on 4xx)
  static bool httpShouldRetry(dynamic error) {
    if (error is String) {
      final errorString = error.toLowerCase();
      // Retry on server errors (5xx) and timeouts
      return errorString.contains('500') ||
          errorString.contains('502') ||
          errorString.contains('503') ||
          errorString.contains('504') ||
          errorString.contains('timeout');
    }
    return false;
  }

  /// Retry condition for Firebase operations
  static bool firebaseShouldRetry(dynamic error) {
    if (error is String) {
      final errorString = error.toLowerCase();
      return errorString.contains('network') ||
          errorString.contains('timeout') ||
          errorString.contains('unavailable') ||
          errorString.contains('internal');
    }
    return false;
  }

  /// Executes a function with retry logic and connectivity awareness
  static Future<T> retryWithConnectivity<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    double backoffMultiplier = 2.0,
    Duration maxDelay = const Duration(seconds: 30),
    bool Function(dynamic error)? shouldRetry,
    String? waitingMessage,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt <= maxRetries) {
      try {
        // Check connectivity before attempting operation
        if (!ConnectivityService.hasConnection) {
          // Wait for connection to return
          await ConnectivityService.isConnected
              .firstWhere((connected) => connected);
        }

        return await operation();
      } catch (error) {
        attempt++;

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(error)) {
          rethrow;
        }

        // If this was the last attempt, rethrow the error
        if (attempt > maxRetries) {
          rethrow;
        }

        // If offline, wait for connection before retrying
        if (!ConnectivityService.hasConnection) {
          // Wait for connection to return
          await ConnectivityService.isConnected
              .firstWhere((connected) => connected);
        }

        // Wait before retrying with exponential backoff
        await Future.delayed(delay);

        // Calculate next delay with exponential backoff
        delay = Duration(
          milliseconds: min(
            (delay.inMilliseconds * backoffMultiplier).round(),
            maxDelay.inMilliseconds,
          ),
        );
      }
    }

    // This should never be reached, but just in case
    throw Exception('Retry logic failed unexpectedly');
  }
}
