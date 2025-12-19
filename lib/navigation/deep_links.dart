// Deep link parsing to typed route intents

import 'package:move_young/navigation/route_registry.dart';

class DeepLinkParser {
  // Accept both URI strings and FCM data payload maps
  RouteIntent? parseUri(String uri) {
    try {
      final u = Uri.parse(uri);
      // Examples:
      // smartplayer://match/<id>
      // smartplayer://friends
      // smartplayer://my-matches?tab=1&highlight=<id>
      final seg = u.pathSegments;
      if (seg.isEmpty) return null;
      switch (seg.first) {
        case 'match':
          final id = seg.length > 1 ? seg[1] : null;
          if (id == null || id.isEmpty) return MyMatchesIntent();
          return MyMatchesIntent(initialTab: 0, highlightMatchId: id);
        case 'friends':
          return FriendsIntent();
        case 'my-matches':
          final tab = int.tryParse(u.queryParameters['tab'] ?? '0') ?? 0;
          final highlight = u.queryParameters['highlight'];
          return MyMatchesIntent(initialTab: tab, highlightMatchId: highlight);
        case 'discover':
          final highlight = u.queryParameters['highlight'];
          return DiscoverMatchesIntent(highlightMatchId: highlight);
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  RouteIntent? parseFcmData(Map<String, dynamic> data) {
    try {
      // Expected keys: type=match|friend|discover, matchId, tab
      final type = data['type']?.toString();
      switch (type) {
        case 'match':
          return MyMatchesIntent(
            initialTab: 0,
            highlightMatchId: data['matchId']?.toString(),
          );
        case 'friend':
          return FriendsIntent();
        case 'discover':
          return DiscoverMatchesIntent(
            highlightMatchId: data['matchId']?.toString(),
          );
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}
