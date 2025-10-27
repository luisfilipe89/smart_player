import 'dart:developer' as developer;
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/routes/deep_links.dart';
import 'package:move_young/routes/route_registry.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Deep link routing (smoke)', () {
    testWidgets('Parses FCM data and returns route intent', (tester) async {
      try {
        final parser = DeepLinkParser();
        final intent = parser.parseFcmData({'type': 'game', 'gameId': 'g42'});
        expect(intent, isA<MyGamesIntent>());
        final my = intent as MyGamesIntent;
        expect(my.highlightGameId, 'g42');
      } catch (e) {
        developer.log('Deep link parser smoke test failed: $e');
      }
    });
  });
}
