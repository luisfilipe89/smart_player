import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/services/friends/friends_provider.dart';

void main() {
  group('Friends Provider Structure Tests', () {
    test('FriendsActions class should exist', () {
      expect(FriendsActions, isNotNull);
    });

    test('friendsServiceProvider should exist', () {
      expect(friendsServiceProvider, isNotNull);
    });

    test('friendsListProvider should exist', () {
      expect(friendsListProvider, isNotNull);
    });

    test('friendRequestsReceivedProvider should exist', () {
      expect(friendRequestsReceivedProvider, isNotNull);
    });

    test('friendRequestsSentProvider should exist', () {
      expect(friendRequestsSentProvider, isNotNull);
    });

    test('watchFriendsListProvider should exist', () {
      expect(watchFriendsListProvider, isNotNull);
    });

    test('watchFriendRequestsReceivedProvider should exist', () {
      expect(watchFriendRequestsReceivedProvider, isNotNull);
    });

    test('friendsActionsProvider should exist', () {
      expect(friendsActionsProvider, isNotNull);
    });
  });
}
