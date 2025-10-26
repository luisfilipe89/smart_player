import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'session_timeout_watcher.dart';
import '../../services/auth/auth_provider.dart';

/// Provider for session timeout watcher
final sessionTimeoutWatcherProvider = Provider<SessionTimeoutWatcher?>((ref) {
  final userAsync = ref.watch(currentUserProvider);

  final user = userAsync.maybeWhen(
    data: (user) => user,
    orElse: () => null,
  );

  if (user == null) return null;

  final watcher = SessionTimeoutWatcher(
    timeout: const Duration(minutes: 30),
    onTimeout: () async {
      debugPrint('Session timeout: Signing out user');
      await FirebaseAuth.instance.signOut();
    },
  );

  // Start watching when user is authenticated
  watcher.start();

  // Clean up when provider is disposed
  ref.onDispose(() {
    watcher.dispose();
  });

  return watcher;
});
