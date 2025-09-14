import 'package:flutter/material.dart';
import 'package:move_young/screens/home/home_screen.dart';
import 'package:move_young/screens/activities/activities_screen.dart';
import 'package:move_young/screens/agenda/agenda_screen.dart';
import 'package:move_young/screens/games/game_organize_screen.dart';
import 'package:move_young/models/game.dart';
import 'package:move_young/screens/games/games_join_screen.dart';
import 'package:easy_localization/easy_localization.dart';

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
const int kTabAgenda = 1;
const int kTabWallet = 2;

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
  final _agendaKey = GlobalKey<NavigatorState>();
  final _walletKey = GlobalKey<NavigatorState>();

  void switchToTab(int index, {bool popToRoot = false}) {
    if (popToRoot) _popToRoot(index);
    setState(() => _currentIndex = index);
  }

  NavigatorState? get _maybeCurrentNavigator {
    switch (_currentIndex) {
      case kTabHome:
        return _homeKey.currentState;
      case kTabAgenda:
        return _agendaKey.currentState;
      case kTabWallet:
      default:
        return _walletKey.currentState;
    }
  }

  void _popToRoot(int index) {
    final keys = [_homeKey, _agendaKey, _walletKey];
    keys[index].currentState?.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
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
                enabled: _currentIndex == kTabAgenda,
                child: _AgendaFlow(navigatorKey: _agendaKey)),
            HeroMode(
                enabled: _currentIndex == kTabWallet,
                child: _WalletFlow(navigatorKey: _walletKey)),
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

class _WalletFlow extends StatelessWidget {
  const _WalletFlow({required this.navigatorKey});
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const WalletScreen(),
          settings: settings,
        );
      },
    );
  }
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
        BottomNavigationBarItem(icon: Icon(Icons.event), label: 'agenda'.tr()),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: 'map'.tr()),
      ],
    );
  }
}
