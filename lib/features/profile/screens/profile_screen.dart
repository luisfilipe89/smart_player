import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/features/profile/services/profile_settings_provider.dart';
import 'package:move_young/utils/profanity.dart';
import 'package:move_young/widgets/app_back_button.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/services/firebase_error_handler.dart';
import 'package:move_young/utils/logger.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _saving = false;
  bool _loadingDetails = true;
  bool _changingEmail = false;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
    }

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) {
      if (mounted) setState(() => _loadingDetails = false);
      return;
    }

    try {
      final data =
          await ref.read(profileSettingsActionsProvider).getUserProfile(uid);
      if (data != null) {
        final dob = int.tryParse('${data['dateOfBirth'] ?? ''}');
        if (dob != null && dob > 0) {
          _dateOfBirth = DateTime.fromMillisecondsSinceEpoch(dob);
        }
      }
    } catch (e, stack) {
      NumberedLogger.e('Error loading user profile details: $e');
      NumberedLogger.d('Stack trace: $stack');
    }
    if (mounted) setState(() => _loadingDetails = false);
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();

    if (newName.isEmpty) return;
    if (newName.length > 24) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Name too long (max 24).')),
        );
      }
      return;
    }
    if (!Profanity.isNameAllowed(newName)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('auth_name_inappropriate'.tr())),
        );
      }
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authActionsProvider).updateProfile(displayName: newName);
      final uid = ref.read(currentUserIdProvider);
      if (uid != null) {
        await ref.read(profileSettingsActionsProvider).updateUserProfile(uid, {
          'dateOfBirth': _dateOfBirth?.millisecondsSinceEpoch ?? '',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMessage = FirebaseErrorHandler.getUserMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: Text('profile'.tr()),
        backgroundColor: AppColors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveProfile,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              disabledForegroundColor: AppColors.grey,
            ),
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('save'.tr()),
          )
        ],
      ),
      body: SafeArea(
        child: _loadingDetails
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: AppPaddings.symmHorizontalReg.copyWith(
                  top: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                ),
                children: [
                  // Profile avatar (no upload/change)
                  _buildSectionCard(
                    child: Column(
                      children: [
                        Hero(
                          tag: 'avatar-${user?.uid ?? 'me'}',
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: AppColors.lightgrey,
                            child: const Icon(
                              Icons.person,
                              size: 52,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Basic Details Section
                  _buildSectionCard(
                    title: 'profile_basic_details'.tr(),
                    child: Column(
                      children: [
                        _buildInputTile(
                          icon: Icons.person_outline,
                          title: 'profile_display_name'.tr(),
                          child: TextField(
                            controller: _nameController,
                            textInputAction: TextInputAction.done,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(24),
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Enter your nickname or first name',
                            ),
                            onSubmitted: (_) => _saveProfile(),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.lightgrey),
                        _buildInputTile(
                          icon: Icons.cake_outlined,
                          title: 'profile_date_of_birth'.tr(),
                          child: InkWell(
                            onTap: _pickDob,
                            child: Text(
                              _dateOfBirth == null
                                  ? 'profile_pick_date'.tr()
                                  : DateFormat.yMMMMd().format(_dateOfBirth!),
                              style: AppTextStyles.body.copyWith(
                                color: _dateOfBirth == null
                                    ? AppColors.grey
                                    : AppColors.text,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Account Section
                  if (email.isNotEmpty)
                    _buildSectionCard(
                      title: 'profile_account'.tr(),
                      child: Column(
                        children: [
                          _buildLinkTile(
                            icon: Icons.email_outlined,
                            title: 'profile_email'.tr(),
                            subtitle: email,
                            onTap: _changingEmail ? null : _changeEmail,
                            trailing: _changingEmail
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.edit, size: 16),
                          ),
                          const Divider(height: 1, color: AppColors.lightgrey),
                          _buildLinkTile(
                            icon: Icons.lock_outline,
                            title: 'profile_change_password'.tr(),
                            onTap: () => _showChangePasswordDialog(),
                            trailingChevron: true,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionCard({String? title, required Widget child}) {
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
          if (title != null) ...[
            Text(title, style: AppTextStyles.h3),
            const SizedBox(height: AppSpacing.sm),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
    bool trailingChevron = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.body),
      subtitle:
          subtitle != null ? Text(subtitle, style: AppTextStyles.small) : null,
      trailing: trailing ??
          (trailingChevron ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }

  Widget _buildInputTile({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: const VisualDensity(vertical: -3),
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.body),
      subtitle: child,
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showCurrentPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('profile_change_password'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: !showCurrentPassword,
                  maxLength: 128,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(128),
                  ],
                  decoration: InputDecoration(
                    labelText: 'settings_current_password'.tr(),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(showCurrentPassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () => setState(
                          () => showCurrentPassword = !showCurrentPassword),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: newPasswordController,
                  obscureText: !showNewPassword,
                  maxLength: 128,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(128),
                  ],
                  decoration: InputDecoration(
                    labelText: 'settings_new_password'.tr(),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(showNewPassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => showNewPassword = !showNewPassword),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: !showConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'settings_confirm_password'.tr(),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(showConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () => setState(
                          () => showConfirmPassword = !showConfirmPassword),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isSubmitting ? null : () => Navigator.of(context).pop(),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final current = currentPasswordController.text.trim();
                      final newPassword = newPasswordController.text.trim();
                      final confirm = confirmPasswordController.text.trim();

                      if (current.isEmpty ||
                          newPassword.isEmpty ||
                          confirm.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('form_fill_all_fields'.tr())),
                        );
                        return;
                      }

                      if (newPassword != confirm) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('settings_passwords_no_match'.tr())),
                        );
                        return;
                      }

                      if (newPassword.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('auth_password_too_short'.tr())),
                        );
                        return;
                      }

                      setState(() => isSubmitting = true);
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await ref
                            .read(authActionsProvider)
                            .changePassword(current, newPassword);
                        if (!context.mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('settings_password_changed'.tr()),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        String errorMessage = e
                            .toString()
                            .replaceFirst(RegExp(r'^Exception:\s*'), '');

                        // Handle specific authentication errors
                        if (errorMessage
                            .contains('Current password is incorrect')) {
                          errorMessage = 'settings_wrong_current_password'.tr();
                        } else if (errorMessage
                            .contains('Please sign in again')) {
                          errorMessage = 'settings_requires_recent_login'.tr();
                        } else if (errorMessage.contains('too weak')) {
                          errorMessage = 'settings_weak_password'.tr();
                        } else if (errorMessage
                            .contains('No email on account')) {
                          errorMessage = 'settings_no_email_on_account'.tr();
                        }

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        if (context.mounted) {
                          setState(() => isSubmitting = false);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('profile_change_password'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeEmail() async {
    final currentEmail = ref.read(currentUserProvider).value?.email ?? '';
    if (currentEmail.isEmpty) return;

    final bool hasPassword = ref.read(authActionsProvider).hasPasswordProvider;
    final newEmailController = TextEditingController(text: currentEmail);
    final currentPasswordController = TextEditingController();
    bool showPassword = false;
    bool isSubmitting = false;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('profile_change_email'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'profile_change_email_description'.tr(),
                  style: AppTextStyles.small,
                ),
                const SizedBox(height: AppSpacing.md),
                if (hasPassword) ...[
                  TextField(
                    controller: currentPasswordController,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      labelText: 'settings_current_password'.tr(),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(() {
                          showPassword = !showPassword;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ] else ...[
                  Text(
                    'settings_google_account_hint'.tr(),
                    style: AppTextStyles.smallMuted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                TextField(
                  controller: newEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'profile_new_email'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (!hasPassword)
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        // Allow social users to set a password via reset email
                        try {
                          final messenger = ScaffoldMessenger.of(context);
                          setState(() => isSubmitting = true);
                          await ref
                              .read(authActionsProvider)
                              .sendPasswordResetEmail(currentEmail);
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('settings_reset_email_sent'.tr()),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          final msg = e
                              .toString()
                              .replaceFirst(RegExp(r'^Exception:\s*'), '');
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            SnackBar(
                                content: Text(msg),
                                backgroundColor: Colors.red),
                          );
                        } finally {
                          if (context.mounted) {
                            setState(() => isSubmitting = false);
                          }
                        }
                      },
                child: Text('settings_send_reset_email'.tr()),
              ),
            TextButton(
              onPressed:
                  isSubmitting ? null : () => Navigator.of(context).pop(false),
              child: Text('cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      final newEmail = newEmailController.text.trim();
                      if (newEmail.isEmpty || newEmail == currentEmail) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('auth_email_invalid'.tr())),
                        );
                        return;
                      }

                      setState(() => isSubmitting = true);
                      try {
                        if (hasPassword) {
                          final currentPw =
                              currentPasswordController.text.trim();
                          if (currentPw.isEmpty) {
                            messenger.showSnackBar(
                              SnackBar(
                                  content: Text('form_fill_all_fields'.tr())),
                            );
                            setState(() => isSubmitting = false);
                            return;
                          }
                          await ref.read(authActionsProvider).changeEmail(
                                currentPassword: currentPw,
                                newEmail: newEmail,
                              );
                        } else {
                          await ref
                              .read(authActionsProvider)
                              .updateEmail(newEmail);
                        }

                        if (!context.mounted) return;
                        navigator.pop(true);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('profile_email_changed'.tr()),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        String errorMessage = e
                            .toString()
                            .replaceFirst(RegExp(r'^Exception:\s*'), '');

                        if (errorMessage.contains('Invalid email')) {
                          errorMessage = 'auth_email_invalid'.tr();
                        } else if (errorMessage.contains('already in use')) {
                          errorMessage = 'error_email_in_use'.tr();
                        } else if (errorMessage
                            .contains('Current password is incorrect')) {
                          errorMessage = 'settings_wrong_current_password'.tr();
                        } else if (errorMessage
                            .contains('Please sign in again')) {
                          errorMessage = 'settings_requires_recent_login'.tr();
                        }

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        if (context.mounted) {
                          setState(() => isSubmitting = false);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('profile_change_email'.tr()),
            ),
          ],
        ),
      ),
    );

    if (submitted == true) {
      setState(() => _changingEmail = false);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'profile_date_of_birth'.tr(),
      builder: (context, child) {
        // Force a neutral theme to avoid any pinkish accent from platform/theme
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.white,
              onSurface: AppColors.text,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppColors.white,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

}
