import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Watches for user inactivity and automatically signs out after timeout
class SessionTimeoutWatcher {
  Timer? _inactivityTimer;
  Duration _timeout;
  final VoidCallback onTimeout;
  bool _isActive = false;

  /// Creates a session timeout watcher
  ///
  /// [timeout] - Duration of inactivity before sign out (default: 30 minutes)
  /// [onTimeout] - Callback to execute when timeout occurs
  SessionTimeoutWatcher({
    Duration timeout = const Duration(minutes: 30),
    required this.onTimeout,
  }) : _timeout = timeout;

  /// Start watching for inactivity
  /// Call this when user signs in or becomes active
  void start() {
    _isActive = true;
    resetTimer();
  }

  /// Stop watching for inactivity
  /// Call this when user signs out
  void stop() {
    _isActive = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  /// Reset the inactivity timer
  /// Call this whenever user performs any action
  void resetTimer() {
    if (!_isActive) return;

    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_timeout, () {
      debugPrint(
          'Session timeout: User inactive for ${_timeout.inMinutes} minutes');
      _handleTimeout();
    });
  }

  /// Handle timeout event
  void _handleTimeout() {
    if (!_isActive) return;

    _isActive = false;
    _inactivityTimer = null;

    // Check if user is still authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('Session timeout: User already signed out');
      return;
    }

    debugPrint('Session timeout: Signing out user ${user.uid}');
    onTimeout();
  }

  /// Update timeout duration
  void setTimeout(Duration duration) {
    _timeout = duration;
    if (_isActive) {
      resetTimer();
    }
  }

  /// Check if watcher is active
  bool get isActive => _isActive;

  /// Dispose of resources
  void dispose() {
    stop();
  }
}
