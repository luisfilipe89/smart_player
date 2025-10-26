import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/providers/infrastructure/config_provider.dart';

void main() {
  group('ConfigProvider Tests', () {
    test('configProvider should provide AppConfig', () {
      final container = ProviderContainer();

      final config = container.read(configProvider);

      expect(config, isNotNull);
      expect(config, isA<AppConfig>());
    });

    test('AppConfig should have correct environment properties', () {
      final container = ProviderContainer();

      final config = container.read(configProvider);

      expect(config.environment, isNotNull);
      expect(config.apiBaseUrl, isNotEmpty);
      expect(config.firebaseProjectId, isNotEmpty);
    });

    test('AppConfig should identify development environment correctly', () {
      final container = ProviderContainer();

      final config = container.read(configProvider);

      // In debug mode, should be development
      if (config.isDevelopment) {
        expect(
            config.apiBaseUrl, anyOf(contains('dev'), contains('development')));
      }
    });

    test('AppConfig should support feature flags', () {
      final container = ProviderContainer();

      final config = container.read(configProvider);

      expect(config.isFeatureEnabled('friends'), isTrue);
      expect(config.isFeatureEnabled('games'), isTrue);
      expect(config.isFeatureEnabled('notifications'), isTrue);
    });

    test('AppConfig should return false for unknown features', () {
      final container = ProviderContainer();

      final config = container.read(configProvider);

      expect(config.isFeatureEnabled('unknown_feature'), isFalse);
    });

    test('sportCharacteristicsProvider should provide SportCharacteristics',
        () {
      final container = ProviderContainer();

      final characteristics = container.read(sportCharacteristicsProvider);

      expect(characteristics, isNotNull);
    });

    test('sportDisplayProvider should provide SportDisplayRegistry', () {
      final container = ProviderContainer();

      final display = container.read(sportDisplayProvider);

      expect(display, isNotNull);
    });

    test('sportFiltersProvider should provide SportFiltersRegistry', () {
      final container = ProviderContainer();

      final filters = container.read(sportFiltersProvider);

      expect(filters, isNotNull);
    });

    test('AppConfig feature flags should be consistent', () {
      final container = ProviderContainer();

      final config = container.read(configProvider);

      // All feature flags should be either true or false
      for (final feature in config.featureFlags.keys) {
        expect(config.isFeatureEnabled(feature), isA<bool>());
      }
    });

    test('AppConfig should have valid Firebase configuration', () {
      final container = ProviderContainer();

      final config = container.read(configProvider);

      expect(config.firebaseProjectId, isNotEmpty);
      expect(config.firebaseProjectId.length, greaterThan(3));
    });
  });
}
