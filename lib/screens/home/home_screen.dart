import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:move_young/models/event_model.dart';
import 'package:move_young/services/load_events_from_json.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/screens/welcome/welcome_screen.dart';
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
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: const Icon(Icons.menu),
        title: const Text('SMARTPLAYER'),
        centerTitle: true,
        actions: [
          // User menu button (only show if signed in)
          if (AuthService.isSignedIn)
            IconButton(
              icon: const Icon(Icons.person, color: AppColors.primary),
              onPressed: () => _showUserMenu(context),
            ),
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
            style: TextButton.styleFrom(foregroundColor: AppColors.blackIcon),
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
                    Text('hello'.tr(), style: AppTextStyles.title),
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
                          borderRadius: BorderRadius.circular(AppRadius.card),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('check_for_fields'.tr(),
                                        style: AppTextStyles.smallCardTitle),
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
                              image:
                                  const AssetImage('assets/images/games2.jpg'),
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
                              image:
                                  const AssetImage('assets/images/games3.jpg'),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('upcoming_events'.tr(),
                                        style: AppTextStyles.smallCardTitle),
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
                                        padding:
                                            AppPaddings.symmHorizontalSmall),
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
                          const Divider(height: 1, color: AppColors.lightgrey),

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
                                                style: AppTextStyles.bodyMuted),
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
                                                  style:
                                                      AppTextStyles.bodyMuted),
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
                                        physics: const BouncingScrollPhysics(),
                                        padding: AppPaddings.bottomMedium,
                                        itemCount: events.length,
                                        separatorBuilder: (_, __) =>
                                            const Padding(
                                          padding:
                                              AppPaddings.symmHorizontalMedium,
                                          child: Divider(
                                              height: 1, color: AppColors.grey),
                                        ),
                                        itemBuilder: (context, index) {
                                          final e = events[index];
                                          return ListTile(
                                            contentPadding: AppPaddings
                                                .symmHorizontalMedium,
                                            leading: const Icon(Icons.event),
                                            title: Text(
                                              e.title,
                                              style: AppTextStyles.cardTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Padding(
                                              padding:
                                                  AppPaddings.topSuperSmall,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(children: [
                                                    const Icon(
                                                        Icons.access_time,
                                                        size: 14,
                                                        color: AppColors.grey),
                                                    const SizedBox(
                                                        width: AppWidths.small),
                                                    Expanded(
                                                      child: Text(
                                                        e.dateTime,
                                                        style:
                                                            AppTextStyles.small,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ]),
                                                  Row(children: [
                                                    const Icon(Icons.group,
                                                        size: 14,
                                                        color: AppColors.grey),
                                                    const SizedBox(
                                                        width: AppWidths.small),
                                                    Expanded(
                                                      child: Text(
                                                        e.targetGroup,
                                                        style:
                                                            AppTextStyles.small,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ]),
                                                  Row(children: [
                                                    const Icon(
                                                        Icons.location_on,
                                                        size: 14,
                                                        color: AppColors.grey),
                                                    const SizedBox(
                                                        width: AppWidths.small),
                                                    Expanded(
                                                      child: Text(
                                                        e.location,
                                                        style:
                                                            AppTextStyles.small,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ]),
                                                  Row(children: [
                                                    const Icon(Icons.euro,
                                                        size: 14,
                                                        color: AppColors.grey),
                                                    const SizedBox(
                                                        width: AppWidths.small),
                                                    Expanded(
                                                      child: Text(
                                                        e.cost,
                                                        style: AppTextStyles
                                                            .smallMuted,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ]),
                                                ],
                                              ),
                                            ),
                                            trailing:
                                                const Icon(Icons.chevron_right),
                                            onTap: () =>
                                                HapticFeedback.selectionClick(),
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
  }

  void _showUserMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User info
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    AuthService.currentUserDisplayName.isNotEmpty
                        ? AuthService.currentUserDisplayName[0].toUpperCase()
                        : 'U',
                    style: AppTextStyles.h3.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AuthService.currentUserDisplayName,
                        style: AppTextStyles.h3,
                      ),
                      Text(
                        AuthService.currentUser?.email ?? '',
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

            // Sign out button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await AuthService.signOut();
                  // Navigate back to welcome screen
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const WelcomeScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign Out'),
              ),
            ),
          ],
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
