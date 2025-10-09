import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:move_young/services/haptics_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import 'package:move_young/services/auth_service.dart';
import 'package:move_young/services/friends_service.dart';
import 'package:move_young/services/email_service.dart';
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
        leading: const AppBackButton(goHome: true),
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
            Tab(text: 'friends_tab_friends'.tr()),
            Tab(text: 'friends_tab_requests'.tr()),
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
    HapticsService.selectionClick();
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
                    icon: Icons.contacts_outlined,
                    title: 'friends_import_contacts'.tr(),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _importContacts();
                    },
                  ),
                  _ActionTile(
                    icon: Icons.search,
                    title: 'friends_search_user'.tr(),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _showSearchDialog();
                    },
                  ),
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
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('friends_my_qr'.tr()),
          content: FutureBuilder<String?>(
            future: FriendsService.generateFriendToken(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                debugPrint('generateFriendToken error: ${snapshot.error}');
                return Text('loading_error'.tr());
              }
              if (!snapshot.hasData || (snapshot.data == null)) {
                return Text('loading_error'.tr());
              }
              final token = snapshot.data!;
              return SizedBox(
                width: 260,
                height: 250,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      data: token,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                    const SizedBox(height: 8),
                    Text('friends_qr_hint'.tr(), style: AppTextStyles.small),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('ok'.tr()),
            ),
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

    // Show contacts with phone numbers and allow quick share via SMS or WhatsApp
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
                final String? phone =
                    c.phones.isNotEmpty ? c.phones.first.number : null;
                if (phone == null || phone.isEmpty) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(c.displayName),
                  subtitle: Text(phone),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => _sendSmsInvite(phone, c.displayName),
                        child: const Text('SMS'),
                      ),
                      TextButton(
                        onPressed: () =>
                            _sendWhatsAppInvite(phone, c.displayName),
                        child: const Text('WhatsApp'),
                      ),
                    ],
                  ),
                  onTap: () => _sendSmsInvite(phone, c.displayName),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _normalizePhoneForWa(String phone) {
    // WhatsApp wa.me requires digits only, no '+' or symbols
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return digitsOnly.startsWith('+') ? digitsOnly.substring(1) : digitsOnly;
  }

  Future<void> _sendSmsInvite(String phone, String? name) async {
    final inviteText =
        "Hey${name != null && name.isNotEmpty ? ' $name' : ''}! Check out SMARTPLAYER – the sports app I'm using. Download: https://smartplayer.app";
    final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(inviteText)}');

    try {
      final can = await canLaunchUrl(uri);
      if (can) {
        await launchUrl(uri);
      } else {
        await Share.share(inviteText);
      }
    } catch (_) {
      await Share.share(inviteText);
    }
  }

  Future<void> _sendWhatsAppInvite(String phone, String? name) async {
    final inviteText =
        "Hey${name != null && name.isNotEmpty ? ' $name' : ''}! Check out SMARTPLAYER – the sports app I'm using. Download: https://smartplayer.app";
    final waNumber = _normalizePhoneForWa(phone);
    final uri = Uri.parse(
        'https://wa.me/$waNumber?text=${Uri.encodeComponent(inviteText)}');

    try {
      final can = await canLaunchUrl(uri);
      if (can) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Share.share(inviteText);
      }
    } catch (_) {
      await Share.share(inviteText);
    }
  }

  Future<void> _showSearchDialog() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('friends_search_title'.tr()),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'friends_search_hint'.tr(),
            ),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: Text('friends_search_button'.tr()),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    final searchQuery = controller.text.trim();
    if (searchQuery.isEmpty) return;

    // Prevent self-search
    final myEmail = AuthService.currentUser?.email?.trim().toLowerCase();
    final myDisplayName =
        AuthService.currentUser?.displayName?.trim().toLowerCase();
    if ((myEmail != null && searchQuery.toLowerCase() == myEmail) ||
        (myDisplayName != null && searchQuery.toLowerCase() == myDisplayName)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('friends_cannot_invite_self'.tr())),
      );
      return;
    }

    // If the query looks like an email, skip DB search and go straight to invite flow
    final looksLikeEmail =
        searchQuery.contains('@') && searchQuery.contains('.');
    if (looksLikeEmail) {
      await _showEmailInviteDialog(searchQuery);
      return;
    }

    // Show loading and search for users
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Search for users by username or email
      final users = await FriendsService.searchUsers(searchQuery);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (users.isEmpty) {
        // If query looks like an email address, offer to send an invite by email
        final looksLikeEmail =
            searchQuery.contains('@') && searchQuery.contains('.');
        if (looksLikeEmail) {
          await _showEmailInviteDialog(searchQuery);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('friends_search_no_results'.tr())),
          );
        }
        return;
      }

      // Show search results
      _showSearchResults(users, searchQuery);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('friends_search_error'.tr())),
      );
    }
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
    // Prevent self-invite
    final myEmail = AuthService.currentUser?.email?.trim().toLowerCase();
    if (myEmail != null &&
        myEmail.isNotEmpty &&
        email.trim().toLowerCase() == myEmail) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('friends_cannot_invite_self'.tr())),
      );
      return;
    }

    // Rate limiting check
    final canSend = await EmailService.canSendInviteToEmail(email.trim());
    if (!canSend) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('friends_invite_rate_limited'.tr())),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success =
          await EmailService.sendFriendInviteEmail(recipientEmail: email.trim())
              .timeout(const Duration(seconds: 12));

      if (mounted) {
        // Close loading dialog if still open
        await Navigator.of(context, rootNavigator: true).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'friends_invite_email_sent'.tr()
                : 'friends_invite_email_failed'.tr()),
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        await Navigator.of(context, rootNavigator: true).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('friends_invite_email_failed'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        await Navigator.of(context, rootNavigator: true).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('friends_invite_email_failed'.tr())),
        );
      }
    }
  }

  void _showSearchResults(
      List<Map<String, dynamic>> users, String searchQuery) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('friends_search_results'.tr(args: [searchQuery])),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final displayName = user['displayName'] ?? 'Unknown User';
                final email = user['email'] ?? '';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user['photoURL'] != null
                        ? NetworkImage(user['photoURL'])
                        : null,
                    child: user['photoURL'] == null
                        ? Text(displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?')
                        : null,
                  ),
                  title: Text(displayName),
                  subtitle: email.isNotEmpty ? Text(email) : null,
                  trailing: TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _sendFriendRequest(user['uid']);
                    },
                    child: Text('friends_send_request'.tr()),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendFriendRequest(String targetUid) async {
    try {
      await FriendsService.sendFriendRequestToUid(targetUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('friends_request_sent'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
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
        HapticsService.selectionClick();
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

class _SuggestionsSection extends StatefulWidget {
  final String uid;
  const _SuggestionsSection({required this.uid});

  @override
  State<_SuggestionsSection> createState() => _SuggestionsSectionState();
}

class _SuggestionsSectionState extends State<_SuggestionsSection> {
  List<Map<String, dynamic>> _suggestions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final suggestions = await FriendsService.getSuggestedFriends(widget.uid);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _loading = false;
        });
      }
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
            const Center(
              child: CircularProgressIndicator(),
            ),
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
    try {
      await FriendsService.sendFriendRequestToUid(targetUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('friends_request_sent'.tr())),
        );
        // Remove the suggestion from the list
        setState(() {
          _suggestions.removeWhere((s) => s['uid'] == targetUid);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}

class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final VoidCallback onAddFriend;

  const _SuggestionCard({
    required this.suggestion,
    required this.onAddFriend,
  });

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
                    ? NetworkImage(photoURL)
                    : null,
                child: photoURL == null || photoURL.isEmpty
                    ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style:
                            AppTextStyles.h3.copyWith(color: AppColors.white),
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
                    icon: const Icon(Icons.person_add,
                        color: AppColors.white, size: 16),
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
            style: AppTextStyles.small.copyWith(
              color: AppColors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// (Old TabWithBadge removed as we now use a body segmented control)
