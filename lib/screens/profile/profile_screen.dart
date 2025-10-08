import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:move_young/services/auth_service.dart';
import 'package:move_young/utils/profanity.dart';
import 'package:move_young/utils/country_data.dart';
import 'package:move_young/theme/app_back_button.dart';
import 'package:move_young/theme/tokens.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _saving = false;
  bool _uploading = false;
  File? _localImage;
  bool _loadingDetails = true;
  bool _changingEmail = false;
  // Phone country code (default Netherlands)
  String _selectedCountryCode = '+31';
  List<Map<String, String>> get _countryList => CountryData.list;

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
    _phoneController.dispose();
    super.dispose();
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
      await AuthService.updateDisplayName(newName);
      final uid = AuthService.currentUserId;
      if (uid != null) {
        await FirebaseDatabase.instance.ref('users/$uid/profile').update({
          'dateOfBirth': _dateOfBirth?.millisecondsSinceEpoch ?? '',
          'phone': _phoneController.text.trim(),
          'phoneCode': _selectedCountryCode,
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
        final phone = (data['phone'] ?? '').toString();
        if (phone.isNotEmpty) {
          _phoneController.text = phone;
        }
        final code = (data['phoneCode'] ?? '').toString();
        if (code.isNotEmpty) {
          _selectedCountryCode = code;
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

      // Request permissions based on source
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('permission_camera_denied'.tr())),
          );
          return;
        }
      } else {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('permission_storage_denied'.tr())),
          );
          return;
        }
      }

      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source as ImageSource,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 95,
      );
      if (picked == null) return;

      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: false,
            showCropGrid: true,
          ),
          IOSUiSettings(
            title: 'Crop',
            aspectRatioLockEnabled: true,
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
            resetButtonHidden: false,
          ),
        ],
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
      );

      if (cropped == null) return;

      setState(() {
        _localImage = File(cropped.path);
        _uploading = true;
      });

      final uid = AuthService.currentUserId;
      if (uid == null) throw Exception('Not signed in');

      final storageRef =
          FirebaseStorage.instance.ref().child('users/$uid/profile.jpg');
      final file = File(cropped.path);
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
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              disabledForegroundColor: AppColors.grey,
            ),
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
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(24),
                            ],
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
                  // Phone number section
                  _buildSectionCard(
                    title: 'profile_phone_title'.tr(),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.phone_outlined,
                              color: AppColors.primary),
                          title: SizedBox(
                            height: 40,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: _pickCountryWithFlags,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: AppColors.lightgrey),
                                      borderRadius: BorderRadius.circular(20),
                                      color: AppColors.white,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.superlightgrey,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _selectedIsoForCode(
                                                _selectedCountryCode),
                                            style: AppTextStyles.small,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(_selectedCountryCode,
                                            style: AppTextStyles.body),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.arrow_drop_down,
                                            size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'profile_phone_hint'.tr(),
                                    ),
                                    onSubmitted: (_) => _saveProfile(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          subtitle: Text(
                            'profile_phone_subtitle'.tr(),
                            style: AppTextStyles.smallMuted,
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
                        await AuthService.changePassword(
                          currentPassword: current,
                          newPassword: newPassword,
                        );
                        if (!mounted) return;
                        navigator.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('settings_password_changed'.tr()),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
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
                        if (mounted) setState(() => isSubmitting = false);
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

    final bool hasPassword = AuthService.hasPasswordProvider;
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
                          setState(() => isSubmitting = true);
                          await AuthService.sendPasswordResetEmail(
                              currentEmail);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('settings_reset_email_sent'.tr()),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          final msg = e
                              .toString()
                              .replaceFirst(RegExp(r'^Exception:\s*'), '');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(msg),
                                backgroundColor: Colors.red),
                          );
                        } finally {
                          if (mounted) setState(() => isSubmitting = false);
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
                      final newEmail = newEmailController.text.trim();
                      if (newEmail.isEmpty || newEmail == currentEmail) {
                        ScaffoldMessenger.of(context).showSnackBar(
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('form_fill_all_fields'.tr())),
                            );
                            setState(() => isSubmitting = false);
                            return;
                          }
                          await AuthService.changeEmail(
                            currentPassword: currentPw,
                            newEmail: newEmail,
                          );
                        } else {
                          await AuthService.updateEmail(newEmail);
                        }

                        if (!mounted) return;
                        Navigator.of(context).pop(true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('profile_email_changed'.tr()),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;
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

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => isSubmitting = false);
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

  String _selectedIsoForCode(String code) {
    final match = _countryList.firstWhere(
      (c) => c['code'] == code,
      orElse: () => const {'iso': 'NL'},
    );
    return match['iso'] ?? 'NL';
  }

  void _pickCountryWithFlags() {
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        String query = '';
        final controller = TextEditingController();
        List<Map<String, String>> sortNumerically(
            List<Map<String, String>> src) {
          final copy = [...src];
          copy.sort((a, b) {
            final ai = int.tryParse((a['code'] ?? '').replaceAll('+', '')) ?? 0;
            final bi = int.tryParse((b['code'] ?? '').replaceAll('+', '')) ?? 0;
            return ai.compareTo(bi);
          });
          return copy;
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = sortNumerically(_countryList).where((c) {
              if (query.isEmpty) return true;
              final q = query.toLowerCase();
              return (c['name'] ?? '').toLowerCase().contains(q) ||
                  (c['iso'] ?? '').toLowerCase().contains(q) ||
                  (c['code'] ?? '').toLowerCase().contains(q);
            }).toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: MediaQuery.of(ctx).size.height * 0.75,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: TextField(
                          controller: controller,
                          onChanged: (v) => setSheetState(() => query = v),
                          decoration: InputDecoration(
                            hintText: 'Search country or code',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.lightgrey),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            final selected = c['code'] == _selectedCountryCode;
                            return InkWell(
                              onTap: () => Navigator.pop(ctx, c['code']),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: const BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: AppColors.lightgrey,
                                          width: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.superlightgrey,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(c['iso'] ?? '',
                                          style: AppTextStyles.small),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(c['name'] ?? '',
                                              style: AppTextStyles.body),
                                          const SizedBox(height: 2),
                                          Text(c['code'] ?? '',
                                              style: AppTextStyles.smallMuted),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(Icons.check_circle,
                                          color: AppColors.primary),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((val) {
      if (val != null) setState(() => _selectedCountryCode = val);
    });
  }
}
