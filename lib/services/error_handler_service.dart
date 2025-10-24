import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/tokens.dart';

/// Error action types for contextual error handling
enum ErrorAction {
  retry, // Generic retry
  openSettings, // Open app settings
  openWifiSettings, // Open network settings
  switchToLogin, // Switch to login screen
  grantPermission, // Open permission settings
  contactSupport, // Open support email/chat
}

/// Centralized error handling service for consistent user feedback
class ErrorHandlerService {
  // Error suppression tracking
  static final Map<String, DateTime> _recentErrors = {};
  static final Map<String, int> _errorCounts = {};
  static Timer? _errorCleanupTimer;

  /// Error types for categorization
  static const String _networkError = 'error_network';
  static const String _timeoutError = 'error_timeout';
  static const String _serverError = 'error_server';
  static const String _permissionError = 'error_permission_denied';
  static const String _databaseError = 'error_database';
  static const String _unknownError = 'error_unknown';
  static const String _gameFullError = 'error_game_full';
  static const String _rateLimitError = 'error_rate_limit';
  static const String _gameStartedError = 'error_game_started';
  static const String _alreadyInGameError = 'error_already_in_game';
  static const String _gameCancelledError = 'error_game_cancelled';
  static const String _notEnoughPlayersError = 'error_not_enough_players';

  /// Converts any exception to a user-friendly translation key
  static String getErrorMessage(dynamic error) {
    if (error is SocketException) {
      return _networkError;
    }

    if (error is TimeoutException) {
      return _timeoutError;
    }

    if (error is DatabaseException) {
      return _databaseError;
    }

    if (error is FirebaseAuthException) {
      return _mapFirebaseAuthError(error);
    }

    if (error is DatabaseException) {
      return _mapFirebaseDatabaseError(error);
    }

    if (error is HttpException) {
      return _mapHttpError(error);
    }

    if (error is FormatException) {
      return _databaseError;
    }

    // If we were given a generic Exception, try to extract the inner message
    // Many call sites throw Exception('<translation_key>'), so unwrap it
    if (error is Exception) {
      final raw = error.toString();
      final cleaned = raw.replaceFirst(RegExp(r'^Exception:\s*'), '');
      // Re-run mapping as a plain string so keys like 'wrong_password' resolve
      return getErrorMessage(cleaned);
    }

    // Check for specific error messages in string format
    if (error is String) {
      final errorStr = error.toLowerCase();
      // Auth-specific keys that may arrive as plain strings
      if (errorStr.contains('wrong_password')) {
        return 'wrong_password';
      }
      if (errorStr.contains('user_not_found')) {
        return 'user_not_found';
      }
      if (errorStr.contains('auth_email_invalid') ||
          errorStr.contains('invalid_email')) {
        return 'auth_email_invalid';
      }
      if (errorStr.contains('auth_password_required') ||
          errorStr.contains('missing-password')) {
        return 'auth_password_required';
      }
      if (errorStr.contains('auth_password_weak') ||
          errorStr.contains('weak-password')) {
        return 'auth_password_weak';
      }
      if (errorStr.contains('user_disabled')) {
        return 'auth_user_disabled';
      }
      if (errorStr.contains('operation_not_allowed')) {
        return 'auth_operation_not_allowed';
      }
      if (errorStr.contains('too_many_requests') ||
          errorStr.contains('rate_limit')) {
        return _rateLimitError;
      }
      if (errorStr.contains('network') || errorStr.contains('connection')) {
        return _networkError;
      }
      if (errorStr.contains('timeout')) {
        return _timeoutError;
      }
      if (errorStr.contains('permission') || errorStr.contains('denied')) {
        return _permissionError;
      }
      if (errorStr.contains('game_full') ||
          errorStr.contains('slot_already_booked')) {
        return _gameFullError;
      }
      if (errorStr.contains('game_started') ||
          errorStr.contains('already_started')) {
        return _gameStartedError;
      }
      if (errorStr.contains('already_joined') ||
          errorStr.contains('already_in_game')) {
        return _alreadyInGameError;
      }
      if (errorStr.contains('game_cancelled') ||
          errorStr.contains('cancelled')) {
        return _gameCancelledError;
      }
      if (errorStr.contains('not_enough_players') ||
          errorStr.contains('insufficient_players')) {
        return _notEnoughPlayersError;
      }
      if (errorStr.contains('rate_limit') ||
          errorStr.contains('too_many_requests')) {
        return _rateLimitError;
      }
    }

    return _unknownError;
  }

