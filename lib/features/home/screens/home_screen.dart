import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/agenda/models/event_model.dart';
import 'package:move_young/features/agenda/services/events_provider.dart';
import 'package:move_young/features/agenda/services/cached_events_provider.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/features/profile/services/profile_settings_provider.dart';
import 'package:move_young/features/welcome/screens/welcome_screen.dart';
import 'package:move_young/features/activities/screens/fitness_screen.dart'
    show ActivitiesScreen;
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/navigation/main_scaffold.dart';
import 'package:move_young/navigation/route_registry.dart';
import 'package:move_young/features/settings/screens/settings_screen.dart';
import 'package:move_young/features/help/screens/help_screen.dart';
import 'package:move_young/features/profile/screens/profile_screen.dart';
import 'package:move_young/features/auth/screens/auth_screen.dart';
import 'package:move_young/providers/locale_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/features/matches/services/cloud_matches_provider.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:move_young/utils/logger.dart';
import 'dart:async';

// Loading state for events
enum _LoadState { idle, loading, success, error }

class HomeScreenNew extends ConsumerStatefulWidget {
  const HomeScreenNew({super.key});

  @override
  ConsumerState<HomeScreenNew> createState() => _HomeScreenNewState();
}

class _HomeScreenNewState extends ConsumerState<HomeScreenNew> {
  List<Event> events = [];
  _LoadState _state = _LoadState.idle;
  int _pendingInvites = 0;
  StreamSubscription<int>? _invitesSub;
  bool _didInit = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _refreshInvites();
    // Watch real-time pending invites count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watchPendingInvites();
    });
    // Prevent scrolling by keeping scroll position at 0
    // The NotificationListener handles blocking scroll updates,
    // but this is a backup to ensure position stays at 0
    _scrollController.addListener(() {
      if (_scrollController.hasClients && _scrollController.offset > 0) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      _fetch();
    }
  }

  @override
  void dispose() {
    _invitesSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final currentLang = context.locale.languageCode;

    // Check if events are already cached
    final cachedEventsAsync = ref.read(cachedEventsProvider(currentLang));

    if (cachedEventsAsync.hasValue &&
        cachedEventsAsync.valueOrNull?.isNotEmpty == true) {
      // Use cached events immediately
      final cachedEvents = cachedEventsAsync.value!;
      if (!mounted) return;
      setState(() {
        events = cachedEvents;
        _state = _LoadState.success;
      });
      return;
    }

    // No cache available - load events
    setState(() => _state = _LoadState.loading);
    try {
      final eventsService = ref.read(eventsServiceProvider);
      final loaded = await eventsService.loadEvents(
        lang: currentLang,
      );
      if (!mounted) return;
      setState(() {
        events = loaded;
        _state = _LoadState.success;
      });
    } catch (e, st) {
      assert(() {
        NumberedLogger.e('Events load failed: $e\n$st');
        return true;
      }());
      if (!mounted) return;
      setState(() => _state = _LoadState.error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('events_load_failed'.tr())));
    }
  }

  Future<void> _refreshInvites() async {
    try {
      final cloudMatchesService = ref.read(cloudMatchesServiceProvider);
      final invited =
          await cloudMatchesService.getInvitedMatchesForCurrentUser();
      if (!mounted) return;
      setState(() => _pendingInvites = invited.length);
    } catch (e, stack) {
      NumberedLogger.e('Error refreshing invites: $e');
      NumberedLogger.d('Stack trace: $stack');
    }
  }

  void _watchPendingInvites() {
    _invitesSub?.cancel();
    try {
      final cloudMatchesService = ref.read(cloudMatchesServiceProvider);
      _invitesSub = cloudMatchesService.watchPendingInvitesCount().listen(
        (n) {
          if (!mounted) return;
          setState(() => _pendingInvites = n);
        },
        onError: (error) {
          NumberedLogger.e('Error watching pending invites: $error');
          // Optionally refresh on error
          if (mounted) {
            _refreshInvites();
          }
        },
        cancelOnError: true,
      );
    } catch (e, stack) {
      NumberedLogger.e('Error setting up invite watcher: $e');
      NumberedLogger.d('Stack trace: $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state using Riverpod
    final authAsync = ref.watch(currentUserProvider);

    return authAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.white,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        backgroundColor: AppColors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Auth Error: $error'),
              ElevatedButton(
                onPressed: () => ref.invalidate(currentUserProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          return const WelcomeScreen();
        }
        return _buildAuthenticatedHome(user);
      },
    );
  }

  Widget _buildAuthenticatedHome(User user) {
    final isSignedIn = ref.watch(isSignedInProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.person_outline, color: AppColors.blackIcon),
          onPressed: () => _showUserMenu(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('SMARTPLAYER'),
            const SizedBox(width: 8),
            Image.asset(
              'assets/images/logo.jpg',
              height: 24,
              width: 24,
              fit: BoxFit.contain,
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.language),
            label: Text(
              context.locale.languageCode == 'nl' ? 'EN' : 'NL',
              style: AppTextStyles.body,
            ),
            onPressed: () async {
              final haptics = ref.read(hapticsServiceProvider);
              haptics?.lightImpact();
              final curr = context.locale;
              final newLocale = curr.languageCode == 'nl'
                  ? const Locale('en')
                  : const Locale('nl');
              await context.setLocale(newLocale);
              // Persist via LocaleController once prefs are ready
              try {
                final ctrl = ref.read(localeControllerProvider);
                await ctrl.saveLocale(newLocale);
              } catch (e) {
                NumberedLogger.e('Error saving locale: $e');
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.blackIcon),
          ),
        ],
      ),
      floatingActionButton: !isSignedIn
          ? FloatingActionButton(
              onPressed: () => _showUserBottomSheet(context),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.person_add, color: Colors.white),
            )
          : null,
      body: SafeArea(
        top: false, // AppBar covers the top inset already
        child: RefreshIndicator(
          onRefresh: () async {
            await _fetch();
            if (mounted) {
              try {
                final h = ref.read(hapticsServiceProvider);
                await h?.mediumImpact();
              } catch (e) {
                NumberedLogger.w('Error triggering haptic feedback: $e');
              }
            }
          },
          child: NotificationListener<ScrollUpdateNotification>(
            onNotification: (notification) {
              // Block scroll updates to prevent scrolling
              // But allow overscroll notifications for RefreshIndicator
              if (notification.scrollDelta != null &&
                  notification.scrollDelta != 0) {
                // Only block if trying to scroll down (positive delta)
                // Allow negative delta (overscroll up) for RefreshIndicator
                if (notification.scrollDelta! > 0) {
                  return true; // Consume to prevent scrolling down
                }
              }
              return false;
            },
            child: ListView(
              controller: _scrollController,
              physics: const ClampingScrollPhysics(),
              padding: AppPaddings.symmHorizontalReg.copyWith(
                bottom: kBottomNavigationBarHeight +
                    MediaQuery.of(context).padding.bottom +
                    16,
              ),
              children: [
                // Outer white container with rounded corners & shadow
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.container),
                    boxShadow: AppShadows.md,
                  ),
                  padding: AppPaddings.allBig.copyWith(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HomeGreeting(ref),
                      const SizedBox(height: AppHeights.reg),
                      SizedBox(
                        height: 168,
                        child: _FitnessFieldsTile(
                          onTap: () {
                            final haptics = ref.read(hapticsServiceProvider);
                            haptics?.lightImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ActivitiesScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppHeights.huge),
                      _QuickTilesRow(
                        pendingInvites: _pendingInvites,
                        ref: ref,
                        onTapOrganize: () {
                          final haptics = ref.read(hapticsServiceProvider);
                          haptics?.lightImpact();
                          if (!isSignedIn) {
                            _showUserBottomSheet(context,
                                showSignInPrompt: true);
                            return;
                          }
                          Navigator.of(context).pushNamed('/organize-match');
                        },
                        onTapJoin: () async {
                          ref.read(hapticsActionsProvider)?.lightImpact();
                          await Navigator.of(
                            context,
                          ).pushNamed('/discover-matches');
                          if (mounted) {
                            await _refreshInvites();
                          }
                        },
                      ),
                      const SizedBox(height: AppHeights.huge),
                      _UpcomingEventsCard(
                        state: _state,
                        events: events,
                        ref: ref,
                        onRetry: _fetch,
                        onSeeAll: () {
                          final haptics = ref.read(hapticsServiceProvider);
                          haptics?.selectionClick();
                          MainScaffold.maybeOf(
                            context,
                          )?.switchToTab(kTabAgenda, popToRoot: true);
                        },
                        onEventTap: (event) {
                          final haptics = ref.read(hapticsServiceProvider);
                          haptics?.selectionClick();
                          MainScaffold.maybeOf(context)?.handleRouteIntent(
                            AgendaIntent(highlightEventTitle: event.title),
                          );
                        },
                      ),
                      const SizedBox(height: AppHeights.huge),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserMenu(BuildContext context) {
    // Always use bottom sheet for consistency and better UX
    _showUserBottomSheet(context);
  }

  void _showUserBottomSheet(
    BuildContext context, {
    bool showSignInPrompt = false,
  }) {
    final isSignedIn = ref.read(isSignedInProvider);
    final userAsync = ref.read(currentUserProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                decoration: BoxDecoration(
                  color: AppColors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Optional prompt (shown above header)
              if (showSignInPrompt)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 24, right: 24),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'please_sign_in_to_organize'.tr(),
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // User Header
              if (isSignedIn)
                Builder(
                  builder: (_) {
                    final user = userAsync.value;
                    final profileAsync = ref.watch(currentUserProfileProvider);
                    final email = user?.email ?? '';

                    // Get displayName from database profile, fallback to Firebase Auth
                    final displayName = profileAsync.when(
                      data: (profile) {
                        if (profile != null && profile['displayName'] != null) {
                          final dbName =
                              profile['displayName'].toString().trim();
                          if (dbName.isNotEmpty) return dbName;
                        }
                        return user?.displayName ?? user?.email ?? 'User';
                      },
                      loading: () => user?.displayName ?? user?.email ?? 'User',
                      error: (_, __) =>
                          user?.displayName ?? user?.email ?? 'User',
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Hero(
                            tag: 'avatar-${user?.uid ?? 'me'}',
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: AppTextStyles.h3.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.blackText,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email.isNotEmpty ? email : 'user@example.com',
                                  style: AppTextStyles.body.copyWith(
                                    color: AppColors.grey,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            color: AppColors.grey,
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.grey,
                        child: const Icon(
                          Icons.person_outline,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'guest_user'.tr(),
                              style: AppTextStyles.h3.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.blackText,
                              ),
                            ),
                            Text(
                              'guest_prompt'.tr(),
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: AppColors.grey,
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1, color: AppColors.lightgrey),

              // Menu Items
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    if (isSignedIn) ...[
                      // Authenticated user menu
                      _buildBottomSheetButton(
                        icon: Icons.person_2_outlined,
                        label: 'profile'.tr(),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        },
                      ),
                      _buildBottomSheetButton(
                        icon: Icons.settings_outlined,
                        label: 'settings'.tr(),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildBottomSheetButton(
                        icon: Icons.help_outline_rounded,
                        label: 'help_title'.tr(),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HelpScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildBottomSheetButton(
                        icon: Icons.logout_rounded,
                        label: 'sign_out'.tr(),
                        onTap: () async {
                          Navigator.of(context).pop();
                          try {
                            await ref.read(authActionsProvider).signOut();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('sign_out_failed'.tr())),
                              );
                            }
                          }
                        },
                        isDestructive: true,
                      ),
                    ] else ...[
                      // Anonymous user menu
                      _buildBottomSheetButton(
                        icon: Icons.login,
                        label: 'auth_signin'.tr(),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AuthScreen(
                                startWithRegistration: false,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildBottomSheetButton(
                        icon: Icons.person_add,
                        label: 'auth_signup'.tr(),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AuthScreen(startWithRegistration: true),
                            ),
                          );
                        },
                        isSecondary: true,
                      ),
                    ],
                  ],
                ),
              ),

              // Bottom padding
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheetButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool isSecondary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive
                    ? Colors.red.shade600
                    : isSecondary
                        ? AppColors.grey
                        : AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    color: isDestructive
                        ? Colors.red.shade600
                        : isSecondary
                            ? AppColors.grey
                            : AppColors.blackText,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Extracted small widgets for better composition ---

class _HomeGreeting extends ConsumerWidget {
  const _HomeGreeting(this.ref);
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use Riverpod for auth state
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Text('...', style: AppTextStyles.title),
      error: (_, __) => Text('hello_generic'.tr(), style: AppTextStyles.title),
      data: (user) {
        if (user == null) {
          return Text('hello_generic'.tr(), style: AppTextStyles.title);
        }
        final name = user.displayName ?? user.email ?? 'User';
        return Text(
          'hello_name'.tr(namedArgs: {'name': name}),
          style: AppTextStyles.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class _QuickTilesRow extends ConsumerWidget {
  final int pendingInvites;
  final VoidCallback onTapOrganize;
  final VoidCallback onTapJoin;
  final WidgetRef ref;

  const _QuickTilesRow({
    required this.pendingInvites,
    required this.onTapOrganize,
    required this.onTapJoin,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 168,
            child: _HomeImageTile(
              image: const AssetImage('assets/images/organize_a_match.jpg'),
              title: 'organize_a_match'.tr(),
              subtitle: 'start_a_match'.tr(),
              onTap: onTapOrganize,
            ),
          ),
        ),
        const SizedBox(width: AppWidths.regular),
        Expanded(
          child: SizedBox(
            height: 168,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _HomeImageTile(
                  image: const AssetImage('assets/images/join_a_game.jpg'),
                  title: 'join_a_match'.tr(),
                  subtitle: 'choose_a_match'.tr(),
                  onTap: onTapJoin,
                ),
                if (pendingInvites > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: _InvitesBadge(count: pendingInvites),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InvitesBadge extends StatelessWidget {
  final int count;
  const _InvitesBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: EdgeInsets.symmetric(horizontal: count < 10 ? 0 : 6),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _UpcomingEventsCard extends ConsumerWidget {
  final _LoadState state;
  final List<Event> events;
  final VoidCallback onRetry;
  final VoidCallback onSeeAll;
  final ValueChanged<Event>? onEventTap;
  final WidgetRef ref;

  const _UpcomingEventsCard({
    required this.state,
    required this.events,
    required this.onRetry,
    required this.onSeeAll,
    this.onEventTap,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppPaddings.allSmall,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'upcoming_events'.tr(),
                      style: AppTextStyles.smallCardTitle,
                    ),
                    const SizedBox(height: AppHeights.superSmall),
                    Text('join_sports_event'.tr(), style: AppTextStyles.small),
                  ],
                ),
                if (state == _LoadState.success && events.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: AppPaddings.symmHorizontalSmall,
                    ),
                    onPressed: onSeeAll,
                    child: Text('see_all'.tr(), style: AppTextStyles.small),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.lightgrey),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _buildStatefulContent(context),
          ),
          const SizedBox(height: AppHeights.huge),
        ],
      ),
    );
  }

  Widget _buildStatefulContent(BuildContext context) {
    switch (state) {
      case _LoadState.loading:
        return const Padding(
          padding: AppPaddings.allMedium,
          child: _EventsSkeleton(),
        );
      case _LoadState.error:
        return Padding(
          padding: AppPaddings.allMedium,
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.grey),
              const SizedBox(width: AppWidths.small),
              Expanded(
                child: Text(
                  'events_load_failed'.tr(),
                  style: AppTextStyles.bodyMuted,
                ),
              ),
              TextButton(onPressed: onRetry, child: Text('retry'.tr())),
            ],
          ),
        );
      case _LoadState.success:
      case _LoadState.idle:
        if (events.isEmpty) {
          return Padding(
            padding: AppPaddings.allMedium,
            child: Row(
              children: [
                const Icon(Icons.inbox, color: AppColors.grey),
                const SizedBox(width: AppWidths.small),
                Expanded(
                  child: Text(
                    'no_upcoming_events'.tr(),
                    style: AppTextStyles.bodyMuted,
                  ),
                ),
              ],
            ),
          );
        }
        // Calculate responsive height based on screen size
        // Use ~22% of screen height, with min 180 and max 240
        // Reduced to ensure bottom boundary is visible
        final screenHeight = MediaQuery.of(context).size.height;
        final calculatedHeight = (screenHeight * 0.22).clamp(180.0, 240.0);

        return SizedBox(
          height: calculatedHeight,
          child: ListView.separated(
            primary: false,
            physics: const BouncingScrollPhysics(),
            padding: AppPaddings.bottomMedium,
            itemCount: events.length,
            separatorBuilder: (_, __) => const Padding(
              padding: AppPaddings.symmHorizontalMedium,
              child: Divider(height: 1, color: AppColors.grey),
            ),
            itemBuilder: (context, index) {
              final e = events[index];
              return ListTile(
                contentPadding: AppPaddings.symmHorizontalMedium,
                leading: const Icon(Icons.event),
                title: Text(
                  e.title,
                  style: AppTextStyles.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: AppPaddings.topSuperSmall,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: AppColors.grey,
                          ),
                          const SizedBox(width: AppWidths.small),
                          Expanded(
                            child: Text(
                              e.dateTime,
                              style: AppTextStyles.small,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.group,
                            size: 14,
                            color: AppColors.grey,
                          ),
                          const SizedBox(width: AppWidths.small),
                          Expanded(
                            child: Text(
                              e.targetGroup,
                              style: AppTextStyles.small,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.grey,
                          ),
                          const SizedBox(width: AppWidths.small),
                          Expanded(
                            child: Text(
                              e.location,
                              style: AppTextStyles.small,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.euro,
                            size: 14,
                            color: AppColors.grey,
                          ),
                          const SizedBox(width: AppWidths.small),
                          Expanded(
                            child: Text(
                              e.cost,
                              style: AppTextStyles.smallMuted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ref.read(hapticsActionsProvider)?.selectionClick();
                  onEventTap?.call(e);
                },
              );
            },
          ),
        );
    }
  }
}

class _EventsSkeleton extends StatelessWidget {
  const _EventsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(children: [_buildSkeletonItem(), _buildSkeletonItem()]);
  }

  Widget _buildSkeletonItem() {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.lightgrey,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      title: Container(
        height: 16,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.lightgrey,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 12,
            width: double.infinity * 0.6,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: AppColors.lightgrey,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Container(
            height: 12,
            width: double.infinity * 0.5,
            decoration: BoxDecoration(
              color: AppColors.lightgrey,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FitnessFieldsTile extends StatelessWidget {
  final VoidCallback onTap;

  const _FitnessFieldsTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.md,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        shadowColor: AppColors.blackShadow,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                flex: 2,
                child: Ink.image(
                  image: const AssetImage('assets/images/fitness_circus.jpg'),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Flexible(
                flex: 1,
                child: Padding(
                  padding: AppPaddings.symmMedium,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'check_for_fields'.tr(),
                        style: AppTextStyles.smallCardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'discover_closest_fitness'.tr(),
                        style: AppTextStyles.superSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeImageTile extends StatelessWidget {
  final ImageProvider image;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeImageTile({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.md,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        elevation: 4,
        shadowColor: AppColors.blackShadow,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                flex: 2,
                child: Ink.image(
                  image: image,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Flexible(
                flex: 1,
                child: Padding(
                  padding: AppPaddings.symmMedium,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.smallCardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.superSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
