import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/features/auth/services/auth_provider.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/widgets/app_back_button.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:move_young/features/settings/screens/notification_settings_screen.dart';
import 'package:move_young/models/infrastructure/service_error.dart';
import 'package:move_young/services/firebase_error_handler.dart';
import 'package:move_young/features/profile/services/profile_settings_provider.dart';
import 'package:move_young/providers/infrastructure/firebase_providers.dart';
import 'package:move_young/db/db_paths.dart';
import 'package:move_young/utils/logger.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _submitting = false;
  bool _haptics = true;
  String _visibility = 'public';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileSettings();
      _loadHapticsSettings();
    });
  }

  Future<void> _loadHapticsSettings() async {
    final hapticsActions = ref.read(hapticsActionsProvider);
    if (hapticsActions != null) {
      try {
        final hapticsService = ref.read(hapticsServiceProvider);
        if (hapticsService != null) {
          // Initialize the service to load saved preferences
          await hapticsService.initialize();
          final isEnabled = await hapticsActions.isEnabled();
          if (mounted) {
            setState(() {
              _haptics = isEnabled;
            });
          }
        }
      } catch (e) {
        // Settings will use defaults
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadProfileSettings() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    final profileActions = ref.read(profileSettingsActionsProvider);
    try {
      final visibility = await profileActions.getVisibility(uid);

      if (mounted) {
        setState(() {
          _visibility = visibility;
        });
      }
    } catch (e) {
      // Settings will use defaults
    }
  }

  Future<void> _deleteAccount({bool allowReauthRetry = true}) async {
    setState(() => _submitting = true);
    try {
      // Get user ID before deletion (will be null after deletion)
      final uid = ref.read(currentUserIdProvider);
      
      final authActions = ref.read(authActionsProvider);
      final result = await authActions.deleteAccount();
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      if (result.isSuccess) {
        // Delete user's database entry to trigger cleanup Cloud Function
        if (uid != null) {
          try {
            final database = ref.read(firebaseDatabaseProvider);
            await database.ref('${DbPaths.users}/$uid').remove();
          } catch (e) {
            // Log error but don't fail the deletion - auth is already deleted
            // The database entry will remain, but auth is gone
            NumberedLogger.w('Failed to delete user database entry: $e');
          }
        }
        
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('settings_account_deleted'.tr())),
        );
        navigator.pop();
        return;
      }

      if (result.needsReauthentication && allowReauthRetry) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('settings_delete_requires_recent_login'.tr())),
        );
        setState(() => _submitting = false);
        final reauthenticated = await _handleReauthenticationFlow();
        if (reauthenticated) {
          await _deleteAccount(allowReauthRetry: false);
        }
        return;
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('settings_account_delete_failed'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final errorMessage = FirebaseErrorHandler.getUserMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool> _handleReauthenticationFlow() async {
    final authActions = ref.read(authActionsProvider);
    if (!authActions.hasPasswordProvider) {
      if (!mounted) return false;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('settings_delete_reauth_title'.tr()),
          content: Text('settings_delete_reauth_other_providers'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
      return false;
    }

    while (mounted) {
      final password = await _promptForPassword();
      if (password == null) {
        return false;
      }
      try {
        await authActions.reauthenticateWithPassword(password);
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings_delete_reauth_success'.tr())),
        );
        return true;
      } on ServiceException catch (e) {
        if (!mounted) return false;
        final message = e.message.tr();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      } catch (_) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings_delete_reauth_failed'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    return false;
  }

  Future<String?> _promptForPassword() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? password;
    try {
      password = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          bool obscure = true;
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: AppSpacing.lg,
                    right: AppSpacing.lg,
                    top: AppSpacing.lg,
                    bottom: AppSpacing.lg + bottomInset,
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'settings_delete_reauth_title'.tr(),
                          style: AppTextStyles.h3,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'settings_delete_reauth_subtitle'.tr(),
                          style: AppTextStyles.bodyMuted,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextFormField(
                          controller: controller,
                          obscureText: obscure,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'settings_delete_password_hint'.tr(),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.card),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setSheetState(() => obscure = !obscure),
                            ),
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'settings_delete_password_error'.tr()
                              : null,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (formKey.currentState?.validate() ?? false) {
                              Navigator.of(sheetContext)
                                  .pop(controller.text.trim());
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(sheetContext).pop(),
                                child: Text('cancel'.tr()),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (formKey.currentState?.validate() ??
                                      false) {
                                    Navigator.of(sheetContext)
                                        .pop(controller.text.trim());
                                  }
                                },
                                child: Text('settings_delete_continue'.tr()),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
      return password;
    } finally {
      controller.dispose();
    }
  }

  Future<void> _handleDeleteTapped() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('settings_confirm_delete_title'.tr()),
            content: Text('settings_confirm_delete_message'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('cancel'.tr()),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('settings_delete_account'.tr()),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    // Stronger haptic for destructive action
    await ref.read(hapticsActionsProvider)?.heavyImpact();
    await _deleteAccount();
  }

  Future<void> _handleVisibilityChange(String newVisibility) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    try {
      final profileActions = ref.read(profileSettingsActionsProvider);
      await profileActions.setVisibility(newVisibility);
      
      if (mounted) {
        setState(() {
          _visibility = newVisibility;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings_prefs_saved'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('settings_save_error'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showVisibilityDialog() async {
    final selectedVisibility = ValueNotifier<String>(_visibility);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('settings_profile_visibility'.tr()),
        content: ValueListenableBuilder<String>(
          valueListenable: selectedVisibility,
          builder: (context, value, child) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  value == 'public' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: value == 'public' ? AppColors.primary : AppColors.grey,
                ),
                title: Text('settings_profile_public'.tr()),
                subtitle: Text('settings_profile_public_desc'.tr()),
                onTap: () {
                  selectedVisibility.value = 'public';
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  value == 'friends' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: value == 'friends' ? AppColors.primary : AppColors.grey,
                ),
                title: Text('settings_profile_friends'.tr()),
                subtitle: Text('settings_profile_friends_desc'.tr()),
                onTap: () {
                  selectedVisibility.value = 'friends';
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  value == 'private' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: value == 'private' ? AppColors.primary : AppColors.grey,
                ),
                title: Text('settings_profile_private'.tr()),
                subtitle: Text('settings_profile_private_desc'.tr()),
                onTap: () {
                  selectedVisibility.value = 'private';
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr()),
          ),
          ValueListenableBuilder<String>(
            valueListenable: selectedVisibility,
            builder: (context, value, child) => ElevatedButton(
              onPressed: () => Navigator.of(context).pop(value),
              child: Text('ok'.tr()),
            ),
          ),
        ],
      ),
    );

    if (result != null && result != _visibility) {
      await _handleVisibilityChange(result);
    }
  }

  String _getVisibilityLabel() {
    switch (_visibility) {
      case 'public':
        return 'settings_profile_public'.tr();
      case 'friends':
        return 'settings_profile_friends'.tr();
      case 'private':
        return 'settings_profile_private'.tr();
      default:
        return 'settings_profile_public'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch haptics enabled state reactively
    ref.listen(hapticsEnabledProvider, (previous, next) {
      next.whenData((isEnabled) {
        if (mounted && isEnabled != _haptics) {
          setState(() => _haptics = isEnabled);
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: Text('settings'.tr()),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: AppPaddings.symmHorizontalReg.copyWith(
            top: AppSpacing.lg,
            bottom: AppSpacing.lg,
          ),
          children: [
            _buildSectionCard(
              child: Column(
                children: [
                  _buildLinkTile(
                    icon: Icons.notifications_outlined,
                    title: 'settings_notifications'.tr(),
                    subtitle: 'settings_notifications_enabled_desc'.tr(),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationSettingsScreen(),
                        ),
                      );
                    },
                    trailingChevron: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSectionCard(
              child: Column(
                children: [
                  _buildLinkTile(
                    icon: Icons.visibility_outlined,
                    title: 'settings_profile_visibility'.tr(),
                    subtitle: _getVisibilityLabel(),
                    onTap: _showVisibilityDialog,
                    trailingChevron: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSectionCard(
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.vibration,
                    title: 'settings_haptics'.tr(),
                    value: _haptics,
                    onChanged: (v) async {
                      setState(() => _haptics = v);
                      final hapticsActions = ref.read(hapticsActionsProvider);
                      if (hapticsActions != null) {
                        await hapticsActions.setEnabled(v);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSectionCard(
              child: Column(
                children: [
                  _buildLinkTile(
                    icon: Icons.delete_forever_outlined,
                    title: 'settings_delete_account'.tr(),
                    onTap: _submitting ? null : _handleDeleteTapped,
                    iconColor: AppColors.red,
                    titleColor: AppColors.red,
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
    bool trailingChevron = false,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: iconColor ?? AppColors.primary),
      title: Text(title, style: AppTextStyles.body.copyWith(
        color: titleColor,
      )),
      subtitle: subtitle != null
          ? Text(subtitle, style: AppTextStyles.small)
          : null,
      trailing: trailingChevron ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.body),
      subtitle: subtitle != null
          ? Text(subtitle, style: AppTextStyles.small)
          : null,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
    );
  }
}

// (Match invites and reminders toggles removed)