  /// Maps Firebase Auth errors to translation keys
  static String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'error_email_in_use';
      case 'invalid-email':
        return 'auth_email_invalid';
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'wrong_password';
      case 'missing-password':
        return 'auth_password_required';
      case 'weak-password':
        return 'auth_password_weak';
      case 'user-not-found':
        return 'user_not_found';
      case 'wrong-password':
        return 'wrong_password';
      case 'user-disabled':
        return 'auth_user_disabled';
      case 'operation-not-allowed':
        return 'auth_operation_not_allowed';
      case 'too-many-requests':
        return _rateLimitError;
      case 'network-request-failed':
        return _networkError;
      case 'requires-recent-login':
        return 'auth_requires_recent_login';
      case 'email-not-verified':
        return 'auth_email_not_verified';
      case 'account-exists-with-different-credential':
        return 'auth_account_exists_different_credential';
      case 'credential-already-in-use':
        return 'auth_credential_already_in_use';
      default:
        return 'error_generic_signin';
    }
  }

  /// Maps Database errors to translation keys
  static String _mapFirebaseDatabaseError(DatabaseException e) {
    final message = e.toString().toLowerCase();
    if (message.contains('permission') || message.contains('denied')) {
      return _permissionError;
    }
    if (message.contains('network') || message.contains('connection')) {
      return _networkError;
    }
    if (message.contains('timeout')) {
      return _timeoutError;
    }
    if (message.contains('unavailable')) {
      return _serverError;
    }
    return _databaseError;
  }

  /// Maps HTTP errors to translation keys
  static String _mapHttpError(HttpException e) {
    // Extract status code from message if possible
    final message = e.message.toLowerCase();
    if (message.contains('400')) return 'error_validation';
    if (message.contains('401')) return 'error_unauthorized';
    if (message.contains('403')) return _permissionError;
    if (message.contains('404')) return 'error_not_found';
    if (message.contains('500')) return _serverError;
    if (message.contains('503')) return _serverError;
    return _serverError;
  }

  /// Shows error message with consistent styling and batch suppression
  static void showError(
    BuildContext context,
    dynamic error, {
    VoidCallback? onRetry,
    ErrorAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    if (!context.mounted) return;

    final message = getErrorMessage(error).tr();
    final now = DateTime.now();

    // Check if this error was shown recently
    if (_recentErrors.containsKey(message)) {
      final lastShown = _recentErrors[message]!;
      if (now.difference(lastShown).inSeconds < 3) {
        // Increment count and update existing SnackBar
        _errorCounts[message] = (_errorCounts[message] ?? 1) + 1;
        _recentErrors[message] = now;

        // Update the existing SnackBar with count
        final count = _errorCounts[message]!;
        final countMessage = count > 1
            ? 'error_occurred_multiple'.tr(args: [count.toString()])
            : message;

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(countMessage),
            backgroundColor: AppColors.red,
            duration: duration,
            behavior: SnackBarBehavior.floating,
            action: onRetry != null
                ? SnackBarAction(
                    label: 'retry'.tr(),
                    textColor: Colors.white,
                    onPressed: onRetry,
                  )
                : null,
          ),
        );
        return;
      }
    }

    // New error or old enough to show again
    _recentErrors[message] = now;
    _errorCounts[message] = 1;

    // Start cleanup timer if not already running
    _errorCleanupTimer?.cancel();
    _errorCleanupTimer = Timer(const Duration(seconds: 10), () {
      _recentErrors.clear();
      _errorCounts.clear();
    });

    // Determine action based on error type or provided action
    final errorAction = action ?? _getErrorAction(error);
    final actionLabel = _getActionLabel(errorAction);
    final actionCallback = _getActionCallback(context, errorAction, onRetry);

    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: AppColors.red,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      action: actionCallback != null
          ? SnackBarAction(
              label: actionLabel,
              textColor: Colors.white,
              onPressed: actionCallback,
            )
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Shows success message with consistent styling
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    final snackBar = SnackBar(
      content: Text(message.tr()),
      backgroundColor: AppColors.green,
      duration: duration,
      behavior: SnackBarBehavior.floating,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Shows warning message with consistent styling
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    final snackBar = SnackBar(
      content: Text(message.tr()),
      backgroundColor: AppColors.orange,
      duration: duration,
      behavior: SnackBarBehavior.floating,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Logs error for debugging (can be extended with crash reporting)
  static void logError(dynamic error, [StackTrace? stackTrace]) {
    debugPrint('ErrorHandler: $error');
    if (stackTrace != null) {
      debugPrint('StackTrace: $stackTrace');
    }
    // TODO: Add crash reporting integration (e.g., Firebase Crashlytics)
  }

  /// Determines the appropriate error action based on error type
  static ErrorAction _getErrorAction(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return ErrorAction.openWifiSettings;
    }
    // Specific permission checks
    if (errorStr.contains('camera') &&
        (errorStr.contains('permission') || errorStr.contains('denied'))) {
      return ErrorAction.grantPermission;
    }
    if (errorStr.contains('photo') &&
        (errorStr.contains('permission') || errorStr.contains('denied'))) {
      return ErrorAction.grantPermission;
    }
    if (errorStr.contains('storage') &&
        (errorStr.contains('permission') || errorStr.contains('denied'))) {
      return ErrorAction.grantPermission;
    }
    if (errorStr.contains('location') &&
        (errorStr.contains('permission') || errorStr.contains('denied'))) {
      return ErrorAction.grantPermission;
    }
    if (errorStr.contains('contacts') &&
        (errorStr.contains('permission') || errorStr.contains('denied'))) {
      return ErrorAction.grantPermission;
    }
    // Generic permission/denied check
    if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return ErrorAction.grantPermission;
    }
    if (errorStr.contains('email_in_use')) {
      return ErrorAction.switchToLogin;
    }
    if (errorStr.contains('unauthorized') || errorStr.contains('auth')) {
      return ErrorAction.switchToLogin;
    }
    if (errorStr.contains('rate_limit') ||
        errorStr.contains('too_many_requests')) {
      return ErrorAction.contactSupport;
    }

    return ErrorAction.retry;
  }

  /// Gets the action label for the error action
  static String _getActionLabel(ErrorAction action) {
    switch (action) {
      case ErrorAction.retry:
        return 'retry'.tr();
      case ErrorAction.openSettings:
        return 'open_settings'.tr();
      case ErrorAction.openWifiSettings:
        return 'check_connection'.tr();
      case ErrorAction.switchToLogin:
        return 'sign_in_instead'.tr();
      case ErrorAction.grantPermission:
        return 'grant_permission'.tr();
      case ErrorAction.contactSupport:
        return 'contact_support'.tr();
    }
  }

  /// Gets the action callback for the error action
  static VoidCallback? _getActionCallback(
    BuildContext context,
    ErrorAction action,
    VoidCallback? onRetry,
  ) {
    switch (action) {
      case ErrorAction.retry:
        return onRetry;
      case ErrorAction.openSettings:
        return () => _openAppSettings();
      case ErrorAction.openWifiSettings:
        return () => _openWifiSettings();
      case ErrorAction.switchToLogin:
        return () => _switchToLogin(context);
      case ErrorAction.grantPermission:
        return () => _openAppSettings();
      case ErrorAction.contactSupport:
        return () => _contactSupport();
    }
  }

  /// Opens app settings
  static Future<void> _openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('Failed to open app settings: $e');
    }
  }

  /// Opens WiFi/network settings
  static Future<void> _openWifiSettings() async {
    try {
      // Try to open WiFi settings (platform specific)
      if (Platform.isAndroid) {
        await launchUrl(Uri.parse('android.settings.WIFI_SETTINGS'));
      } else if (Platform.isIOS) {
        await launchUrl(Uri.parse('App-Prefs:WIFI'));
      } else {
        // Fallback to app settings
        await _openAppSettings();
      }
    } catch (e) {
      debugPrint('Failed to open WiFi settings: $e');
      // Fallback to app settings
      await _openAppSettings();
    }
  }

  /// Switches to login screen
  static void _switchToLogin(BuildContext context) {
    // This would need to be implemented based on your navigation structure
    // For now, just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Please sign in to continue'.tr()),
        backgroundColor: AppColors.orange,
      ),
    );
  }

  /// Opens support contact
  static Future<void> _contactSupport() async {
    try {
      final email = 'luisfccfigueiredo@gmail.com';
      final subject = 'Support Request';
      final body = 'Please describe the issue you encountered...';

      final uri = Uri(
        scheme: 'mailto',
        path: email,
        query:
            'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      );

      await launchUrl(uri);
    } catch (e) {
      debugPrint('Failed to open email client: $e');
    }
  }
}
