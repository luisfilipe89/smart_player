import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/providers/services/auth_provider.dart';

void main() {
  group('Auth Provider Tests', () {
    testWidgets('authServiceProvider should create AuthServiceInstance',
        (tester) async {
      final container = ProviderContainer();

      final authService = container.read(authServiceProvider);
      expect(authService, isNotNull);

      container.dispose();
    });

    testWidgets('currentUserProvider should handle initial state',
        (tester) async {
      final container = ProviderContainer();

      final user = container.read(currentUserProvider);
      expect(user, isNull);

      container.dispose();
    });

    testWidgets('isSignedInProvider should return false when not authenticated',
        (tester) async {
      final container = ProviderContainer();

      final isSignedIn = container.read(isSignedInProvider);
      expect(isSignedIn, isFalse);

      container.dispose();
    });

    testWidgets(
        'currentUserIdProvider should return null when not authenticated',
        (tester) async {
      final container = ProviderContainer();

      final userId = container.read(currentUserIdProvider);
      expect(userId, isNull);

      container.dispose();
    });

    testWidgets('authActionsProvider should create AuthActions',
        (tester) async {
      final container = ProviderContainer();

      final authActions = container.read(authActionsProvider);
      expect(authActions, isNotNull);

      container.dispose();
    });
  });
}
