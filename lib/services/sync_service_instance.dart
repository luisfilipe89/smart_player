// lib/services/sync_service_instance.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:move_young/services/cloud_games_service_instance.dart';
import 'package:move_young/services/friends_service_instance.dart';

/// Instance-based SyncService for use with Riverpod dependency injection
class SyncServiceInstance {
  final CloudGamesServiceInstance _cloudGamesService;
  final FriendsServiceInstance _friendsService;
  final SharedPreferences _prefs;

  static const String _syncQueueKey = 'sync_queue';

  // Sync status types
  static const String _statusSynced = 'synced';
  static const String _statusPending = 'pending';
  static const String _statusFailed = 'failed';

  final List<SyncOperation> _syncQueue = [];
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  Timer? _retryTimer;

  SyncServiceInstance(
    this._cloudGamesService,
    this._friendsService,
    this._prefs,
  );

  /// Stream of sync status changes
  Stream<SyncStatus> get statusStream => _statusController.stream;

  /// Current sync status
  SyncStatus get currentStatus => _syncQueue.isEmpty
      ? SyncStatus.synced
      : _syncQueue.any((op) => op.status == _statusFailed)
          ? SyncStatus.failed
          : SyncStatus.pending;

  /// Initialize sync service
  Future<void> initialize() async {
    try {
      await _loadSyncQueue();
      _startRetryTimer();
    } catch (e) {
      // If SharedPreferences fails during initialization, start with empty queue
      _syncQueue.clear();
      _startRetryTimer();
    }
  }

  /// Add operation to sync queue
  Future<void> addSyncOperation({
    required String type,
    required Map<String, dynamic> data,
    required Future<bool> Function() operation,
    String? itemId,
  }) async {
    final syncOp = SyncOperation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      data: data,
      operation: operation,
      status: _statusPending,
      timestamp: DateTime.now(),
      retryCount: 0,
      itemId: itemId,
    );

    _syncQueue.add(syncOp);
    await _saveSyncQueue();
    _notifyStatusChange();
  }

  /// Retry failed operations
  Future<void> retryFailedOperations() async {
    final failedOps =
        _syncQueue.where((op) => op.status == _statusFailed).toList();

    for (final op in failedOps) {
      try {
        final success = await _executeOperation(op);
        if (success) {
          op.status = _statusSynced;
          op.lastAttempt = DateTime.now();
        } else {
          op.retryCount++;
          op.lastAttempt = DateTime.now();
          if (op.retryCount >= 3) {
            op.status = _statusFailed;
          }
        }
      } catch (e) {
        op.retryCount++;
        op.lastAttempt = DateTime.now();
        if (op.retryCount >= 3) {
          op.status = _statusFailed;
        }
        debugPrint('Sync retry failed: $e');
      }
    }

    // Remove synced operations
    _syncQueue.removeWhere((op) => op.status == _statusSynced);
    await _saveSyncQueue();
    _notifyStatusChange();
  }

  /// Mark operation as synced
  Future<void> markAsSynced(String operationId) async {
    final op = _syncQueue.firstWhere(
      (op) => op.id == operationId,
      orElse: () => throw Exception('Operation not found'),
    );

    op.status = _statusSynced;
    op.lastAttempt = DateTime.now();

    // Remove from queue
    _syncQueue.removeWhere((op) => op.id == operationId);
    await _saveSyncQueue();
    _notifyStatusChange();
  }

  /// Mark operation as failed
  Future<void> markAsFailed(String operationId) async {
    final op = _syncQueue.firstWhere(
      (op) => op.id == operationId,
      orElse: () => throw Exception('Operation not found'),
    );

    op.status = _statusFailed;
    op.lastAttempt = DateTime.now();
    op.retryCount++;

    await _saveSyncQueue();
    _notifyStatusChange();
  }

  /// Get sync queue
  List<SyncOperation> get syncQueue => List.unmodifiable(_syncQueue);

  /// Get failed operations count
  int get failedOperationsCount =>
      _syncQueue.where((op) => op.status == _statusFailed).length;

  /// Clear all operations
  Future<void> clearAll() async {
    _syncQueue.clear();
    await _saveSyncQueue();
    _notifyStatusChange();
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
    _statusController.close();
  }

  /// Load sync queue from storage
  Future<void> _loadSyncQueue() async {
    try {
      final queueJson = _prefs.getString(_syncQueueKey);

      if (queueJson != null) {
        final List<dynamic> queueList = jsonDecode(queueJson);
        _syncQueue.clear();

        for (final item in queueList) {
          final op = SyncOperation.fromJson(item);
          // Don't restore the actual operation function, just the metadata
          _syncQueue.add(op);
        }
      }
    } catch (e) {
      debugPrint('Failed to load sync queue: $e');
    }
  }

  /// Save sync queue to storage
  Future<void> _saveSyncQueue() async {
    try {
      final queueJson =
          jsonEncode(_syncQueue.map((op) => op.toJson()).toList());
      await _prefs.setString(_syncQueueKey, queueJson);
    } catch (e) {
      debugPrint('Failed to save sync queue: $e');
    }
  }

  /// Start retry timer
  void _startRetryTimer() {
    _retryTimer?.cancel(); // Cancel existing timer before creating new one
    _retryTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_syncQueue.isNotEmpty) {
        retryFailedOperations();
      }
    });
  }

  /// Notify status change
  void _notifyStatusChange() {
    _statusController.add(currentStatus);
  }

  /// Execute operation based on type and data
  Future<bool> _executeOperation(SyncOperation operation) async {
    final type = operation.type;
    final data = operation.data;

    try {
      switch (type) {
        case 'game_join':
          final gameId = data['gameId'] as String;
          await _cloudGamesService.joinGame(gameId);
          return true;

        case 'game_leave':
          final gameId = data['gameId'] as String;
          await _cloudGamesService.leaveGame(gameId);
          return true;

        case 'friend_request':
          final toUid = data['toUid'] as String;
          return await _friendsService.sendFriendRequest(toUid);

        case 'friend_accept':
          final fromUid = data['fromUid'] as String;
          return await _friendsService.acceptFriendRequest(fromUid);

        default:
          debugPrint('Unknown operation type: $type');
          return false;
      }
    } catch (e) {
      debugPrint('Error executing operation $type: $e');
      return false;
    }
  }
}

/// Sync operation model
class SyncOperation {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final Future<bool> Function() operation;
  String status;
  final DateTime timestamp;
  int retryCount;
  DateTime? lastAttempt;
  final String? itemId;

  SyncOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.operation,
    required this.status,
    required this.timestamp,
    required this.retryCount,
    this.lastAttempt,
    this.itemId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'data': data,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
        'retryCount': retryCount,
        'lastAttempt': lastAttempt?.toIso8601String(),
        'itemId': itemId,
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
        id: json['id'],
        type: json['type'],
        data: Map<String, dynamic>.from(json['data']),
        operation: () async =>
            false, // Placeholder since function can't be serialized
        status: json['status'],
        timestamp: DateTime.parse(json['timestamp']),
        retryCount: json['retryCount'],
        lastAttempt: json['lastAttempt'] != null
            ? DateTime.parse(json['lastAttempt'])
            : null,
        itemId: json['itemId'],
      );
}

/// Sync status enum
enum SyncStatus {
  synced,
  pending,
  failed,
}
