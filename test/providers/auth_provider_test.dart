import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/services/auth/auth_provider.dart';

void main() {
  group('Auth Provider Structure Tests', () {
    test('AuthActions class should exist', () {
      expect(AuthActions, isNotNull);
    });

    test('authServiceProvider should exist', () {
      expect(authServiceProvider, isNotNull);
    });

    test('currentUserProvider should exist', () {
      expect(currentUserProvider, isNotNull);
    });

    test('isSignedInProvider should exist', () {
      expect(isSignedInProvider, isNotNull);
    });

    test('currentUserIdProvider should exist', () {
      expect(currentUserIdProvider, isNotNull);
    });

    test('currentUserDisplayNameProvider should exist', () {
      expect(currentUserDisplayNameProvider, isNotNull);
    });

    test('authActionsProvider should exist', () {
      expect(authActionsProvider, isNotNull);
    });
  });
}
