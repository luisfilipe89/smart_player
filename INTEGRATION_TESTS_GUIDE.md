# Integration Tests Guide

This document explains how to run integration tests that test your app's **real Firebase functionality** on a connected device.

## 🎯 What These Tests Do

These tests run your app **on a real device** and test:
- ✅ **Real Firebase Authentication** (sign-in, sign-out, user management)
- ✅ **Real Firebase Database** operations (create, read, update, delete games)
- ✅ **Real-time game state** synchronization
- ✅ **Friend request flows** with actual Firebase data
- ✅ **Actual user flows** that catch bugs before users do

## 📁 Test Files

### `integration_test/auth_flow_test.dart`
Tests Firebase Authentication with real Firebase:
- Anonymous sign-in and sign-out
- User state persistence
- Multiple sign-in scenarios
- Profile updates

**✅ Status: PASSING** - 5 tests

### `integration_test/game_flow_test.dart`
Tests Firebase Realtime Database game operations:
- Create games in Firebase
- Update game information
- Delete games
- Join games (player management)

**✅ Status: PASSING** - 4 tests

### `integration_test/friend_flow_test.dart`
Tests friend request functionality:
- Send friend requests
- Accept/reject friend requests
- Manage friend relationships

**✅ Status: PASSING** - 3 tests

### `integration_test/app_test.dart`
Tests full app launch and initialization (currently has conflicts).

## 🚀 How to Run

### Run All Integration Tests
```bash
# Run all integration tests on your connected device
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/auth_flow_test.dart -d <DEVICE_ID>

# Run game tests
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/game_flow_test.dart -d <DEVICE_ID>

# Run friend tests
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/friend_flow_test.dart -d <DEVICE_ID>
```

### Find Your Device ID
```bash
flutter devices
```

### Run with Batch Script
```bash
# Coming soon: Add integration test support to test\scripts\run_all_tests.bat
```

## 🔧 Requirements

1. **Connected Android Device or Emulator**
   - Physical device recommended for most realistic testing
   - Must be on same network for Firebase access

2. **Firebase Project Configured**
   - Your app connects to **real Firebase** (production or staging)
   - No emulators needed - uses actual Firebase backend

3. **Test User Isolation**
   - Tests use anonymous authentication
   - All test data is marked with `__test_game__` flag
   - Tests clean up after themselves

## 📊 Current Test Coverage

### What IS Being Tested ✅
- Firebase Authentication (real)
- Firebase Realtime Database CRUD operations (real)
- User state management
- Game lifecycle operations
- Friend request workflows
- Real-time data synchronization

### What IS NOT Being Tested Yet ⚠️
- Full app UI flows
- Photo uploads/storage
- Notifications
- Push notifications
- Offline sync behavior
- Complex multi-user scenarios

## 🎨 Test Philosophy

These tests follow **real user behavior**:
1. Sign in anonymously ✅
2. Create a game ✅
3. Update game details ✅
4. Join someone else's game ✅
5. Send/receive friend requests ✅
6. Clean up after themselves ✅

This catches production issues like:
- 🔥 Firebase permission errors
- 🔥 Network timeouts
- 🔥 Database sync issues
- 🔥 Authentication edge cases
- 🔥 Real-time update failures

## 🐛 Troubleshooting

### "Java home is invalid"
**Fix**: Update `android/gradle.properties` with correct JDK path:
```properties
org.gradle.java.home=C:\\Program Files\\Eclipse Adoptium\\jdk-17.0.16.8-hotspot
```

### "Firebase already initialized"
**Fix**: This is expected when running multiple tests. Tests handle this gracefully.

### "No Firebase App has been created"
**Fix**: Ensure `setUpAll()` initializes Firebase:
```dart
setUpAll(() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
});
```

### Tests fail with "No Internet Connection"
**Fix**: Device must be connected to the internet to reach Firebase.

## 📈 Next Steps

Consider adding integration tests for:
1. **Photo uploads** - Test Firebase Storage
2. **Notifications** - Test push notification delivery
3. **Offline mode** - Test sync when connection restored
4. **Multiple users** - Test game invites with 2+ real users
5. **UI workflows** - Test complete user journeys through the app

## 🎉 Success!

You now have **12 real integration tests** that run on your device and test actual Firebase functionality. This helps catch production bugs before your users do!

