import 'package:flutter/material.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/app_back_button.dart';
import 'package:move_young/services/friends_service.dart';
import 'package:move_young/services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _submitting = false;
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _emailCurrentPassCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();
  bool _showPwd1 = false;
  bool _showPwd2 = false;
  bool _showPwd3 = false;
  bool _showEmailPwd = false;

  bool _haptics = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _emailCurrentPassCtrl.dispose();
    _newEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentCtrl.text.trim();
    final next = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('form_fill_all_fields'.tr())),
      );
      return;
    }
    if (next != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings_passwords_no_match'.tr())),
      );
      return;
    }
    if (next.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth_password_too_short'.tr())),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await AuthService.changePassword(
        currentPassword: current,
        newPassword: next,
      );
      if (!mounted) return;
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings_password_changed'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _changeEmail() async {
    final pass = _emailCurrentPassCtrl.text.trim();
    final newEmail = _newEmailCtrl.text.trim();
    if (pass.isEmpty || newEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('form_fill_all_fields'.tr())),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await AuthService.changeEmail(
        currentPassword: pass,
        newEmail: newEmail,
      );
      if (!mounted) return;
      _emailCurrentPassCtrl.clear();
      _newEmailCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings_email_updated_check_inbox'.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final isPasswordUser = AuthService.hasPasswordProvider;

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
              title: 'settings_account'.tr(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPasswordUser) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline,
                          color: AppColors.primary),
                      title: Text('settings_change_password'.tr()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showChangePasswordDialog,
                    ),
                    const Divider(height: 1, color: AppColors.lightgrey),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.mail_outline,
                          color: AppColors.primary),
                      title: Text('settings_change_email'.tr()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showChangeEmailDialog,
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('settings_google_account_hint'.tr(),
                          style: AppTextStyles.body),
                    ),
                  ],
                ],
              ),
            ),
            // change email moved into action tile above
            const SizedBox(height: AppSpacing.lg),
            _buildSectionCard(
              title: 'settings_friends_preferences'.tr(),
              child: Column(
                children: [
                  _AllowRequestsTile(),
                  const Divider(height: 1, color: AppColors.lightgrey),
                  _FriendsNotifPrefs(),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildSectionCard(
              title: 'settings_games_preferences'.tr(),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _haptics,
                    onChanged: (v) => setState(() => _haptics = v),
                    title: Text('settings_haptics'.tr()),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(height: 1, color: AppColors.lightgrey),
                  _GamesNotifPrefs(),
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
            const SizedBox(height: AppSpacing.lg),
            _buildSectionCard(
              title: 'settings_blocked_users'.tr(),
              child: _BlockedUsersPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    _currentCtrl.clear();
    _newCtrl.clear();
    _confirmCtrl.clear();
    _showPwd1 = _showPwd2 = _showPwd3 = false;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('settings_change_password'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _currentCtrl,
                  obscureText: !_showPwd1,
                  decoration: InputDecoration(
                    labelText: 'settings_current_password'.tr(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _showPwd1 ? Icons.visibility : Icons.visibility_off),
                      onPressed: () =>
                          setStateDialog(() => _showPwd1 = !_showPwd1),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _newCtrl,
                  obscureText: !_showPwd2,
                  decoration: InputDecoration(
                    labelText: 'settings_new_password'.tr(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _showPwd2 ? Icons.visibility : Icons.visibility_off),
                      onPressed: () =>
                          setStateDialog(() => _showPwd2 = !_showPwd2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: !_showPwd3,
                  decoration: InputDecoration(
                    labelText: 'settings_confirm_new_password'.tr(),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _showPwd3 ? Icons.visibility : Icons.visibility_off),
                      onPressed: () =>
                          setStateDialog(() => _showPwd3 = !_showPwd3),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        await _changePassword();
                        if (mounted) navigator.pop();
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('settings_change_password'.tr()),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _showChangeEmailDialog() async {
    _newEmailCtrl.clear();
    _emailCurrentPassCtrl.clear();
    _showEmailPwd = false;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('settings_change_email'.tr()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _newEmailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      InputDecoration(labelText: 'settings_new_email'.tr()),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _emailCurrentPassCtrl,
                  obscureText: !_showEmailPwd,
                  decoration: InputDecoration(
                    labelText: 'settings_current_password'.tr(),
                    suffixIcon: IconButton(
                      icon: Icon(_showEmailPwd
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setStateDialog(() => _showEmailPwd = !_showEmailPwd),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('cancel'.tr()),
              ),
              ElevatedButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        await _changeEmail();
                        if (mounted) navigator.pop();
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white),
                child: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('settings_change_email'.tr()),
              ),
            ],
          );
        });
      },
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

class _BlockedUsersPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUserId;
    if (uid == null) {
      return Text('guest_user'.tr(), style: AppTextStyles.smallMuted);
    }
    return StreamBuilder<List<String>>(
      stream: FriendsService.blockedUsersStream(uid),
      builder: (context, snapshot) {
        final blocked = snapshot.data ?? const <String>[];
        if (blocked.isEmpty) {
          return Text('settings_no_blocked_users'.tr(),
              style: AppTextStyles.smallMuted);
        }
        return ListView.separated(
          shrinkWrap: true,
          primary: false,
          itemCount: blocked.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: AppColors.lightgrey),
          itemBuilder: (context, i) {
            final otherUid = blocked[i];
            return FutureBuilder<Map<String, String?>>(
              future: FriendsService.fetchMinimalProfile(otherUid),
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
                    backgroundImage: (photo != null && photo.isNotEmpty)
                        ? NetworkImage(photo)
                        : null,
                    child: (photo == null || photo.isEmpty)
                        ? Text(name[0].toUpperCase())
                        : null,
                  ),
                  title: Text(name),
                  trailing: TextButton(
                    onPressed: () => FriendsService.unblockUser(otherUid),
                    child: Text('settings_unblock'.tr()),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AllowRequestsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUserId;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<bool>(
      stream: FriendsService.allowRequestsStream(uid),
      builder: (context, snapshot) {
        final allow = snapshot.data ?? true;
        return SwitchListTile(
          value: allow,
          onChanged: (v) => FriendsService.setAllowRequests(v),
          title: Text('settings_allow_requests'.tr()),
          contentPadding: EdgeInsets.zero,
        );
      },
    );
  }
}

class _FriendsNotifPrefs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUserId;
    if (uid == null) return const SizedBox.shrink();
    return Column(
      children: [
        _NotifSwitch(
          title: 'settings_notif_friends'.tr(),
          keyName: 'friends',
        ),
      ],
    );
  }
}

class _GamesNotifPrefs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUserId;
    if (uid == null) return const SizedBox.shrink();
    return Column(
      children: [
        _NotifSwitch(
          title: 'settings_notif_games'.tr(),
          keyName: 'games',
        ),
        _NotifSwitch(
          title: 'settings_notif_reminders'.tr(),
          keyName: 'reminders',
        ),
      ],
    );
  }
}

class _NotifSwitch extends StatelessWidget {
  final String title;
  final String keyName;
  const _NotifSwitch({required this.title, required this.keyName});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUserId!;
    return StreamBuilder<bool>(
      stream: NotificationService.prefStream(uid, keyName),
      builder: (context, snapshot) {
        final on = snapshot.data ?? true;
        return SwitchListTile(
          value: on,
          onChanged: (v) => NotificationService.setPref(keyName, v),
          title: Text(title),
          contentPadding: EdgeInsets.zero,
        );
      },
    );
  }
}
