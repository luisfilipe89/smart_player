import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/home/screens/home_screen.dart';
import 'package:move_young/features/activities/screens/fitness_screen.dart';
import 'package:move_young/features/agenda/screens/agenda_screen.dart';
import 'package:move_young/features/matches/screens/match_organize_screen.dart';
import 'package:move_young/features/matches/models/match.dart';
import 'package:move_young/features/matches/screens/match_join_screen.dart';
import 'package:move_young/features/matches/screens/match_my_screen.dart';
import 'package:move_young/features/friends/screens/friends_screen.dart';
import 'package:move_young/widgets/offline_banner.dart';
import 'package:move_young/widgets/sync_status_indicator.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/navigation/route_registry.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:move_young/utils/navigation_utils.dart';
import 'package:move_young/features/friends/services/friends_provider.dart';
import 'package:move_young/utils/logger.dart';

// ---------------------------- Navigation Controller Scope ----------------------------
class MainScaffoldController {
  const MainScaffoldController(this._switchToTab,
      [this._openMyMatches, this._openJoinScreen]);
  final void Function(int index, {bool popToRoot}) _switchToTab;
  final void Function(
      {int initialTab,
      String? highlightMatchId,
      bool popToRoot})? _openMyMatches;
  final void Function(String? highlightMatchId)? _openJoinScreen;

  void switchToTab(int index, {bool popToRoot = false}) =>
      _switchToTab(index, popToRoot: popToRoot);

  void openMyMatches(
      {int initialTab = 0, String? highlightMatchId, bool popToRoot = true}) {
    final fn = _openMyMatches;
    if (fn != null) {
      fn(
          initialTab: initialTab,
          highlightMatchId: highlightMatchId,
          popToRoot: popToRoot);
    } else {
      _switchToTab(kTabJoin, popToRoot: popToRoot);
    }
  }

  void openJoinScreen(String? highlightMatchId) {
    final fn = _openJoinScreen;
    if (fn != null) {
      fn(highlightMatchId);
    } else {
      _switchToTab(kTabJoin, popToRoot: true);
    }
  }

