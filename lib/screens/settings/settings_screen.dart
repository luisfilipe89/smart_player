import 'package:flutter/material.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/app_back_button.dart';

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

  Future<void> _sendResetEmail() async {
    final email = AuthService.currentUser?.email ?? '';
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings_no_email_on_account'.tr())),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await AuthService.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings_reset_email_sent'.tr(args: [email]))),
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
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('settings_account_deleted'.tr())),
        );
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
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
                    TextField(
                      controller: _currentCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'settings_current_password'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _newCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'settings_new_password'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'settings_confirm_new_password'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('settings_change_password'.tr()),
                      ),
                    ),
                  ] else ...[
                    Text('settings_google_account_hint'.tr(),
                        style: AppTextStyles.body),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _submitting ? null : _sendResetEmail,
                        icon: const Icon(Icons.email_outlined),
                        label: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('settings_send_reset_email'.tr()),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isPasswordUser) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildSectionCard(
                title: 'settings_change_email'.tr(),
                child: Column(
                  children: [
                    TextField(
                      controller: _newEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'settings_new_email'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _emailCurrentPassCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'settings_current_password'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _changeEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('settings_change_email'.tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _buildSectionCard(
              title: 'settings_preferences'.tr(),
              child: Column(
                children: [
                  SwitchListTile(
                    value: _haptics,
                    onChanged: (v) => setState(() => _haptics = v),
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
