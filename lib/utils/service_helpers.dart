import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'service_error.dart';
import 'package:flutter/material.dart';
import '../services/firebase_error_handler.dart';

/// Safely executes a service operation with typed error handling
///
/// Wraps common try-catch patterns to throw typed exceptions
Future<T> safeServiceCall<T>(
  Future<T> Function() operation, {
  String? errorMessage,
}) async {
  try {
    return await operation();
  } on FirebaseException catch (e) {
    if (FirebaseErrorHandler.isNetworkError(e)) {
      throw NetworkException(
        errorMessage ?? 'Network error occurred',
        code: e.code,
        originalError: e,
      );
    }
    if (FirebaseErrorHandler.isPermissionDenied(e)) {
      throw PermissionException(
        errorMessage ?? 'Permission denied',
        code: e.code,
        originalError: e,
      );
    }
    throw ServiceException(
      errorMessage ?? e.message ?? 'Operation failed',
      code: e.code,
      originalError: e,
    );
  } on ServiceException {
    // Re-throw typed exceptions as-is
    rethrow;
  } catch (e, stack) {
    debugPrint('Unexpected error in safeServiceCall: $e\n$stack');
    throw ServiceException(
      errorMessage ?? 'Unexpected error occurred',
      originalError: e,
    );
  }
}

/// Unified floating snackbar with icon and theming.
/// Prefer this over raw SnackBar for consistency.
void showFloatingSnack(
  BuildContext context, {
  required String message,
  required Color backgroundColor,
  required IconData icon,
  Duration duration = const Duration(seconds: 2),
}) {
  final snack = SnackBar(
    content: Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ],
    ),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    backgroundColor: backgroundColor,
    duration: duration,
  );
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snack);
}

/// Safely executes a Firebase RTDB read operation with error handling
Future<DataSnapshot> safeFirebaseGet(
  DatabaseReference ref,
  String path,
) async {
  try {
    final snap = await ref.child(path).get();
    debugPrint('✓ READ OK: $path (exists: ${snap.exists})');
    return snap;
  } catch (e) {
    debugPrint('✗ READ FAIL: $path -> $e');

    if (FirebaseErrorHandler.requiresAuthRefresh(e)) {
      debugPrint('⚠ Auth refresh required for: $path');
      // Could trigger auth refresh here if needed in the future
    }

    if (FirebaseErrorHandler.isPermissionDenied(e)) {
      throw PermissionException(
        'Permission denied accessing $path',
        originalError: e,
      );
    }

    if (FirebaseErrorHandler.isNetworkError(e)) {
      throw NetworkException(
        'Network error accessing $path',
        originalError: e,
      );
    }

    throw ServiceException(
      'Failed to read from $path',
      originalError: e,
    );
  }
}

/// Safely executes a Firebase RTDB write operation with error handling
Future<void> safeFirebaseSet(
  DatabaseReference ref,
  String path,
  dynamic value,
) async {
  try {
    await ref.child(path).set(value);
    debugPrint('✓ WRITE OK: $path');
  } catch (e) {
    debugPrint('✗ WRITE FAIL: $path -> $e');

    if (FirebaseErrorHandler.isPermissionDenied(e)) {
      throw PermissionException(
        'Permission denied writing to $path',
        originalError: e,
      );
    }

    if (FirebaseErrorHandler.isNetworkError(e)) {
      throw NetworkException(
        'Network error writing to $path',
        originalError: e,
      );
    }

    throw ServiceException(
      'Failed to write to $path',
      originalError: e,
    );
  }
}

/// Safely executes a Firebase RTDB update operation with error handling
Future<void> safeFirebaseUpdate(
  DatabaseReference ref,
  Map<String, dynamic> updates,
) async {
  try {
    await ref.update(updates);
    debugPrint('✓ UPDATE OK: ${updates.keys.join(", ")}');
  } catch (e) {
    debugPrint('✗ UPDATE FAIL -> $e');

    if (FirebaseErrorHandler.isPermissionDenied(e)) {
      throw PermissionException(
        'Permission denied updating data',
        originalError: e,
      );
    }

    if (FirebaseErrorHandler.isNetworkError(e)) {
      throw NetworkException(
        'Network error updating data',
        originalError: e,
      );
    }

    throw ServiceException(
      'Failed to update data',
      originalError: e,
    );
  }
}
