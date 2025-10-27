// Centralized route registry with typed route intents

import 'package:flutter/widgets.dart';

// Route names for Navigator-based flows
class AppRoutes {
  static const String home = '/';
  static const String activities = '/activities';
  static const String organizeGame = '/organize-game';
  static const String discoverGames = '/discover-games';
  static const String friends = '/friends';
  static const String myGames = '/my-games';
  static const String agenda = '/agenda';
}

// Typed route intents used by deep links and in-app navigation
abstract class RouteIntent {}

class HomeIntent extends RouteIntent {}

class FriendsIntent extends RouteIntent {}

class AgendaIntent extends RouteIntent {}

class ActivitiesIntent extends RouteIntent {}

class DiscoverGamesIntent extends RouteIntent {
  DiscoverGamesIntent({this.highlightGameId});
  final String? highlightGameId;
}

class MyGamesIntent extends RouteIntent {
  MyGamesIntent({this.initialTab = 0, this.highlightGameId});
  final int initialTab; // 0: joined, 1: organized
  final String? highlightGameId;
}

class OrganizeGameIntent extends RouteIntent {
  OrganizeGameIntent({this.gameId});
  final String? gameId; // optional existing game to edit
}

// Helper to push a route on a nested navigator
Future<T?> pushNamedOn<T extends Object?>(
  GlobalKey<NavigatorState> key,
  String routeName, {
  Object? arguments,
}) async {
  final nav = key.currentState;
  if (nav == null) return null;
  return nav.pushNamed<T>(routeName, arguments: arguments);
}
