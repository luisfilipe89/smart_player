// lib/screens/maps/profile_screen.dart
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // Unused import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:cached_network_image/cached_network_image.dart'; // Unused import
import 'package:image_cropper/image_cropper.dart';
// import 'package:permission_handler/permission_handler.dart'; // Unused import
import 'package:move_young/services/auth/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:move_young/utils/profanity.dart';
import 'package:move_young/utils/country_data.dart';
import 'package:move_young/theme/app_back_button.dart';
import 'package:move_young/theme/tokens.dart';
import 'package:move_young/db/db_paths.dart';
// import 'package:move_young/widgets/upload_progress_indicator.dart'; // Unused import
// import 'package:move_young/utils/retry_helpers.dart'; // Unused import

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _uploading = false;
  double _uploadProgress = 0.0;
  File? _pendingUploadFile;
  File? _localImage;
  // Phone country code (default Netherlands)
  String _selectedCountryCode = '+31';
  List<Map<String, String>> get _countryList => CountryData.list;

  @override
  void initState() {
    super.initState();
    // Load user details when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserDetails();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    // Watch current user reactively
    final user = ref.read(currentUserProvider).value;
    if (user != null) {
      _nameController.text = user.displayName ?? '';

      // Load additional profile details from database
      try {
        final uid = user.uid;
        final snapshot =
            await FirebaseDatabase.instance.ref(DbPaths.userProfile(uid)).get();
        if (snapshot.exists && snapshot.value is Map) {
          final data = Map<String, dynamic>.from(snapshot.value as Map);
          _phoneController.text = data['phone'] ?? '';
          _selectedCountryCode = data['phoneCode'] ?? '+31';
          if (data['dateOfBirth'] != null) {
            _dateOfBirth =
                DateTime.fromMillisecondsSinceEpoch(data['dateOfBirth']);
          }
        }
      } catch (e) {
        // Handle error silently for now
        debugPrint('Error loading profile details: $e');
      }
    }
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

    try {
      // Update display name using auth actions
      await ref.read(authActionsProvider).updateProfile(displayName: newName);

      // Update additional profile details in database
      final uid = ref.read(currentUserIdProvider);
      if (uid != null) {
        await FirebaseDatabase.instance.ref(DbPaths.userProfile(uid)).update({
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
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final File imageFile = File(image.path);
        await _cropImage(imageFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _cropImage(File imageFile) async {
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _localImage = File(croppedFile.path);
          _pendingUploadFile = File(croppedFile.path);
        });
        await _uploadImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cropping image: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_pendingUploadFile == null) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) throw Exception('User not authenticated');

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$uid.jpg');

      final uploadTask = storageRef.putFile(_pendingUploadFile!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await uploadTask;
      final downloadUrl = await storageRef.getDownloadURL();

      // Update user profile with new photo URL
      await ref.read(authActionsProvider).updateProfile(photoURL: downloadUrl);

      // Update database with new photo URL
      await FirebaseDatabase.instance.ref(DbPaths.userProfile(uid)).update({
        'photoURL': downloadUrl,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      setState(() {
        _uploading = false;
        _pendingUploadFile = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated')),
        );
      }
    } catch (e) {
      setState(() {
        _uploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch current user reactively
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 48,
        leading: const AppBackButton(goHome: true),
        title: Text('profile'.tr()),
        actions: [
          TextButton(
            onPressed: _saveProfile,
            child: Text(
              'save'.tr(),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading profile: $error'),
              ElevatedButton(
                onPressed: () => ref.invalidate(currentUserProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Please sign in to view profile'));
          }

          return _buildProfileContent(user);
        },
      ),
    );
  }

  Widget _buildProfileContent(User user) {
    return Column(
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.8)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile picture section
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          backgroundImage: _localImage != null
                              ? FileImage(_localImage!)
                              : user.photoURL != null
                                  ? NetworkImage(user.photoURL!)
                                      as ImageProvider
                                  : null,
                          child: _localImage == null && user.photoURL == null
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color:
                                      AppColors.primary.withValues(alpha: 0.5),
                                )
                              : null,
                        ),
                        if (_uploading)
                          Positioned.fill(
                            child: CircularProgressIndicator(
                              value: _uploadProgress,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt,
                                  color: Colors.white),
                              onPressed: _pickImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Profile form
                  Text(
                    'profile_information'.tr(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name field
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'name'.tr(),
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email field (read-only)
                  TextFormField(
                    initialValue: user.email ?? '',
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'email'.tr(),
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          _showEmailChangeDialog();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phone field
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedCountryCode,
                          decoration: InputDecoration(
                            labelText: 'country'.tr(),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          items: _countryList.map((country) {
                            return DropdownMenuItem<String>(
                              value: country['code'],
                              child: Text(country['code']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCountryCode = value ?? '+31';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'phone'.tr(),
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date of birth field
                  InkWell(
                    onTap: _selectDateOfBirth,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'date_of_birth'.tr(),
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _dateOfBirth != null
                            ? DateFormat('dd/MM/yyyy').format(_dateOfBirth!)
                            : 'select_date'.tr(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sign out button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showSignOutDialog(),
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: Text(
                        'sign_out'.tr(),
                        style: const TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('sign_out'.tr()),
        content: Text('are_you_sure_sign_out'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ref.read(authActionsProvider).signOut();
                if (mounted && context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/auth');
                }
              } catch (e) {
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error signing out: $e')),
                  );
                }
              }
            },
            child: Text(
              'sign_out'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmailChangeDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Enter your new email address. A verification email will be sent.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'New Email',
                hintText: 'Enter new email address',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newEmail = emailController.text.trim();
              if (newEmail.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid email address')),
                );
                return;
              }

              Navigator.pop(context);
              await _changeEmail(newEmail);
            },
            child: const Text('Change Email'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeEmail(String newEmail) async {
    try {
      final authActions = ref.read(authActionsProvider);
      await authActions.updateEmail(newEmail);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification email sent to $newEmail'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
