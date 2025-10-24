import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/providers/services/friends_provider.dart';

void main() {
  group('Friends Provider Tests', () {
    testWidgets('friendsServiceProvider should create FriendsServiceInstance',
        (tester) async {
      final container = ProviderContainer();

      final friendsService = container.read(friendsServiceProvider);
      expect(friendsService, isNotNull);

      container.dispose();
    });

    testWidgets('friendsListProvider should handle loading state',
        (tester) async {
      final container = ProviderContainer();

      final asyncValue = container.read(friendsListProvider);
      expect(asyncValue.isLoading, isTrue);

      container.dispose();
    });

    testWidgets('friendRequestsReceivedProvider should handle loading state',
        (tester) async {
      final container = ProviderContainer();

      final asyncValue = container.read(friendRequestsReceivedProvider);
      expect(asyncValue.isLoading, isTrue);

      container.dispose();
    });

    testWidgets('friendRequestsSentProvider should handle loading state',
        (tester) async {
      final container = ProviderContainer();

      final asyncValue = container.read(friendRequestsSentProvider);
      expect(asyncValue.isLoading, isTrue);

      container.dispose();
    });

    testWidgets('friendsActionsProvider should create FriendsActions',
        (tester) async {
      final container = ProviderContainer();

      final friendsActions = container.read(friendsActionsProvider);
      expect(friendsActions, isNotNull);

      container.dispose();
    });
  });
}
