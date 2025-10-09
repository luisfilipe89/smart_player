import 'package:flutter/material.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/app_back_button.dart';
import 'package:move_young/services/haptics_service.dart';
import 'package:move_young/services/profile_settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
      final ok = await AuthService.deleteAccount();
      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      if (ok) {
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
    await _deleteAccount();
  }

  Future<void> _saveSettings() async {
    setState(() => _submitting = true);
    try {
      await HapticsService.setEnabled(_haptics);
      final uid = AuthService.currentUserId;
      if (uid != null) {
        await ProfileSettingsService.setVisibility(_visibility);
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
    // ensure we reflect persisted state once available
    HapticsService.isEnabled().then((v) {
      if (mounted && v != _haptics) setState(() => _haptics = v);
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
                final uid = AuthService.currentUserId;
                if (uid == null) {
                  return Text('guest_user'.tr(),
                      style: AppTextStyles.smallMuted);
                }
                return StreamBuilder<String>(
                  stream: ProfileSettingsService.visibilityStream(uid),
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
                        RadioListTile<String>(
                          value: 'public',
                          groupValue: value,
                          onChanged: (v) =>
                              ProfileSettingsService.setVisibility('public'),
                          title: Text('settings_profile_public'.tr()),
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<String>(
                          value: 'friends',
                          groupValue: value,
                          onChanged: (v) =>
                              ProfileSettingsService.setVisibility('friends'),
                          title: Text('settings_profile_friends'.tr()),
                          contentPadding: EdgeInsets.zero,
                        ),
                        RadioListTile<String>(
                          value: 'private',
                          groupValue: value,
                          onChanged: (v) =>
                              ProfileSettingsService.setVisibility('private'),
                          title: Text('settings_profile_private'.tr()),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const Divider(height: 1, color: AppColors.lightgrey),
                        Builder(builder: (context) {
                          final uid = AuthService.currentUserId;
                          if (uid == null) {
                            return const SizedBox.shrink();
                          }
                          return StreamBuilder<Map<String, dynamic>>(
                            stream: ProfileSettingsService.settingsStream(uid),
                            builder: (context, snapshot) {
                              final settings = snapshot.data ?? {};
                              final showOnline = settings['showOnline'] ?? true;
                              final visibility =
                                  settings['visibility'] ?? 'public';

                              return SwitchListTile(
                                value: showOnline && visibility != 'private',
                                onChanged: visibility == 'private'
                                    ? null
                                    : (value) async {
                                        await ProfileSettingsService
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
              title: 'settings_notifications_tba'.tr(),
              child: Text(
                '',
                style: AppTextStyles.smallMuted,
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
                      await HapticsService.setEnabled(v);
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
