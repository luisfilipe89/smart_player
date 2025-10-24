// lib/screens/friends/email_input_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:move_young/providers/services/friends_provider.dart';
import 'package:move_young/providers/services/auth_provider.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/theme/app_back_button.dart';

class EmailInputScreen extends ConsumerStatefulWidget {
  const EmailInputScreen({super.key});

  @override
  ConsumerState<EmailInputScreen> createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends ConsumerState<EmailInputScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _searchUsers() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'email_required'.tr();
      });
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() {
        _errorMessage = 'email_invalid'.tr();
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final friendsActions = ref.read(friendsActionsProvider);
      final users = await friendsActions.searchUsersByEmail(email);

      if (mounted) {
        if (users.isEmpty) {
          setState(() {
            _errorMessage = 'email_no_users_found'.tr();
            _isLoading = false;
          });
        } else {
          _showUserResults(users);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'email_search_error'.tr();
          _isLoading = false;
        });
      }
    }
  }

  void _showUserResults(List<Map<String, String>> users) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserSearchResultsScreen(users: users),
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: Text('email_search_title'.tr()),
      ),
      body: Padding(
        padding: AppPaddings.allMedium,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              'email_search_description'.tr(),
              style: AppTextStyles.body.copyWith(
                color: AppColors.grey,
              ),
            ),

            const SizedBox(height: AppHeights.superHuge),

            // Email input
            TextField(
              controller: _emailController,
              focusNode: _emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'email_address'.tr(),
                hintText: 'email_placeholder'.tr(),
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                errorText: _errorMessage,
              ),
              onSubmitted: (_) => _searchUsers(),
            ),

            const SizedBox(height: AppHeights.superHuge),

            // Search button
            ElevatedButton(
              onPressed: _isLoading ? null : _searchUsers,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: AppPaddings.allMedium,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text('search_users'.tr()),
            ),

            const SizedBox(height: AppHeights.huge),

            // Info text
            Container(
              padding: AppPaddings.allMedium,
              decoration: BoxDecoration(
                color: AppColors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppColors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: AppWidths.small),
                  Expanded(
                    child: Text(
                      'email_search_info'.tr(),
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserSearchResultsScreen extends ConsumerWidget {
  final List<Map<String, String>> users;

  const UserSearchResultsScreen({
    super.key,
    required this.users,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: Text('search_results'.tr()),
      ),
      body: ListView.builder(
        padding: AppPaddings.allMedium,
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final userId = user['uid']!;
          final displayName = user['displayName'] ?? 'Unknown User';
          final photoURL = user['photoURL'];

          // Don't show current user
          if (userId == currentUserId) {
            return const SizedBox.shrink();
          }

          return Card(
            margin: AppPaddings.bottomSmall,
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: photoURL != null && photoURL.isNotEmpty
                    ? NetworkImage(photoURL)
                    : null,
                child: photoURL == null || photoURL.isEmpty
                    ? Text(displayName[0].toUpperCase())
                    : null,
              ),
              title: Text(displayName),
              subtitle: Text('tap_to_send_request'.tr()),
              trailing: ElevatedButton(
                onPressed: () => _sendFriendRequest(context, ref, userId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text('send_request'.tr()),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendFriendRequest(
      BuildContext context, WidgetRef ref, String userId) async {
    try {
      final friendsActions = ref.read(friendsActionsProvider);
      final success = await friendsActions.sendFriendRequest(userId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'friend_request_sent'.tr()
                  : 'friend_request_failed'.tr(),
            ),
            backgroundColor: success ? AppColors.green : AppColors.red,
          ),
        );

        if (success) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('friend_request_error'.tr()),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }
}
