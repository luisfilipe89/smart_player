// Deep link parsing to typed route intents

import 'package:move_young/routes/route_registry.dart';

class DeepLinkParser {
  // Accept both URI strings and FCM data payload maps
  RouteIntent? parseUri(String uri) {
    try {
      final u = Uri.parse(uri);
      // Examples:
      // smartplayer://game/<id>
      // smartplayer://friends
      // smartplayer://my-games?tab=1&highlight=<id>
      final seg = u.pathSegments;
      if (seg.isEmpty) return null;
      switch (seg.first) {
        case 'game':
          final id = seg.length > 1 ? seg[1] : null;
          if (id == null || id.isEmpty) return MyGamesIntent();
          return MyGamesIntent(initialTab: 0, highlightGameId: id);
        case 'friends':
          return FriendsIntent();
        case 'my-games':
          final tab = int.tryParse(u.queryParameters['tab'] ?? '0') ?? 0;
          final highlight = u.queryParameters['highlight'];
          return MyGamesIntent(initialTab: tab, highlightGameId: highlight);
        case 'discover':
          final highlight = u.queryParameters['highlight'];
          return DiscoverGamesIntent(highlightGameId: highlight);
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  RouteIntent? parseFcmData(Map<String, dynamic> data) {
    try {
      // Expected keys: type=game|friend|discover, gameId, tab
      final type = data['type']?.toString();
      switch (type) {
        case 'game':
          return MyGamesIntent(
            initialTab: 0,
            highlightGameId: data['gameId']?.toString(),
          );
        case 'friend':
          return FriendsIntent();
        case 'discover':
          return DiscoverGamesIntent(
            highlightGameId: data['gameId']?.toString(),
          );
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}
