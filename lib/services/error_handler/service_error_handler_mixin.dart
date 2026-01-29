import 'package:move_young/models/infrastructure/service_error.dart';
import 'package:move_young/services/firebase_error_handler.dart';
import 'package:move_young/utils/logger.dart';

/// Mixin that provides standardized error handling for services.
///
/// This mixin standardizes error handling patterns across all services:
/// - Mutation operations (create, update, delete) throw exceptions
/// - Query operations return empty/null on error for offline-friendly behavior
///
/// Usage:
/// ```dart
/// class MyService with ServiceErrorHandlerMixin {
///   Future<String> createItem(Item item) async {
///     return handleMutationError(
///       () => _performCreate(item),
///       'creating item',
///     );
///   }
///
///   Future<List<Item>> getItems() async {
///     return handleListQueryError(
///       () => _performQuery(),
///       'getting items',
///     );
///   }
/// }
/// ```
mixin ServiceErrorHandlerMixin {
  /// Handles errors for mutation operations (create, update, delete, join, leave).
  ///
  /// These operations throw exceptions to ensure callers handle errors explicitly.
  /// This is appropriate for mutations because:
  /// - The caller needs to know if the operation failed
  /// - UI can show specific error messages
  /// - Operations can be retried or queued for sync
  ///
  /// Returns the result of the operation, or throws a [ServiceException].
  Future<T> handleMutationError<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    try {
      return await operation();
    } on ServiceException {
      rethrow; // Already typed, just rethrow
    } catch (e) {
      NumberedLogger.e('Error $operationName: $e');
      throw FirebaseErrorHandler.toServiceException(e);
    }
  }

  /// Handles errors for query operations that return non-nullable lists.
  ///
  /// These operations return empty list on error for offline-friendly behavior.
  /// This is appropriate for queries because:
  /// - UI can still render (empty state)
  /// - App continues to function offline
  /// - Errors are logged but don't break the user experience
  ///
  /// Returns the list of items, or an empty list on error.
  Future<List<T>> handleListQueryError<T>(
    Future<List<T>> Function() operation,
    String operationName,
  ) async {
    try {
      return await operation();
    } catch (e) {
      NumberedLogger.w('Error $operationName: $e');
      return <T>[];
    }
  }

  /// Handles errors for query operations that return nullable values.
  ///
  /// These operations return null on error for offline-friendly behavior.
  /// This is appropriate for single-item queries because:
  /// - UI can handle null gracefully
  /// - App continues to function offline
  /// - Errors are logged but don't break the user experience
  ///
  /// Returns the item, or null on error.
  Future<T?> handleNullableQueryError<T>(
    Future<T?> Function() operation,
    String operationName,
  ) async {
    try {
      return await operation();
    } catch (e) {
      NumberedLogger.w('Error $operationName: $e');
      return null;
    }
  }

  /// Handles errors for operations that return boolean.
  ///
  /// Returns false on error (assumes operation failed).
  /// This is appropriate for boolean operations because:
  /// - False is a safe default (operation didn't succeed)
  /// - UI can handle false gracefully
  /// - Errors are logged but don't break the user experience
  ///
  /// Returns true if operation succeeds, false on error.
  Future<bool> handleBooleanError(
    Future<bool> Function() operation,
    String operationName,
  ) async {
    try {
      return await operation();
    } catch (e) {
      NumberedLogger.w('Error $operationName: $e');
      return false;
    }
  }

  /// Handles errors for operations that return void.
  ///
  /// Swallows errors and logs them. Use this for best-effort operations
  /// where failure is acceptable and shouldn't break the user experience.
  ///
  /// Returns true if operation succeeds, false on error.
  Future<bool> handleVoidError(
    Future<void> Function() operation,
    String operationName,
  ) async {
    try {
      await operation();
      return true;
    } catch (e) {
      NumberedLogger.w('Error $operationName: $e');
      return false;
    }
  }
}
