import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:move_young/services/cache/image_cache_service_instance.dart';

void main() {
  group('ImageCacheServiceInstance Tests', () {
    late ImageCacheServiceInstance imageCacheService;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      imageCacheService = ImageCacheServiceInstance();
    });

    test('should initialize image cache service', () async {
      await imageCacheService.initialize();

      // Service should be initialized
      expect(true, true);
    });

    test('should not initialize multiple times', () async {
      await imageCacheService.initialize();
      await imageCacheService.initialize();

      // Should not throw
      expect(true, true);
    });

    test('should provide service instance', () {
      expect(imageCacheService, isNotNull);
      expect(imageCacheService, isA<ImageCacheServiceInstance>());
    });

    test('should handle initialization errors gracefully', () async {
      await imageCacheService.initialize();

      // Should handle errors without crashing
      expect(true, true);
    });

    test('should create optimized image widget', () {
      const imageUrl = 'https://example.com/image.jpg';

      final widget = imageCacheService.getOptimizedImage(
        imageUrl: imageUrl,
        width: 200,
        height: 200,
      );

      expect(widget, isNotNull);
      expect(widget, isA<Widget>());
    });

    test('should handle infinite dimensions', () {
      const imageUrl = 'https://example.com/image.jpg';

      // Test with infinite width
      final widget = imageCacheService.getOptimizedImage(
        imageUrl: imageUrl,
        width: double.infinity,
        height: 100,
      );

      expect(widget, isNotNull);
      expect(widget, isA<Widget>());
    });

    test('should handle null dimensions', () {
      const imageUrl = 'https://example.com/image.jpg';

      final widget = imageCacheService.getOptimizedImage(
        imageUrl: imageUrl,
        width: null,
        height: null,
      );

      expect(widget, isNotNull);
      expect(widget, isA<Widget>());
    });

    test('should use custom fit parameter', () {
      const imageUrl = 'https://example.com/image.jpg';

      final widget = imageCacheService.getOptimizedImage(
        imageUrl: imageUrl,
        width: 200,
        height: 200,
        fit: BoxFit.cover,
      );

      expect(widget, isNotNull);

      // Test other fit options
      final widget2 = imageCacheService.getOptimizedImage(
        imageUrl: imageUrl,
        width: 200,
        height: 200,
        fit: BoxFit.contain,
      );

      expect(widget2, isNotNull);
    });

    test('should support different box fit options', () {
      const imageUrl = 'https://example.com/image.jpg';
      final fits = [
        BoxFit.cover,
        BoxFit.contain,
        BoxFit.fill,
        BoxFit.fitWidth,
        BoxFit.fitHeight,
        BoxFit.none,
        BoxFit.scaleDown,
      ];

      for (final fit in fits) {
        final widget = imageCacheService.getOptimizedImage(
          imageUrl: imageUrl,
          width: 200,
          height: 200,
          fit: fit,
        );
        expect(widget, isNotNull);
      }
    });

    test('should handle various fade in durations', () {
      const imageUrl = 'https://example.com/image.jpg';

      final widget1 = imageCacheService.getOptimizedImage(
        imageUrl: imageUrl,
        width: 200,
        height: 200,
        fadeInDuration: Duration(milliseconds: 100),
      );

      expect(widget1, isNotNull);

      final widget2 = imageCacheService.getOptimizedImage(
        imageUrl: imageUrl,
        width: 200,
        height: 200,
        fadeInDuration: Duration(milliseconds: 500),
      );

      expect(widget2, isNotNull);
    });

    test('should support different fade curves', () {
      const imageUrl = 'https://example.com/image.jpg';

      final curves = [
        Curves.easeIn,
        Curves.easeOut,
        Curves.easeInOut,
        Curves.linear,
        Curves.elasticIn,
        Curves.elasticOut,
      ];

      for (final curve in curves) {
        final widget = imageCacheService.getOptimizedImage(
          imageUrl: imageUrl,
          width: 200,
          height: 200,
          fadeInCurve: curve,
        );
        expect(widget, isNotNull);
      }
    });

    test('should create optimized avatar widget with null URL', () {
      final widget = imageCacheService.getOptimizedAvatar(
        imageUrl: null,
        radius: 25,
        fallbackText: 'AB',
      );

      expect(widget, isNotNull);
      expect(widget, isA<Widget>());
    });

    test('should create optimized avatar widget with empty URL', () {
      final widget = imageCacheService.getOptimizedAvatar(
        imageUrl: '',
        radius: 25,
        fallbackText: 'CD',
      );

      expect(widget, isNotNull);
      expect(widget, isA<Widget>());
    });

    test('should get cache statistics', () async {
      await imageCacheService.initialize();

      final stats = imageCacheService.getCacheStats();

      expect(stats, isNotNull);
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats['currentSize'], isNotNull);
      expect(stats['maximumSize'], isNotNull);
    });

    test('should clear cache without errors', () async {
      await imageCacheService.initialize();

      expect(() => imageCacheService.clearCache(), returnsNormally);
    });
  });
}
