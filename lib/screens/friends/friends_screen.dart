import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:move_young/services/image_cache_service.dart';
import 'package:move_young/services/haptics_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
// QR rendering handled inside bottom sheet widget
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'dart:async';
// Shimmer import not used yet; removed
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:move_young/services/auth_service.dart';
import 'package:move_young/services/friends_service.dart';
import 'package:move_young/services/email_service.dart';
import 'package:move_young/services/error_handler_service.dart';
import 'package:move_young/utils/undo_helpers.dart';
import 'package:move_young/widgets/rate_limit_feedback.dart';
import 'package:move_young/widgets/cached_data_indicator.dart';
import 'package:move_young/utils/pagination_helper.dart';
import 'package:move_young/utils/widget_memo.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/theme/app_back_button.dart';
import 'package:shimmer/shimmer.dart';

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
              StreamBuilder<List<String>>(
                stream: FriendsService.friendsStream(uid),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  final base = 'friends_tab_friends'.tr();
                  return Tab(text: count > 0 ? '$base ($count)' : base);
                },
              ),
            if (uid == null)
              Tab(text: 'friends_tab_requests'.tr())
            else
              StreamBuilder<List<String>>(
                stream: FriendsService.receivedRequestsStream(uid),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  final base = 'friends_tab_requests'.tr();
                  return Tab(text: count > 0 ? '$base ($count)' : base);
                },
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
                              RefreshIndicator(
                                onRefresh: () async {
                                  // Trigger streams by a small delay
                                  await Future.delayed(
                                      const Duration(milliseconds: 400));
                                },
                                child: _FriendsList(
                                    uid: uid, onAddFriend: _showAddFriendSheet),
                              ),
                              RefreshIndicator(
                                onRefresh: () async {
                                  await Future.delayed(
                                      const Duration(milliseconds: 400));
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
                    icon: Icons.search,
                    title: 'friends_search_user'.tr(),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _showSearchDialog();
                    },
                  ),
                  _ActionTile(
                    icon: Icons.ios_share_outlined,
                    title: 'friends_invite_via_message'.tr(),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _showInviteByMessage();
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
    // Auto-close the QR dialog when a new friend request arrives for me
    StreamSubscription<DatabaseEvent>? qrAutoCloseSub;
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;

    final dialogFuture = showDialog(
      context: context,
      builder: (dialogContext) {
        return _QrBottomSheetContent();
      },
    );

    // If my QR is shown, close it automatically once someone sends me a request
    if (myUid != null) {
      try {
        final DatabaseReference receivedRef = FirebaseDatabase.instance
            .ref('users/$myUid/friendRequests/received');
        qrAutoCloseSub = receivedRef.limitToLast(1).onChildAdded.listen((_) {
          try {
            if (mounted) {
              Navigator.of(context, rootNavigator: true).maybePop();
            }
            // After closing the QR dialog, switch to Requests tab (index 1)
            if (mounted) {
              Future.delayed(const Duration(milliseconds: 150), () {
                if (mounted) {
                  _tabController.animateTo(1);
                }
              });
            }
          } catch (_) {}
        });
      } catch (_) {}
    }

    unawaited(dialogFuture.whenComplete(() async {
      try {
        await qrAutoCloseSub?.cancel();
      } catch (_) {}
    }));
  }

  Future<void> _scanQr() async {
    final currentContext = context;
    final scaffoldMessenger = ScaffoldMessenger.of(currentContext);

    // Request camera permission
    final camStatus = await Permission.camera.request();
    if (!camStatus.isGranted) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('permission_camera_denied'.tr()),
          backgroundColor: Colors.red,
        ),
      );
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
                    debugPrint(
                        '🔍 MobileScanner detected \'${barcodes.length}\' barcodes');
                    if (barcodes.isNotEmpty) {
                      scanned = barcodes.first.rawValue;
                      debugPrint('🔍 Scanned value: $scanned');
                      // Use maybePop to avoid assertion error if history is empty
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop(scanned);
                      }
                    }
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('cancel'.tr()),
                )
              ],
            );
          },
        );
      }
    } catch (e) {
      debugPrint('🔍 Error during QR scanning: $e');
      scanned = null;
    }

    if (scanned == null || scanned!.isEmpty) {
      debugPrint('🔍 No QR code scanned or empty result');
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('friends_no_qr_detected'.tr()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show processing indicator
    if (!mounted) return;
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text('friends_processing_qr'.tr()),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    // Defensive: trim whitespace and handle QR payloads with URLs
    final payload = scanned!.trim();
    debugPrint('🔍 Processing payload: $payload');

    try {
      final ok = await FriendsService.consumeFriendToken(payload);
      debugPrint('🔍 consumeFriendToken result: $ok');

      if (!mounted) return;

      if (ok) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('friends_request_sent'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('friends_invalid_qr_code'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('🔍 Error processing QR code: $e');
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('friends_qr_processing_error'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                        onPressed: () =>
                            _sendSmsFriendInvite(phone, c.displayName),
                        child: const Text('SMS'),
                      ),
                      TextButton(
                        onPressed: () =>
                            _sendWhatsAppFriendInvite(phone, c.displayName),
                        child: const Text('WhatsApp'),
                      ),
                    ],
                  ),
                  onTap: () => _sendSmsFriendInvite(phone, c.displayName),
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

  // Invite-by-message helpers (tokenized friend request links)
  String _friendInviteUrl(String token) =>
      'https://smartplayer.app/f?token=$token';

  String _friendInviteMessage({required String token, String? name}) {
    final hello = "Hey${name != null && name.isNotEmpty ? ' $name' : ''}!";
    final link = _friendInviteUrl(token);
    return "$hello Add me on SMARTPLAYER: $link\nIf the link doesn’t open, copy this code into the app: $token";
  }

  Future<void> _inviteViaShare() async {
    final token = await FriendsService.generateFriendToken();
    if (token == null || !mounted) return;
    final text = _friendInviteMessage(token: token);
    await Share.share(text, subject: 'Add me on SMARTPLAYER');
  }

  Future<void> _sendSmsFriendInvite(String phone, String? name) async {
    final token = await FriendsService.generateFriendToken();
    if (token == null) return;
    final text = _friendInviteMessage(token: token, name: name);
    final uri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(text)}');
    try {
      final can = await canLaunchUrl(uri);
      if (can) {
        await launchUrl(uri);
      } else {
        await Share.share(text);
      }
    } catch (_) {
      await Share.share(text);
    }
  }

  Future<void> _sendWhatsAppFriendInvite(String phone, String? name) async {
    final token = await FriendsService.generateFriendToken();
    if (token == null) return;
    final text = _friendInviteMessage(token: token, name: name);
    final waNumber = _normalizePhoneForWa(phone);
    final uri =
        Uri.parse('https://wa.me/$waNumber?text=${Uri.encodeComponent(text)}');
    try {
      final can = await canLaunchUrl(uri);
      if (can) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Share.share(text);
      }
    } catch (_) {
      await Share.share(text);
    }
  }

  Future<void> _showInviteByMessage() async {
    if (!mounted) return;
    await showModalBottomSheet(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share_outlined),
                  title: Text('friends_invite_share_via_apps'.tr()),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _inviteViaShare();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.contacts_outlined),
                  title: Text('friends_invite_share_with_contacts'.tr()),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _importContacts();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
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
        await navigator.maybePop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(success
                ? 'friends_invite_email_sent'.tr()
                : 'friends_invite_email_failed'.tr()),
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
                  leading: ImageCacheService.getOptimizedAvatar(
                    imageUrl: user['photoURL'],
                    radius: 20,
                    fallbackText: displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : '?',
                  ),
                  title: Text(displayName),
                  subtitle: email.isNotEmpty ? Text(email) : null,
                  trailing: RateLimitButton(
                    uid: AuthService.currentUser?.uid ?? '',
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

class _FriendsList extends StatefulWidget {
  final String uid;
  final VoidCallback onAddFriend;
  const _FriendsList({required this.uid, required this.onAddFriend});

  @override
  State<_FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<_FriendsList> {
  late PaginationHelper<String> _paginationHelper;
  late PaginationScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _paginationHelper = PaginationHelper<String>(
      pageSize: 30,
      loadData: _loadFriendsPage,
    );
    _scrollController = PaginationScrollController(
      paginationHelper: _paginationHelper,
    );
    _paginationHelper.initialize();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<String>> _loadFriendsPage(int page, int pageSize) async {
    // Get all friends from the stream and paginate
    final friends = await FriendsService.friendsStream(widget.uid).first;

    // Calculate pagination
    final startIndex = page * pageSize;
    final endIndex = (startIndex + pageSize).clamp(0, friends.length);

    if (startIndex >= friends.length) {
      return [];
    }

    return friends.sublist(startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: FriendsService.friendsStream(widget.uid),
      builder: (context, snapshot) {
        final allFriends = snapshot.data ?? const <String>[];

        return Stack(
          children: [
            ListView(
              controller: _scrollController,
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
                  child: allFriends.isEmpty
                      ? _buildEmptyState()
                      : _buildPaginatedFriendsList(),
                ),
                const SizedBox(height: 16),
                _SentRequests(uid: widget.uid),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ConnectivityAwareCachedIndicator(
                onRefresh: () async {
                  await _paginationHelper.refresh();
                },
                child: const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.group_outlined, size: 48, color: AppColors.grey),
        const SizedBox(height: 8),
        Text('friends_empty'.tr(), style: AppTextStyles.body),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: widget.onAddFriend,
          icon: const Icon(Icons.person_add_alt_1),
          label: Text('friends_add_title'.tr()),
        ),
      ],
    );
  }

  Widget _buildPaginatedFriendsList() {
    return ValueListenableBuilder<PaginationState<String>>(
      valueListenable: _paginationHelper.state,
      builder: (context, state, child) {
        return PaginationLoadingWidget(
          state: state,
          itemBuilder: (friends) => _buildFriendsList(friends.cast<String>()),
          emptyWidget: _buildEmptyState(),
        );
      },
    );
  }

  Widget _buildFriendsList(List<String> friends) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        FriendsService.fetchMinimalProfiles(friends),
        FriendsService.fetchMutualFriendsCounts(friends),
      ]),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data == null) {
          return const SizedBox.shrink();
        }
        final Map<String, Map<String, String?>> profiles =
            (snap.data![0] as Map<String, Map<String, String?>>);
        final Map<String, int> mutual = (snap.data![1] as Map<String, int>);

        return ListView.separated(
          shrinkWrap: true,
          primary: false,
          itemCount: friends.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.lightgrey),
          itemBuilder: (context, i) {
            final friendUid = friends[i];
            return MemoizedBuilder(
              cacheKey: 'friend_$friendUid',
              builder: (context) =>
                  _buildFriendTile(friendUid, profiles, mutual),
            );
          },
        );
      },
    );
  }

  Widget _buildFriendTile(
    String friendUid,
    Map<String, Map<String, String?>> profiles,
    Map<String, int> mutual,
  ) {
    final data =
        profiles[friendUid] ?? const {'displayName': 'User', 'photoURL': null};
    final name = data['displayName'] ?? 'User';
    final photo = data['photoURL'];
    final m = mutual[friendUid] ?? 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ImageCacheService.getOptimizedAvatar(
        imageUrl: photo,
        radius: 20,
        backgroundColor: AppColors.superlightgrey,
        foregroundColor: AppColors.primary,
        fallbackText: name.isNotEmpty ? name[0].toUpperCase() : '?',
      ),
      title: Text(name, style: AppTextStyles.body),
      subtitle: m > 0
          ? Text('friends_mutual'.tr(args: [m.toString()]),
              style: AppTextStyles.small)
          : const SizedBox.shrink(),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showFriendOptions(friendUid),
      ),
    );
  }

  Future<void> _showFriendOptions(String friendUid) async {
    final action = await showModalBottomSheet<String>(
      context: context,
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
              ListTile(
                leading:
                    const Icon(Icons.remove_circle_outline, color: Colors.red),
                title: Text('friends_remove'.tr(),
                    style: const TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: Text('friends_block'.tr(),
                    style: const TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'block'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (action == 'remove') {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('are_you_sure'.tr()),
          content: Text('friends_confirm_remove'.tr()),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr())),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('ok'.tr())),
          ],
        ),
      );
      if (ok == true) {
        await FriendsService.removeFriend(friendUid);
      }
    } else if (action == 'block') {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('are_you_sure'.tr()),
          content: Text('friends_confirm_block'.tr()),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('cancel'.tr())),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('ok'.tr())),
          ],
        ),
      );
      if (ok == true) {
        await FriendsService.blockUser(friendUid);
      }
    }
  }
}

