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
      await storageRef.putFile(
          file, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await storageRef.getDownloadURL();

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
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.primary, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: AppColors.lightgrey,
                            backgroundImage: _localImage != null
                                ? FileImage(_localImage!)
                                : (photoUrl != null
                                    ? NetworkImage(photoUrl)
                                    : null) as ImageProvider?,
                            child: (photoUrl == null && _localImage == null)
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
                                  : const Icon(Icons.camera_alt, size: 20),
                              onPressed:
                                  _uploading ? null : _pickAndUploadPhoto,
                              tooltip: 'profile_change_photo'.tr(),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadius.container),
                      boxShadow: AppShadows.md,
                    ),
                    padding: AppPaddings.allBig,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('profile_basic_details'.tr(),
                            style: AppTextStyles.h3),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: 'profile_display_name'.tr(),
                            border: const OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _saveProfile(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        InkWell(
                          onTap: _pickDob,
                          borderRadius: BorderRadius.circular(8),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'profile_date_of_birth'.tr(),
                              border: const OutlineInputBorder(),
                            ),
                            child: Text(
                              _dateOfBirth == null
                                  ? 'profile_pick_date'.tr()
                                  : DateFormat.yMMMMd().format(_dateOfBirth!),
                              style: AppTextStyles.body,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (email.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: AppColors.lightgrey),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(email, style: AppTextStyles.body)),
                        ],
                      ),
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

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'profile_date_of_birth'.tr(),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }
}
