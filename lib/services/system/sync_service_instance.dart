// lib/services/sync_service_instance.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:move_young/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../games/games_service.dart';
import '../friends/friends_service.dart';

/// Instance-based SyncService for use with Riverpod dependency injection
class SyncServiceInstance {
  final IGamesService _cloudGamesService;
  final IFriendsService _friendsService;
  final SharedPreferences? _prefs;

  static const String _syncQueueKey = 'sync_queue';

  // Sync status types
  static const String _statusSynced = 'synced';
  static const String _statusPending = 'pending';
  static const String _statusFailed = 'failed';

  final List<SyncOperation> _syncQueue = [];
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();
  Timer? _retryTimer;
  Timer? _healthLogTimer;

  // Health monitoring configuration
  static const Duration _stuckThreshold = Duration(minutes: 15);
  static const Duration _healthLogInterval = Duration(minutes: 10);

  // Retry configuration with exponential backoff
  static const int _maxRetries = 5;
  static const Duration _baseRetryDelay = Duration(seconds: 30);
  static const Duration _maxRetryDelay = Duration(minutes: 15);

  // Operation priority levels (higher number = higher priority)
  // Public constants for callers to use when adding sync operations
  static const int priorityHigh =
      3; // Critical operations (e.g., friend accept)
  static const int priorityNormal =
      2; // Normal operations (e.g., game join/leave)
  static const int priorityLow = 1; // Low priority (e.g., updates)

