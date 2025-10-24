// lib/screens/home/home_screen_migrated.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/models/external/event_model.dart';
import 'package:move_young/services/load_events_from_json.dart';
import 'package:move_young/services/auth/auth_provider.dart';
import 'package:move_young/services/games/cloud_games_provider.dart' as cloud;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/screens/welcome/welcome_screen.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/screens/profile/profile_screen.dart';
import 'package:move_young/screens/friends/friends_screen.dart';
import 'package:move_young/services/error_handler_service.dart';
import 'package:move_young/services/cache/image_cache_provider.dart';
import 'package:move_young/widgets/common/retry_error_view.dart';
import 'package:move_young/screens/main_scaffold.dart';

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

  @override
  void initState() {
    super.initState();
    _fetch();
    // Preload images
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(imageCacheServiceProvider)
          .preloadImages(context, ['assets/images/general_public.jpg']);
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
      ErrorHandlerService.logError(e, st);
      if (!mounted) return;
      setState(() => _state = _LoadState.error);
      ErrorHandlerService.showError(context, e, onRetry: _fetch);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state reactively
    final authAsync = ref.watch(currentUserProvider);

    return Scaffold(
      body: authAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Authentication Error: $error'),
              ElevatedButton(
                onPressed: () => ref.invalidate(currentUserProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (user) {
          if (user == null) {
            return const WelcomeScreen();
          }

          return _buildAuthenticatedContent(user);
        },
      ),
    );
  }

  Widget _buildAuthenticatedContent(User user) {
    return Scaffold(
      body: _buildBody(user),
      bottomNavigationBar: _buildBottomNavigationBar(user),
    );
  }

  Widget _buildBody(User user) {
    switch (_state) {
      case _LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadState.error:
        return RetryErrorView(onRetry: _fetch);
      case _LoadState.success:
        return _buildEventsList(user);
      case _LoadState.idle:
        return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildEventsList(User user) {
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWelcomeSection(user),
          const SizedBox(height: 24),
          _buildQuickActions(user),
          const SizedBox(height: 24),
          _buildEventsSection(),
          const SizedBox(height: 24),
          _buildPendingInvitesSection(),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(User user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'welcome_back'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user.displayName ?? user.email ?? 'User',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'home_subtitle'.tr(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(User user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'quick_actions'.tr(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.sports_soccer,
                title: 'join_game'.tr(),
                subtitle: 'find_nearby_games'.tr(),
                onTap: () {
                  HapticFeedback.lightImpact();
                  // Navigate to games tab
                  final mainScaffold = MainScaffold.maybeOf(context);
                  mainScaffold?.switchToTab(2); // kTabJoin
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_circle_outline,
                title: 'organize_game'.tr(),
                subtitle: 'create_new_game'.tr(),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pushNamed(context, '/organize-game');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 32,
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'upcoming_events'.tr(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...events.take(3).map((event) => _buildEventCard(event)),
        if (events.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: TextButton(
                onPressed: () {
                  // Navigate to agenda tab
                  final mainScaffold = MainScaffold.maybeOf(context);
                  mainScaffold?.switchToTab(3); // kTabAgenda
                },
                child: Text('view_all_events'.tr()),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEventCard(Event event) {
    // Parse the date from the event's dateTime string
    String dayText = '?';
    try {
      // Try to extract day from dateTime string
      final dateTimeParts = event.dateTime.split(' ');
      if (dateTimeParts.isNotEmpty) {
        final datePart = dateTimeParts[0];
        final dayMatch = RegExp(r'\d{1,2}').firstMatch(datePart);
        if (dayMatch != null) {
          dayText = dayMatch.group(0)!;
        }
      }
    } catch (e) {
      // Fallback to '?' if parsing fails
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Text(
            dayText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(event.title),
        subtitle: Text(
          event.location.isNotEmpty
              ? event.location
              : event.targetGroup.isNotEmpty
                  ? event.targetGroup
                  : 'event_no_description'.tr(),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Navigate to event details
        },
      ),
    );
  }

  Widget _buildPendingInvitesSection() {
    // Watch pending invites count reactively
    final pendingInvitesAsync = ref.watch(cloud.pendingInvitesCountProvider);

    return pendingInvitesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (pendingInvites) {
        if (pendingInvites == 0) return const SizedBox.shrink();

        return Card(
          color: AppColors.primary.withValues(alpha: 0.1),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                pendingInvites.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text('pending_invites'.tr()),
            subtitle: Text('you_have_invites'.tr()),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to games tab
              final mainScaffold = MainScaffold.maybeOf(context);
              mainScaffold?.switchToTab(2); // kTabJoin
            },
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(User user) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: 0, // Home tab is active
      onTap: (index) {
        switch (index) {
          case 0:
            // Home - already here
            break;
          case 1:
            // Navigate to games tab
            final mainScaffold = MainScaffold.maybeOf(context);
            mainScaffold?.switchToTab(2); // kTabJoin
            break;
          case 2:
            // Navigate to agenda tab
            final mainScaffold = MainScaffold.maybeOf(context);
            mainScaffold?.switchToTab(3); // kTabAgenda
            break;
          case 3:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FriendsScreen()),
            );
            break;
          case 4:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
            break;
        }
      },
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.home),
          label: 'home'.tr(),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.sports_soccer),
          label: 'games'.tr(),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.calendar_today),
          label: 'agenda'.tr(),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.people),
          label: 'friends'.tr(),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.person),
          label: 'profile'.tr(),
        ),
      ],
    );
  }
}
