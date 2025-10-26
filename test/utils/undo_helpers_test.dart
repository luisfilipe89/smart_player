import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/utils/undo_helpers.dart';

void main() {
  group('UndoHelpers Tests', () {
    setUp(() {
      UndoHelpers.clearUndoQueue();
    });

    tearDown(() {
      UndoHelpers.clearUndoQueue();
    });

    test('should clear undo queue', () {
      UndoHelpers.clearUndoQueue();

      final queue = UndoHelpers.undoQueue;
      expect(queue, isEmpty);
    });

    test('should provide undo queue', () {
      final queue = UndoHelpers.undoQueue;

      expect(queue, isNotNull);
      expect(queue, isA<List<UndoAction>>());
    });

    test('should add undo action to queue', () {
      UndoHelpers.addUndoAction(
        type: 'test',
        message: 'Test action',
        onUndo: () {},
        data: {'key': 'value'},
      );

      final queue = UndoHelpers.undoQueue;
      expect(queue.length, 1);
      expect(queue.first.type, 'test');
      expect(queue.first.message, 'Test action');
      expect(queue.first.data['key'], 'value');
    });

    test('should limit undo queue size', () {
      for (int i = 0; i < 5; i++) {
        UndoHelpers.addUndoAction(
          type: 'test',
          message: 'Test action $i',
          onUndo: () {},
        );
      }

      final queue = UndoHelpers.undoQueue;
      expect(queue.length, lessThanOrEqualTo(3)); // Max 3 actions
    });

    test('should handle multiple undo actions', () {
      UndoHelpers.addUndoAction(
        type: 'delete',
        message: 'Deleted item',
        onUndo: () {},
      );

      UndoHelpers.addUndoAction(
        type: 'edit',
        message: 'Edited item',
        onUndo: () {},
      );

      final queue = UndoHelpers.undoQueue;
      expect(queue.length, 2);
      expect(queue.last.type, 'edit');
    });

    test('should track undo action timestamp', () {
      UndoHelpers.addUndoAction(
        type: 'test',
        message: 'Test action',
        onUndo: () {},
      );

      final queue = UndoHelpers.undoQueue;
      expect(queue.first.timestamp, isA<DateTime>());
    });

    test('should store undo action data', () {
      final testData = {'id': '123', 'name': 'Test'};

      UndoHelpers.addUndoAction(
        type: 'test',
        message: 'Test action',
        onUndo: () {},
        data: testData,
      );

      final queue = UndoHelpers.undoQueue;
      expect(queue.first.data, testData);
    });

    test('should execute undo callback', () {
      bool undoExecuted = false;

      UndoHelpers.addUndoAction(
        type: 'test',
        message: 'Test action',
        onUndo: () {
          undoExecuted = true;
        },
      );

      final queue = UndoHelpers.undoQueue;
      queue.first.onUndo();

      expect(undoExecuted, true);
    });
  });

  group('UndoAction Tests', () {
    test('should create undo action with all fields', () {
      bool callbackCalled = false;
      final action = UndoAction(
        type: 'delete',
        message: 'Deleted item',
        onUndo: () => callbackCalled = true,
        data: {'id': '123'},
        timestamp: DateTime.now(),
      );

      expect(action.type, 'delete');
      expect(action.message, 'Deleted item');
      expect(action.data['id'], '123');
      expect(action.timestamp, isA<DateTime>());

      action.onUndo();
      expect(callbackCalled, true);
    });

    test('should handle empty data', () {
      final action = UndoAction(
        type: 'test',
        message: 'Test action',
        onUndo: () {},
        data: {},
        timestamp: DateTime.now(),
      );

      expect(action.data, isEmpty);
    });
  });
}
