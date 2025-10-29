import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:move_young/services/auth/auth_provider.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/app_back_button.dart';
import 'package:move_young/services/system/haptics_provider.dart';
import 'package:move_young/services/system/profile_settings_provider.dart';
import 'package:move_young/screens/settings/notification_settings_screen.dart';

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
  void dispose() {
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    setState(() => _submitting = true);
    try {
      final authActions = ref.read(authActionsProvider);
      final ok = await authActions.deleteAccount();
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      if (ok == true) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('settings_account_deleted'.tr())),
        );
        navigator.pop();
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text('settings_account_delete_failed'.tr()),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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

  Future<void> _saveSettings() async {
    setState(() => _submitting = true);
    try {
      final hapticsActions = ref.read(hapticsActionsProvider);
      if (hapticsActions != null) {
        await hapticsActions.setEnabled(_haptics);
      }
      final uid = ref.read(currentUserIdProvider);
      if (uid != null && uid.isNotEmpty) {
        final profileSettingsActions = ref.read(profileSettingsActionsProvider);
        await profileSettingsActions.setVisibility(_visibility);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings_prefs_saved'.tr())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('loading_error'.tr()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
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
        actions: [
          TextButton(
            onPressed: _submitting ? null : _saveSettings,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              disabledForegroundColor: AppColors.grey,
            ),
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: AppPaddings.symmHorizontalReg.copyWith(
            top: AppSpacing.lg,
            bottom: AppSpacing.lg,
          ),
          children: [
            _buildSectionCard(
              title: 'settings_profile'.tr(),
              child: Builder(builder: (context) {
                final uid = ref.read(currentUserIdProvider);
                if (uid == null || uid.isEmpty) {
                  return Text('guest_user'.tr(),
                      style: AppTextStyles.smallMuted);
                }
                return StreamBuilder<String>(
                  stream: ref
                      .read(profileSettingsActionsProvider)
                      .visibilityStream(uid),
                  builder: (context, snapshot) {
                    final value = snapshot.data ?? _visibility;
                    _visibility = value;
                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('settings_profile_visibility'.tr()),
                          subtitle: Text(
                            value == 'friends'
                                ? 'settings_profile_friends_desc'.tr()
                                : value == 'private'
                                    ? 'settings_profile_private_desc'.tr()
                                    : 'settings_profile_public_desc'.tr(),
                          ),
                        ),
                        // ignore: deprecated_member_use
                        RadioListTile<String>(
                          value: 'public',
                          // ignore: deprecated_member_use
                          groupValue: value,
                          // ignore: deprecated_member_use
                          onChanged: (v) => ref
                              .read(profileSettingsActionsProvider)
                              .setVisibility('public'),
                          title: Text('settings_profile_public'.tr()),
                          contentPadding: EdgeInsets.zero,
                        ),
                        // ignore: deprecated_member_use
                        RadioListTile<String>(
                          value: 'friends',
                          // ignore: deprecated_member_use
                          groupValue: value,
                          // ignore: deprecated_member_use
                          onChanged: (v) => ref
                              .read(profileSettingsActionsProvider)
                              .setVisibility('friends'),
                          title: Text('settings_profile_friends'.tr()),
                          contentPadding: EdgeInsets.zero,
                        ),
                        // ignore: deprecated_member_use
                        RadioListTile<String>(
                          value: 'private',
                          // ignore: deprecated_member_use
                          groupValue: value,
                          // ignore: deprecated_member_use
                          onChanged: (v) => ref
                              .read(profileSettingsActionsProvider)
                              .setVisibility('private'),
                          title: Text('settings_profile_private'.tr()),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const Divider(height: 1, color: AppColors.lightgrey),
                        Builder(builder: (context) {
                          final uid = ref.read(currentUserIdProvider);
                          if (uid == null || uid.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return StreamBuilder<Map<String, dynamic>>(
                            stream: ref
                                .read(profileSettingsActionsProvider)
                                .settingsStream(uid),
                            builder: (context, snapshot) {
                              final settings = snapshot.data ?? {};
                              final showOnline = settings['showOnline'] ?? true;
                              final visibility =
                                  settings['visibility'] ?? 'public';

                              final shareEmail = settings['shareEmail'] ?? true;

                              return Column(
                                children: [
                                  SwitchListTile(
                                    value:
                                        showOnline && visibility != 'private',
                                    onChanged: visibility == 'private'
                                        ? null
                                        : (value) async {
                                            await ref
                                                .read(
                                                    profileSettingsActionsProvider)
                                                .setShowOnline(value);
                                          },
                                    title: Text('settings_show_online'.tr()),
                                    subtitle: Text(
                                      visibility == 'private'
                                          ? 'settings_show_online_disabled_private'
                                              .tr()
                                          : 'settings_show_online_desc'.tr(),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  const Divider(
                                      height: 1, color: AppColors.lightgrey),
                                  SwitchListTile(
                                    value:
                                        shareEmail && visibility != 'private',
                                    onChanged: visibility == 'private'
                                        ? null
                                        : (value) async {
                                            await ref
                                                .read(
                                                    profileSettingsActionsProvider)
                                                .setShareEmail(value);
                                          },
                                    title: Text('settings_share_email'.tr()),
                                    subtitle: Text(
                                      visibility == 'private'
                                          ? 'settings_show_online_disabled_private'
                                              .tr()
                                          : 'settings_share_email_desc'.tr(),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ],
                              );
                            },
                          );
                        }),
                      ],
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSectionCard(
              title: 'settings_notifications'.tr(),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_outlined),
                title: Text('settings_notifications'.tr()),
                subtitle: Text('settings_notifications_enabled_desc'.tr()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSectionCard(
              title: 'settings_games_preferences'.tr(),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _haptics,
                    onChanged: (v) async {
                      setState(() => _haptics = v);
                      final hapticsActions = ref.read(hapticsActionsProvider);
                      if (hapticsActions != null) {
                        await hapticsActions.setEnabled(v);
                      }
                    },
                    title: Text('settings_haptics'.tr()),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSectionCard(
              title: 'settings_account_actions'.tr(),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _submitting ? null : _handleDeleteTapped,
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  label: Text('settings_delete_account'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
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
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

// (Game invites and reminders toggles removed)
