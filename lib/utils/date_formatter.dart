/// Date formatting utilities for consistent date display across the application.
///
/// Provides localized date formatting functions that handle locale-specific
/// formatting quirks (like trailing periods in some locales).
library;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// Gets a localized day of week abbreviation (e.g., "MON", "TUE").
///
/// Uses the context's locale to format the date. Removes trailing periods
/// that some locales add (e.g., "Mon." becomes "MON").
///
/// Example:
/// - English: "MON", "TUE", "WED"
/// - Dutch: "MA", "DI", "WO"
///
/// Returns the uppercase abbreviation without trailing periods.
String getDayOfWeekAbbr(DateTime date, BuildContext context) {
  // EEE => Mon, Tue (localized). Some locales add a trailing '.' → strip it
  final s = DateFormat('EEE', context.locale.toString()).format(date);
  return s.replaceAll('.', '').toUpperCase();
}

/// Gets a localized month abbreviation (e.g., "JAN", "FEB").
///
/// Uses the context's locale to format the date. Removes trailing periods
/// that some locales add (e.g., "Jan." becomes "JAN").
///
/// Example:
/// - English: "JAN", "FEB", "MAR"
/// - Dutch: "JAN", "FEB", "MRT"
///
/// Returns the uppercase abbreviation without trailing periods.
String getMonthAbbr(DateTime date, BuildContext context) {
  // MMM => Jan, Feb (localized). Some locales add a trailing '.' → strip it
  final s = DateFormat('MMM', context.locale.toString()).format(date);
  return s.replaceAll('.', '').toUpperCase();
}
