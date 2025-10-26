import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'service_error.dart';

/// Extension methods for AsyncValue to provide consistent error handling
extension AsyncValueX<T> on AsyncValue<T> {
  /// Gets a user-friendly error message from the error
  String? get errorMessage {
    if (!hasError) return null;

    final error = this.error;
    if (error is ServiceException) {
      return error.message;
    }

    if (error is Exception) {
      return error.toString();
    }

    return error?.toString() ?? 'An error occurred';
  }

  /// Checks if the error is a specific exception type
  bool isErrorOfType<X>() {
    return hasError && error is X;
  }

  /// Gets the error as a specific type
  X? errorAs<X>() {
    return hasError && error is X ? error as X : null;
  }
}
