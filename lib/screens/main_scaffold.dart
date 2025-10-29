import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/screens/home/home_screen.dart';
import 'package:move_young/screens/activities/activities_screen.dart';
import 'package:move_young/screens/agenda/agenda_screen.dart';
import 'package:move_young/screens/games/game_organize_screen.dart';
import 'package:move_young/models/core/game.dart';
import 'package:move_young/screens/games/games_join_screen.dart';
import 'package:move_young/screens/games/games_my_screen.dart';
import 'package:move_young/screens/friends/friends_screen.dart';
import 'package:move_young/widgets/common/offline_banner.dart';
import 'package:move_young/widgets/common/sync_status_indicator.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/routes/route_registry.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:move_young/widgets/navigation/navigation_utils.dart';

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

  // Static method to find the controller from context
  static MainScaffoldController? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<MainScaffoldScope>();
    return scope?.controller;
  }

  // Static method to navigate to a specific game from notifications
  static void navigateToGame(String gameId) {
    debugPrint('Navigating to game: $gameId');
    // This will be implemented to work with the current controller instance
  }
}

// MainScaffoldController provider
final mainScaffoldControllerProvider =
    StateProvider<MainScaffoldController?>((ref) => null);

// Tab index provider to standardize state via Riverpod
final mainTabIndexProvider = StateProvider<int>((ref) => 0);

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

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  // Handy way to reach the state from any descendant
  static MainScaffoldState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<MainScaffoldState>();

  @override
  ConsumerState<MainScaffold> createState() => MainScaffoldState();
}

class MainScaffoldState extends ConsumerState<MainScaffold> {
  late final ValueNotifier<int> _currentIndexNotifier;

  final _homeKey = GlobalKey<NavigatorState>();
  final _friendsKey = GlobalKey<NavigatorState>();
  final _joinKey = GlobalKey<NavigatorState>();
  final _agendaKey = GlobalKey<NavigatorState>();

  late final MainScaffoldController _controller;
  MyGamesArgs? _myGamesArgs;
  // expose intent handlers
  void handleRouteIntent(RouteIntent intent) {
    if (intent is FriendsIntent) {
      switchToTab(kTabFriends, popToRoot: true);
    } else if (intent is AgendaIntent) {
      switchToTab(kTabAgenda, popToRoot: true);
    } else if (intent is DiscoverGamesIntent) {
      switchToTab(kTabJoin, popToRoot: true);
    } else if (intent is MyGamesIntent) {
      _myGamesArgs = MyGamesArgs(
          initialTab: intent.initialTab,
          highlightGameId: intent.highlightGameId);
      switchToTab(kTabJoin, popToRoot: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = _joinKey.currentState;
        if (nav != null) {
          nav.pushReplacement(
            MaterialPageRoute(
              builder: (_) => GamesMyScreen(
                initialTab: intent.initialTab,
                highlightGameId: intent.highlightGameId,
              ),
            ),
          );
        }
      });
    } else {
      switchToTab(kTabHome, popToRoot: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndexNotifier = ValueNotifier<int>(ref.read(mainTabIndexProvider));
    _controller = MainScaffoldController(
      (int index, {bool popToRoot = false}) {
        if (popToRoot) _popToRoot(index);
        if (mounted) {
          ref.read(mainTabIndexProvider.notifier).state = index;
          _currentIndexNotifier.value = index;
        }
      },
      ({int initialTab = 0, String? highlightGameId, bool popToRoot = true}) {
        if (popToRoot) {
          _popToRoot(kTabJoin);
          // Also clear Home flow so returning Home shows the root Home screen
          _homeKey.currentState?.popUntil((r) => r.isFirst);
        }
        _myGamesArgs = MyGamesArgs(
            initialTab: initialTab, highlightGameId: highlightGameId);
        ref.read(mainTabIndexProvider.notifier).state = kTabJoin;
        _currentIndexNotifier.value = kTabJoin;
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

    // Set the controller in the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(mainScaffoldControllerProvider.notifier).state = _controller;
    });

    // Handle pending notifications after the scaffold is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingNotifications();
    });
  }

  @override
  void dispose() {
    _currentIndexNotifier.dispose();
    super.dispose();
  }

  void switchToTab(int index, {bool popToRoot = false}) {
    if (popToRoot) _popToRoot(index);
    ref.read(mainTabIndexProvider.notifier).state = index;
    _currentIndexNotifier.value = index;
  }

  NavigatorState? get _maybeCurrentNavigator {
    final currentIndex = ref.watch(mainTabIndexProvider);
    switch (currentIndex) {
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

  void _handlePendingNotifications() {
    // Check if there's a pending game ID to navigate to
    // This would be set by the notification tap handler
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        // Check for pending game ID from notification tap
        // This is a simple approach - in production you'd use proper state management
        debugPrint('Checking for pending notifications...');

        // Check if there's a pending game ID to navigate to
        // This would be set by the notification tap handler in main.dart
        // For now, we'll implement a simple approach
        // The actual navigation will be handled by the notification tap handler
        // when the user is already authenticated and in the main app
      }
    });
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

          if (ref.read(mainTabIndexProvider) != 0) {
            ref.read(mainTabIndexProvider.notifier).state = 0;
            _currentIndexNotifier.value = 0;
            return;
          }
        },
        child: OfflineBanner(
          child: GlobalSyncStatusBanner(
            child: ValueListenableBuilder<int>(
              valueListenable: _currentIndexNotifier,
              builder: (context, currentIndex, child) {
                return Scaffold(
                  body: KeyedSubtree(
                    key: ValueKey(currentIndex),
                    child: IndexedStack(
                      index: currentIndex,
                      children: <Widget>[
                        HeroMode(
                            enabled: currentIndex == kTabHome,
                            child: _HomeFlow(navigatorKey: _homeKey)),
                        HeroMode(
                            enabled: currentIndex == kTabFriends,
                            child: _FriendsFlow(navigatorKey: _friendsKey)),
                        HeroMode(
                            enabled: currentIndex == kTabJoin,
                            child: _MyGamesFlow(
                                navigatorKey: _joinKey, args: _myGamesArgs)),
                        HeroMode(
                            enabled: currentIndex == kTabAgenda,
                            child: _AgendaFlow(navigatorKey: _agendaKey)),
                      ],
                    ),
                  ),
                  bottomNavigationBar: SafeArea(
                    child: _BottomBar(
                      currentIndex: currentIndex,
                      onTap: (index) async {
                        // Haptic on tab select/reselect
                        await ref
                            .read(hapticsActionsProvider)
                            ?.selectionClick();
                        if (index == currentIndex) {
                          _popToRoot(index);
                        } else {
                          ref.read(mainTabIndexProvider.notifier).state = index;
                          _currentIndexNotifier.value = index;
                        }
                      },
                    ),
                  ),
                );
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
            return NavigationUtils.sharedAxisRoute(
              builder: (_) => ActivitiesScreen(),
              settings: settings,
            );
          case '/organize-game':
            return NavigationUtils.sharedAxisRoute(
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
            return NavigationUtils.sharedAxisRoute(
              builder: (_) => const GamesJoinScreen(),
              settings: settings,
            );

          default:
            return NavigationUtils.sharedAxisRoute(
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
