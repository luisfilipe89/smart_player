import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:move_young/services/haptics_service.dart';
import 'package:move_young/models/event_model.dart';
import 'package:move_young/services/load_events_from_json.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/screens/welcome/welcome_screen.dart';
import 'package:move_young/screens/auth/auth_screen.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/screens/main_scaffold.dart'; // MainScaffold & kTabAgenda
import 'package:move_young/screens/settings/settings_screen.dart';
import 'package:move_young/screens/help/help_screen.dart';
import 'package:move_young/screens/maps/profile_screen.dart';
import 'package:move_young/screens/friends/friends_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/services/cloud_games_service.dart';
import 'dart:async';

// Loading state for events
enum _LoadState { idle, loading, success, error }

class HomeScreenNew extends StatefulWidget {
  const HomeScreenNew({super.key});

  @override
  State<HomeScreenNew> createState() => _HomeScreenNewState();
}

class _HomeScreenNewState extends State<HomeScreenNew> {
  List<Event> events = [];
  _LoadState _state = _LoadState.idle;
  int _pendingInvites = 0;
  StreamSubscription<int>? _invitesSub;

  @override
  void initState() {
    super.initState();
    _fetch();
    _refreshInvites();
    // Watch real-time pending invites count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watchPendingInvites();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
          const AssetImage('assets/images/general_public.jpg'), context);
    });
  }

  @override
  void dispose() {
    _invitesSub?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _state = _LoadState.loading);
    try {
      final loaded = await loadEventsFromJson();
      if (!mounted) return;
      setState(() {
        events = loaded;
        _state = _LoadState.success;
      });
    } catch (e, st) {
      assert(() {
        debugPrint('Events load failed: $e\n$st');
        return true;
      }());
      if (!mounted) return;
      setState(() => _state = _LoadState.error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('events_load_failed'.tr())),
      );
    }
  }

  Future<void> _refreshInvites() async {
    try {
      final invited = await CloudGamesService.getInvitedGamesForCurrentUser();
      if (!mounted) return;
      setState(() => _pendingInvites = invited.length);
    } catch (_) {}
  }

  void _watchPendingInvites() {
    _invitesSub?.cancel();
    try {
      _invitesSub = CloudGamesService.watchPendingInvitesCount().listen((n) {
        if (!mounted) return;
        setState(() => _pendingInvites = n);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: AppColors.white,
          appBar: AppBar(
            backgroundColor: AppColors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.account_circle_outlined,
                color: AppColors.blackIcon,
              ),
              onPressed: () => _showUserMenu(context),
            ),
            title: const Text('SMARTPLAYER'),
            centerTitle: true,
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.language),
                label: Text(
                  context.locale.languageCode == 'nl' ? 'EN' : 'NL',
                  style: AppTextStyles.body,
                ),
                onPressed: () {
                  HapticsService.lightImpact();
                  final curr = context.locale;
                  context.setLocale(
                    curr.languageCode == 'nl'
                        ? const Locale('en')
                        : const Locale('nl'),
                  );
                },
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.blackIcon),
              ),
            ],
          ),
          floatingActionButton: !AuthService.isSignedIn
              ? FloatingActionButton(
                  onPressed: () => _showUserBottomSheet(context),
                  backgroundColor: AppColors.primary,
                  child: const Icon(
                    Icons.person_add,
                    color: Colors.white,
                  ),
                )
              : null,
          body: SafeArea(
            top: false, // AppBar covers the top inset already
            child: RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                      children: [
                        const _HomeGreeting(),
                        const SizedBox(height: AppHeights.small),
                        const _ActivitiesCard(),
                        const SizedBox(height: AppHeights.huge),
                        _QuickTilesRow(
                          pendingInvites: _pendingInvites,
                          onTapOrganize: () {
                            HapticsService.lightImpact();
                            if (!AuthService.isSignedIn) {
                              _showUserBottomSheet(context,
                                  showSignInPrompt: true);
                              return;
                            }
                            Navigator.of(context).pushNamed('/organize-game');
                          },
                          onTapJoin: () async {
                            HapticFeedback.lightImpact();
                            await Navigator.of(context)
                                .pushNamed('/discover-games');
                            if (mounted) {
                              await _refreshInvites();
                            }
                          },
                        ),
                        const SizedBox(height: AppHeights.huge),
                        _UpcomingEventsCard(
                          state: _state,
                          events: events,
                          onRetry: _fetch,
                          onSeeAll: () {
                            HapticsService.selectionClick();
                            MainScaffold.maybeOf(context)
                                ?.switchToTab(kTabAgenda, popToRoot: true);
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
        );
      },
    );
  }

  void _showUserMenu(BuildContext context) {
    // Always use bottom sheet for consistency and better UX
    _showUserBottomSheet(context);
  }

  void _showUserBottomSheet(BuildContext context,
      {bool showSignInPrompt = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                margin: const EdgeInsets.symmetric(vertical: 12),
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
              if (AuthService.isSignedIn) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          AuthService.currentUserDisplayName.isNotEmpty
                              ? AuthService.currentUserDisplayName[0]
                                  .toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AuthService.currentUserDisplayName.isNotEmpty
                                  ? AuthService.currentUserDisplayName
                                  : 'User',
                              style: AppTextStyles.h3.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.blackText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AuthService.currentUser?.email?.isNotEmpty == true
                                  ? AuthService.currentUser!.email!
                                  : 'user@example.com',
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
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.lightgrey),
              ] else ...[
                // Anonymous user header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.lightgrey),
              ],

              // Menu Items
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    if (AuthService.isSignedIn) ...[
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
                        icon: Icons.people_outline,
                        label: 'friends'.tr(),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const FriendsScreen(),
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
                          await AuthService.signOut();
                          if (context.mounted) {
                            Navigator.of(context, rootNavigator: true)
                                .pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const WelcomeScreen(),
                              ),
                              (route) => false,
                            );
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
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AuthScreen(
                                  startWithRegistration: false),
                            ),
                          );
                          if (result == true && context.mounted) {
                            setState(() {}); // Refresh the UI
                          }
                        },
                      ),
                      _buildBottomSheetButton(
                        icon: Icons.person_add,
                        label: 'auth_signup'.tr(),
                        onTap: () async {
                          Navigator.of(context).pop();
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AuthScreen(startWithRegistration: true),
                            ),
                          );
                          if (result == true && context.mounted) {
                            setState(() {}); // Refresh the UI
                          }
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

