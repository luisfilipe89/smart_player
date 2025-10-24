import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/tokens.dart';

/// Helper utilities for implementing undo functionality
class UndoHelpers {
  // Enhanced undo queue (simple version: 3 actions, 15s window)
  static final List<UndoAction> _undoQueue = [];
  static Timer? _undoCleanupTimer;

  /// Maximum number of undo actions to keep
  static const int _maxUndoActions = 3;

  /// Duration to keep undo actions available
  static const Duration _undoWindow = Duration(seconds: 15);

  /// Shows a SnackBar with undo action
  static void showUndoSnackBar(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 5),
  }) {
    if (!context.mounted) return;

    final snackBar = SnackBar(
      content: Text(message.tr()),
      backgroundColor: AppColors.grey,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'undo'.tr(),
        textColor: Colors.white,
        onPressed: onUndo,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Shows a success SnackBar with undo action
  static void showSuccessWithUndo(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 5),
  }) {
    if (!context.mounted) return;

    final snackBar = SnackBar(
      content: Text(message.tr()),
      backgroundColor: AppColors.green,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'undo'.tr(),
        textColor: Colors.white,
        onPressed: onUndo,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Shows a warning SnackBar with undo action
  static void showWarningWithUndo(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 5),
  }) {
    if (!context.mounted) return;

    final snackBar = SnackBar(
      content: Text(message.tr()),
      backgroundColor: AppColors.orange,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'undo'.tr(),
        textColor: Colors.white,
        onPressed: onUndo,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Adds an action to the undo queue
  static void addUndoAction({
    required String type,
    required String message,
    required VoidCallback onUndo,
    Map<String, dynamic>? data,
  }) {
    // Remove oldest action if queue is full
    if (_undoQueue.length >= _maxUndoActions) {
      _undoQueue.removeAt(0);
    }

    // Add new action
    _undoQueue.add(UndoAction(
      type: type,
      message: message,
      onUndo: onUndo,
      data: data ?? {},
      timestamp: DateTime.now(),
    ));

    // Start cleanup timer
    _undoCleanupTimer?.cancel();
    _undoCleanupTimer = Timer(_undoWindow, _cleanupExpiredActions);
  }

  /// Shows enhanced undo SnackBar with multiple actions
  static void showEnhancedUndoSnackBar(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
    String? actionType,
    Map<String, dynamic>? actionData,
    Duration duration = const Duration(seconds: 15),
  }) {
    if (!context.mounted) return;

    // Add to undo queue if action type provided
    if (actionType != null) {
      addUndoAction(
        type: actionType,
        message: message,
        onUndo: onUndo,
        data: actionData,
      );
    }

    // Show SnackBar with undo count
    final undoCount = _undoQueue.length;
    final displayMessage = undoCount > 1
        ? '$message ($undoCount actions can be undone)'
        : message;

    final snackBar = SnackBar(
      content: Text(displayMessage.tr()),
      backgroundColor: AppColors.grey,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'undo'.tr(),
        textColor: Colors.white,
        onPressed: () {
          if (_undoQueue.isNotEmpty) {
            final lastAction = _undoQueue.removeLast();
            lastAction.onUndo();
          }
        },
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Gets the current undo queue
  static List<UndoAction> get undoQueue => List.unmodifiable(_undoQueue);

  /// Clears all undo actions
  static void clearUndoQueue() {
    _undoQueue.clear();
    _undoCleanupTimer?.cancel();
  }

  /// Cleans up expired undo actions
  static void _cleanupExpiredActions() {
    final now = DateTime.now();
    _undoQueue.removeWhere(
        (action) => now.difference(action.timestamp) > _undoWindow);
  }
}

/// Represents an undo action
class UndoAction {
  final String type;
  final String message;
  final VoidCallback onUndo;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  UndoAction({
    required this.type,
    required this.message,
    required this.onUndo,
    required this.data,
    required this.timestamp,
  });
}
