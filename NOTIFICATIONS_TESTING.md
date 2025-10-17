# Notifications Testing Guide

## Current Implementation Status

✅ **Completed:**
- Enhanced NotificationService with multiple channels
- Game reminders (30 min & 1 hour before game time)
- Friend request notifications (data written to Firebase)
- Notification settings screen
- Android configuration
- Firebase Cloud Functions (optional, not deployed yet)

## What You Can Test Right Now

### 1. **Game Reminders (Local Notifications)**

This works immediately without any server setup:

1. **Run the app:**
   ```bash
   flutter run
   ```

2. **Create or join a game:**
   - Sign in to the app
   - Create a game scheduled for 1-2 hours from now
   - OR join an existing game

3. **Wait for reminders:**
   - You'll get a notification 1 hour before the game
   - You'll get another notification 30 minutes before the game
   - These work even if the app is closed!

4. **Test notifications are enabled:**
   - Go to Settings → Notifications
   - Toggle notifications on/off
   - When off, no reminders will be scheduled

### 2. **Notification Settings Screen**

1. Navigate to the notification settings (you'll need to add navigation from your settings screen)
2. Test the toggle on/off
3. Observe the UI changes

## What Requires Additional Setup

### **Server-Side Notifications (Friend Requests, Game Invites)**

These require Firebase Cloud Functions to be deployed. Here's what you need:

#### Prerequisites:
1. **Firebase CLI installed:**
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase:**
   ```bash
   firebase login
   ```

3. **Initialize Firebase (if not already done):**
   ```bash
   firebase init functions
   ```
   - Choose your Firebase project
   - Choose TypeScript
   - Don't overwrite existing files

4. **Install dependencies:**
   ```bash
   cd functions
   npm install
   ```

5. **Deploy Cloud Functions:**
   ```bash
   firebase deploy --only functions
   ```

#### After Deployment:

**Friend Request Notifications:**
1. User A sends a friend request to User B
2. Cloud Function triggers automatically
3. User B receives a push notification (even if app is closed)
4. Tapping notification opens the Friends screen

**Game Invite Notifications:**
1. User A creates a game and invites User B
2. Cloud Function triggers automatically
3. User B receives a push notification
4. Tapping notification opens the My Games screen

## Testing Checklist

### ✅ Without Cloud Functions (Available Now):

- [ ] App runs without errors
- [ ] Can create a game scheduled for future
- [ ] Notification reminder appears 1 hour before game
- [ ] Notification reminder appears 30 minutes before game
- [ ] Tapping notification opens the app
- [ ] Notifications settings screen opens
- [ ] Can toggle notifications on/off
- [ ] When notifications are off, no reminders are scheduled
- [ ] When leaving a game, reminders are cancelled
- [ ] When cancelling a game, reminders are cancelled

### 🔄 With Cloud Functions (Requires Deployment):

- [ ] Send friend request → recipient gets notification
- [ ] Accept friend request → requester gets notification
- [ ] Invite friend to game → friend gets notification
- [ ] Player joins your game → you get notification
- [ ] Game is cancelled → all players get notification

## Troubleshooting

### Notifications Not Appearing?

1. **Check Android Permissions:**
   - Go to device Settings → Apps → YourApp → Notifications
   - Ensure notifications are enabled

2. **Check In-App Settings:**
   - Go to app Settings → Notifications
   - Ensure notifications are enabled

3. **For scheduled notifications:**
   - Make sure the game time is in the future (at least 1 hour)
   - Check device's "Do Not Disturb" mode

4. **For Android 13+:**
   - The app should request notification permission on first launch
   - If denied, manually enable in device settings

### App Crashes on Launch?

Check for missing imports or linter errors:
```bash
flutter analyze
```

## Adding Navigation to Notification Settings

To access the notification settings screen, add this to your settings/profile screen:

```dart
import 'package:move_young/screens/settings/notification_settings_screen.dart';

// In your settings list:
ListTile(
  leading: Icon(Icons.notifications),
  title: Text('settings_notifications'.tr()),
  trailing: Icon(Icons.chevron_right),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationSettingsScreen(),
      ),
    );
  },
)
```

## Next Steps for Production

1. **Deploy Cloud Functions** for real-time notifications
2. **Test on iOS** (requires Apple Developer account for push notifications)
3. **Update Firebase Database rules** to allow notification writes
4. **Implement deep linking navigation** in main scaffold
5. **Add notification badges** (unread count)
6. **Add notification history** screen

## Notes

- Game reminders are **local notifications** - they work offline
- Friend/game notifications are **push notifications** - require internet and Cloud Functions
- Notification data is stored in Firebase Database at `users/$uid/notifications/`
- FCM tokens are stored at `users/$uid/fcmTokens/`
- All notification strings are localized (English & Dutch)

