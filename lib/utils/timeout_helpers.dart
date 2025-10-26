import 'dart:async';
import 'package:flutter/material.dart';
import '../services/error_handler/error_handler_service_instance.dart';

/// Helper utilities for adding timeout protection to operations
class TimeoutHelpers {
  /// Wraps a Future with timeout protection
  static Future<T> withTimeout<T>(
    Future<T> operation, {
    Duration timeout = const Duration(seconds: 30),
    String? timeoutMessage,
  }) async {
    try {
      return await operation.timeout(
        timeout,
        onTimeout: () {
          throw TimeoutException(
            timeoutMessage ?? 'operation_timeout',
            timeout,
          );
        },
      );
    } on TimeoutException catch (e) {
      // Re-throw with proper error message for ErrorHandlerService
      throw Exception(e.message);
    }
  }

  /// Wraps a Future with timeout and shows error if it fails
  static Future<T> withTimeoutAndErrorHandling<T>(
    Future<T> operation,
    BuildContext context, {
    Duration timeout = const Duration(seconds: 30),
    String? timeoutMessage,
    VoidCallback? onRetry,
  }) async {
    try {
      return await withTimeout(
        operation,
        timeout: timeout,
        timeoutMessage: timeoutMessage,
      );
    } catch (e) {
      ErrorHandlerServiceInstance().showError(
        context,
        e,
        onRetry: onRetry,
      );
      rethrow;
    }
  }

  /// Quick timeout for fast operations (status checks, etc.)
  static Future<T> withQuickTimeout<T>(
    Future<T> operation, {
    String? timeoutMessage,
  }) {
    return withTimeout(
      operation,
      timeout: const Duration(seconds: 10),
      timeoutMessage: timeoutMessage ?? 'quick_operation_timeout',
    );
  }

  /// Long timeout for slow operations (uploads, etc.)
  static Future<T> withLongTimeout<T>(
    Future<T> operation, {
    String? timeoutMessage,
  }) {
    return withTimeout(
      operation,
      timeout: const Duration(seconds: 60),
      timeoutMessage: timeoutMessage ?? 'long_operation_timeout',
    );
  }
}
