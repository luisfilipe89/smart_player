// Centralized route registry with typed route intents

// Typed route intents used by deep links and in-app navigation
abstract class RouteIntent {}

class FriendsIntent extends RouteIntent {}

class AgendaIntent extends RouteIntent {
  AgendaIntent({this.highlightEventTitle});
  final String? highlightEventTitle;
}

class DiscoverMatchesIntent extends RouteIntent {
  DiscoverMatchesIntent({this.highlightMatchId});
  final String? highlightMatchId;
}

class MyMatchesIntent extends RouteIntent {
  MyMatchesIntent({this.initialTab = 0, this.highlightMatchId});
  final int initialTab; // 0: joined, 1: organized
  final String? highlightMatchId;
}
