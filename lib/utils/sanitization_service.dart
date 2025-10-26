import '../../utils/service_error.dart';

/// Security service for input sanitization and validation
class SanitizationService {
  // Prevent instantiation
  SanitizationService._();

  /// Sanitize string input to prevent XSS and injection attacks
  static String sanitizeString(String input) {
    return input
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;')
        .replaceAll('&', '&amp;')
        .trim();
  }

  /// Sanitize for database storage (remove script tags and SQL injection attempts)
  static String sanitizeForDatabase(String input) {
    return input
        .replaceAll(RegExp('[<>"]'), '')
        .replaceAll("'", '')
        .replaceAll(
            RegExp(r'(\bDROP\b|\bDELETE\b|\bUPDATE\b|\bINSERT\b|\bSELECT\b)',
                caseSensitive: false),
            '')
        .trim();
  }

  /// Validate and sanitize display name
  static String validateAndSanitizeDisplayName(String input) {
    if (input.isEmpty) {
      throw ValidationException('Display name cannot be empty');
    }

    final trimmed = input.trim();

    if (trimmed.length < 2) {
      throw ValidationException('Display name must be at least 2 characters');
    }

    if (trimmed.length > 24) {
      throw ValidationException('Display name cannot exceed 24 characters');
    }

    // Check for invalid characters
    final regex = RegExp(r'^[a-zA-Z0-9\s\-\.]+$');
    if (!regex.hasMatch(trimmed)) {
      throw ValidationException('Display name contains invalid characters');
    }

    return sanitizeForDatabase(trimmed);
  }

  /// Validate and sanitize description text
  static String validateAndSanitizeDescription(String input) {
    final trimmed = input.trim();

    if (trimmed.length > 500) {
      throw ValidationException('Description cannot exceed 500 characters');
    }

    return sanitizeForDatabase(trimmed);
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  /// Validate and sanitize email
  static String validateEmail(String email) {
    final trimmed = email.trim().toLowerCase();

    if (!isValidEmail(trimmed)) {
      throw ValidationException('Invalid email format');
    }

    if (trimmed.length > 254) {
      throw ValidationException('Email address is too long');
    }

    return trimmed;
  }

  /// Mask sensitive data for logging
  static String maskSensitiveData(String data, {int visibleChars = 4}) {
    if (data.length <= visibleChars) {
      return '*' * data.length;
    }
    return data.substring(0, visibleChars) + '*' * (data.length - visibleChars);
  }

  /// Mask password for logging
  static String maskPassword(String? password) {
    if (password == null || password.isEmpty) return '';
    return '*' * password.length;
  }

  /// Validate phone number format (basic validation)
  static bool isValidPhoneNumber(String phone) {
    // Remove common separators
    final cleaned = phone.replaceAll(RegExp(r'[-\s\(\)]'), '');
    // Check if it's digits and reasonable length
    return RegExp(r'^\d{6,15}$').hasMatch(cleaned);
  }

  /// Sanitize URL
  static String? sanitizeUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    // Only allow http/https URLs
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      throw ValidationException('URL must start with http:// or https://');
    }

    return sanitizeString(url);
  }
}