class _BatchedFriendTile extends StatefulWidget {
  final String friendUid;
  const _BatchedFriendTile({required this.friendUid});

  @override
  State<_BatchedFriendTile> createState() => _BatchedFriendTileState();
}

class _BatchedFriendTileState extends State<_BatchedFriendTile> {
  Map<String, String?>? _profile;
  int? _mutualCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      FriendsService.fetchMinimalProfile(widget.friendUid),
      FriendsService.fetchMutualFriendsCount(widget.friendUid),
    ]);
    if (!mounted) return;
    setState(() {
      _profile = results[0] as Map<String, String?>?;
      _mutualCount = results[1] as int?;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _profile ?? const {'displayName': 'User', 'photoURL': null};
    final name = data['displayName'] ?? 'User';
    final photo = data['photoURL'];
    final m = _mutualCount ?? 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ImageCacheService.getOptimizedAvatar(
        imageUrl: photo,
        radius: 20,
        backgroundColor: AppColors.superlightgrey,
        foregroundColor: AppColors.primary,
        fallbackText: name.isNotEmpty ? name[0].toUpperCase() : '?',
      ),
      title: Text(name, style: AppTextStyles.body),
      subtitle: m > 0
          ? Text('friends_mutual'.tr(args: [m.toString()]),
              style: AppTextStyles.small)
          : const SizedBox.shrink(),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () async {
          final currentContext = context;
          final action = await showModalBottomSheet<String>(
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
                        leading: const Icon(Icons.remove_circle_outline,
                            color: Colors.red),
                        title: Text('friends_remove'.tr(),
                            style: const TextStyle(color: Colors.red)),
                        onTap: () => Navigator.pop(context, 'remove'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.block, color: Colors.red),
                        title: Text('friends_block'.tr(),
                            style: const TextStyle(color: Colors.red)),
                        onTap: () => Navigator.pop(context, 'block'),
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
                  content: Text('friends_confirm_remove'.tr()),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('cancel'.tr())),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('ok'.tr())),
                  ],
                ),
              );
            }
            if (ok == true) {
              await FriendsService.removeFriend(widget.friendUid);
            }
          } else if (action == 'block') {
            bool? ok;
            if (currentContext.mounted) {
              ok = await showDialog<bool>(
                context: currentContext,
                builder: (ctx) => AlertDialog(
                  title: Text('are_you_sure'.tr()),
                  content: Text('friends_confirm_block'.tr()),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('cancel'.tr())),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('ok'.tr())),
                  ],
                ),
              );
            }
            if (ok == true) {
              await FriendsService.blockUser(widget.friendUid);
            }
          }
        },
      ),
    );
  }
}

