import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'error_handler_service_instance.dart';

/// ErrorHandlerService provider with dependency injection
final errorHandlerServiceProvider =
    Provider<ErrorHandlerServiceInstance>((ref) {
  return ErrorHandlerServiceInstance();
});

/// Error handler actions provider
final errorHandlerActionsProvider = Provider<ErrorHandlerActions>((ref) {
  final errorHandlerService = ref.watch(errorHandlerServiceProvider);
  return ErrorHandlerActions(errorHandlerService);
});

/// Helper class for error handler actions
class ErrorHandlerActions {
  final ErrorHandlerServiceInstance _errorHandlerService;

  ErrorHandlerActions(this._errorHandlerService);

  void logError(dynamic error, StackTrace? stackTrace) =>
      _errorHandlerService.logError(error, stackTrace);
  void showError(BuildContext context, dynamic error,
          {VoidCallback? onRetry}) =>
      _errorHandlerService.showError(context, error, onRetry: onRetry);
  void showSnackBar(BuildContext context, String message,
          {Color? backgroundColor}) =>
      _errorHandlerService.showSnackBar(context, message,
          backgroundColor: backgroundColor);
}
