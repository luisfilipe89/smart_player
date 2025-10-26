import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/services/system/sync_service_instance.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SyncServiceInstance Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance();
    });

    test('SyncOperation should serialize and deserialize correctly', () {
      final original = SyncOperation(
        id: 'op1',
        type: 'game_join',
        data: {'gameId': 'game123'},
        operation: () async => true,
        status: 'pending',
        timestamp: DateTime(2023, 1, 1),
        retryCount: 0,
        itemId: 'item1',
      );

      final json = original.toJson();
      expect(json['id'], 'op1');
      expect(json['type'], 'game_join');
      expect(json['data']['gameId'], 'game123');
      expect(json['status'], 'pending');
      expect(json['retryCount'], 0);
      expect(json['itemId'], 'item1');

      final restored = SyncOperation.fromJson(json);
      expect(restored.id, 'op1');
      expect(restored.type, 'game_join');
      expect(restored.data['gameId'], 'game123');
      expect(restored.status, 'pending');
      expect(restored.retryCount, 0);
      expect(restored.itemId, 'item1');
    });

    test('SyncOperation should handle missing lastAttempt', () {
      final original = SyncOperation(
        id: 'op1',
        type: 'game_join',
        data: {'gameId': 'game123'},
        operation: () async => true,
        status: 'pending',
        timestamp: DateTime(2023, 1, 1),
        retryCount: 0,
      );

      final json = original.toJson();
      expect(json['lastAttempt'], isNull);

      final restored = SyncOperation.fromJson(json);
      expect(restored.lastAttempt, isNull);
    });

    test('SyncOperation should handle lastAttempt correctly', () {
      final lastAttempt = DateTime(2023, 1, 2);
      final original = SyncOperation(
        id: 'op1',
        type: 'game_join',
        data: {'gameId': 'game123'},
        operation: () async => true,
        status: 'pending',
        timestamp: DateTime(2023, 1, 1),
        retryCount: 1,
        lastAttempt: lastAttempt,
      );

      final json = original.toJson();
      expect(json['lastAttempt'], lastAttempt.toIso8601String());

      final restored = SyncOperation.fromJson(json);
      expect(restored.lastAttempt, isNotNull);
      expect(restored.lastAttempt!.toIso8601String(),
          lastAttempt.toIso8601String());
    });

    test('SyncOperation should handle different statuses', () {
      final statuses = ['synced', 'pending', 'failed'];

      for (final status in statuses) {
        final operation = SyncOperation(
          id: 'op',
          type: 'test',
          data: {},
          operation: () async => true,
          status: status,
          timestamp: DateTime.now(),
          retryCount: 0,
        );

        final json = operation.toJson();
        expect(json['status'], status);

        final restored = SyncOperation.fromJson(json);
        expect(restored.status, status);
      }
    });

    test('SyncStatus enum should have correct values', () {
      expect(SyncStatus.synced, isNotNull);
      expect(SyncStatus.pending, isNotNull);
      expect(SyncStatus.failed, isNotNull);
      expect(SyncStatus.values.length, 3);
    });

    test('SyncOperation should accept complex data structures', () {
      final complexData = {
        'gameId': 'game123',
        'userId': 'user456',
        'metadata': {
          'source': 'app',
          'version': '1.0.0',
          'platform': 'android',
        },
        'list': [1, 2, 3],
      };

      final operation = SyncOperation(
        id: 'op1',
        type: 'complex_operation',
        data: complexData,
        operation: () async => true,
        status: 'pending',
        timestamp: DateTime.now(),
        retryCount: 0,
      );

      final json = operation.toJson();
      expect(json['data'], complexData);

      final restored = SyncOperation.fromJson(json);
      expect(restored.data['gameId'], 'game123');
      expect(restored.data['metadata']['source'], 'app');
      expect(restored.data['list'], [1, 2, 3]);
    });
  });
}
