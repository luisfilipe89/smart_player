import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/services/games/games_service_instance.dart';
import 'package:move_young/services/games/games_service.dart';
import 'package:move_young/services/auth/auth_service.dart';
import 'package:move_young/repositories/game_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _AuthFake implements IAuthService {
  String? _uid = 'u1';
  @override
  String? get currentUserId => _uid;
  @override
  bool get isSignedIn => _uid != null;
  @override
  User? get currentUser => null;
  @override
  String get currentUserDisplayName => 'User';
  @override
  Stream<User?> get authStateChanges => const Stream<User?>.empty();
  @override
  Stream<User?> get userChanges => const Stream<User?>.empty();
  @override
  Future<UserCredential> createUserWithEmailAndPassword(
          String email, String password, String displayName) async =>
      throw UnimplementedError();
  @override
  Future<void> changeEmail(
          {required String currentPassword, required String newEmail}) async =>
      throw UnimplementedError();
  @override
  Future<void> changePassword(
          String currentPassword, String newPassword) async =>
      throw UnimplementedError();
  @override
  Future<bool> deleteAccount() async => false;
  @override
  Future<void> sendPasswordResetEmail(String email) async =>
      throw UnimplementedError();
  @override
  Future<UserCredential> signInAnonymously() async =>
      throw UnimplementedError();
  @override
  Future<UserCredential> signInWithEmailAndPassword(
          String email, String password) async =>
      throw UnimplementedError();
  @override
  Future<UserCredential?> signInWithGoogle() async =>
      throw UnimplementedError();
  @override
  Future<void> signOut() async {}
  @override
  Future<void> updateDisplayName(String displayName) async =>
      throw UnimplementedError();
  @override
  Future<void> updateEmail(String newEmail) async => throw UnimplementedError();
  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async =>
      throw UnimplementedError();
  @override
  bool get hasPasswordProvider => true;
}

class _GameRepositoryFake implements IGameRepository {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('GamesService invalidation methods are callable', () async {
    final auth = _AuthFake();
    final repository = _GameRepositoryFake();
    final IGamesService games = GamesServiceInstance(auth, repository);

    // Should be callable without throwing
    await games.syncWithCloud();
  });
}
