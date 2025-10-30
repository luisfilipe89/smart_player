/// Base mixin for standardized error handling across all services
///
/// @deprecated This mixin adds unnecessary complexity with closure wrapping.
/// Services should use direct try-catch patterns with FirebaseErrorHandler.toServiceException()
/// for clearer, more maintainable code.
///
/// Guidelines for error handling:
/// 1. Use direct try-catch blocks in service methods
/// 2. Re-throw ServiceException as-is (already typed)
/// 3. Convert other exceptions using FirebaseErrorHandler.toServiceException()
/// 4. Log errors appropriately with NumberedLogger
/// 5. Choose appropriate fallback behavior (rethrow vs return empty/null)
///
/// Example:
/// ```dart
/// Future<String> createGame(Game game) async {
///   try {
///     return await _repository.createGame(game);
///   } on ServiceException {
///     rethrow; // Already typed, just rethrow
///   } catch (e) {
///     NumberedLogger.e('Error creating game: $e');
///     throw FirebaseErrorHandler.toServiceException(e);
///   }
/// }
/// ```
@Deprecated('Use direct try-catch patterns instead')
mixin ServiceBaseMixin {
  /// Executes an operation with standardized error handling
  @Deprecated('Use direct try-catch instead')
  Future<T> executeWithErrorHandling<T>({
    required Future<T> Function() operation,
    required String context,
    bool logErrors = true,
  }) async {
    try {
      return await operation();
    } catch (e) {
      // Note: This mixin is deprecated - use direct try-catch instead
      // Import service_error.dart and firebase_error_handler.dart in your service
      rethrow;
    }
  }

  /// Executes an operation that may return null/empty list on error
  @Deprecated('Use direct try-catch instead')
  Future<T> executeWithFallback<T>({
    required Future<T> Function() operation,
    required T Function() fallback,
    required String context,
    bool logErrors = true,
  }) async {
    try {
      return await operation();
    } catch (e) {
      return fallback();
    }
  }

  /// Executes an operation that may return nullable on error
  @Deprecated('Use direct try-catch instead')
  Future<T?> executeWithNullableFallback<T>({
    required Future<T?> Function() operation,
    required String context,
    bool logErrors = true,
  }) async {
    try {
      return await operation();
    } catch (e) {
      return null;
    }
  }
}