  // Static method to find the controller from context
  static MainScaffoldController? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<MainScaffoldScope>();
    return scope?.controller;
  }

  // Static method to navigate to a specific match from notifications
  static void navigateToMatch(String matchId) {
    NumberedLogger.d('Navigating to match: $matchId');
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
  MyMatchesArgs? _myMatchesArgs;
  String? _highlightEventTitle;
  // expose intent handlers
  void handleRouteIntent(RouteIntent intent) {
    if (intent is FriendsIntent) {
      switchToTab(kTabFriends, popToRoot: true);
    } else if (intent is AgendaIntent) {
      _highlightEventTitle = intent.highlightEventTitle;
      NumberedLogger.d(
          'MainScaffold: Handling AgendaIntent with highlightEventTitle: $_highlightEventTitle');
      switchToTab(kTabAgenda, popToRoot: true);
      // Note: AgendaScreen will receive highlightEventTitle via widget parameter
      // and will scroll to it when events are loaded
    } else if (intent is DiscoverMatchesIntent) {
      switchToTab(kTabJoin, popToRoot: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = _joinKey.currentState;
        if (nav != null) {
          nav.push(
            NavigationUtils.sharedAxisRoute(
              builder: (_) => MatchesJoinScreen(
                highlightMatchId: intent.highlightMatchId,
              ),
            ),
          );
        }
      });
    } else if (intent is MyMatchesIntent) {
      _myMatchesArgs = MyMatchesArgs(
          initialTab: intent.initialTab,
          highlightMatchId: intent.highlightMatchId);
      switchToTab(kTabJoin, popToRoot: true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = _joinKey.currentState;
        if (nav != null) {
          nav.pushReplacement(
            MaterialPageRoute(
              builder: (_) => MatchesMyScreen(
                initialTab: intent.initialTab,
                highlightMatchId: intent.highlightMatchId,
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
      ({int initialTab = 0, String? highlightMatchId, bool popToRoot = true}) {
        if (popToRoot) {
          _popToRoot(kTabJoin);
          // Also clear Home flow so returning Home shows the root Home screen
          _homeKey.currentState?.popUntil((r) => r.isFirst);
        }
        _myMatchesArgs = MyMatchesArgs(
            initialTab: initialTab, highlightMatchId: highlightMatchId);
        ref.read(mainTabIndexProvider.notifier).state = kTabJoin;
        _currentIndexNotifier.value = kTabJoin;
        // Nudge the nested My Matches navigator to rebuild and show latest
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = _joinKey.currentState;
          if (nav != null) {
            nav.pushReplacement(
              MaterialPageRoute(
                builder: (_) => MatchesMyScreen(
                  initialTab: initialTab,
                  highlightMatchId: highlightMatchId,
                ),
              ),
            );
          }
        });
      },
      (String? highlightMatchId) {
        // Pop to root of Join tab first
        _popToRoot(kTabJoin);
        ref.read(mainTabIndexProvider.notifier).state = kTabJoin;
        _currentIndexNotifier.value = kTabJoin;
        // Push MatchesJoinScreen with highlightMatchId
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = _joinKey.currentState;
          if (nav != null) {
            nav.push(
              NavigationUtils.sharedAxisRoute(
                builder: (_) => MatchesJoinScreen(
                  highlightMatchId: highlightMatchId,
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
    // Check if there's a pending match ID to navigate to
    // This would be set by the notification tap handler
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        // Check for pending match ID from notification tap
        // This is a simple approach - in production you'd use proper state management
        NumberedLogger.d('Checking for pending notifications...');

        // Check if there's a pending match ID to navigate to
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
                            child: _MyMatchesFlow(
                                navigatorKey: _joinKey, args: _myMatchesArgs)),
                        HeroMode(
                            enabled: currentIndex == kTabAgenda,
                            child: _AgendaFlow(
                                key: ValueKey(
                                    'agenda_flow_${_highlightEventTitle ?? 'null'}'),
                                navigatorKey: _agendaKey,
                                highlightEventTitle: _highlightEventTitle)),
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
                          // Clear highlightEventTitle when switching to agenda tab directly
                          // (not via handleRouteIntent)
                          if (index == kTabAgenda &&
                              _highlightEventTitle != null) {
                            _highlightEventTitle = null;
                            NumberedLogger.d(
                                'MainScaffold: Cleared highlightEventTitle on direct agenda tab click');
                            // Pop to root to ensure we start fresh
                            _popToRoot(kTabAgenda);
                          }
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
          case '/organize-match':
            return NavigationUtils.sharedAxisRoute(
              builder: (_) {
                final args = settings.arguments;
                if (args is Match) {
                  return MatchOrganizeScreen(initialMatch: args as Match?);
                }
                return const MatchOrganizeScreen();
              },
              settings: settings,
            );
          case '/discover-matches':
            return NavigationUtils.sharedAxisRoute(
              builder: (_) => const MatchesJoinScreen(),
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

class _AgendaFlow extends StatefulWidget {
  const _AgendaFlow({
    super.key,
    required this.navigatorKey,
    this.highlightEventTitle,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final String? highlightEventTitle;

  @override
  State<_AgendaFlow> createState() => _AgendaFlowState();
}

class _AgendaFlowState extends State<_AgendaFlow> {
  @override
  void initState() {
    super.initState();
    // If we have a highlightEventTitle on initial build, push it after first frame
    if (widget.highlightEventTitle != null) {
      NumberedLogger.d(
          '_AgendaFlow initState: highlightEventTitle=${widget.highlightEventTitle}, will push after first frame');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = widget.navigatorKey.currentState;
        if (nav != null && mounted) {
          NumberedLogger.d(
              '_AgendaFlow initState: Pushing route with highlightEventTitle=${widget.highlightEventTitle}');
          nav.pushReplacement(
            MaterialPageRoute(
              builder: (_) => AgendaScreen(
                key: ValueKey('agenda_${widget.highlightEventTitle}'),
                highlightEventTitle: widget.highlightEventTitle,
              ),
            ),
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(_AgendaFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    NumberedLogger.d(
        '_AgendaFlow didUpdateWidget: old=${oldWidget.highlightEventTitle}, new=${widget.highlightEventTitle}');
    // If highlightEventTitle changed (from null to value, value to null, or value to different value), push a new route
    if (widget.highlightEventTitle != oldWidget.highlightEventTitle) {
      NumberedLogger.d(
          '_AgendaFlow didUpdateWidget: highlightEventTitle changed, pushing new route');
      // Pop to root first to clear any existing routes
      widget.navigatorKey.currentState?.popUntil((r) => r.isFirst);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = widget.navigatorKey.currentState;
        if (nav != null && mounted) {
          final key = widget.highlightEventTitle != null
              ? ValueKey('agenda_${widget.highlightEventTitle}')
              : const ValueKey('agenda');
          NumberedLogger.d(
              '_AgendaFlow didUpdateWidget: Executing pushReplacement with highlightEventTitle=${widget.highlightEventTitle}');
          nav.pushReplacement(
            MaterialPageRoute(
              builder: (_) => AgendaScreen(
                key: key,
                highlightEventTitle: widget.highlightEventTitle,
              ),
            ),
          );
        } else {
          NumberedLogger.w(
              '_AgendaFlow didUpdateWidget: Navigator is null or widget not mounted');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    NumberedLogger.d(
        '_AgendaFlow build: highlightEventTitle=${widget.highlightEventTitle}');
    return Navigator(
      key: widget.navigatorKey,
      onGenerateRoute: (settings) {
        // Use a key based on highlightEventTitle to force rebuild when it changes
        final key = widget.highlightEventTitle != null
            ? ValueKey('agenda_${widget.highlightEventTitle}')
            : const ValueKey('agenda');
        NumberedLogger.d(
            '_AgendaFlow onGenerateRoute: creating AgendaScreen with key=$key, highlightEventTitle=${widget.highlightEventTitle}');
        return MaterialPageRoute(
          builder: (_) => AgendaScreen(
            key: key,
            highlightEventTitle: widget.highlightEventTitle,
          ),
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

class _MyMatchesFlow extends StatelessWidget {
  const _MyMatchesFlow({required this.navigatorKey, this.args});
  final GlobalKey<NavigatorState> navigatorKey;
  final MyMatchesArgs? args;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => MatchesMyScreen(
            initialTab: args?.initialTab ?? 0,
            highlightMatchId: args?.highlightMatchId,
          ),
          settings: settings,
        );
      },
    );
  }
}

class MyMatchesArgs {
  final int initialTab;
  final String? highlightMatchId;
  const MyMatchesArgs({this.initialTab = 0, this.highlightMatchId});
}

// ---------------------------- Bottom Bar Wrapper ----------------------------

class _BottomBar extends ConsumerWidget {
  const _BottomBar({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BottomNavigationBar(
      key: ValueKey(context.locale.languageCode),
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home'.tr()),
        BottomNavigationBarItem(
          icon: const _FriendsIconWithBadge(),
          label: 'friends'.tr(),
        ),
        BottomNavigationBarItem(
            icon: Icon(Icons.sports_soccer), label: 'my_matches'.tr()),
        BottomNavigationBarItem(icon: Icon(Icons.event), label: 'agenda'.tr()),
      ],
    );
  }
}

class _FriendsIconWithBadge extends ConsumerWidget {
  const _FriendsIconWithBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(watchFriendRequestsReceivedProvider);

    return requestsAsync.when(
      data: (requests) {
        final count = requests.length;
        if (count == 0) {
          return const Icon(Icons.group);
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.group),
            Positioned(
              right: -6,
              top: -6,
              child: _FriendRequestsBadge(count: count),
            ),
          ],
        );
      },
      loading: () => const Icon(Icons.group),
      error: (_, __) => const Icon(Icons.group),
    );
  }
}

class _FriendRequestsBadge extends StatelessWidget {
  final int count;
  const _FriendRequestsBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      padding: EdgeInsets.symmetric(horizontal: count < 10 ? 4 : 5),
      constraints: const BoxConstraints(minWidth: 18),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
