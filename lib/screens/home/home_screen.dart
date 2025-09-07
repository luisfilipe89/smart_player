import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:move_young/models/event_model.dart';
import 'package:move_young/services/load_events_from_json.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/screens/welcome/welcome_screen.dart';
import 'package:move_young/screens/auth/auth_screen.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/screens/main_scaffold.dart'; // MainScaffold & kTabAgenda

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

  @override
  void initState() {
    super.initState();
    _fetch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
          const AssetImage('assets/images/general_public.jpg'), context);
    });
  }

  @override
  void dispose() {
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
                AuthService.isSignedIn ? Icons.menu : Icons.person_outline,
                color: AuthService.isSignedIn
                    ? AppColors.blackIcon
                    : AppColors.primary,
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
                  HapticFeedback.lightImpact();
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
          body: SafeArea(
            top: false, // AppBar covers the top inset already
            child: RefreshIndicator(
              onRefresh: _fetch,
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
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
                    padding: AppPaddings.allBig.copyWith(top: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AuthService.isSignedIn
                              ? 'Hello ${AuthService.currentUserDisplayName}!'
                              : 'Hello User!',
                          style: AppTextStyles.title,
                        ),
                        const SizedBox(height: AppHeights.small),

                        // --- Activities card (ripple + haptic) ---
                        Container(
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
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.of(context).pushNamed('/activities');
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Ink.image(
                                    image: const AssetImage(
                                        'assets/images/general_public.jpg'),
                                    height: 100,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                  Padding(
                                    padding: AppPaddings.allSmall,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('check_for_fields'.tr(),
                                            style:
                                                AppTextStyles.smallCardTitle),
                                        const SizedBox(height: 1),
                                        Text('look_for_fields'.tr(),
                                            style: AppTextStyles.small),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: AppHeights.huge),

                        // --- Two quick tiles side-by-side ---
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 168,
                                child: _HomeImageTile(
                                  image: const AssetImage(
                                      'assets/images/games2.jpg'),
                                  title: 'organize_a_game'.tr(),
                                  subtitle: 'start_a_game'.tr(),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context)
                                        .pushNamed('/organize-game');
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: AppWidths.regular),
                            Expanded(
                              child: SizedBox(
                                height: 168,
                                child: _HomeImageTile(
                                  image: const AssetImage(
                                      'assets/images/games3.jpg'),
                                  title: 'join_a_game'.tr(),
                                  subtitle: 'choose_a_game'.tr(),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    Navigator.of(context)
                                        .pushNamed('/discover-games');
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppHeights.huge),

                        // --- Upcoming Events card ---
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            boxShadow: AppShadows.md,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with See all
                              Padding(
                                padding: AppPaddings.allSmall,
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('upcoming_events'.tr(),
                                            style:
                                                AppTextStyles.smallCardTitle),
                                        const SizedBox(
                                            height: AppHeights.superSmall),
                                        Text('join_sports_event'.tr(),
                                            style: AppTextStyles.small),
                                      ],
                                    ),
                                    if (_state == _LoadState.success &&
                                        events.isNotEmpty)
                                      TextButton(
                                        style: TextButton.styleFrom(
                                            padding: AppPaddings
                                                .symmHorizontalSmall),
                                        onPressed: () {
                                          HapticFeedback.selectionClick();
                                          MainScaffold.maybeOf(context)
                                              ?.switchToTab(kTabAgenda,
                                                  popToRoot: true);
                                        },
                                        child: Text('see_all'.tr(),
                                            style: AppTextStyles.small),
                                      ),
                                  ],
                                ),
                              ),
                              const Divider(
                                  height: 1, color: AppColors.lightgrey),

                              // State-driven content
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: Builder(
                                  key: ValueKey(_state),
                                  builder: (context) {
                                    switch (_state) {
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
                                              const Icon(Icons.error_outline,
                                                  color: AppColors.grey),
                                              const SizedBox(
                                                  width: AppWidths.small),
                                              Expanded(
                                                child: Text(
                                                    'events_load_failed'.tr(),
                                                    style: AppTextStyles
                                                        .bodyMuted),
                                              ),
                                              TextButton(
                                                  onPressed: _fetch,
                                                  child: Text('retry'.tr())),
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
                                                const Icon(Icons.inbox,
                                                    color: AppColors.grey),
                                                const SizedBox(
                                                    width: AppWidths.small),
                                                Expanded(
                                                  child: Text(
                                                      'no_upcoming_events'.tr(),
                                                      style: AppTextStyles
                                                          .bodyMuted),
                                                ),
                                              ],
                                            ),
                                          );
                                        }

                                        // Scrollable inner list within fixed-height viewport
                                        return SizedBox(
                                          height: 220,
                                          child: ListView.separated(
                                            primary: false,
                                            physics:
                                                const BouncingScrollPhysics(),
                                            padding: AppPaddings.bottomMedium,
                                            itemCount: events.length,
                                            separatorBuilder: (_, __) =>
                                                const Padding(
                                              padding: AppPaddings
                                                  .symmHorizontalMedium,
                                              child: Divider(
                                                  height: 1,
                                                  color: AppColors.grey),
                                            ),
                                            itemBuilder: (context, index) {
                                              final e = events[index];
                                              return ListTile(
                                                contentPadding: AppPaddings
                                                    .symmHorizontalMedium,
                                                leading:
                                                    const Icon(Icons.event),
                                                title: Text(
                                                  e.title,
                                                  style:
                                                      AppTextStyles.cardTitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                subtitle: Padding(
                                                  padding:
                                                      AppPaddings.topSuperSmall,
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(children: [
                                                        const Icon(
                                                            Icons.access_time,
                                                            size: 14,
                                                            color:
                                                                AppColors.grey),
                                                        const SizedBox(
                                                            width: AppWidths
                                                                .small),
                                                        Expanded(
                                                          child: Text(
                                                            e.dateTime,
                                                            style: AppTextStyles
                                                                .small,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ]),
                                                      Row(children: [
                                                        const Icon(Icons.group,
                                                            size: 14,
                                                            color:
                                                                AppColors.grey),
                                                        const SizedBox(
                                                            width: AppWidths
                                                                .small),
                                                        Expanded(
                                                          child: Text(
                                                            e.targetGroup,
                                                            style: AppTextStyles
                                                                .small,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ]),
                                                      Row(children: [
                                                        const Icon(
                                                            Icons.location_on,
                                                            size: 14,
                                                            color:
                                                                AppColors.grey),
                                                        const SizedBox(
                                                            width: AppWidths
                                                                .small),
                                                        Expanded(
                                                          child: Text(
                                                            e.location,
                                                            style: AppTextStyles
                                                                .small,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ]),
                                                      Row(children: [
                                                        const Icon(Icons.euro,
                                                            size: 14,
                                                            color:
                                                                AppColors.grey),
                                                        const SizedBox(
                                                            width: AppWidths
                                                                .small),
                                                        Expanded(
                                                          child: Text(
                                                            e.cost,
                                                            style: AppTextStyles
                                                                .smallMuted,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ]),
                                                    ],
                                                  ),
                                                ),
                                                trailing: const Icon(
                                                    Icons.chevron_right),
                                                onTap: () => HapticFeedback
                                                    .selectionClick(),
                                              );
                                            },
                                          ),
                                        );
                                    }
                                  },
                                ),
                              ),

                              const SizedBox(height: AppHeights.superHuge),
                            ],
                          ),
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
    if (AuthService.isSignedIn) {
      // Show slide-in drawer for authenticated users
      _showAuthenticatedDrawer(context);
    } else {
      // Show bottom sheet for anonymous users
      _showAnonymousBottomSheet(context);
    }
  }

  void _showAuthenticatedDrawer(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final drawerWidth =
            screenWidth * 0.6; // 60% of screen width to match image

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          )),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: drawerWidth,
              height: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(2, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User info section
                          if (AuthService.isSignedIn) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.transparent,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.grey,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            // Anonymous user section
                            Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Row(
                                children: [
                                  Text(
                                    'Guest User',
                                    style: AppTextStyles.h3.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.transparent,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.grey,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Menu options
                          if (AuthService.isSignedIn) ...[
                            // Signed in user options
                            _buildMenuButton(
                              icon: Icons.settings,
                              label: 'Profile Settings',
                              onTap: () {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Profile settings coming soon!'),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildMenuButton(
                              icon: Icons.logout,
                              label: 'Sign Out',
                              onTap: () async {
                                Navigator.of(context).pop();
                                await AuthService.signOut();
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const WelcomeScreen(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              },
                              isDestructive: true,
                            ),
                          ] else ...[
                            // Anonymous user options
                            _buildMenuButton(
                              icon: Icons.login,
                              label: 'Sign In',
                              onTap: () async {
                                Navigator.of(context).pop();
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const AuthScreen(),
                                  ),
                                );
                                if (result == true && context.mounted) {
                                  setState(() {}); // Refresh the UI
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildMenuButton(
                              icon: Icons.person_add,
                              label: 'Create Account',
                              onTap: () async {
                                Navigator.of(context).pop();
                                final result = await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const AuthScreen(),
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAnonymousBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Anonymous user section
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.grey,
                  child: const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guest User',
                        style: AppTextStyles.h3,
                      ),
                      Text(
                        'Sign in to sync your data',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Anonymous user options
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AuthScreen(),
                    ),
                  );
                  if (result == true && context.mounted) {
                    setState(() {}); // Refresh the UI
                  }
                },
                icon: const Icon(Icons.login),
                label: const Text('Sign In'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AuthScreen(),
                    ),
                  );
                  if (result == true && context.mounted) {
                    setState(() {}); // Refresh the UI
                  }
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Create Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red : AppColors.grey,
                size: 20,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  color: isDestructive ? Colors.red : AppColors.blackText,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
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
