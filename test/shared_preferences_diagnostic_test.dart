import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

void main() {
  // Initialize binding for platform channel tests
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('SharedPreferences Diagnostic Tests', () {
    tearDown(() {
      // Clean up after each test
      SharedPreferences.setMockInitialValues({});
    });

    test('Test 1: Basic initialization should work', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs, isNotNull);
    });

    test('Test 2: Timing - immediate initialization', () async {
      final stopwatch = Stopwatch()..start();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      stopwatch.stop();
      
      expect(prefs, isNotNull);
      print('✓ Immediate init took: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('Test 3: Timing - with 500ms delay (current pattern)', () async {
      SharedPreferences.setMockInitialValues({});
      await Future.delayed(const Duration(milliseconds: 500));
      
      final stopwatch = Stopwatch()..start();
      final prefs = await SharedPreferences.getInstance();
      stopwatch.stop();
      
      expect(prefs, isNotNull);
      print('✓ With 500ms delay init took: ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Test 4: Read/Write operations', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('test_key', 'test_value');
      final value = prefs.getString('test_key');
      expect(value, equals('test_value'));
      print('✓ Read/Write operations work correctly');
    });

    test('Test 5: Multiple rapid initializations (concurrent access)', () async {
      SharedPreferences.setMockInitialValues({});
      
      final stopwatch = Stopwatch()..start();
      final futures = List.generate(10, (_) => SharedPreferences.getInstance());
      final results = await Future.wait(futures);
      stopwatch.stop();
      
      expect(results.length, equals(10));
      expect(results.every((p) => p != null), isTrue);
      
      // All should be the same instance (singleton pattern)
      final first = results.first;
      expect(results.every((p) => identical(p, first)), isTrue);
      
      print('✓ Concurrent access: ${results.length} requests in ${stopwatch.elapsedMilliseconds}ms');
    });

    test('Test 6: Error handling on platform channel failure', () async {
      // Simulate platform channel error
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        (call) async {
          throw PlatformException(
            code: 'channel-error',
            message: 'Platform channel not ready',
          );
        },
      );

      try {
        final prefs = await SharedPreferences.getInstance().timeout(
          const Duration(seconds: 1),
        );
        print('⚠ Got prefs despite error: ${prefs != null}');
      } catch (e) {
        print('✓ Expected error caught: ${e.toString().substring(0, 100)}...');
        expect(e, isA<PlatformException>());
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/shared_preferences'),
          null,
        );
      }
    });

    test('Test 7: Concurrent write operations', () async {
      SharedPreferences.setMockInitialValues({});
      
      final prefs1 = await SharedPreferences.getInstance();
      final prefs2 = await SharedPreferences.getInstance();
      
      // Should be same instance
      expect(identical(prefs1, prefs2), isTrue);
      
      // Concurrent writes
      final results = await Future.wait([
        prefs1.setString('key1', 'value1'),
        prefs2.setString('key2', 'value2'),
        prefs1.setInt('key3', 42),
      ]);
      
      expect(results.every((r) => r == true), isTrue);
      expect(prefs1.getString('key1'), equals('value1'));
      expect(prefs2.getString('key2'), equals('value2'));
      expect(prefs1.getInt('key3'), equals(42));
      
      print('✓ Concurrent writes completed successfully');
    });

    test('Test 8: Initialization timeout behavior', () async {
      SharedPreferences.setMockInitialValues({});
      
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
      );
      
      expect(prefs, isNotNull);
      print('✓ Initialization completes within 2 second timeout');
    });

    test('Test 9: Retry pattern (current implementation)', () async {
      SharedPreferences.setMockInitialValues({});
      
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
        print('✓ First attempt succeeded');
      } catch (e) {
        print('⚠ First attempt failed: $e');
        await Future.delayed(const Duration(milliseconds: 2000));
        try {
          prefs = await SharedPreferences.getInstance();
          print('✓ Retry attempt succeeded');
        } catch (e2) {
          print('✗ Retry attempt also failed: $e2');
        }
      }
      
      expect(prefs, isNotNull);
    });
  });
}

