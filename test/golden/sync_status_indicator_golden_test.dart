import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alchemist/alchemist.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/widgets/common/sync_status_indicator.dart';
import 'package:move_young/services/system/sync_provider.dart';
import 'package:move_young/services/system/sync_service_instance.dart';
import 'package:mockito/mockito.dart';
import '../helpers/golden_test_helper.dart';

/// Test wrapper for SyncStatusIndicator with mock sync service
class TestSyncStatusIndicator extends StatelessWidget {
  final SyncStatus status;
  final int failedCount;
  final Widget child;

  const TestSyncStatusIndicator({
    super.key,
    required this.status,
    this.failedCount = 0,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final mockSyncService =
        MockSyncService(status: status, failedCount: failedCount);

    return ProviderScope(
      overrides: [
        syncServiceProvider.overrideWithValue(mockSyncService),
      ],
      child: SyncStatusIndicator(
        child: child,
      ),
    );
  }
}

/// Mock SyncServiceInstance
class MockSyncService extends Mock implements SyncServiceInstance {
  final SyncStatus _status;
  final int _failedCount;

  MockSyncService({required SyncStatus status, required int failedCount})
      : _status = status,
        _failedCount = failedCount;

  @override
  SyncStatus get currentStatus => _status;

  @override
  int get failedOperationsCount => _failedCount;

  @override
  Stream<SyncStatus> get statusStream => Stream.value(_status);

  @override
  Future<void> retryFailedOperations() async {
    // Mock implementation
  }
}

void main() {
  group('SyncStatusIndicator Golden Tests', () {
    goldenTest(
      'SyncStatusIndicator synced state (no indicator)',
      fileName: 'sync_status_synced',
      builder: () => goldenMaterialAppWrapper(
        TestSyncStatusIndicator(
          status: SyncStatus.synced,
          child: Container(
            width: 200,
            height: 200,
            color: Colors.blue[100],
            child: const Center(child: Text('Synced Content')),
          ),
        ),
      ),
    );

    goldenTest(
      'SyncStatusIndicator pending state',
      fileName: 'sync_status_pending',
      builder: () => goldenMaterialAppWrapper(
        TestSyncStatusIndicator(
          status: SyncStatus.pending,
          child: Container(
            width: 200,
            height: 200,
            color: Colors.blue[100],
            child: const Center(child: Text('Syncing Content')),
          ),
        ),
      ),
    );

    goldenTest(
      'SyncStatusIndicator failed state',
      fileName: 'sync_status_failed',
      builder: () => goldenMaterialAppWrapper(
        TestSyncStatusIndicator(
          status: SyncStatus.failed,
          failedCount: 3,
          child: Container(
            width: 200,
            height: 200,
            color: Colors.blue[100],
            child: const Center(child: Text('Failed Content')),
          ),
        ),
      ),
    );
  });
}
