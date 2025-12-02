// lib/providers/services/sync_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/services/system/sync_service_instance.dart';
import 'package:move_young/features/games/services/games_provider.dart';
import 'package:move_young/features/friends/services/friends_provider.dart';
import 'package:move_young/providers/infrastructure/shared_preferences_provider.dart';

// Re-export SyncServiceInstance constants for convenience
export 'sync_service_instance.dart' show SyncServiceInstance;

// SyncService provider with dependency injection
// Returns null if SharedPreferences is still loading or on error
final syncServiceProvider = Provider<SyncServiceInstance?>((ref) {
  final cloudGamesService = ref.watch(gamesServiceProvider);
  final friendsService = ref.watch(friendsServiceProvider);
  final prefsAsync = ref.watch(sharedPreferencesProvider);

  return prefsAsync.when(
    data: (prefs) => SyncServiceInstance(
      cloudGamesService,
      friendsService,
      prefs,
    ),
    loading: () => null,
    error: (_, __) => null,
  );
});

// Sync status provider (reactive stream)
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  if (syncService == null) {
    return Stream.value(SyncStatus.synced);
  }
  return syncService.statusStream;
});

// Sync queue provider (reactive)
final syncQueueProvider = Provider<List<SyncOperation>>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  if (syncService == null) {
    return <SyncOperation>[];
  }
  return syncService.syncQueue;
});

// Derived providers
final syncQueueSizeProvider = Provider<int>((ref) {
  final queue = ref.watch(syncQueueProvider);
  return queue.length;
});

final syncFailedCountProvider = Provider<int>((ref) {
  final queue = ref.watch(syncQueueProvider);
  return queue.where((op) => op.status == 'failed').length;
});

final syncStuckOpsProvider = Provider<List<SyncOperation>>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  if (syncService == null) return const [];
  return syncService.getStuckOperations();
});

final syncLastErrorProvider = StateProvider<String?>((ref) => null);

// Failed operations count provider (reactive)
final failedOperationsCountProvider = Provider<int>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  if (syncService == null) {
    return 0;
  }
  return syncService.failedOperationsCount;
});

// Sync actions provider (for sync operations)
final syncActionsProvider = Provider<SyncActions?>((ref) {
  final syncService = ref.watch(syncServiceProvider);
  if (syncService == null) {
    return null;
  }
  return SyncActions(syncService);
});

// Helper class for sync actions
class SyncActions {
  final SyncServiceInstance _syncService;

  SyncActions(this._syncService);

  Future<void> initialize() => _syncService.initialize();
  Future<void> addSyncOperation({
    required String type,
    required Map<String, dynamic> data,
    required Future<bool> Function() operation,
    String? itemId,
    int priority = SyncServiceInstance.priorityNormal,
  }) =>
      _syncService.addSyncOperation(
        type: type,
        data: data,
        operation: operation,
        itemId: itemId,
        priority: priority,
      );
  Future<void> retryFailedOperations() => _syncService.retryFailedOperations();
  Future<void> markAsSynced(String operationId) =>
      _syncService.markAsSynced(operationId);
  Future<void> markAsFailed(String operationId) =>
      _syncService.markAsFailed(operationId);
  Future<void> clearAll() => _syncService.clearAll();
}
