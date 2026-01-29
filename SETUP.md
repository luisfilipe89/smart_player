# SmartPlayer — Local setup (Windows)

Steps to set up a Windows machine and run the app locally.

---

## Required software

- **Git**
- **Flutter SDK** (Stable)
- **Android Studio** (Android SDK + Emulator)
- **Node.js** (LTS), e.g. via [nvm-windows](https://github.com/coreybutler/nvm-windows/releases)
- **Firebase CLI**

---

## 1. Install Git

Install [Git for Windows](https://git-scm.com/download/win) and verify:

```powershell
git --version
```

---

## 2. Install Flutter (Windows)

1. Download the **Flutter SDK (Stable)** from [flutter.dev](https://flutter.dev).
2. Extract to e.g. `C:\src\flutter` and add the `bin` folder to your PATH.
3. Verify in PowerShell:

```powershell
flutter --version
flutter doctor
```

---

## 3. Install Android Studio & Android SDK

1. Install [Android Studio](https://developer.android.com/studio).
2. Open **More Actions** → **SDK Manager** and install:
   - **Android SDK Platform-Tools**
   - **Android SDK Build-Tools**
   - **Android SDK Command-line Tools** (latest)
   - **Android Emulator**
   - **Android SDK Platform 35** (Android 15.0) and **36** if available — required by the app and plugins (e.g. `flutter_local_notifications`).  
     In **SDK Platforms**, enable **Show Package Details**, then check **Android API 35** and **Android API 36**.
3. Accept Android licences:

```powershell
flutter doctor --android-licences
```

4. Verify:

```powershell
flutter doctor
```

Visual Studio is not required for Android-only development.

---

## 4. Install Node.js (nvm-windows)

1. Install [nvm-windows](https://github.com/coreybutler/nvm-windows/releases).  
   Recommended path: `C:\nvm`.
2. Restart your IDE, then in PowerShell:

```powershell
nvm version
```

3. Install and use a Node LTS version:

```powershell
nvm install 22.22.0
nvm use 22.22.0
node -v
npm -v
```

If `node` is not recognised, restart the IDE and ensure `C:\nvm` and `C:\Program Files\nodejs` are in your user PATH.

---

## 5. Install Firebase CLI

In PowerShell:

```powershell
npm install -g firebase-tools
firebase --version
```

Log in (browser will open):

```powershell
firebase login
```

---

## 6. Project dependencies

From the project root:

```powershell
flutter pub get
```

---

## 7. Run the app

**Physical Android device**

1. Enable **Developer options** and **USB debugging** on the device.
2. Connect via USB and accept the debugging prompt.
3. Run:

```powershell
flutter devices
flutter run -d <DEVICE_ID>
```

**Android emulator**

1. In Android Studio: **Device Manager** → **Create device** → choose a Pixel device → select a **Google APIs x86_64** system image → finish and start the emulator.
2. Run:

```powershell
flutter devices
flutter run -d emulator-5554
```

Use **Hot Reload** (`r`) and **Hot Restart** (`R`) during development.

---
