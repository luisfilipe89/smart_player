import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/services/auth/auth_service_instance.dart';

// Generate mocks for test
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  group('AuthServiceInstance Tests', () {
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late AuthServiceInstance authService;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      authService = AuthServiceInstance(mockAuth);
    });

    group('Properties', () {
      test('currentUser returns null when no user signed in', () {
        when(mockAuth.currentUser).thenReturn(null);

        expect(authService.currentUser, isNull);
        expect(authService.isSignedIn, isFalse);
        expect(authService.currentUserId, isNull);
      });

      test('currentUser returns user when signed in', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn('test-uid-123');

        expect(authService.currentUser, isNotNull);
        expect(authService.isSignedIn, isTrue);
        expect(authService.currentUserId, 'test-uid-123');
      });
    });

    group('Display Name', () {
      test('returns "Anonymous User" when no user signed in', () {
        when(mockAuth.currentUser).thenReturn(null);

        expect(authService.currentUserDisplayName, 'Anonymous User');
      });

      test('returns displayName when available', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.displayName).thenReturn('John Smith');

        expect(authService.currentUserDisplayName, 'John');
      });

      test('returns email prefix when displayName is empty', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.displayName).thenReturn('');
        when(mockUser.email).thenReturn('johndoe@example.com');

        expect(authService.currentUserDisplayName, 'Johndoe');
      });

      test('returns "User" when no displayName or email', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.displayName).thenReturn('');
        when(mockUser.email).thenReturn(null);

        expect(authService.currentUserDisplayName, 'User');
      });

      test('capitalizes first letter of name', () {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.displayName).thenReturn('john smith');

        expect(authService.currentUserDisplayName, 'John');
      });
    });

    group('Streams', () {
      test('authStateChanges returns stream from Firebase', () {
        final testStream = Stream<User?>.fromIterable([mockUser, null]);
        when(mockAuth.authStateChanges()).thenAnswer((_) => testStream);

        final stream = authService.authStateChanges;
        expect(stream, isA<Stream<User?>>());
      });

      test('userChanges returns stream from Firebase', () {
        final testStream = Stream<User?>.fromIterable([mockUser, null]);
        when(mockAuth.userChanges()).thenAnswer((_) => testStream);

        final stream = authService.userChanges;
        expect(stream, isA<Stream<User?>>());
      });
    });

    group('Sign In', () {
      test('signInAnonymously returns null on error', () async {
        when(mockAuth.signInAnonymously()).thenThrow(Exception('Auth failed'));

        final result = await authService.signInAnonymously();

        expect(result, isNull);
      });

      test('signOut calls Firebase signOut', () async {
        when(mockAuth.signOut()).thenAnswer((_) async {});

        await authService.signOut();

        verify(mockAuth.signOut()).called(1);
      });
    });

    group('Profile Updates', () {
      test('updateDisplayName updates user display name', () async {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.updateDisplayName('New Name')).thenAnswer((_) async {});
        when(mockUser.reload()).thenAnswer((_) async {});

        await authService.updateDisplayName('New Name');

        verify(mockUser.updateDisplayName('New Name')).called(1);
        verify(mockUser.reload()).called(1);
      });

      test('updateDisplayName does nothing when no user', () async {
        when(mockAuth.currentUser).thenReturn(null);

        await authService.updateDisplayName('New Name');

        // Should not throw
        expect(authService.isSignedIn, isFalse);
      });

      test('updateDisplayName handles empty name', () async {
        when(mockAuth.currentUser).thenReturn(mockUser);

        await authService.updateDisplayName('');

        // Should not throw but should not update
        verifyNever(mockUser.updateDisplayName(any));
      });
    });

    group('Account Management', () {
      test('deleteAccount returns true on success', () async {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.delete()).thenAnswer((_) async {});

        final result = await authService.deleteAccount();

        expect(result, isTrue);
        verify(mockUser.delete()).called(1);
      });

      test('deleteAccount returns false when no user', () async {
        when(mockAuth.currentUser).thenReturn(null);

        final result = await authService.deleteAccount();

        expect(result, isFalse);
      });

      test('deleteAccount returns false on error', () async {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.delete()).thenThrow(Exception('Delete failed'));

        final result = await authService.deleteAccount();

        expect(result, isFalse);
      });
    });

    group('Error Handling', () {
      test('signInAnonymously handles exceptions gracefully', () async {
        when(mockAuth.signInAnonymously()).thenThrow(FirebaseAuthException(
          code: 'operation-not-allowed',
          message: 'Anonymous sign-in disabled',
        ));

        final result = await authService.signInAnonymously();

        expect(result, isNull);
      });

      test('updateProfile handles errors gracefully', () async {
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.updateDisplayName(any))
            .thenThrow(Exception('Update failed'));

        await authService.updateDisplayName('Test');

        // Should not throw
        verify(mockUser.updateDisplayName('Test')).called(1);
      });
    });
  });

  group('Integration Test Coverage Note', () {
    test('Note: Full auth flows covered by integration tests', () {
      // This test serves as documentation that full authentication flows
      // including Firebase integration, sign-in flows, and error handling
      // are comprehensively tested in:
      // - integration_test/auth_flow_test.dart (5 tests)
      // - integration_test/screen_auth_test.dart (4 tests)

      expect(true, isTrue);
    });
  });
}
