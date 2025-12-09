/// Form validation utilities for game creation and editing.
///
/// Extracts validation logic from UI components to improve separation of concerns
/// and provide a single source of truth for validation rules.
library;

import 'package:easy_localization/easy_localization.dart';

/// Validation result for form fields.
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
  });

  const ValidationResult.success()
      : isValid = true,
        errorMessage = null;

  ValidationResult.error(String message)
      : isValid = false,
        errorMessage = message;
}

/// Validates game form data before submission.
class GameFormValidator {
  /// Validates that all required fields are filled.
  ///
  /// Returns a validation result indicating if the form is complete
  /// and any missing field information.
  static ValidationResult validateRequiredFields({
    required String? sport,
    required Map<String, dynamic>? field,
    required DateTime? date,
    required String? time,
  }) {
    if (sport == null) {
      return ValidationResult.error('please_select_sport'.tr());
    }
    if (field == null) {
      return ValidationResult.error('please_select_field'.tr());
    }
    if (date == null) {
      return ValidationResult.error('please_select_date'.tr());
    }
    if (time == null) {
      return ValidationResult.error('please_select_time'.tr());
    }
    return ValidationResult.success();
  }

  /// Validates that the selected date and time are in the future.
  ///
  /// Returns a validation result with an error message if the time is in the past.
  static ValidationResult validateFutureDateTime({
    required DateTime? date,
    required String? time,
  }) {
    if (date == null || time == null) {
      return ValidationResult.success(); // Let required field validation handle this
    }

    final now = DateTime.now();
    final timeParts = time.split(':');
    if (timeParts.length < 2) {
      return ValidationResult.error('invalid_time_format'.tr());
    }

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) {
      return ValidationResult.error('invalid_time_format'.tr());
    }

    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );

    if (!dt.isAfter(now)) {
      return ValidationResult.error('please_select_future_time'.tr());
    }

    return ValidationResult.success();
  }

  /// Validates the time format (HH:mm).
  ///
  /// Returns a validation result indicating if the time format is valid.
  static ValidationResult validateTimeFormat(String? time) {
    if (time == null || time.isEmpty) {
      return ValidationResult.success(); // Let required field validation handle this
    }

    final timeParts = time.split(':');
    if (timeParts.length < 2) {
      return ValidationResult.error('invalid_time_format'.tr());
    }

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) {
      return ValidationResult.error('invalid_time_format'.tr());
    }

    if (hour < 0 || hour >= 24 || minute < 0 || minute >= 60) {
      return ValidationResult.error('invalid_time_format'.tr());
    }

    return ValidationResult.success();
  }

  /// Parses a time string (HH:mm) and combines it with a date to create a DateTime.
  ///
  /// Returns the combined DateTime, or null if parsing fails.
  static DateTime? parseDateTime({
    required DateTime date,
    required String time,
  }) {
    final timeParts = time.split(':');
    if (timeParts.length < 2) return null;

    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return null;

    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }
}




