/// Custom exception types for service layer errors.
///
/// These provide better error categorization and handling than generic exceptions.
library;

/// Base exception for all service layer errors
class ServiceException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const ServiceException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => message;
}

/// Network-related errors (connection, timeout, etc.)
class NetworkException extends ServiceException {
  const NetworkException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Authentication/authorization errors
class AuthException extends ServiceException {
  const AuthException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Permission denied errors
class PermissionException extends ServiceException {
  const PermissionException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Validation errors (invalid input, missing required fields, etc.)
class ValidationException extends ServiceException {
  const ValidationException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Not found errors
class NotFoundException extends ServiceException {
  const NotFoundException(
    super.message, {
    super.code,
    super.originalError,
  });
}

/// Already exists errors (duplicate entries, etc.)
class AlreadyExistsException extends ServiceException {
  const AlreadyExistsException(
    super.message, {
    super.code,
    super.originalError,
  });
}
