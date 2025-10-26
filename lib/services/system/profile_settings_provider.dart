// lib/providers/services/profile_settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'profile_settings_service_instance.dart';
import 'package:move_young/providers/infrastructure/firebase_providers.dart';

// ProfileSettingsService provider with dependency injection
final profileSettingsServiceProvider =
    Provider<ProfileSettingsServiceInstance>((ref) {
  final firebaseDatabase = ref.watch(firebaseDatabaseProvider);
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  return ProfileSettingsServiceInstance(firebaseDatabase, firebaseAuth);
});

// Profile settings actions provider (for profile operations)
final profileSettingsActionsProvider = Provider<ProfileSettingsActions>((ref) {
  final profileSettingsService = ref.watch(profileSettingsServiceProvider);
  return ProfileSettingsActions(profileSettingsService);
});

// Helper class for profile settings actions
class ProfileSettingsActions {
  final ProfileSettingsServiceInstance _profileSettingsService;

  ProfileSettingsActions(this._profileSettingsService);

  // Visibility settings
  Stream<String> visibilityStream(String uid) =>
      _profileSettingsService.visibilityStream(uid);
  Future<String> getVisibility(String uid) =>
      _profileSettingsService.getVisibility(uid);
  Future<bool> setVisibility(String visibility) =>
      _profileSettingsService.setVisibility(visibility);

  // Show online settings
  Stream<bool> showOnlineStream(String uid) =>
      _profileSettingsService.showOnlineStream(uid);
  Future<bool> getShowOnline(String uid) =>
      _profileSettingsService.getShowOnline(uid);
  Future<bool> setShowOnline(bool showOnline) =>
      _profileSettingsService.setShowOnline(showOnline);

  // Allow friend requests settings
  Stream<bool> allowFriendRequestsStream(String uid) =>
      _profileSettingsService.allowFriendRequestsStream(uid);
  Future<bool> getAllowFriendRequests(String uid) =>
      _profileSettingsService.getAllowFriendRequests(uid);
  Future<bool> setAllowFriendRequests(bool allow) =>
      _profileSettingsService.setAllowFriendRequests(allow);

  // Share email settings
  Stream<bool> shareEmailStream(String uid) =>
      _profileSettingsService.shareEmailStream(uid);
  Future<bool> getShareEmail(String uid) =>
      _profileSettingsService.getShareEmail(uid);
  Future<bool> setShareEmail(bool share) =>
      _profileSettingsService.setShareEmail(share);

  // Combined settings stream
  Stream<Map<String, dynamic>> settingsStream(String uid) =>
      _profileSettingsService.settingsStream(uid);

  // Profile data operations
  Future<Map<String, dynamic>?> getUserProfile(String uid) =>
      _profileSettingsService.getUserProfile(uid);
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) =>
      _profileSettingsService.updateUserProfile(uid, data);
}
