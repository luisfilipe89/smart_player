import 'package:flutter_test/flutter_test.dart';
import 'package:move_young/routes/deep_links.dart';
import 'package:move_young/routes/route_registry.dart';

void main() {
  group('DeepLinkParser.parseUri', () {
    final parser = DeepLinkParser();

    test('parses game URI with id', () {
      final intent = parser.parseUri('smartplayer://game/abc123');
      expect(intent, isA<MyGamesIntent>());
      final my = intent as MyGamesIntent;
      expect(my.highlightGameId, 'abc123');
      expect(my.initialTab, 0);
    });

    test('parses game URI without id -> default MyGamesIntent', () {
      final intent = parser.parseUri('smartplayer://game/');
      expect(intent, isA<MyGamesIntent>());
      final my = intent as MyGamesIntent;
      expect(my.highlightGameId, isNull);
    });

    test('parses friends URI', () {
      final intent = parser.parseUri('smartplayer://friends');
      expect(intent, isA<FriendsIntent>());
    });

    test('parses my-games with tab and highlight', () {
      final intent =
          parser.parseUri('smartplayer://my-games?tab=1&highlight=xyz');
      expect(intent, isA<MyGamesIntent>());
      final my = intent as MyGamesIntent;
      expect(my.initialTab, 1);
      expect(my.highlightGameId, 'xyz');
    });

    test('parses discover with highlight', () {
      final intent = parser.parseUri('smartplayer://discover?highlight=g1');
      expect(intent, isA<DiscoverGamesIntent>());
      final d = intent as DiscoverGamesIntent;
      expect(d.highlightGameId, 'g1');
    });
  });

  group('DeepLinkParser.parseFcmData', () {
    final parser = DeepLinkParser();

    test('game type with gameId', () {
      final intent = parser.parseFcmData({'type': 'game', 'gameId': 'id1'});
      expect(intent, isA<MyGamesIntent>());
      final my = intent as MyGamesIntent;
      expect(my.highlightGameId, 'id1');
    });

    test('friend type', () {
      final intent = parser.parseFcmData({'type': 'friend'});
      expect(intent, isA<FriendsIntent>());
    });

    test('discover type', () {
      final intent = parser.parseFcmData({'type': 'discover', 'gameId': 'id2'});
      expect(intent, isA<DiscoverGamesIntent>());
      final d = intent as DiscoverGamesIntent;
      expect(d.highlightGameId, 'id2');
    });
  });
}
