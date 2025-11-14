// Centralized route registry with typed route intents

// Typed route intents used by deep links and in-app navigation
abstract class RouteIntent {}

class FriendsIntent extends RouteIntent {}

class AgendaIntent extends RouteIntent {}

class DiscoverGamesIntent extends RouteIntent {
  DiscoverGamesIntent({this.highlightGameId});
  final String? highlightGameId;
}

class MyGamesIntent extends RouteIntent {
  MyGamesIntent({this.initialTab = 0, this.highlightGameId});
  final int initialTab; // 0: joined, 1: organized
  final String? highlightGameId;
}
