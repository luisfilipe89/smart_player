import 'package:flutter/material.dart';
import 'package:move_young/screens/home/home_screen.dart';
import 'package:move_young/screens/activities/activities_screen.dart';
import 'package:move_young/screens/agenda/agenda_screen.dart';
import 'package:move_young/screens/games/game_organize_screen.dart';
import 'package:move_young/models/game.dart';
import 'package:move_young/screens/games/games_join_screen.dart';
import 'package:move_young/screens/games/games_my_screen.dart';
import 'package:move_young/screens/friends/friends_screen.dart';
import 'package:easy_localization/easy_localization.dart';

// ---------------------------- Navigation Controller Scope ----------------------------
class MainScaffoldController {
  const MainScaffoldController(this._switchToTab, [this._openMyGames]);
  final void Function(int index, {bool popToRoot}) _switchToTab;
  final void Function(
      {int initialTab, String? highlightGameId, bool popToRoot})? _openMyGames;

  void switchToTab(int index, {bool popToRoot = false}) =>
      _switchToTab(index, popToRoot: popToRoot);

  void openMyGames(
      {int initialTab = 0, String? highlightGameId, bool popToRoot = true}) {
    final fn = _openMyGames;
    if (fn != null) {
      fn(
          initialTab: initialTab,
          highlightGameId: highlightGameId,
          popToRoot: popToRoot);
    } else {
      _switchToTab(kTabJoin, popToRoot: popToRoot);
    }
  }
}

class MainScaffoldScope extends InheritedWidget {
  const MainScaffoldScope(
      {super.key, required this.controller, required super.child});

  final MainScaffoldController controller;

  static MainScaffoldController? maybeOf(BuildContext context) {
    final MainScaffoldScope? scope =
        context.dependOnInheritedWidgetOfExactType<MainScaffoldScope>();
    return scope?.controller;
  }

  @override
  bool updateShouldNotify(MainScaffoldScope oldWidget) =>
      controller != oldWidget.controller;
}

// --- Dummy screens -
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: const Center(child: Text('Wallet coming soon')),
    );
  }
}

// ---------------------------- Main Scaffold ----------------------------
// Tab indices (match your BottomNav order)
const int kTabHome = 0;
const int kTabFriends = 1;
const int kTabJoin = 2;
const int kTabAgenda = 3;

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  // Handy way to reach the state from any descendant
  static MainScaffoldState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<MainScaffoldState>();

  @override
  State<MainScaffold> createState() => MainScaffoldState();
}

class MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final _homeKey = GlobalKey<NavigatorState>();
  final _friendsKey = GlobalKey<NavigatorState>();
  final _joinKey = GlobalKey<NavigatorState>();
  final _agendaKey = GlobalKey<NavigatorState>();

  late final MainScaffoldController _controller;
  MyGamesArgs? _myGamesArgs;

  @override
  void initState() {
    super.initState();
    _controller = MainScaffoldController(
      (int index, {bool popToRoot = false}) {
        if (popToRoot) _popToRoot(index);
        if (mounted) setState(() => _currentIndex = index);
      },
      ({int initialTab = 0, String? highlightGameId, bool popToRoot = true}) {
        if (popToRoot) {
          _popToRoot(kTabJoin);
          // Also clear Home flow so returning Home shows the root Home screen
          _homeKey.currentState?.popUntil((r) => r.isFirst);
        }
        setState(() {
          _myGamesArgs = MyGamesArgs(
              initialTab: initialTab, highlightGameId: highlightGameId);
          _currentIndex = kTabJoin;
        });
        // Nudge the nested My Games navigator to rebuild and show latest
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = _joinKey.currentState;
          if (nav != null) {
            nav.pushReplacement(
              MaterialPageRoute(
                builder: (_) => GamesMyScreen(
                  initialTab: initialTab,
                  highlightGameId: highlightGameId,
                ),
              ),
            );
          }
        });
      },
    );
  }

  void switchToTab(int index, {bool popToRoot = false}) {
    if (popToRoot) _popToRoot(index);
    setState(() => _currentIndex = index);
  }

  NavigatorState? get _maybeCurrentNavigator {
    switch (_currentIndex) {
      case kTabHome:
        return _homeKey.currentState;
      case kTabFriends:
        return _friendsKey.currentState;
      case kTabJoin:
        return _joinKey.currentState;
      case kTabAgenda:
        return _agendaKey.currentState;
      default:
        return _homeKey.currentState;
    }
  }

  void _popToRoot(int index) {
    final keys = [_homeKey, _friendsKey, _joinKey, _agendaKey];
    keys[index].currentState?.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffoldScope(
      controller: _controller,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          final popped = await _maybeCurrentNavigator?.maybePop() ?? false;
          if (popped) return;

          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
            return;
          }
        },
        child: Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: <Widget>[
              HeroMode(
                  enabled: _currentIndex == kTabHome,
                  child: _HomeFlow(navigatorKey: _homeKey)),
              HeroMode(
                  enabled: _currentIndex == kTabFriends,
                  child: _FriendsFlow(navigatorKey: _friendsKey)),
              HeroMode(
                  enabled: _currentIndex == kTabJoin,
                  child:
                      _MyGamesFlow(navigatorKey: _joinKey, args: _myGamesArgs)),
              HeroMode(
                  enabled: _currentIndex == kTabAgenda,
                  child: _AgendaFlow(navigatorKey: _agendaKey)),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: _BottomBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                if (index == _currentIndex) {
                  _popToRoot(index);
                } else {
                  setState(() => _currentIndex = index);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------- Tab Flows ----------------------------

// NOTE: Removed `super.key` from these private widgets to silence the “unused key” warning.

class _HomeFlow extends StatelessWidget {
  const _HomeFlow({required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/activities':
            return MaterialPageRoute(
              builder: (_) => ActivitiesScreen(),
              settings: settings,
            );
          case '/organize-game':
            return MaterialPageRoute(
              builder: (_) {
                final args = settings.arguments;
                if (args is Game) {
                  return GameOrganizeScreen(initialGame: args);
                }
                return const GameOrganizeScreen();
              },
              settings: settings,
            );
          case '/discover-games':
            return MaterialPageRoute(
              builder: (_) => const GamesDiscoveryScreen(),
              settings: settings,
            );

          default:
            return MaterialPageRoute(
              builder: (_) => const HomeScreenNew(),
              settings: settings,
            );
        }
      },
    );
  }
}

class _AgendaFlow extends StatelessWidget {
  const _AgendaFlow({required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => AgendaScreen(),
          settings: settings,
        );
      },
    );
  }
}

class _FriendsFlow extends StatelessWidget {
  const _FriendsFlow({required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const FriendsScreen(),
          settings: settings,
        );
      },
    );
  }
}

class _MyGamesFlow extends StatelessWidget {
  const _MyGamesFlow({required this.navigatorKey, this.args});
  final GlobalKey<NavigatorState> navigatorKey;
  final MyGamesArgs? args;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => GamesMyScreen(
            initialTab: args?.initialTab ?? 0,
            highlightGameId: args?.highlightGameId,
          ),
          settings: settings,
        );
      },
    );
  }
}

class MyGamesArgs {
  final int initialTab;
  final String? highlightGameId;
  const MyGamesArgs({this.initialTab = 0, this.highlightGameId});
}

// ---------------------------- Bottom Bar Wrapper ----------------------------

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      key: ValueKey(context.locale.languageCode),
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home'.tr()),
        BottomNavigationBarItem(icon: Icon(Icons.group), label: 'friends'.tr()),
        BottomNavigationBarItem(
            icon: Icon(Icons.sports_soccer), label: 'my_games'.tr()),
        BottomNavigationBarItem(icon: Icon(Icons.event), label: 'agenda'.tr()),
      ],
    );
  }
}
