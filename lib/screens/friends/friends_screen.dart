import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:move_young/services/auth_service.dart';
import 'package:move_young/services/friends_service.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/theme/app_back_button.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _myToken;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Ensure indexes for discovery
    FriendsService.ensureUserIndexes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUserId;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: _FriendsAppBarTitle(uid: uid),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            color: AppColors.primary,
            onPressed: _showAddFriendSheet,
            tooltip: 'friends_add_title'.tr(),
          ),
        ],
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey,
          indicatorColor: AppColors.primary,
          tabs: [
            if (uid == null)
              Tab(text: 'friends_tab_friends'.tr())
            else
              _TabWithBadge(
                label: 'friends_tab_friends'.tr(),
                countStream:
                    FriendsService.friendsStream(uid).map((e) => e.length),
              ),
            if (uid == null)
              Tab(text: 'friends_tab_requests'.tr())
            else
              _TabWithBadge(
                label: 'friends_tab_requests'.tr(),
                countStream: FriendsService.receivedRequestsStream(uid)
                    .map((e) => e.length),
              ),
          ],
        ),
      ),
      // FAB removed in favor of AppBar action for cleaner UI
      body: SafeArea(
        child: Padding(
          padding: AppPaddings.symmHorizontalReg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            children: [
                              _FriendsList(
                                  uid: uid, onAddFriend: _showAddFriendSheet),
                              _RequestsList(uid: uid),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddFriendSheet() {
    HapticFeedback.selectionClick();
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
                    icon: Icons.qr_code,
                    title: 'friends_my_qr'.tr(),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _showMyQr();
                    },
                  ),
                  _ActionTile(
                    icon: Icons.qr_code_scanner,
                    title: 'friends_scan_qr'.tr(),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _scanQr();
                    },
                  ),
                  _ActionTile(
                    icon: Icons.contacts_outlined,
                    title: 'friends_import_contacts'.tr(),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _importContacts();
                    },
                  ),
                  _ActionTile(
                    icon: Icons.alternate_email,
                    title: 'friends_search_email'.tr(),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _promptSearchByEmail();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showMyQr() async {
    setState(() => _generating = true);
    final token = await FriendsService.generateFriendToken();
    setState(() {
      _myToken = token;
      _generating = false;
    });
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('friends_my_qr'.tr()),
          content: _generating
              ? const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()))
              : (_myToken == null)
                  ? Text('loading_error'.tr())
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QrImageView(
                          data: _myToken!,
                          version: QrVersions.auto,
                          size: 200.0,
                        ),
                        const SizedBox(height: 8),
                        Text('friends_qr_hint'.tr(),
                            style: AppTextStyles.small),
                      ],
                    ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ok'.tr()),
            )
          ],
        );
      },
    );
  }

  Future<void> _scanQr() async {
    final currentContext = context;
    final scaffoldMessenger = ScaffoldMessenger.of(currentContext);
    // Request camera permission
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('permission_camera_denied'.tr())));
      return;
    }

    String? scanned;
    try {
      if (currentContext.mounted) {
        scanned = await showDialog<String>(
          context: currentContext,
          builder: (context) {
            return AlertDialog(
              title: Text('friends_scan_qr'.tr()),
              content: SizedBox(
                width: 260,
                height: 260,
                child: MobileScanner(
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      scanned = barcodes.first.rawValue;
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('cancel'.tr()),
                )
              ],
            );
          },
        );
      }
    } catch (e) {
      // Dialog was dismissed or error occurred
      scanned = null;
    }

    if (scanned == null || scanned!.isEmpty) return;
    // Defensive: trim whitespace and handle QR payloads with URLs
    final payload = scanned!.trim();
    final ok = await FriendsService.consumeFriendToken(payload);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(ok ? 'friends_request_sent'.tr() : 'loading_error'.tr())),
    );
  }

  Future<void> _importContacts() async {
    // Check/request contacts permission with graceful fallback
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      final res = await Permission.contacts.request();
      if (!res.isGranted) {
        if (res.isPermanentlyDenied) {
          if (!mounted) return;
          final go = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('permission_required'.tr()),
              content: Text('permission_contacts_denied'.tr()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('cancel'.tr()),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx, true);
                    await openAppSettings();
                  },
                  child: Text('open_settings'.tr()),
                ),
              ],
            ),
          );
          if (go != true) return;
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('permission_contacts_denied'.tr())),
          );
          return;
        }
      }
    }

    final contacts = await FlutterContacts.getContacts(withProperties: true);
    if (!mounted) return;

    // Simple selection list: show emails, allow tap to send request if matched
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: SafeArea(
            child: ListView.builder(
              itemCount: contacts.length,
              itemBuilder: (context, i) {
                final c = contacts[i];
                final email =
                    c.emails.isNotEmpty ? c.emails.first.address : null;
                if (email == null || email.isEmpty) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(c.displayName),
                  subtitle: Text(email),
                  trailing: TextButton(
                    child: Text('friends_send_request'.tr()),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final uid = await FriendsService.searchUidByEmail(email);
                      if (uid == null) {
                        if (!mounted) return;
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('friends_not_on_app'.tr())),
                        );
                        return;
                      }
                      await FriendsService.sendFriendRequestToUid(uid);
                      if (!mounted) return;
                      navigator.pop();
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('friends_request_sent'.tr())),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _promptSearchByEmail() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('friends_search_email'.tr()),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'auth_email'.tr()),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('cancel'.tr())),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('ok'.tr())),
          ],
        );
      },
    );
    if (ok != true) return;
    final email = controller.text.trim();
    if (email.isEmpty) return;
    final uid = await FriendsService.searchUidByEmail(email);
    if (uid == null) {
      await _launchEmailInvite(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening email app...')),
      );
    } else {
      await FriendsService.sendFriendRequestToUid(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('friends_request_sent'.tr())),
      );
    }
  }

  Future<void> _launchEmailInvite(String toEmail) async {
    final subject = Uri.encodeComponent('Join Move Young');
    const playUrl =
        'https://play.google.com/store/apps/details?id=com.example.move_young';
    const iosUrl = 'https://apps.apple.com/';
    final body = Uri.encodeComponent(
        'Hey! Join me on Move Young to play and organize games together.\n\nAndroid: $playUrl\niPhone: $iosUrl');
    final uri = Uri.parse('mailto:$toEmail?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _FriendsList extends StatelessWidget {
  final String uid;
  final VoidCallback onAddFriend;
  const _FriendsList({required this.uid, required this.onAddFriend});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: FriendsService.friendsStream(uid),
      builder: (context, snapshot) {
        final friends = snapshot.data ?? const <String>[];
        return ListView(
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
                        const Icon(Icons.group_outlined,
                            size: 48, color: AppColors.grey),
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
                  : ListView.separated(
                      shrinkWrap: true,
                      primary: false,
                      itemCount: friends.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.lightgrey),
                      itemBuilder: (context, i) {
                        final friendUid = friends[i];
                        return FutureBuilder<Map<String, String?>>(
                          future: FriendsService.fetchMinimalProfile(friendUid),
                          builder: (context, snap) {
                            final data = snap.data ??
                                const {'displayName': 'User', 'photoURL': null};
                            final name = data['displayName'] ?? 'User';
                            final photo = data['photoURL'];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.superlightgrey,
                                foregroundColor: AppColors.primary,
                                backgroundImage:
                                    (photo != null && photo.isNotEmpty)
                                        ? NetworkImage(photo)
                                        : null,
                                child: (photo == null || photo.isEmpty)
                                    ? Text(name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?')
                                    : null,
                              ),
                              title: Text(name, style: AppTextStyles.body),
                              subtitle: FutureBuilder<int>(
                                future: FriendsService.fetchMutualFriendsCount(
                                    friendUid),
                                builder: (context, mutualSnap) {
                                  final m = mutualSnap.data ?? 0;
                                  if (m <= 0) return const SizedBox.shrink();
                                  return Text(
                                      'friends_mutual'.tr(args: [m.toString()]),
                                      style: AppTextStyles.small);
                                },
                              ),
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
                                                    color: Colors.red),
                                                title: Text(
                                                    'friends_remove'.tr(),
                                                    style: const TextStyle(
                                                        color: Colors.red)),
                                                onTap: () => Navigator.pop(
                                                    context, 'remove'),
                                              ),
                                              ListTile(
                                                leading: const Icon(Icons.block,
                                                    color: Colors.red),
                                                title: Text(
                                                    'friends_block'.tr(),
                                                    style: const TextStyle(
                                                        color: Colors.red)),
                                                onTap: () => Navigator.pop(
                                                    context, 'block'),
                                              ),
                                              const SizedBox(height: 8),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                  if (action == 'remove') {
                                    bool? ok;
                                    if (currentContext.mounted) {
                                      ok = await showDialog<bool>(
                                        context: currentContext,
                                        builder: (ctx) => AlertDialog(
                                          title: Text('are_you_sure'.tr()),
                                          content: Text(
                                              'friends_confirm_remove'.tr()),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: Text('cancel'.tr())),
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: Text('ok'.tr())),
                                          ],
                                        ),
                                      );
                                    }
                                    if (ok == true) {
                                      await FriendsService.removeFriend(
                                          friendUid);
                                    }
                                  } else if (action == 'block') {
                                    bool? ok;
                                    if (currentContext.mounted) {
                                      ok = await showDialog<bool>(
                                        context: currentContext,
                                        builder: (ctx) => AlertDialog(
                                          title: Text('are_you_sure'.tr()),
                                          content: Text(
                                              'friends_confirm_block'.tr()),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: Text('cancel'.tr())),
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: Text('ok'.tr())),
                                          ],
                                        ),
                                      );
                                    }
                                    if (ok == true) {
                                      await FriendsService.blockUser(friendUid);
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
          ],
        );
      },
    );
  }
}

