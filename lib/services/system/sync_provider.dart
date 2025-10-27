// lib/providers/services/sync_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sync_service_instance.dart';
import '../games/cloud_games_provider.dart';
import '../friends/friends_provider.dart';
import '../../providers/infrastructure/shared_preferences_provider.dart';

// SyncService provider with dependency injection
final syncServiceProvider = Provider<SyncServiceInstance?>((ref) {
  final cloudGamesService = ref.watch(cloudGamesServiceProvider);
  final friendsService = ref.watch(friendsServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  return SyncServiceInstance(
    cloudGamesService,
    friendsService,
    prefs,
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
  }) =>
      _syncService.addSyncOperation(
        type: type,
        data: data,
        operation: operation,
        itemId: itemId,
      );
  Future<void> retryFailedOperations() => _syncService.retryFailedOperations();
  Future<void> markAsSynced(String operationId) =>
      _syncService.markAsSynced(operationId);
  Future<void> markAsFailed(String operationId) =>
      _syncService.markAsFailed(operationId);
  Future<void> clearAll() => _syncService.clearAll();
}
