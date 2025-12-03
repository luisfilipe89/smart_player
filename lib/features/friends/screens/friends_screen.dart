import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/features/friends/services/friends_provider.dart';
import 'package:move_young/features/friends/services/email_provider.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/utils/service_helpers.dart' show showFloatingSnack;
import 'package:move_young/widgets/app_back_button.dart';
import 'package:move_young/widgets/tab_with_count.dart';
import 'package:move_young/widgets/cached_data_indicator.dart';
import 'package:shimmer/shimmer.dart';

// Helper moved to utils/service_helpers.dart and imported above

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsSkeleton extends StatelessWidget {
  const _FriendsSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.superlightgrey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.superlightgrey,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: MediaQuery.of(context).size.width * 0.5,
                    decoration: BoxDecoration(
                      color: AppColors.superlightgrey,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniListSkeleton extends StatelessWidget {
  const _MiniListSkeleton();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.superlightgrey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.superlightgrey,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
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
    final uid = ref.read(currentUserIdProvider);
    // Watch locale to rebuild on language change
    final currentLocale = context.locale;

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
          Semantics(
            label: 'Add friend',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.person_add),
              color: AppColors.primary,
              onPressed: _showAddFriendSheet,
              tooltip: 'friends_add_title'.tr(),
            ),
          ),
        ],
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          key: ValueKey(currentLocale.languageCode),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey,
          indicatorColor: AppColors.primary,
          isScrollable: false,
          tabAlignment: TabAlignment.fill,
          tabs: [
            if (uid == null)
              Tab(text: 'friends_tab_friends'.tr())
            else
              Consumer(
                builder: (context, ref, child) {
                  // Use select() to only rebuild when count changes, not on any list change
                  final count = ref.watch(
                    watchFriendsListProvider.select(
                      (asyncValue) => asyncValue.maybeWhen(
                        data: (friends) => friends.length,
                        orElse: () => 0,
                      ),
                    ),
                  );
                  // Still need to check loading/error state for proper UI
                  final friendsAsync = ref.watch(watchFriendsListProvider);
                  return friendsAsync.when(
                    data: (_) => TabWithCount(
                      label: 'friends_tab_friends'.tr(),
                      count: count,
                    ),
                    loading: () => Tab(text: 'friends_tab_friends'.tr()),
                    error: (_, __) => Tab(text: 'friends_tab_friends'.tr()),
                  );
                },
              ),
            if (uid == null)
              Tab(text: 'friends_tab_requests'.tr())
            else
              Consumer(
                builder: (context, ref, child) {
                  // Use select() to only rebuild when count changes, not on any list change
                  final requestsCount = ref.watch(
                    watchFriendRequestsReceivedProvider.select(
                      (asyncValue) => asyncValue.maybeWhen(
                        data: (requests) => requests.length,
                        orElse: () => 0,
                      ),
                    ),
                  );
                  // Still need to check loading/error state for proper UI
                  final requestsAsync =
                      ref.watch(watchFriendRequestsReceivedProvider);
                  return requestsAsync.when(
                    data: (_) => TabWithCount(
                      label: 'friends_tab_requests'.tr(),
                      count: requestsCount,
                    ),
                    loading: () => Tab(text: 'friends_tab_requests'.tr()),
                    error: (_, __) => Tab(text: 'friends_tab_requests'.tr()),
                  );
                },
              ),
          ],
        ),
      ),
      body: CachedDataIndicator(
        child: SafeArea(
          child: Padding(
            padding: AppPaddings.symmHorizontalReg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // Suggestions section
                if (uid != null) ...[
                  _SuggestionsSection(uid: uid),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadius.container),
                      boxShadow: AppShadows.md,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.container),
                      child: uid == null
                          ? const SizedBox.shrink()
                          : TabBarView(
                              controller: _tabController,
                              key: ValueKey(currentLocale.languageCode),
                              children: [
                                RefreshIndicator(
                                  onRefresh: () async {
                                    // Refresh data immediately
                                    ref.invalidate(watchFriendsListProvider);
                                  },
                                  child: _FriendsList(
                                    uid: uid,
                                    onAddFriend: _showAddFriendSheet,
                                  ),
                                ),
                                RefreshIndicator(
                                  onRefresh: () async {
                                    ref.invalidate(
                                      watchFriendRequestsReceivedProvider,
                                    );
                                  },
                                  child: _RequestsList(uid: uid),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddFriendSheet() {
    ref.read(hapticsActionsProvider)?.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('friends_add_title'.tr(), style: AppTextStyles.h3),
                  const SizedBox(height: 8),
                  _ActionTile(
                    icon: Icons.search,
                    title: 'friends_search_user_email'.tr(),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _showSearchDialog();
                    },
                  ),
                  // QR options removed
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSearchDialog() async {
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final myEmail = currentUser?.email?.trim().toLowerCase();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FriendSearchSheet(
        myEmail: myEmail,
        onSendFriendRequest: _sendFriendRequest,
        onInviteByEmail: _showEmailInviteDialog,
      ),
    );
  }

  Future<void> _showEmailInviteDialog(String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('friends_invite_email_title'.tr()),
          content: Text('friends_invite_email_message'.tr(args: [email])),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('friends_send_invite'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _sendEmailInvite(email);
    }
  }

  Future<void> _sendEmailInvite(String email) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final myEmail = currentUser?.email?.trim().toLowerCase();

    if (myEmail != null && email.trim().toLowerCase() == myEmail) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('friends_cannot_invite_self'.tr())),
      );
      return;
    }

    final emailActions = ref.read(emailActionsProvider);
    final canSend = await emailActions.canSendInviteToEmail(email.trim());
    if (!canSend) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('friends_invite_rate_limited'.tr())),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await emailActions
          .sendFriendInviteEmail(recipientEmail: email.trim())
          .timeout(const Duration(seconds: 12));

      if (mounted) {
        await navigator.maybePop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'friends_invite_email_sent'.tr()
                  : 'friends_invite_email_failed'.tr(),
            ),
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        await navigator.maybePop();
        messenger.showSnackBar(
          SnackBar(content: Text('friends_invite_email_failed'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        await navigator.maybePop();
        messenger.showSnackBar(
          SnackBar(content: Text('friends_invite_email_failed'.tr())),
        );
      }
    }
  }

  Future<bool> _sendFriendRequest(String targetUid) async {
    if (!mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    final bool ok;
    try {
      ok = await ref.read(friendsActionsProvider).sendFriendRequest(targetUid);
    } catch (e) {
      if (!mounted) return false;
      messenger.showSnackBar(
        SnackBar(content: Text('friends_request_failed'.tr())),
      );
      return false;
    }

    if (!mounted) return ok;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'friends_request_sent'.tr() : 'friends_request_failed'.tr(),
        ),
      ),
    );
    return ok;
  }
}