class _RequestsList extends StatelessWidget {
  final String uid;
  const _RequestsList({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: FriendsService.receivedRequestsStream(uid),
      builder: (context, snapshot) {
        final reqs = snapshot.data ?? const <String>[];
        return ListView(
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
              child: reqs.isEmpty
                  ? Center(
                      child: Text(
                        'friends_no_requests'.tr(),
                        style: AppTextStyles.body,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      primary: false,
                      itemCount: reqs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.lightgrey),
                      itemBuilder: (context, i) {
                        final fromUid = reqs[i];
                        return FutureBuilder<Map<String, String?>>(
                          future: FriendsService.fetchMinimalProfile(fromUid),
                          builder: (context, snap) {
                            final data = snap.data ??
                                const {'displayName': 'User', 'photoURL': null};
                            final name = data['displayName'] ?? 'User';
                            final photo = data['photoURL'];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.superlightgrey,
                                foregroundColor: AppColors.primary,
                                backgroundImage:
                                    (photo != null && photo.isNotEmpty)
                                        ? NetworkImage(photo)
                                        : null,
                                child: (photo == null || photo.isEmpty)
                                    ? const Icon(Icons.mail_outline,
                                        color: AppColors.primary)
                                    : null,
                              ),
                              title: Text(name, style: AppTextStyles.body),
                              subtitle: Text(
                                'friends_request_from'.tr(args: [name]),
                                style: AppTextStyles.small,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'help_report_problem'.tr(),
                                    onPressed: () async {
                                      final controller =
                                          TextEditingController();
                                      final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: Text(
                                                  'friends_report_user'.tr()),
                                              content: TextField(
                                                controller: controller,
                                                decoration: InputDecoration(
                                                    hintText:
                                                        'friends_report_reason'
                                                            .tr()),
                                                maxLines: 3,
                                              ),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child: Text('cancel'.tr())),
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    child: Text('ok'.tr())),
                                              ],
                                            ),
                                          ) ??
                                          false;
                                      if (ok) {
                                        final reason = controller.text.trim();
                                        if (reason.isNotEmpty) {
                                          await FriendsService.reportUser(
                                              targetUid: fromUid,
                                              reason: reason);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(
                                                        'friends_report_submitted'
                                                            .tr())));
                                          }
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.flag_outlined,
                                        color: Colors.red),
                                  ),
                                  IconButton(
                                    tooltip: 'friends_block'.tr(),
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: Text('are_you_sure'.tr()),
                                              content: Text(
                                                  'friends_confirm_block'.tr()),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child: Text('cancel'.tr())),
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    child: Text('ok'.tr())),
                                              ],
                                            ),
                                          ) ??
                                          false;
                                      if (ok) {
                                        await FriendsService.blockUser(fromUid);
                                      }
                                    },
                                    icon: const Icon(Icons.block,
                                        color: Colors.red),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        FriendsService.declineFriendRequest(
                                            fromUid),
                                    child: Text('cancel'.tr()),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white),
                                    onPressed: () =>
                                        FriendsService.acceptFriendRequest(
                                            fromUid),
                                    child: Text('friends_accept'.tr()),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}

class _FriendsAppBarTitle extends StatelessWidget {
  final String? uid;
  const _FriendsAppBarTitle({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid == null) return Text('friends'.tr());
    return StreamBuilder<List<String>>(
      stream: FriendsService.receivedRequestsStream(uid!),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        final base = 'friends'.tr();
        return Text(count > 0 ? '$base ($count)' : base);
      },
    );
  }
}

class _TabWithBadge extends StatelessWidget {
  final String label;
  final Stream<int> countStream;
  const _TabWithBadge({required this.label, required this.countStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: countStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('$count',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                )
              ]
            ],
          ),
        );
      },
    );
  }
}
