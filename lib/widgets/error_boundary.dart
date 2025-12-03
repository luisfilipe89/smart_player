import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/widgets/error_retry_widget.dart';
import 'package:move_young/utils/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

/// Error boundary widget that catches errors in child widgets
/// and displays a fallback UI instead of crashing
///
/// This widget provides a way to isolate errors in specific widget trees,
/// preventing a single widget failure from crashing the entire app.
///
/// Usage:
/// ```dart
/// ErrorBoundary(
///   child: YourComplexWidget(),
///   errorMessage: 'error_loading_content'.tr(),
/// )
/// ```
class ErrorBoundary extends StatefulWidget {
  /// The widget tree to wrap with error boundary
  final Widget child;

  /// Optional custom error message to display
  final String? errorMessage;

  /// Optional custom fallback widget
  /// If not provided, uses ErrorRetryWidget
  final Widget? fallback;

  /// Callback when an error is caught
  final void Function(FlutterErrorDetails details)? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorMessage,
    this.fallback,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Store the original error handler
    final originalOnError = FlutterError.onError;

    // Set up error handler for this widget tree
    FlutterError.onError = (FlutterErrorDetails details) {
      // Check if this error is within our widget tree
      // (This is a simplified check - in production you might want more sophisticated detection)
      if (mounted) {
        setState(() {
          _hasError = true;
        });
        _handleError(details);
      }

      // Also call the original handler for global error reporting
      originalOnError?.call(details);
    };
  }

  @override
  void dispose() {
    // Note: We don't restore FlutterError.onError here because
    // multiple ErrorBoundary widgets might be in the tree
    // The global handler in main.dart will handle all errors
    super.dispose();
  }

  void _handleError(FlutterErrorDetails details) {
    NumberedLogger.e('ErrorBoundary caught error: ${details.exception}');
    NumberedLogger.d('Stack: ${details.stack}');

    // Report to Crashlytics in production
    if (kReleaseMode) {
      try {
        FirebaseCrashlytics.instance.recordError(
          details.exception,
          details.stack,
          reason: 'ErrorBoundary caught error',
          fatal: false,
        );
      } catch (_) {
        // Crashlytics not ready; ignore
      }
    }

    // Call custom error callback if provided
    widget.onError?.call(details);
  }

  void _resetError() {
    setState(() {
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallback ??
          ErrorRetryWidget(
            message: widget.errorMessage ?? 'error_rendering_widget'.tr(),
            onRetry: _resetError,
          );
    }

    return widget.child;
  }
}
