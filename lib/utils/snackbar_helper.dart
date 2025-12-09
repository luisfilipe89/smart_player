import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/tokens.dart';

/// Centralized SnackBar helper for consistent UI feedback.
///
/// Provides common patterns for showing error, success, warning, and info messages.
/// This eliminates code duplication and ensures consistent styling across the app.
class SnackBarHelper {
  /// Shows a simple error message snackbar.
  ///
  /// Uses red background with default 3-second duration.
  static void showError(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    _showSimple(
      context,
      message: message,
      backgroundColor: AppColors.red,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Shows a simple success message snackbar.
  ///
  /// Uses green background with default 3-second duration.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    _showSimple(
      context,
      message: message,
      backgroundColor: AppColors.green,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Shows a simple warning message snackbar.
  ///
  /// Uses orange background with default 4-second duration.
  static void showWarning(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    _showSimple(
      context,
      message: message,
      backgroundColor: AppColors.orange,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Shows a simple info message snackbar.
  ///
  /// Uses grey background with default 3-second duration.
  static void showInfo(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    _showSimple(
      context,
      message: message,
      backgroundColor: AppColors.grey,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// Shows an error message with an icon.
  ///
  /// Useful for important error messages that need visual emphasis.
  static void showErrorWithIcon(
    BuildContext context,
    String message, {
    IconData icon = Icons.error_outline,
    Duration? duration,
    bool floating = true,
  }) {
    _showWithIcon(
      context,
      message: message,
      icon: icon,
      backgroundColor: AppColors.red,
      duration: duration ?? const Duration(seconds: 3),
      floating: floating,
    );
  }

  /// Shows a success message with an icon.
  static void showSuccessWithIcon(
    BuildContext context,
    String message, {
    IconData icon = Icons.check_circle_outline,
    Duration? duration,
    bool floating = true,
  }) {
    _showWithIcon(
      context,
      message: message,
      icon: icon,
      backgroundColor: AppColors.green,
      duration: duration ?? const Duration(seconds: 3),
      floating: floating,
    );
  }

  /// Shows a warning message with an icon.
  static void showWarningWithIcon(
    BuildContext context,
    String message, {
    IconData icon = Icons.warning_amber_rounded,
    Duration? duration,
    bool floating = true,
  }) {
    _showWithIcon(
      context,
      message: message,
      icon: icon,
      backgroundColor: AppColors.orange,
      duration: duration ?? const Duration(seconds: 4),
      floating: floating,
    );
  }

  /// Shows a blocking/restriction message with block icon.
  ///
  /// Specifically for slot unavailable or access denied messages.
  static void showBlocked(
    BuildContext context,
    String message, {
    Duration? duration,
  }) {
    _showWithIcon(
      context,
      message: message,
      icon: Icons.block,
      backgroundColor: AppColors.red,
      duration: duration ?? const Duration(seconds: 3),
      floating: true,
    );
  }

  /// Internal helper for simple text-only snackbars.
  static void _showSimple(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required Duration duration,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.tr()),
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }

  /// Internal helper for snackbars with icons.
  static void _showWithIcon(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color backgroundColor,
    required Duration duration,
    bool floating = false,
  }) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message.tr(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      duration: duration,
      behavior: floating ? SnackBarBehavior.floating : SnackBarBehavior.fixed,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}