class _RequestsList extends StatefulWidget {
  final String uid;
  const _RequestsList({required this.uid});

  @override
  State<_RequestsList> createState() => _RequestsListState();
}

class _RequestsListState extends State<_RequestsList> {
  final Set<String> _dismissed = <String>{};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: FriendsService.receivedRequestsStream(widget.uid),
      builder: (context, reqSnap) {
        final received = reqSnap.data ?? const <String>[];
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
              child: received.isEmpty
                  ? Center(
                      child: Text(
                        'friends_no_requests'.tr(),
                        style: AppTextStyles.body,
                      ),
                    )
                  : StreamBuilder<List<String>>(
                      stream: FriendsService.friendsStream(widget.uid),
                      builder: (context, friendsSnap) {
                        final friends = friendsSnap.data ?? const <String>[];
                        final filtered = received
                            .where((r) =>
                                !_dismissed.contains(r) && !friends.contains(r))
                            .toList();
                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              'friends_no_requests'.tr(),
                              style: AppTextStyles.body,
                            ),
                          );
                        }
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child:
                              FutureBuilder<Map<String, Map<String, String?>>>(
                            future:
                                FriendsService.fetchMinimalProfiles(filtered),
                            builder: (context, batchSnap) {
                              if (batchSnap.connectionState ==
                                  ConnectionState.waiting) {
                                return ListView.separated(
                                  shrinkWrap: true,
                                  primary: false,
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const Divider(
                                      height: 1, color: AppColors.lightgrey),
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
                                    height: 1, color: AppColors.lightgrey),
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
                                        await HapticsService.heavyImpact();
                                        await FriendsService
                                            .declineFriendRequest(fromUid);
                                        if (context.mounted) {
                                          showFloatingSnack(
                                            context,
                                            message:
                                                'friends_request_declined'.tr(),
                                            backgroundColor: AppColors.primary,
                                            icon: Icons.cancel,
                                          );
                                        }
                                      } else {
                                        await HapticsService.mediumImpact();
                                        final ok = await FriendsService
                                            .acceptFriendRequest(fromUid);
                                        if (!context.mounted) return;
                                        if (ok) {
                                          setState(() {
                                            _dismissed.add(fromUid);
                                          });
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              content: Text(
                                                  'friends_request_accepted'
                                                      .tr()),
                                              action: SnackBarAction(
                                                label: 'friends_undo'.tr(),
                                                onPressed: () async {
                                                  // Best-effort undo: remove friend edges and re-create request
                                                  await FriendsService
                                                      .removeFriend(fromUid);
                                                  await FriendsService
                                                      .sendFriendRequestToUid(
                                                          fromUid);
                                                },
                                              ),
                                            ),
                                          );
                                        }
                                        showFloatingSnack(
                                          context,
                                          message: ok
                                              ? 'friends_request_accepted'.tr()
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
                                    child: Builder(builder: (context) {
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
                                          child: ImageCacheService
                                              .getOptimizedAvatar(
                                            imageUrl: photo,
                                            radius: 20,
                                            backgroundColor:
                                                _avatarBgFromName(name),
                                            foregroundColor: Colors.white,
                                            fallbackText: name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                          ),
                                        ),
                                        title: Text(
                                          name,
                                          style: AppTextStyles.body,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          'friends_request_from'
                                              .tr(args: [name]),
                                          style: AppTextStyles.small,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        // Compact actions to avoid overflow
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
                                                        minHeight: 48),
                                                onPressed: () async {
                                                  await HapticsService
                                                      .heavyImpact();
                                                  await FriendsService
                                                      .declineFriendRequest(
                                                          fromUid);
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
                                                icon: const Icon(Icons.cancel,
                                                    color: Colors.red),
                                              ),
                                              IconButton(
                                                tooltip:
                                                    'friends_accept_request'
                                                        .tr(),
                                                constraints:
                                                    const BoxConstraints(
                                                        minWidth: 48,
                                                        minHeight: 48),
                                                onPressed: () async {
                                                  debugPrint(
                                                      '🔍 UI: Accept tapped for $fromUid');
                                                  await HapticsService
                                                      .mediumImpact();
                                                  final ok =
                                                      await FriendsService
                                                          .acceptFriendRequest(
                                                              fromUid);
                                                  if (!context.mounted) return;
                                                  if (ok) {
                                                    setState(() {
                                                      _dismissed.add(fromUid);
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
                                                        : Icons.error_outline,
                                                  );
                                                  debugPrint(
                                                      '🔍 UI: Accept finished ok=$ok for $fromUid');
                                                },
                                                icon: const Icon(
                                                    Icons.check_circle,
                                                    color: AppColors.green),
                                              ),
                                              PopupMenuButton<String>(
                                                icon:
                                                    const Icon(Icons.more_vert),
                                                onSelected: (value) async {
                                                  if (value == 'report') {
                                                    final controller =
                                                        TextEditingController();
                                                    final ok =
                                                        await showDialog<bool>(
                                                              context: context,
                                                              builder: (ctx) =>
                                                                  AlertDialog(
                                                                title: Text(
                                                                    'friends_report_user'
                                                                        .tr()),
                                                                content:
                                                                    TextField(
                                                                  controller:
                                                                      controller,
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
                                                                              ctx,
                                                                              false),
                                                                      child: Text(
                                                                          'cancel'
                                                                              .tr())),
                                                                  TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                              ctx,
                                                                              true),
                                                                      child: Text(
                                                                          'ok'.tr())),
                                                                ],
                                                              ),
                                                            ) ??
                                                            false;
                                                    if (ok) {
                                                      final reason = controller
                                                          .text
                                                          .trim();
                                                      if (reason.isNotEmpty) {
                                                        await FriendsService
                                                            .reportUser(
                                                                targetUid:
                                                                    fromUid,
                                                                reason: reason);
                                                        if (context.mounted) {
                                                          showFloatingSnack(
                                                            context,
                                                            message:
                                                                'friends_report_submitted'
                                                                    .tr(),
                                                            backgroundColor:
                                                                AppColors
                                                                    .primary,
                                                            icon: Icons
                                                                .flag_outlined,
                                                          );
                                                        }
                                                      }
                                                    }
                                                  } else if (value == 'block') {
                                                    final ok =
                                                        await showDialog<bool>(
                                                              context: context,
                                                              builder: (ctx) =>
                                                                  AlertDialog(
                                                                title: Text(
                                                                    'are_you_sure'
                                                                        .tr()),
                                                                content: Text(
                                                                    'friends_confirm_block'
                                                                        .tr()),
                                                                actions: [
                                                                  TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                              ctx,
                                                                              false),
                                                                      child: Text(
                                                                          'cancel'
                                                                              .tr())),
                                                                  TextButton(
                                                                      onPressed: () =>
                                                                          Navigator.pop(
                                                                              ctx,
                                                                              true),
                                                                      child: Text(
                                                                          'ok'.tr())),
                                                                ],
                                                              ),
                                                            ) ??
                                                            false;
                                                    if (ok) {
                                                      await FriendsService
                                                          .blockUser(fromUid);
                                                      if (context.mounted) {
                                                        showFloatingSnack(
                                                          context,
                                                          message:
                                                              'friends_user_blocked'
                                                                  .tr(),
                                                          backgroundColor:
                                                              AppColors.primary,
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
                                                            .tr()),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'block',
                                                    child: Text(
                                                        'friends_block'.tr()),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Swipe support background handled by Dismissible wrapper above
                                        onTap: () {
                                          debugPrint(
                                              '🔍 UI: Request tile tapped for $fromUid');
                                        },
                                      );
                                    }),
                                  );
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
            // Sent section moved to Friends tab
          ],
        );
      },
    );
  }
}

