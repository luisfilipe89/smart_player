import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/services/connectivity/connectivity_provider.dart';
import 'package:move_young/services/connectivity/connectivity_service_instance.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('ConnectivityProvider Tests', () {
    test(
        'connectivityServiceProvider should provide ConnectivityServiceInstance',
        () {
      final container = ProviderContainer();

      final service = container.read(connectivityServiceProvider);

      expect(service, isNotNull);
      expect(service, isA<ConnectivityServiceInstance>());
    });

    test('connectivityActionsProvider should provide ConnectivityActions', () {
      final container = ProviderContainer();

      final actions = container.read(connectivityActionsProvider);

      expect(actions, isNotNull);
      expect(actions, isA<ConnectivityActions>());
    });

    test('ConnectivityActions should initialize service', () async {
      final container = ProviderContainer();

      final actions = container.read(connectivityActionsProvider);

      // Should not throw
      await actions.initialize();
    });

    test('ConnectivityActions should check connectivity', () async {
      final container = ProviderContainer();

      final actions = container.read(connectivityActionsProvider);

      final isConnected = await actions.checkConnectivity();

      expect(isConnected, isA<bool>());
    });

    test('ConnectivityActions should check internet connection', () async {
      final container = ProviderContainer();

      final actions = container.read(connectivityActionsProvider);

      final hasInternet = await actions.hasInternetConnection();

      expect(hasInternet, isA<bool>());
    });

    test('ConnectivityActions should dispose service', () {
      final container = ProviderContainer();

      final actions = container.read(connectivityActionsProvider);

      // Should not throw
      actions.dispose();
    });

    test('connectivityStatusProvider should provide stream', () {
      final container = ProviderContainer();

      final streamAsync = container.read(connectivityStatusProvider);

      expect(streamAsync, isNotNull);
    });

    test('hasConnectionProvider should provide boolean value', () {
      final container = ProviderContainer();

      final hasConnection = container.read(hasConnectionProvider);

      expect(hasConnection, isA<bool>());
    });
  });
}
