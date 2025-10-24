import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/providers/services/auth_provider.dart';

void main() {
  group('Auth Flow Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('should handle complete auth flow', (tester) async {
      // Test initial state - not signed in
      final isSignedIn = container.read(isSignedInProvider);
      expect(isSignedIn, isFalse);

      final currentUser = container.read(currentUserProvider);
      expect(currentUser, isNull);

      final userId = container.read(currentUserIdProvider);
      expect(userId, isNull);

      // Test that auth actions are available
      final authActions = container.read(authActionsProvider);
      expect(authActions, isNotNull);
    });

    testWidgets('should handle provider state changes', (tester) async {
      // Test that providers can be read multiple times without issues
      for (int i = 0; i < 5; i++) {
        final isSignedIn = container.read(isSignedInProvider);
        // final currentUser = container.read(currentUserProvider); // Unused variable
        // final userId = container.read(currentUserIdProvider); // Unused variable
        final authActions = container.read(authActionsProvider);

        expect(isSignedIn, isA<bool>());
        expect(authActions, isNotNull);
      }
    });

    testWidgets('should handle provider invalidation', (tester) async {
      // Test that providers can be invalidated without issues
      expect(() => container.invalidate(isSignedInProvider), returnsNormally);
      expect(() => container.invalidate(currentUserProvider), returnsNormally);
      expect(
          () => container.invalidate(currentUserIdProvider), returnsNormally);
      expect(() => container.invalidate(authActionsProvider), returnsNormally);
    });
  });
}