class _SentRequests extends StatelessWidget {
  final String uid;
  const _SentRequests({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<String>>(
      stream: FriendsService.sentRequestsStream(uid),
      builder: (context, snapshot) {
        final sent = snapshot.data ?? const <String>[];
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
                future: FriendsService.fetchMinimalProfiles(sent),
                builder: (context, snap) {
                  final profiles =
                      snap.data ?? <String, Map<String, String?>>{};
                  return ListView.separated(
                    shrinkWrap: true,
                    primary: false,
                    itemCount: sent.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.lightgrey),
                    itemBuilder: (context, i) {
                      final toUid = sent[i];
                      final data = profiles[toUid] ??
                          const {'displayName': 'User', 'photoURL': null};
                      final name = data['displayName'] ?? 'User';
                      final photo = data['photoURL'];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.superlightgrey,
                          foregroundColor: AppColors.primary,
                          backgroundImage: (photo != null && photo.isNotEmpty)
                              ? CachedNetworkImageProvider(photo)
                              : null,
                          child: (photo == null || photo.isEmpty)
                              ? const Icon(Icons.outbox,
                                  color: AppColors.primary)
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
                            final ok =
                                await FriendsService.cancelSentFriendRequest(
                                    toUid);
                            if (!context.mounted) return;

                            if (ok) {
                              UndoHelpers.showSuccessWithUndo(
                                context,
                                'friend_request_cancelled',
                                onUndo: () async {
                                  await FriendsService.sendFriendRequestToUid(
                                      toUid);
                                },
                              );
                            } else {
                              ErrorHandlerService.showError(
                                  context, 'friends_request_cancel_failed');
                            }
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

// Removed AppBar title badge; badge is now on the Requests tab label

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
                return RateLimitFeedback(
                  uid: AuthService.currentUser?.uid ?? '',
                  child: _SuggestionCard(
                    suggestion: suggestion,
                    onAddFriend: () => _sendFriendRequest(suggestion['uid']),
                  ),
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
              ImageCacheService.getOptimizedAvatar(
                imageUrl: photoURL,
                radius: 30,
                fallbackText:
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
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

class _SwipeBg extends StatelessWidget {
  final Color color;
  final IconData icon;
  final bool alignLeft;
  const _SwipeBg(
      {required this.color, required this.icon, required this.alignLeft});

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

// Subtle gradient ring for avatars
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
        decoration:
            const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        padding: const EdgeInsets.all(2),
        child: child,
      ),
    );
  }
}

// Shimmer skeleton for request list items
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
                    height: 12, width: double.infinity, color: Colors.white),
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

// Deterministic background color for avatar initials based on name
Color _avatarBgFromName(String name) {
  if (name.isEmpty) return AppColors.superlightgrey;
  final code = name.codeUnits.fold<int>(0, (a, b) => (a + b) & 0xFF);
  final hue = (code % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.55, 0.55).toColor();
}

class _QrBottomSheetContent extends StatelessWidget {
  const _QrBottomSheetContent();

  @override
  Widget build(BuildContext context) {
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
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
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
          onPressed: () => Navigator.of(context).pop(),
          child: Text('ok'.tr()),
        ),
      ],
    );
  }
}
