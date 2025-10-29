import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/utils/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../../utils/service_error.dart';
import '../../utils/service_helpers.dart' show showFloatingSnack;
import '../../theme/tokens.dart';

/// Instance-based ErrorHandlerService for use with Riverpod dependency injection
class ErrorHandlerServiceInstance {
  /// Log error to console and potentially to crash reporting service
  void logError(dynamic error, StackTrace? stackTrace) {
    NumberedLogger.e('Error: $error');
    if (stackTrace != null) {
      NumberedLogger.d('Stack trace: $stackTrace');
    }

    // Send to Crashlytics in production
    if (kReleaseMode) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Non-fatal error',
        fatal: false,
      );
    }
  }

  /// Show error dialog to user
  void showError(BuildContext context, dynamic error, {VoidCallback? onRetry}) {
    String errorMessage = 'error_generic'.tr();

    if (error is ServiceException) {
      errorMessage = error.message;
    } else if (error is Exception) {
      errorMessage = error.toString();
    } else if (error is String) {
      errorMessage = error;
    }

    // Modern UX for common auth error: wrong password → floating snackbar
    if (errorMessage == 'wrong_password' ||
        errorMessage.contains('wrong_password')) {
      showFloatingSnack(
        context,
        message: 'wrong_password'.tr(),
        backgroundColor: AppColors.red,
        icon: Icons.lock_outline,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('error_title'.tr()),
        content: Text(errorMessage.tr()),
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