class _FriendSearchSheet extends ConsumerStatefulWidget {
  final String? myEmail;
  final Future<bool> Function(String uid) onSendFriendRequest;
  final Future<void> Function(String email) onInviteByEmail;

  const _FriendSearchSheet({
    required this.myEmail,
    required this.onSendFriendRequest,
    required this.onInviteByEmail,
  });

  @override
  ConsumerState<_FriendSearchSheet> createState() => _FriendSearchSheetState();
}

class _FriendSearchSheetState extends ConsumerState<_FriendSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, String>> _suggestions = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _showInviteOption = false;
  int _searchToken = 0;
  String? _pendingInviteEmail;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String raw) async {
    final query = raw.trim();
    final queryLower = query.toLowerCase();
    final isEmailQuery = query.contains('@') && query.contains('.');

    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _errorMessage = null;
        _showInviteOption = false;
        _isLoading = false;
        _pendingInviteEmail = null;
      });
      return;
    }

    if (widget.myEmail != null && queryLower == widget.myEmail) {
      setState(() {
        _suggestions = [];
        _errorMessage = 'friends_cannot_invite_self'.tr();
        _showInviteOption = false;
        _isLoading = false;
        _pendingInviteEmail = null;
      });
      return;
    }

    if (!isEmailQuery) {
      setState(() {
        _suggestions = [];
        _errorMessage = 'friends_search_email_only'.tr();
        _showInviteOption = false;
        _isLoading = false;
        _pendingInviteEmail = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showInviteOption = false;
      _pendingInviteEmail = null;
    });

    final token = ++_searchToken;
    try {
      final friendsActions = ref.read(friendsActionsProvider);
      final normalizedEmail = _normalizeEmailForLookup(queryLower);
      final rawResults =
          await friendsActions.searchUsersByEmail(normalizedEmail);

      if (!mounted || token != _searchToken) return;

      final filteredResults =
          rawResults.where((entry) => entry['isFallback'] != 'true').toList();
      final fallbackEntry = rawResults.firstWhere(
        (entry) => entry['isFallback'] == 'true',
        orElse: () => <String, String>{},
      );
      final inviteEmail = filteredResults.isEmpty
          ? (fallbackEntry['email'] ?? normalizedEmail)
          : null;

      setState(() {
        _suggestions = filteredResults;
        _isLoading = false;
        _pendingInviteEmail = inviteEmail;
        _showInviteOption = filteredResults.isEmpty && inviteEmail != null;
        _errorMessage =
            filteredResults.isEmpty ? 'friends_search_no_results'.tr() : null;
      });
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _suggestions = [];
        _isLoading = false;
        _showInviteOption = true;
        _errorMessage = 'friends_search_error'.tr();
        _pendingInviteEmail = _normalizeEmailForLookup(queryLower);
      });
    }
  }

  String _normalizeEmailForLookup(String email) {
    String value = email.trim();
    if (value.isEmpty) return value;

    final atIndex = value.indexOf('@');
    if (atIndex <= 0 || atIndex == value.length - 1) {
      return value;
    }

    final localPart = value.substring(0, atIndex);
    var domainPart = value.substring(atIndex + 1).trim();
    if (domainPart.isEmpty) {
      return value;
    }

    while (domainPart.endsWith('.')) {
      domainPart = domainPart.substring(0, domainPart.length - 1);
    }

    domainPart = domainPart.toLowerCase();

    if (!domainPart.contains('.')) {
      const defaultDomains = {
        'gmail': 'gmail.com',
        'hotmail': 'hotmail.com',
        'outlook': 'outlook.com',
        'live': 'live.com',
        'icloud': 'icloud.com',
        'me': 'me.com',
        'yahoo': 'yahoo.com',
        'proton': 'proton.me',
        'protonmail': 'protonmail.com',
      };

      domainPart = defaultDomains[domainPart] ?? '$domainPart.com';
    }

    return '$localPart@${domainPart.toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('friends_search_title'.tr(), style: AppTextStyles.h3),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'friends_search_email_hint'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: _performSearch,
              ),
              if (_isLoading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_errorMessage != null && !_isLoading) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.smallMuted,
                ),
              ],
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: _suggestions.isEmpty &&
                        !_showInviteOption &&
                        (_errorMessage == null || _isLoading)
                    ? const SizedBox.shrink()
                    : Material(
                        color: Colors.transparent,
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _showInviteOption
                              ? _suggestions.length + 1
                              : _suggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (_showInviteOption &&
                                index == _suggestions.length) {
                              final email = _pendingInviteEmail ??
                                  _controller.text.trim();
                              return ListTile(
                                leading: const Icon(Icons.mail_outline),
                                title: Text('friends_invite_email'.tr()),
                                subtitle: Text(
                                  'friends_invite_email_message'.tr(args: [
                                    email,
                                  ]),
                                  style: AppTextStyles.smallMuted,
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  await widget.onInviteByEmail(email);
                                },
                              );
                            }

                            final suggestion = _suggestions[index];
                            final displayName =
                                suggestion['displayName']?.isNotEmpty == true
                                    ? suggestion['displayName']!
                                    : 'Unknown User';
                            final email = suggestion['email'] ?? '';
                            final photoUrl = suggestion['photoURL'];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage:
                                    photoUrl != null && photoUrl.isNotEmpty
                                        ? CachedNetworkImageProvider(photoUrl)
                                        : null,
                                child: photoUrl == null || photoUrl.isEmpty
                                    ? Text(
                                        displayName.isNotEmpty
                                            ? displayName[0].toUpperCase()
                                            : '?',
                                      )
                                    : null,
                              ),
                              title: Text(displayName),
                              subtitle: email.isNotEmpty ? Text(email) : null,
                              trailing: TextButton(
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await widget
                                      .onSendFriendRequest(suggestion['uid']!);
                                },
                                child: Text('friends_send_request'.tr()),
                              ),
                            );
                          },
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

