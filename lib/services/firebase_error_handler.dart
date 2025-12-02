import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/models/infrastructure/service_error.dart';
import 'package:firebase_core/firebase_core.dart';

/// Centralized Firebase error handling service
class FirebaseErrorHandler {
  FirebaseErrorHandler._();

  /// Check if an error is a Firebase permission-denied error
  static bool isPermissionDenied(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('permission-denied') ||
        errorStr.contains('permission_denied') ||
        errorStr.contains('insufficient permissions');
  }

  /// Check if an error is a Firebase network error
  static bool isNetworkError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout') ||
        errorStr.contains('offline');
  }

  /// Check if an error is a Firebase unavailable error
  static bool isUnavailableError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('unavailable') ||
        errorStr.contains('service unavailable') ||
        errorStr.contains('temporarily unavailable');
  }

  /// Check if an error is an authentication error
  static bool isAuthError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('auth') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('invalid token') ||
        errorStr.contains('token expired');
  }

  /// Get user-friendly error message for Firebase errors
  static String getErrorMessage(dynamic error) {
    if (isPermissionDenied(error)) {
      return 'firebase_permission_denied'.tr();
    }
    if (isNetworkError(error)) {
      return 'network_error'.tr();
    }
    if (isUnavailableError(error)) {
      return 'firebase_unavailable'.tr();
    }
    if (isAuthError(error)) {
      return 'auth_error'.tr();
    }
    return 'error_generic'.tr();
  }

  /// Handle Firebase errors with appropriate user feedback
  /// Returns true if the error was handled, false otherwise
  static bool handleFirebaseError(dynamic error, {Function()? onRetry}) {
    if (isPermissionDenied(error)) {
      // Permission denied - might need to refresh auth token
      return false; // Let caller handle retry logic
    }
    if (isNetworkError(error)) {
      // Network error - show retry option
      onRetry?.call();
      return true;
    }
    if (isUnavailableError(error)) {
      // Service unavailable - show retry option
      onRetry?.call();
      return true;
    }
    return false; // Unhandled error
  }

  /// Check if error requires auth token refresh
  static bool requiresAuthRefresh(dynamic error) {
    return isPermissionDenied(error) || isAuthError(error);
  }

  /// Get specific error code if available
  static String? getErrorCode(dynamic error) {
    if (error is Exception) {
      final errorStr = error.toString();
      // Try to extract Firebase error code
      final match = RegExp(r'\[([a-z-]+)\]').firstMatch(errorStr);
      return match?.group(1);
    }
    return null;
  }

  /// Convert Firebase errors to typed ServiceException
  static ServiceException toServiceException(dynamic error) {
    if (error is FirebaseException) {
      if (isPermissionDenied(error)) {
        return PermissionException(
          'firebase_permission_denied'.tr(),
          code: error.code,
          originalError: error,
        );
      }
      if (isNetworkError(error)) {
        return NetworkException(
          'network_error'.tr(),
          code: error.code,
          originalError: error,
        );
      }
      if (isAuthError(error)) {
        return AuthException(
          'auth_error'.tr(),
          code: error.code,
          originalError: error,
        );
      }
      return ServiceException(
        error.message ?? 'error_generic'.tr(),
        code: error.code,
        originalError: error,
      );
    }
    if (error is ServiceException) {
      return error;
    }
    return ServiceException(
      'error_generic'.tr(),
      originalError: error,
    );
  }

  /// Extract user-friendly error message from any error type
  static String getUserMessage(dynamic error) {
    if (error is ServiceException) {
      return error.message;
    }
    if (error is FirebaseException) {
      return getErrorMessage(error);
    }
    return error?.toString() ?? 'error_generic'.tr();
  }
}
