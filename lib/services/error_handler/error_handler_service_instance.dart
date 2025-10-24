import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';

/// Instance-based ErrorHandlerService for use with Riverpod dependency injection
class ErrorHandlerServiceInstance {
  /// Log error to console and potentially to crash reporting service
  void logError(dynamic error, StackTrace? stackTrace) {
    debugPrint('Error: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }

    // In production, you would send this to a crash reporting service
    // like Firebase Crashlytics, Sentry, etc.
    if (kReleaseMode) {
      // TODO: Send to crash reporting service
    }
  }

  /// Show error dialog to user
  void showError(BuildContext context, dynamic error, {VoidCallback? onRetry}) {
    String errorMessage = 'error_generic'.tr();

    if (error is Exception) {
      errorMessage = error.toString();
    } else if (error is String) {
      errorMessage = error;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('error_title'.tr()),
        content: Text(errorMessage),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: Text('retry'.tr()),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }

  /// Show snackbar with error message
  void showSnackBar(BuildContext context, String message,
      {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