// --- Skeleton widget for loading state ---
class _EventsSkeleton extends StatelessWidget {
  const _EventsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
          3,
          (i) => Padding(
                padding: AppPaddings.symmVerticalSmall,
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.superlightgrey,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: AppShadows.md,
                      ),
                    ),
                    const SizedBox(width: AppWidths.superbig),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              height: 12, color: AppColors.superlightgrey),
                          const SizedBox(height: 6),
                          Container(
                              height: 10,
                              width: 120,
                              color: AppColors.superlightgrey),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
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
                      Text(title,
                          style: AppTextStyles.smallCardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      //const SizedBox(height: 1),
                      Text(subtitle,
                          style: AppTextStyles.superSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
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

// --- Extracted small widgets for better composition ---

class _HomeGreeting extends StatelessWidget {
  const _HomeGreeting();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.userChanges,
      builder: (context, _) {
        final name = FirebaseAuth.instance.currentUser?.displayName ??
            AuthService.currentUserDisplayName;
        return Text(
          AuthService.isSignedIn
              ? 'hello_name'.tr(namedArgs: {'name': name})
              : 'hello_generic'.tr(),
          style: AppTextStyles.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class _ActivitiesCard extends StatelessWidget {
  const _ActivitiesCard();

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
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () {
            HapticsService.lightImpact();
            Navigator.of(context).pushNamed('/activities');
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Ink.image(
                image: const AssetImage('assets/images/running6.png'),
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Padding(
                padding: AppPaddings.allSmall,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('check_for_fields'.tr(),
                        style: AppTextStyles.smallCardTitle),
                    const SizedBox(height: 1),
                    Text('look_for_fields'.tr(), style: AppTextStyles.small),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickTilesRow extends StatelessWidget {
  final int pendingInvites;
  final VoidCallback onTapOrganize;
  final VoidCallback onTapJoin;

  const _QuickTilesRow({
    required this.pendingInvites,
    required this.onTapOrganize,
    required this.onTapJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 168,
            child: _HomeImageTile(
              image: const AssetImage('assets/images/games2.jpg'),
              title: 'organize_a_game'.tr(),
              subtitle: 'start_a_game'.tr(),
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
                  image: const AssetImage('assets/images/games3.jpg'),
                  title: 'join_a_game'.tr(),
                  subtitle: 'choose_a_game'.tr(),
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
        count > 99 ? '99+' : '$count',
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

class _UpcomingEventsCard extends StatelessWidget {
  final _LoadState state;
  final List<Event> events;
  final VoidCallback onRetry;
  final VoidCallback onSeeAll;

  const _UpcomingEventsCard({
    required this.state,
    required this.events,
    required this.onRetry,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
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
                    Text('upcoming_events'.tr(),
                        style: AppTextStyles.smallCardTitle),
                    const SizedBox(height: AppHeights.superSmall),
                    Text('join_sports_event'.tr(), style: AppTextStyles.small),
                  ],
                ),
                if (state == _LoadState.success && events.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                        padding: AppPaddings.symmHorizontalSmall),
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
          const SizedBox(height: AppHeights.superHuge),
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
                child: Text('events_load_failed'.tr(),
                    style: AppTextStyles.bodyMuted),
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
                  child: Text('no_upcoming_events'.tr(),
                      style: AppTextStyles.bodyMuted),
                ),
              ],
            ),
          );
        }
        return SizedBox(
          height: 220,
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
                title: Text(e.title,
                    style: AppTextStyles.cardTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Padding(
                  padding: AppPaddings.topSuperSmall,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.access_time,
                            size: 14, color: AppColors.grey),
                        const SizedBox(width: AppWidths.small),
                        Expanded(
                          child: Text(e.dateTime,
                              style: AppTextStyles.small,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      Row(children: [
                        const Icon(Icons.group,
                            size: 14, color: AppColors.grey),
                        const SizedBox(width: AppWidths.small),
                        Expanded(
                          child: Text(e.targetGroup,
                              style: AppTextStyles.small,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      Row(children: [
                        const Icon(Icons.location_on,
                            size: 14, color: AppColors.grey),
                        const SizedBox(width: AppWidths.small),
                        Expanded(
                          child: Text(e.location,
                              style: AppTextStyles.small,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                      Row(children: [
                        const Icon(Icons.euro, size: 14, color: AppColors.grey),
                        const SizedBox(width: AppWidths.small),
                        Expanded(
                          child: Text(e.cost,
                              style: AppTextStyles.smallMuted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => HapticFeedback.selectionClick(),
              );
            },
          ),
        );
    }
  }
}
