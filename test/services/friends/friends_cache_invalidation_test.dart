import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/services/friends/friends_service_instance.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:move_young/services/notifications/notification_interface.dart';

class _AuthFake implements FirebaseAuth {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DbFake implements FirebaseDatabase {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NotifFake implements INotificationService {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('FriendsService cache methods are callable', () {
    final svc = FriendsServiceInstance(_AuthFake(), _DbFake(), _NotifFake());
    svc.clearCache();
    svc.clearExpiredCache();
  });
}