  // Private constants for internal use (alias to public constants)
  static const int _priorityNormal = priorityNormal;

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
      _startHealthLogTimer();
    } catch (e) {
      // If SharedPreferences fails during initialization, start with empty queue
      _syncQueue.clear();
      _startRetryTimer();
      _startHealthLogTimer();
    }
  }

  /// Add operation to sync queue with priority
  ///
  /// [priority] determines execution order:
  /// - 3 (high): Critical operations like friend accept
  /// - 2 (normal): Standard operations like game join/leave
  /// - 1 (low): Low priority operations like updates
  Future<void> addSyncOperation({
    required String type,
    required Map<String, dynamic> data,
    required Future<bool> Function() operation,
    String? itemId,
    int priority = _priorityNormal,
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
      priority: priority,
    );

    // Insert based on priority (higher priority first)
    // For same priority, FIFO order (insert at appropriate position)
    int insertIndex = _syncQueue.length;
    for (int i = 0; i < _syncQueue.length; i++) {
      if (_syncQueue[i].priority < priority) {
        insertIndex = i;
        break;
      }
    }
    _syncQueue.insert(insertIndex, syncOp);

    await _saveSyncQueue();
    _notifyStatusChange();
  }

  /// Retry failed operations with exponential backoff
  ///
  /// Operations are retried with exponential backoff based on retry count.
  /// Higher priority operations are retried first.
  Future<void> retryFailedOperations() async {
    // Get failed operations sorted by priority (high first) and then by timestamp (oldest first)
    final failedOps =
        _syncQueue.where((op) => op.status == _statusFailed).toList()
          ..sort((a, b) {
            // First sort by priority (descending)
            if (a.priority != b.priority) {
              return b.priority.compareTo(a.priority);
            }
            // Then by timestamp (oldest first)
            return a.timestamp.compareTo(b.timestamp);
          });

    for (final op in failedOps) {
      // Check if enough time has passed since last attempt (exponential backoff)
      if (op.lastAttempt != null) {
        final delay = _calculateRetryDelay(op.retryCount);
        final timeSinceLastAttempt = DateTime.now().difference(op.lastAttempt!);
        if (timeSinceLastAttempt < delay) {
          // Too soon to retry, skip for now
          continue;
        }
      }

      // Check max retries
      if (op.retryCount >= _maxRetries) {
        NumberedLogger.w(
            'Sync operation ${op.id} exceeded max retries (${_maxRetries}), marking as permanently failed');
        continue; // Skip permanently failed operations
      }

      try {
        final success = await _executeOperation(op);
        if (success) {
          op.status = _statusSynced;
          op.lastAttempt = DateTime.now();
          NumberedLogger.d(
              'Sync operation ${op.id} succeeded after ${op.retryCount} retries');
        } else {
          op.retryCount++;
          op.lastAttempt = DateTime.now();
          op.status = _statusFailed; // Keep as failed for next retry cycle
          NumberedLogger.w(
              'Sync operation ${op.id} failed (attempt ${op.retryCount}/$_maxRetries)');
        }
      } catch (e, stack) {
        op.retryCount++;
        op.lastAttempt = DateTime.now();
        op.status = _statusFailed;
        NumberedLogger.w('Sync retry failed for ${op.id}: $e');
        NumberedLogger.d('Stack trace: $stack');
      }
    }

    // Remove synced operations
    _syncQueue.removeWhere((op) => op.status == _statusSynced);
    await _saveSyncQueue();
    _notifyStatusChange();
  }

  /// Calculate exponential backoff delay for retry
  ///
  /// Formula: min(baseDelay * 2^retryCount, maxDelay)
  Duration _calculateRetryDelay(int retryCount) {
    final delay = Duration(
      milliseconds: _baseRetryDelay.inMilliseconds * (1 << retryCount),
    );
    return delay > _maxRetryDelay ? _maxRetryDelay : delay;
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

  /// Returns operations older than [_stuckThreshold]
  List<SyncOperation> getStuckOperations() {
    final now = DateTime.now();
    return _syncQueue.where((op) {
      if (op.status != _statusPending) return false;
      return now.difference(op.timestamp) > _stuckThreshold;
    }).toList(growable: false);
  }

  /// Clear all operations
  Future<void> clearAll() async {
    _syncQueue.clear();
    await _saveSyncQueue();
    _notifyStatusChange();
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
    _healthLogTimer?.cancel();
    _statusController.close();
  }

  /// Load sync queue from storage
  Future<void> _loadSyncQueue() async {
    try {
      if (_prefs == null) {
        debugPrint(
            'SharedPreferences not available, starting with empty queue');
        _syncQueue.clear();
        return;
      }

      final queueJson = _prefs!.getString(_syncQueueKey);

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
      NumberedLogger.w('Failed to load sync queue: $e');
      // If SharedPreferences is not ready, just start with empty queue
      _syncQueue.clear();
    }
  }

  /// Save sync queue to storage
  Future<void> _saveSyncQueue() async {
    try {
      if (_prefs == null) {
        NumberedLogger.w('SharedPreferences not available, cannot save queue');
        return;
      }

      final queueJson =
          jsonEncode(_syncQueue.map((op) => op.toJson()).toList());
      await _prefs!.setString(_syncQueueKey, queueJson);
    } catch (e) {
      NumberedLogger.w('Failed to save sync queue: $e');
      // If SharedPreferences fails, operations will be lost but app continues
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

  /// Start periodic health logs (non-invasive telemetry via debugPrint)
  void _startHealthLogTimer() {
    _healthLogTimer?.cancel();
    _healthLogTimer = Timer.periodic(_healthLogInterval, (_) {
      _logHealthSnapshot();
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
          NumberedLogger.w('Unknown operation type: $type');
          return false;
      }
    } catch (e) {
      NumberedLogger.e('Error executing operation $type: $e');
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
  final int priority; // Higher number = higher priority

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
    this.priority = SyncServiceInstance._priorityNormal,
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
        'priority': priority,
      };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
        id: json['id'],
        type: json['type'],
        data: Map<String, dynamic>.from(json['data']),
        operation: () async =>
            false, // Placeholder since function can't be serialized
        status: json['status'],
        timestamp: DateTime.parse(json['timestamp']),
        retryCount: json['retryCount'] ?? 0,
        lastAttempt: json['lastAttempt'] != null
            ? DateTime.parse(json['lastAttempt'])
            : null,
        itemId: json['itemId'],
        priority: json['priority'] ?? SyncServiceInstance._priorityNormal,
      );
}

/// Sync status enum
enum SyncStatus {
  synced,
  pending,
  failed,
}

/// Health snapshot for the sync system
class SyncHealthSnapshot {
  final int total;
  final int pending;
  final int failed;
  final int stuck;
  final Duration? oldestPendingAge;
  final Map<String, int> byTypePending;
  final Map<String, int> byTypeFailed;

  const SyncHealthSnapshot({
    required this.total,
    required this.pending,
    required this.failed,
    required this.stuck,
    required this.oldestPendingAge,
    required this.byTypePending,
    required this.byTypeFailed,
  });
}

extension _SyncServiceHealth on SyncServiceInstance {
  /// Returns a health snapshot of the current queue
  SyncHealthSnapshot getHealthSnapshot() {
    final now = DateTime.now();
    int pending = 0;
    int failed = 0;
    int stuck = 0;
    Duration? oldestPendingAge;
    final Map<String, int> byTypePending = {};
    final Map<String, int> byTypeFailed = {};

    for (final op in _syncQueue) {
      if (op.status == SyncServiceInstance._statusPending) {
        pending++;
        final age = now.difference(op.timestamp);
        if (oldestPendingAge == null || age > oldestPendingAge) {
          oldestPendingAge = age;
        }
        byTypePending.update(op.type, (v) => v + 1, ifAbsent: () => 1);
        if (age > SyncServiceInstance._stuckThreshold) stuck++;
      } else if (op.status == SyncServiceInstance._statusFailed) {
        failed++;
        byTypeFailed.update(op.type, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    return SyncHealthSnapshot(
      total: _syncQueue.length,
      pending: pending,
      failed: failed,
      stuck: stuck,
      oldestPendingAge: oldestPendingAge,
      byTypePending: byTypePending,
      byTypeFailed: byTypeFailed,
    );
  }

  /// Returns operations older than [_stuckThreshold]
  List<SyncOperation> getStuckOperations() {
    final now = DateTime.now();
    return _syncQueue.where((op) {
      if (op.status != SyncServiceInstance._statusPending) return false;
      return now.difference(op.timestamp) > SyncServiceInstance._stuckThreshold;
    }).toList(growable: false);
  }

  void _logHealthSnapshot() {
    final snap = getHealthSnapshot();
    if (snap.total == 0) return; // keep noise low
    NumberedLogger.d(
        '[SyncHealth] total=${snap.total} pending=${snap.pending} failed=${snap.failed} '
        'stuck=${snap.stuck} oldestPendingAge=${snap.oldestPendingAge?.inMinutes}m');
    if (snap.byTypePending.isNotEmpty) {
      NumberedLogger.d('[SyncHealth] pendingByType=${snap.byTypePending}');
    }
    if (snap.byTypeFailed.isNotEmpty) {
      NumberedLogger.d('[SyncHealth] failedByType=${snap.byTypeFailed}');
    }
    final stuckOps = getStuckOperations();
    if (stuckOps.isNotEmpty) {
      final sample = stuckOps.take(3).map((o) => {
            'id': o.id,
            'type': o.type,
            'ageMin': DateTime.now().difference(o.timestamp).inMinutes,
            'retries': o.retryCount,
          });
      NumberedLogger.d(
          '[SyncHealth] stuckOps=${stuckOps.length} sample=$sample');
    }
  }
}