class _FriendsList extends ConsumerWidget {
  final String uid;
  final VoidCallback onAddFriend;
  const _FriendsList({required this.uid, required this.onAddFriend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(watchFriendsListProvider).when(
          data: (friends) => ListView(
            padding: AppPaddings.symmHorizontalReg.copyWith(
              top: AppSpacing.lg,
              bottom: AppSpacing.lg,
            ),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.container),
                  boxShadow: AppShadows.md,
                ),
                padding: AppPaddings.allBig,
                child: friends.isEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.group_outlined,
                            size: 48,
                            color: AppColors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text('friends_empty'.tr(), style: AppTextStyles.body),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: onAddFriend,
                            icon: const Icon(Icons.person_add_alt_1),
                            label: Text('friends_add_title'.tr()),
                          ),
                        ],
                      )
                    : FutureBuilder<Map<String, Map<String, String?>>>(
                        future: Future.wait(
                          friends.map(
                            (id) => ref
                                .read(friendsActionsProvider)
                                .fetchMinimalProfile(id),
                          ),
                        ).then((profiles) {
                          final map = <String, Map<String, String?>>{};
                          for (int i = 0;
                              i < friends.length && i < profiles.length;
                              i++) {
                            map[friends[i]] = profiles[i];
                          }
                          return map;
                        }),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (!snap.hasData || snap.data == null) {
                            return const SizedBox.shrink();
                          }
                          final profiles = snap.data!;

                          return ListView.separated(
                            shrinkWrap: true,
                            primary: false,
                            itemCount: friends.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: AppColors.lightgrey,
                            ),
                            itemBuilder: (context, i) {
                              final friendUid = friends[i];
                              final data = profiles[friendUid] ??
                                  const {
                                    'displayName': 'User',
                                    'photoURL': null,
                                  };
                              final name = data['displayName'] ?? 'User';
                              final photo = data['photoURL'];

                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.superlightgrey,
                                  foregroundColor: AppColors.primary,
                                  backgroundImage:
                                      (photo != null && photo.isNotEmpty)
                                          ? CachedNetworkImageProvider(photo)
                                          : null,
                                  child: (photo == null || photo.isEmpty)
                                      ? Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                        )
                                      : null,
                                ),
                                title: Text(name, style: AppTextStyles.body),
                                trailing: IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () async {
                                    final currentContext = context;
                                    final action =
                                        await showModalBottomSheet<String>(
                                      context: currentContext,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) {
                                        return Container(
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
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.remove_circle_outline,
                                                    color: Colors.red,
                                                  ),
                                                  title: Text(
                                                    'friends_remove'.tr(),
                                                    style: const TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                  onTap: () => Navigator.pop(
                                                    context,
                                                    'remove',
                                                  ),
                                                ),
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.block,
                                                    color: Colors.red,
                                                  ),
                                                  title: Text(
                                                    'friends_block'.tr(),
                                                    style: const TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                  onTap: () => Navigator.pop(
                                                    context,
                                                    'block',
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );

                                    if (!currentContext.mounted) return;

                                    if (action == 'remove') {
                                      final ok = await showDialog<bool>(
                                        context: currentContext,
                                        builder: (ctx) => AlertDialog(
                                          title: Text('are_you_sure'.tr()),
                                          content: Text(
                                            'friends_confirm_remove'.tr(),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: Text('cancel'.tr()),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                await ref
                                                    .read(
                                                      hapticsActionsProvider,
                                                    )
                                                    ?.heavyImpact();
                                                if (ctx.mounted) {
                                                  Navigator.pop(ctx, true);
                                                }
                                              },
                                              child: Text('ok'.tr()),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (!currentContext.mounted) return;
                                      if (ok == true) {
                                        await ref
                                            .read(friendsActionsProvider)
                                            .removeFriend(friendUid);
                                      }
                                    } else if (action == 'block') {
                                      final ok = await showDialog<bool>(
                                        context: currentContext,
                                        builder: (ctx) => AlertDialog(
                                          title: Text('are_you_sure'.tr()),
                                          content: Text(
                                            'friends_confirm_block'.tr(),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: Text('cancel'.tr()),
                                            ),
                                            TextButton(
                                              onPressed: () async {
                                                await ref
                                                    .read(
                                                      hapticsActionsProvider,
                                                    )
                                                    ?.heavyImpact();
                                                if (ctx.mounted) {
                                                  Navigator.pop(ctx, true);
                                                }
                                              },
                                              child: Text('ok'.tr()),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (!currentContext.mounted) return;
                                      if (ok == true) {
                                        await ref
                                            .read(friendsActionsProvider)
                                            .blockFriend(friendUid);
                                      }
                                    }
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              _SentRequests(uid: uid),
            ],
          ),
          loading: () => const _FriendsSkeleton(),
          error: (error, stack) => Center(child: Text('Error: $error')),
        );
  }
}

class _SentRequests extends ConsumerWidget {
  final String uid;
  const _SentRequests({required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(watchFriendRequestsSentProvider).when(
          data: (sent) {
            if (sent.isEmpty) return const SizedBox.shrink();
            return Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.container),
                boxShadow: AppShadows.md,
              ),
              padding: AppPaddings.allBig,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('friends_sent_requests'.tr(), style: AppTextStyles.h3),
                  const SizedBox(height: 8),
                  FutureBuilder<Map<String, Map<String, String?>>>(
                    future: Future.wait(
                      sent.map(
                        (id) => ref
                            .read(friendsActionsProvider)
                            .fetchMinimalProfile(id),
                      ),
                    ).then((profiles) {
                      final map = <String, Map<String, String?>>{};
                      for (int i = 0;
                          i < sent.length && i < profiles.length;
                          i++) {
                        map[sent[i]] = profiles[i];
                      }
                      return map;
                    }),
                    builder: (context, snap) {
                      final profiles =
                          snap.data ?? <String, Map<String, String?>>{};
                      return ListView.separated(
                        shrinkWrap: true,
                        primary: false,
                        itemCount: sent.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: AppColors.lightgrey,
                        ),
                        itemBuilder: (context, i) {
                          final toUid = sent[i];
                          final data = profiles[toUid] ??
                              const {
                                'displayName': 'User',
                                'photoURL': null,
                              };
                          final name = data['displayName'] ?? 'User';
                          final photo = data['photoURL'];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppColors.superlightgrey,
                              foregroundColor: AppColors.primary,
                              backgroundImage:
                                  (photo != null && photo.isNotEmpty)
                                      ? CachedNetworkImageProvider(photo)
                                      : null,
                              child: (photo == null || photo.isEmpty)
                                  ? const Icon(
                                      Icons.outbox,
                                      color: AppColors.primary,
                                    )
                                  : null,
                            ),
                            title: Text(
                              name,
                              style: AppTextStyles.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'friends_request_sent_to'.tr(args: [name]),
                              style: AppTextStyles.small,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: TextButton(
                              onPressed: () async {
                                final ok = await ref
                                    .read(friendsActionsProvider)
                                    .cancelFriendRequest(toUid);
                                if (!context.mounted) return;
                                showFloatingSnack(
                                  context,
                                  message: ok
                                      ? 'friends_request_declined'.tr()
                                      : 'friends_request_failed'.tr(),
                                  backgroundColor:
                                      ok ? AppColors.primary : Colors.red,
                                  icon: ok ? Icons.cancel : Icons.error_outline,
                                );
                              },
                              child: Text('cancel'.tr()),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
  }
}

class _ActionTile extends ConsumerWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      onTap: () {
        ref.read(hapticsActionsProvider)?.selectionClick();
        onTap();
      },
    );
  }
}

class _SuggestionsSection extends ConsumerStatefulWidget {
  final String uid;
  const _SuggestionsSection({required this.uid});

  @override
  ConsumerState<_SuggestionsSection> createState() =>
      _SuggestionsSectionState();
}

class _SuggestionsSectionState extends ConsumerState<_SuggestionsSection> {
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      // Note: getSuggestedFriends needs to be implemented in service
      setState(() {
        _suggestions = [];
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.container),
          boxShadow: AppShadows.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('friends_suggestions'.tr(), style: AppTextStyles.h3),
            const SizedBox(height: 12),
            const _FriendsSkeleton(),
          ],
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.container),
        boxShadow: AppShadows.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('friends_suggestions'.tr(), style: AppTextStyles.h3),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return _SuggestionCard(
                  suggestion: suggestion,
                  onAddFriend: () => _sendFriendRequest(suggestion['uid']),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFriendRequest(String targetUid) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    bool ok;
    try {
      ok = await ref.read(friendsActionsProvider).sendFriendRequest(targetUid);
    } catch (_) {
      ok = false;
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'friends_request_sent'.tr() : 'friends_request_failed'.tr(),
        ),
      ),
    );

    if (ok) {
      setState(() {
        _suggestions.removeWhere((s) => s['uid'] == targetUid);
      });
    }
  }
}

class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final VoidCallback onAddFriend;

  const _SuggestionCard({required this.suggestion, required this.onAddFriend});

  @override
  Widget build(BuildContext context) {
    final displayName = suggestion['displayName'] ?? 'Unknown User';
    final reason = suggestion['reason'] ?? '';
    final photoURL = suggestion['photoURL'];

    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: photoURL != null && photoURL.isNotEmpty
                    ? CachedNetworkImageProvider(photoURL)
                    : null,
                child: photoURL == null || photoURL.isEmpty
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.white,
                        ),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.person_add,
                      color: AppColors.white,
                      size: 16,
                    ),
                    onPressed: onAddFriend,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            displayName,
            style: AppTextStyles.small,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            reason,
            style: AppTextStyles.small.copyWith(color: AppColors.grey),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final Color color;
  final IconData icon;
  final bool alignLeft;
  const _SwipeBg({
    required this.color,
    required this.icon,
    required this.alignLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  final Widget child;
  const _AvatarRing({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF4FC3F7), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(2),
        child: child,
      ),
    );
  }
}

