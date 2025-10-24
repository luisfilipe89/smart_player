// lib/screens/friends/friends_screen_migrated.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:move_young/providers/services/auth_provider.dart';
import 'package:move_young/providers/services/friends_provider.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/theme/app_back_button.dart';
import 'package:shimmer/shimmer.dart';
import 'package:move_young/screens/friends/qr_scanner_screen.dart';
import 'package:move_young/screens/friends/email_input_screen.dart';
import 'package:move_young/screens/friends/qr_sharing_screen.dart';

// Helper: modern floating SnackBar with icon
void showFloatingSnack(
  BuildContext context, {
  required String message,
  required Color backgroundColor,
  required IconData icon,
  Duration duration = const Duration(seconds: 2),
}) {
  final snack = SnackBar(
    content: Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ],
    ),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    backgroundColor: backgroundColor,
    duration: duration,
  );
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(snack);
}

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Ensure indexes for discovery
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(friendsActionsProvider).ensureUserIndexes();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch current user ID reactively
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 48,
        leading: const AppBackButton(goHome: true),
        title: Text('friends'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            color: AppColors.primary,
            onPressed: _showAddFriendSheet,
            tooltip: 'friends_add_title'.tr(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: 'friends_list'.tr()),
                      Tab(text: 'friend_requests'.tr()),
                    ],
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppColors.primary,
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildFriendsList(currentUserId),
                        _buildFriendRequests(currentUserId),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendsList(String? currentUserId) {
    if (currentUserId == null) {
      return const Center(child: Text('Please sign in to view friends'));
    }

    // Watch friends list reactively
    final friendsAsync = ref.watch(friendsListProvider);

    return friendsAsync.when(
      loading: () => _buildLoadingShimmer(),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading friends: $error'),
            ElevatedButton(
              onPressed: () => ref.invalidate(friendsListProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (friends) {
        if (friends.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(friendsListProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friendId = friends[index];
              return _buildFriendCard(friendId);
            },
          ),
        );
      },
    );
  }

  Widget _buildFriendRequests(String? currentUserId) {
    if (currentUserId == null) {
      return const Center(
          child: Text('Please sign in to view friend requests'));
    }

    // Watch friend requests received reactively
    final friendRequestsAsync = ref.watch(friendRequestsReceivedProvider);

    return friendRequestsAsync.when(
      loading: () => _buildLoadingShimmer(),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading friend requests: $error'),
            ElevatedButton(
              onPressed: () => ref.invalidate(friendRequestsReceivedProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (friendRequests) {
        if (friendRequests.isEmpty) {
          return _buildEmptyRequestsState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(friendRequestsReceivedProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: friendRequests.length,
            itemBuilder: (context, index) {
              final friendId = friendRequests[index];
              return _buildFriendRequestCard(friendId);
            },
          ),
        );
      },
    );
  }

  Widget _buildFriendCard(String friendId) {
    // Watch friend profile reactively
    final friendProfileAsync = ref.watch(
      FutureProvider.autoDispose<Map<String, String?>>((ref) async {
        return await ref
            .read(friendsActionsProvider)
            .fetchMinimalProfile(friendId);
      }),
    );

    return friendProfileAsync.when(
      loading: () => _buildFriendCardShimmer(),
      error: (_, __) => const SizedBox.shrink(),
      data: (profile) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: profile['photoURL'] != null
                  ? CachedNetworkImageProvider(profile['photoURL']!)
                  : null,
              child: profile['photoURL'] == null
                  ? Text(
                      profile['displayName']?.substring(0, 1).toUpperCase() ??
                          '?')
                  : null,
            ),
            title: Text(profile['displayName'] ?? 'Unknown'),
            subtitle: Text('Friend'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'remove':
                    _removeFriend(friendId);
                    break;
                  case 'block':
                    _blockFriend(friendId);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'remove',
                  child: Text('remove_friend'.tr()),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Text('block_friend'.tr()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFriendRequestCard(String friendId) {
    // Watch friend profile reactively
    final friendProfileAsync = ref.watch(
      FutureProvider.autoDispose<Map<String, String?>>((ref) async {
        return await ref
            .read(friendsActionsProvider)
            .fetchMinimalProfile(friendId);
      }),
    );

    return friendProfileAsync.when(
      loading: () => _buildFriendCardShimmer(),
      error: (_, __) => const SizedBox.shrink(),
      data: (profile) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: profile['photoURL'] != null
                  ? CachedNetworkImageProvider(profile['photoURL']!)
                  : null,
              child: profile['photoURL'] == null
                  ? Text(
                      profile['displayName']?.substring(0, 1).toUpperCase() ??
                          '?')
                  : null,
            ),
            title: Text(profile['displayName'] ?? 'Unknown'),
            subtitle: Text('wants_to_be_friends'.tr()),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _acceptFriendRequest(friendId),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _declineFriendRequest(friendId),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.grey[300]),
            title: Container(
              height: 16,
              color: Colors.grey[300],
            ),
            subtitle: Container(
              height: 12,
              color: Colors.grey[300],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFriendCardShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: Colors.grey[300]),
          title: Container(
            height: 16,
            color: Colors.grey[300],
          ),
          subtitle: Container(
            height: 12,
            color: Colors.grey[300],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'no_friends_yet'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'add_friends_to_get_started'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddFriendSheet,
              icon: const Icon(Icons.person_add),
              label: Text('add_friends'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRequestsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'no_friend_requests'.tr(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'friend_requests_will_appear_here'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFriendSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddFriendSheet(),
    );
  }

  Widget _buildAddFriendSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'add_friends'.tr(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _buildAddFriendOption(
              icon: Icons.qr_code,
              title: 'scan_qr_code'.tr(),
              subtitle: 'scan_friend_qr_code'.tr(),
              onTap: _showQRScanner,
            ),
            const SizedBox(height: 16),
            _buildAddFriendOption(
              icon: Icons.email,
              title: 'add_by_email'.tr(),
              subtitle: 'enter_friend_email'.tr(),
              onTap: _showEmailInput,
            ),
            const SizedBox(height: 16),
            _buildAddFriendOption(
              icon: Icons.share,
              title: 'share_my_qr'.tr(),
              subtitle: 'share_qr_code_with_friends'.tr(),
              onTap: _shareMyQR,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFriendOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showQRScanner() {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );
  }

  void _showEmailInput() {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmailInputScreen(),
      ),
    );
  }

  void _shareMyQR() {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const QRSharingScreen(),
      ),
    );
  }

  void _removeFriend(String friendId) async {
    try {
      await ref.read(friendsActionsProvider).removeFriend(friendId);
      if (mounted) {
        showFloatingSnack(
          context,
          message: 'friend_removed'.tr(),
          backgroundColor: Colors.green,
          icon: Icons.check,
        );
        // Refresh friends list
        ref.invalidate(friendsListProvider);
      }
    } catch (e) {
      if (mounted) {
        showFloatingSnack(
          context,
          message: 'error_removing_friend'.tr(),
          backgroundColor: Colors.red,
          icon: Icons.error,
        );
      }
    }
  }

  void _blockFriend(String friendId) async {
    try {
      final success =
          await ref.read(friendsActionsProvider).blockFriend(friendId);
      if (mounted) {
        if (success) {
          showFloatingSnack(
            context,
            message: 'friend_blocked'.tr(),
            backgroundColor: Colors.orange,
            icon: Icons.block,
          );
          // Refresh friends list
          ref.invalidate(friendsListProvider);
        } else {
          showFloatingSnack(
            context,
            message: 'error_blocking_friend'.tr(),
            backgroundColor: Colors.red,
            icon: Icons.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showFloatingSnack(
          context,
          message: 'error_blocking_friend'.tr(),
          backgroundColor: Colors.red,
          icon: Icons.error,
        );
      }
    }
  }

  void _acceptFriendRequest(String friendId) async {
    try {
      await ref.read(friendsActionsProvider).acceptFriendRequest(friendId);
      if (mounted) {
        showFloatingSnack(
          context,
          message: 'friend_request_accepted'.tr(),
          backgroundColor: Colors.green,
          icon: Icons.check,
        );
        // Refresh friend requests and friends list
        ref.invalidate(friendRequestsReceivedProvider);
        ref.invalidate(friendsListProvider);
      }
    } catch (e) {
      if (mounted) {
        showFloatingSnack(
          context,
          message: 'error_accepting_request'.tr(),
          backgroundColor: Colors.red,
          icon: Icons.error,
        );
      }
    }
  }

  void _declineFriendRequest(String friendId) async {
    try {
      await ref.read(friendsActionsProvider).declineFriendRequest(friendId);
      if (mounted) {
        showFloatingSnack(
          context,
          message: 'friend_request_declined'.tr(),
          backgroundColor: Colors.grey,
          icon: Icons.close,
        );
        // Refresh friend requests
        ref.invalidate(friendRequestsReceivedProvider);
      }
    } catch (e) {
      if (mounted) {
        showFloatingSnack(
          context,
          message: 'error_declining_request'.tr(),
          backgroundColor: Colors.red,
          icon: Icons.error,
        );
      }
    }
  }
}
