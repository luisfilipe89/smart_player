import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/theme/app_back_button.dart';
import 'package:move_young/theme/tokens.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _saving = false;
  bool _uploading = false;
  File? _localImage;
  bool _loadingDetails = true;
  bool _changingEmail = false;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    _nameController.text = user?.displayName ?? '';
    _loadUserDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();

    if (newName.isEmpty) return;
    setState(() => _saving = true);
    try {
      await AuthService.updateDisplayName(newName);
      final uid = AuthService.currentUserId;
      if (uid != null) {
        await FirebaseDatabase.instance.ref('users/$uid/profile').update({
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadUserDetails() async {
    final uid = AuthService.currentUserId;
    if (uid == null) {
      if (mounted) setState(() => _loadingDetails = false);
      return;
    }
    try {
      final snap =
          await FirebaseDatabase.instance.ref('users/$uid/profile').get();
      if (snap.exists) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        final dob = int.tryParse('${data['dateOfBirth'] ?? ''}');
        if (dob != null && dob > 0) {
          _dateOfBirth = DateTime.fromMillisecondsSinceEpoch(dob);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingDetails = false);
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final source = await showModalBottomSheet<dynamic>(
            context: context,
            builder: (ctx) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library_outlined),
                    title: Text('profile_gallery'.tr()),
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: Text('profile_camera'.tr()),
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                  if (_localImage != null ||
                      (AuthService.currentUser?.photoURL != null)) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text('profile_remove_photo'.tr()),
                      onTap: () => Navigator.pop(ctx, 'remove'),
                    ),
                  ]
                ],
              ),
            ),
          ) ??
          ImageSource.gallery;

      if (source == 'remove') {
        await _removePhoto();
        return;
      }

      final picker = ImagePicker();
      final XFile? picked =
          await picker.pickImage(source: source as ImageSource, maxWidth: 1024);
      if (picked == null) return;
      setState(() {
        _localImage = File(picked.path);
        _uploading = true;
      });

      final uid = AuthService.currentUserId;
      if (uid == null) throw Exception('Not signed in');

      final storageRef =
          FirebaseStorage.instance.ref().child('users/$uid/profile.jpg');
      final file = File(picked.path);
      final task = await storageRef.putFile(
          file, SettableMetadata(contentType: 'image/jpeg'));
      String downloadUrl;
      try {
        downloadUrl = await task.ref.getDownloadURL();
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 300));
        downloadUrl = await task.ref.getDownloadURL();
      }

      await AuthService.updateProfile(photoURL: downloadUrl);

      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final photoUrl = user?.photoURL;
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
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
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
                  // Profile Photo Section
                  _buildSectionCard(
                    child: Column(
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.primary, width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 52,
                                  backgroundColor: AppColors.lightgrey,
                                  backgroundImage: _localImage != null
                                      ? FileImage(_localImage!)
                                      : (photoUrl != null
                                          ? NetworkImage(photoUrl)
                                          : null) as ImageProvider?,
                                  child:
                                      (photoUrl == null && _localImage == null)
                                          ? const Icon(Icons.person,
                                              size: 52, color: Colors.white)
                                          : null,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Material(
                                  color: AppColors.white,
                                  shape: const CircleBorder(),
                                  elevation: 2,
                                  child: IconButton(
                                    icon: _uploading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : const Icon(Icons.camera_alt,
                                            size: 20),
                                    onPressed:
                                        _uploading ? null : _pickAndUploadPhoto,
                                    tooltip: 'profile_change_photo'.tr(),
                                  ),
                                ),
                              )
                            ],
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
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Enter your name',
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
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.body),
      subtitle: child,
    );
  }

  void _showChangePasswordDialog() {
    // TODO: Implement change password dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Change password coming soon!')),
    );
  }

  Future<void> _removePhoto() async {
    try {
      setState(() => _uploading = true);
      final uid = AuthService.currentUserId;
      if (uid != null) {
        final ref =
            FirebaseStorage.instance.ref().child('users/$uid/profile.jpg');
        try {
          await ref.delete();
        } catch (_) {
          // ignore if not found
        }
      }
      await AuthService.updateProfile(photoURL: '');
      if (!mounted) return;
      setState(() {
        _localImage = null;
        _uploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo removed')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _changeEmail() async {
    final currentEmail = AuthService.currentUser?.email ?? '';
    if (currentEmail.isEmpty) return;

    final newEmailController = TextEditingController(text: currentEmail);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('profile_change_email'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('profile_change_email_description'.tr()),
            const SizedBox(height: AppSpacing.md),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              final newEmail = newEmailController.text.trim();
              if (newEmail.isNotEmpty && newEmail != currentEmail) {
                Navigator.of(context).pop(newEmail);
              }
            },
            child: Text('profile_change_email'.tr()),
          ),
        ],
      ),
    );

    if (result != null && result != currentEmail) {
      setState(() => _changingEmail = true);
      try {
        await AuthService.updateEmail(result);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile_email_changed'.tr()),
            backgroundColor: AppColors.primary,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _changingEmail = false);
      }
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