class _RequestSkeleton extends StatelessWidget {
  const _RequestSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Shimmer.fromColors(
          baseColor: AppColors.superlightgrey,
          highlightColor: Colors.white,
          child: const CircleAvatar(radius: 20, backgroundColor: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Shimmer.fromColors(
                baseColor: AppColors.superlightgrey,
                highlightColor: Colors.white,
                child: Container(
                  height: 12,
                  width: double.infinity,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Shimmer.fromColors(
                baseColor: AppColors.superlightgrey,
                highlightColor: Colors.white,
                child: Container(height: 10, width: 140, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Color _avatarBgFromName(String name) {
  if (name.isEmpty) return AppColors.superlightgrey;
  final code = name.codeUnits.fold<int>(0, (a, b) => (a + b) & 0xFF);
  final hue = (code % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.55, 0.55).toColor();
}

class _RequestsList extends ConsumerStatefulWidget {
  final String uid;
  const _RequestsList({required this.uid});

  @override
  ConsumerState<_RequestsList> createState() => _RequestsListState();
}

class _RequestsListState extends ConsumerState<_RequestsList> {
  final Set<String> _dismissed = <String>{};

  @override
  Widget build(BuildContext context) {
    return ref.watch(watchFriendRequestsReceivedProvider).when(
          data: (received) => ListView(
            padding: AppPaddings.symmHorizontalReg.copyWith(
              top: AppSpacing.lg,
              bottom: AppSpacing.lg,
            ),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.container),
                  boxShadow: AppShadows.md,
                ),
                padding: AppPaddings.allBig,
                child: received.isEmpty
                    ? Center(
                        child: Text(
                          'friends_no_requests'.tr(),
                          style: AppTextStyles.body,
                        ),
                      )
                    : ref.watch(watchFriendsListProvider).when(
                          data: (friends) {
                            final filtered = received
                                .where(
                                  (r) =>
                                      !_dismissed.contains(r) &&
                                      !friends.contains(r),
                                )
                                .toList();
                            if (filtered.isEmpty) {
                              return Center(
                                child: Text(
                                  'friends_no_requests'.tr(),
                                  style: AppTextStyles.body,
                                ),
                              );
                            }
                            return FutureBuilder<
                                Map<String, Map<String, String?>>>(
                              future: Future.wait(
                                filtered.map(
                                  (id) => ref
                                      .read(friendsActionsProvider)
                                      .fetchMinimalProfile(id),
                                ),
                              ).then((profiles) {
                                final map = <String, Map<String, String?>>{};
                                for (int i = 0;
                                    i < filtered.length && i < profiles.length;
                                    i++) {
                                  map[filtered[i]] = profiles[i];
                                }
                                return map;
                              }),
                              builder: (context, batchSnap) {
                                if (batchSnap.connectionState ==
                                    ConnectionState.waiting) {
                                  return ListView.separated(
                                    shrinkWrap: true,
                                    primary: false,
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) => const Divider(
                                      height: 1,
                                      color: AppColors.lightgrey,
                                    ),
                                    itemBuilder: (_, __) =>
                                        const _RequestSkeleton(),
                                  );
                                }
                                final profiles = batchSnap.data ??
                                    <String, Map<String, String?>>{};
                                return ListView.separated(
                                  shrinkWrap: true,
                                  primary: false,
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const Divider(
                                    height: 1,
                                    color: AppColors.lightgrey,
                                  ),
                                  itemBuilder: (context, i) {
                                    final fromUid = filtered[i];
                                    return Dismissible(
                                      key: Key(fromUid),
                                      background: _SwipeBg(
                                        color: AppColors.red,
                                        icon: Icons.cancel,
                                        alignLeft: true,
                                      ),
                                      secondaryBackground: _SwipeBg(
                                        color: AppColors.green,
                                        icon: Icons.check_circle,
                                        alignLeft: false,
                                      ),
                                      onDismissed: (direction) async {
                                        if (direction ==
                                            DismissDirection.startToEnd) {
                                          ref
                                              .read(hapticsActionsProvider)
                                              ?.heavyImpact();
                                          await ref
                                              .read(friendsActionsProvider)
                                              .declineFriendRequest(fromUid);
                                          if (context.mounted) {
                                            showFloatingSnack(
                                              context,
                                              message:
                                                  'friends_request_declined'
                                                      .tr(),
                                              backgroundColor:
                                                  AppColors.primary,
                                              icon: Icons.cancel,
                                            );
                                          }
                                        } else {
                                          ref
                                              .read(hapticsActionsProvider)
                                              ?.mediumImpact();
                                          // Capture messenger before async operation to avoid BuildContext warning
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          final ok = await ref
                                              .read(friendsActionsProvider)
                                              .acceptFriendRequest(fromUid);
                                          if (!context.mounted) return;
                                          if (ok) {
                                            setState(() {
                                              _dismissed.add(fromUid);
                                            });
                                            messenger.showSnackBar(
                                              SnackBar(
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                content: Text(
                                                  'friends_request_accepted'
                                                      .tr(),
                                                ),
                                                action: SnackBarAction(
                                                  label: 'friends_undo'.tr(),
                                                  onPressed: () async {
                                                    await ref
                                                        .read(
                                                          friendsActionsProvider,
                                                        )
                                                        .removeFriend(
                                                          fromUid,
                                                        );
                                                    // Would need to recreate request
                                                  },
                                                ),
                                              ),
                                            );
                                          }
                                          showFloatingSnack(
                                            context,
                                            message: ok
                                                ? 'friends_request_accepted'
                                                    .tr()
                                                : 'friends_request_failed'.tr(),
                                            backgroundColor: ok
                                                ? AppColors.primary
                                                : Colors.red,
                                            icon: ok
                                                ? Icons.check_circle
                                                : Icons.error_outline,
                                          );
                                        }
                                      },
                                      child: Builder(
                                        builder: (context) {
                                          final data = profiles[fromUid] ??
                                              const {
                                                'displayName': 'User',
                                                'photoURL': null,
                                              };
                                          final name =
                                              data['displayName'] ?? 'User';
                                          final photo = data['photoURL'];
                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            leading: _AvatarRing(
                                              child: CircleAvatar(
                                                backgroundColor:
                                                    _avatarBgFromName(name),
                                                foregroundColor: Colors.white,
                                                backgroundImage: (photo !=
                                                            null &&
                                                        photo.isNotEmpty)
                                                    ? CachedNetworkImageProvider(
                                                        photo,
                                                      )
                                                    : null,
                                                child: (photo == null ||
                                                        photo.isEmpty)
                                                    ? Text(
                                                        name.isNotEmpty
                                                            ? name[0]
                                                                .toUpperCase()
                                                            : '?',
                                                      )
                                                    : null,
                                              ),
                                            ),
                                            title: Text(
                                              name,
                                              style: AppTextStyles.body,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Text(
                                              'friends_request_from'.tr(
                                                args: [name],
                                              ),
                                              style: AppTextStyles.small,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            trailing: SizedBox(
                                              width: 176,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  IconButton(
                                                    tooltip: 'cancel'.tr(),
                                                    constraints:
                                                        const BoxConstraints(
                                                      minWidth: 48,
                                                      minHeight: 48,
                                                    ),
                                                    onPressed: () async {
                                                      ref
                                                          .read(
                                                            hapticsActionsProvider,
                                                          )
                                                          ?.heavyImpact();
                                                      await ref
                                                          .read(
                                                            friendsActionsProvider,
                                                          )
                                                          .declineFriendRequest(
                                                            fromUid,
                                                          );
                                                      if (context.mounted) {
                                                        showFloatingSnack(
                                                          context,
                                                          message:
                                                              'friends_request_declined'
                                                                  .tr(),
                                                          backgroundColor:
                                                              AppColors.primary,
                                                          icon: Icons.cancel,
                                                        );
                                                      }
                                                    },
                                                    icon: const Icon(
                                                      Icons.cancel,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip:
                                                        'friends_accept_request'
                                                            .tr(),
                                                    constraints:
                                                        const BoxConstraints(
                                                      minWidth: 48,
                                                      minHeight: 48,
                                                    ),
                                                    onPressed: () async {
                                                      ref
                                                          .read(
                                                            hapticsActionsProvider,
                                                          )
                                                          ?.mediumImpact();
                                                      final ok = await ref
                                                          .read(
                                                            friendsActionsProvider,
                                                          )
                                                          .acceptFriendRequest(
                                                            fromUid,
                                                          );
                                                      if (!context.mounted) {
                                                        return;
                                                      }
                                                      if (ok) {
                                                        setState(() {
                                                          _dismissed.add(
                                                            fromUid,
                                                          );
                                                        });
                                                      }
                                                      showFloatingSnack(
                                                        context,
                                                        message: ok
                                                            ? 'friends_request_accepted'
                                                                .tr()
                                                            : 'friends_request_failed'
                                                                .tr(),
                                                        backgroundColor: ok
                                                            ? AppColors.primary
                                                            : Colors.red,
                                                        icon: ok
                                                            ? Icons.check_circle
                                                            : Icons
                                                                .error_outline,
                                                      );
                                                    },
                                                    icon: const Icon(
                                                      Icons.check_circle,
                                                      color: AppColors.green,
                                                    ),
                                                  ),
                                                  PopupMenuButton<String>(
                                                    icon: const Icon(
                                                      Icons.more_vert,
                                                    ),
                                                    onSelected: (value) async {
                                                      if (value == 'report') {
                                                        // Report functionality
                                                      } else if (value ==
                                                          'block') {
                                                        final ok =
                                                            await showDialog<
                                                                    bool>(
                                                                  context:
                                                                      context,
                                                                  builder: (ctx) =>
                                                                      AlertDialog(
                                                                    title: Text(
                                                                      'are_you_sure'
                                                                          .tr(),
                                                                    ),
                                                                    content:
                                                                        Text(
                                                                      'friends_confirm_block'
                                                                          .tr(),
                                                                    ),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed:
                                                                            () =>
                                                                                Navigator.pop(
                                                                          ctx,
                                                                          false,
                                                                        ),
                                                                        child:
                                                                            Text(
                                                                          'cancel'
                                                                              .tr(),
                                                                        ),
                                                                      ),
                                                                      TextButton(
                                                                        onPressed:
                                                                            () =>
                                                                                Navigator.pop(
                                                                          ctx,
                                                                          true,
                                                                        ),
                                                                        child:
                                                                            Text(
                                                                          'ok'.tr(),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ) ??
                                                                false;
                                                        if (ok) {
                                                          await ref
                                                              .read(
                                                                friendsActionsProvider,
                                                              )
                                                              .blockFriend(
                                                                fromUid,
                                                              );
                                                          if (context.mounted) {
                                                            showFloatingSnack(
                                                              context,
                                                              message:
                                                                  'friends_user_blocked'
                                                                      .tr(),
                                                              backgroundColor:
                                                                  AppColors
                                                                      .primary,
                                                              icon: Icons.block,
                                                            );
                                                          }
                                                        }
                                                      }
                                                    },
                                                    itemBuilder: (ctx) => [
                                                      PopupMenuItem(
                                                        value: 'report',
                                                        child: Text(
                                                          'help_report_problem'
                                                              .tr(),
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'block',
                                                        child: Text(
                                                          'friends_block'.tr(),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            onTap: () {},
                                          );
                                        },
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },
                          loading: () => const _MiniListSkeleton(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
              ),
            ],
          ),
          loading: () => const _FriendsSkeleton(),
          error: (error, stack) => Center(child: Text('Error: $error')),
        );
  }
}
