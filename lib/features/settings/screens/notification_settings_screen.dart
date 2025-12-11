import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:move_young/theme/_theme.dart';
import 'package:move_young/services/system/notification_settings_provider.dart';
import 'package:move_young/widgets/app_back_button.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _friendRequests = true;
  bool _gameInvites = true;
  bool _gameUpdates = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    final settingsActions = ref.read(notificationSettingsActionsProvider);
    if (settingsActions != null) {
      try {
        // Initialize the service to load saved preferences
        await settingsActions.initialize();
        final settings = settingsActions.getSettings();
        
        if (mounted) {
          setState(() {
            _notificationsEnabled = settings['notificationsEnabled'] ?? true;
            _friendRequests = settings['friendRequests'] ?? true;
            _gameInvites = settings['gameInvites'] ?? true;
            _gameUpdates = settings['gameUpdates'] ?? true;
            _isLoading = false;
          });
        }
      } catch (e) {
        // Settings will use defaults
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() {
      _notificationsEnabled = value;
    });
    
    final settingsActions = ref.read(notificationSettingsActionsProvider);
    if (settingsActions != null) {
      try {
        await settingsActions.setNotificationsEnabled(value);
      } catch (e) {
        // Revert on error
        if (mounted) {
          setState(() {
            _notificationsEnabled = !value;
          });
        }
      }
    }
  }

  Future<void> _toggleCategory(String category, bool value) async {
    final settingsActions = ref.read(notificationSettingsActionsProvider);
    if (settingsActions != null) {
      try {
        await settingsActions.setCategory(category, value);
      } catch (e) {
        // Revert on error - determine which state to revert based on category
        if (mounted) {
          setState(() {
            switch (category) {
              case 'friend_requests':
                _friendRequests = !value;
                break;
              case 'game_invites':
                _gameInvites = !value;
                break;
              case 'game_updates':
                _gameUpdates = !value;
                break;
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: const AppBackButton(),
        title: Text('settings_notifications'.tr()),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main toggle
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadius.container),
                      boxShadow: AppShadows.md,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications,
                          color: _notificationsEnabled
                              ? AppColors.primary
                              : AppColors.grey,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'settings_notifications_enabled'.tr(),
                                style: AppTextStyles.h3,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'settings_notifications_enabled_desc'.tr(),
                                style: AppTextStyles.bodyMuted,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Notification categories
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppRadius.container),
                      boxShadow: AppShadows.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'settings_notification_types'.tr(),
                          style: AppTextStyles.h3,
                        ),
                        const SizedBox(height: 16),
                        _buildCategoryToggle(
                          icon: Icons.people,
                          title: 'settings_notif_friend_requests'.tr(),
                          description: 'settings_notif_friends_desc'.tr(),
                          value: _friendRequests,
                          onChanged: (value) {
                            setState(() {
                              _friendRequests = value;
                            });
                            _toggleCategory('friend_requests', value);
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildCategoryToggle(
                          icon: Icons.sports,
                          title: 'settings_notif_game_invites'.tr(),
                          description: 'settings_notif_games_desc'.tr(),
                          value: _gameInvites,
                          onChanged: (value) {
                            setState(() {
                              _gameInvites = value;
                            });
                            _toggleCategory('game_invites', value);
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildCategoryToggle(
                          icon: Icons.update,
                          title: 'settings_notif_game_updates'.tr(),
                          description: 'settings_notif_game_updates_desc'.tr(),
                          value: _gameUpdates,
                          onChanged: (value) {
                            setState(() {
                              _gameUpdates = value;
                            });
                            _toggleCategory('game_updates', value);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info text
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.lightgrey,
                      borderRadius: BorderRadius.circular(AppRadius.container),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'settings_notifications_info'.tr(),
                            style: AppTextStyles.bodyMuted.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCategoryToggle({
    required IconData icon,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: _notificationsEnabled && value
              ? AppColors.primary
              : AppColors.grey,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: _notificationsEnabled && value
                      ? AppColors.text
                      : AppColors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTextStyles.bodyMuted,
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: _notificationsEnabled ? onChanged : null,
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }
}
