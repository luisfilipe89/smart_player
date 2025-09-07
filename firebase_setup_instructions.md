# 🔥 Firebase Setup Instructions

## **Step 1: Create Firebase Project**

1. **Go to** [Firebase Console](https://console.firebase.google.com/)
2. **Click** "Create a project" or "Add project"
3. **Enter project name**: `move-young` (or your preferred name)
4. **Enable Google Analytics** (optional but recommended)
5. **Click** "Create project"

## **Step 2: Add Android App**

1. **In Firebase Console**, click "Add app" → Android
2. **Enter package name**: `com.example.move_young`
3. **Enter app nickname**: `Move Young Android`
4. **Download** `google-services.json`
5. **Place** `google-services.json` in `android/app/` directory

## **Step 3: Add iOS App (if needed)**

1. **In Firebase Console**, click "Add app" → iOS
2. **Enter bundle ID**: `com.example.moveYoung`
3. **Enter app nickname**: `Move Young iOS`
4. **Download** `GoogleService-Info.plist`
5. **Place** `GoogleService-Info.plist` in `ios/Runner/` directory

## **Step 4: Enable Authentication**

1. **In Firebase Console**, go to "Authentication"
2. **Click** "Get started"
3. **Go to** "Sign-in method" tab
4. **Enable** the following providers:
   - ✅ **Anonymous** (for quick testing)
   - ✅ **Google** (for social login)
   - ✅ **Email/Password** (for traditional login)

## **Step 5: Enable Realtime Database**

1. **In Firebase Console**, go to "Realtime Database"
2. **Click** "Create database"
3. **Choose** "Start in test mode" (for development)
4. **Select** a location (choose closest to your users)
5. **Click** "Done"

## **Step 6: Set Database Rules**

1. **In Realtime Database**, go to "Rules" tab
2. **Replace** the rules with:

```json
{
  "rules": {
    "games": {
      ".read": "auth != null",
      ".write": "auth != null"
    },
    "users": {
      "$uid": {
        ".read": "auth != null && auth.uid == $uid",
        ".write": "auth != null && auth.uid == $uid"
      }
    }
  }
}
```

3. **Click** "Publish"

## **Step 7: Update Android Configuration**

1. **Open** `android/app/build.gradle`
2. **Add** at the top:

```gradle
apply plugin: 'com.google.gms.google-services'
```

3. **Open** `android/build.gradle`
4. **Add** in dependencies:

```gradle
classpath 'com.google.gms:google-services:4.3.15'
```

## **Step 8: Update iOS Configuration (if needed)**

1. **Open** `ios/Runner.xcworkspace` in Xcode
2. **Add** `GoogleService-Info.plist` to the project
3. **Ensure** it's added to the target

## **Step 9: Test the Setup**

1. **Run** `flutter pub get`
2. **Run** `flutter run`
3. **Check** console for Firebase initialization messages

## **🔧 Troubleshooting**

### **Common Issues:**

1. **"No Firebase App '[DEFAULT]' has been created"**
   - Make sure `google-services.json` is in the correct location
   - Run `flutter clean` and `flutter pub get`

2. **"Google Play Services not available"**
   - Make sure you're testing on a real device or emulator with Google Play Services

3. **"Permission denied"**
   - Check your database rules
   - Make sure user is authenticated

### **Testing Commands:**

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Check for errors
flutter analyze
```

## **✅ Success Indicators:**

- App starts without Firebase errors
- User can sign in anonymously
- Games can be created and synced to cloud
- Real-time updates work

## **🚀 Next Steps:**

Once Firebase is set up, you can:
- Test game creation and cloud sync
- Test real-time updates
- Add user authentication UI
- Test cross-device synchronization

---

**Need help?** Check the [Firebase Flutter documentation](https://firebase.flutter.dev/) or create an issue in your project repository.
