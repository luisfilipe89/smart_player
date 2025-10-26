import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/providers/infrastructure/navigation_provider.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('NavigationProvider Tests', () {
    test('navigatorKeyProvider should provide GlobalKey', () {
      final container = ProviderContainer();

      final navigatorKey = container.read(navigatorKeyProvider);

      expect(navigatorKey, isNotNull);
      expect(navigatorKey, isA<GlobalKey<NavigatorState>>());
    });

    test('navigationActionsProvider should provide NavigationActions', () {
      final container = ProviderContainer();

      final actions = container.read(navigationActionsProvider);

      expect(actions, isNotNull);
      expect(actions, isA<NavigationActions>());
    });

    test('NavigationActions canPop should return correct state', () {
      final container = ProviderContainer();

      final actions = container.read(navigationActionsProvider);

      // When navigator is not initialized, should return false
      expect(actions.canPop(), isFalse);
    });

    test('NavigationActions should handle pop operation', () {
      final container = ProviderContainer();

      final actions = container.read(navigationActionsProvider);

      // Should not throw when pop is called without navigator
      actions.pop();
    });

    test('NavigationActions should handle pop with result', () {
      final container = ProviderContainer();

      final actions = container.read(navigationActionsProvider);

      // Should not throw when pop is called with result
      actions.pop('test');
    });

    test('NavigationActions should handle pushNamed without navigator',
        () async {
      final container = ProviderContainer();

      final actions = container.read(navigationActionsProvider);

      final result = await actions.pushNamed('test_route');

      expect(result, isNull);
    });

    test('NavigationActions should handle pushReplacementNamed', () async {
      final container = ProviderContainer();

      final actions = container.read(navigationActionsProvider);

      final result = await actions.pushReplacementNamed('test_route');

      expect(result, isNull);
    });

    test('NavigationActions should handle popUntil', () {
      final container = ProviderContainer();

      final actions = container.read(navigationActionsProvider);

      // Should not throw
      actions.popUntil((route) => false);
    });

    test('NavigationActions should handle pushNamedAndRemoveUntil', () async {
      final container = ProviderContainer();

      final actions = container.read(navigationActionsProvider);

      final result = await actions.pushNamedAndRemoveUntil(
        'test_route',
        (route) => false,
      );

      expect(result, isNull);
    });
  });
}
