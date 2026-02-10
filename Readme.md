# SmartPlayer

A Flutter app for organising and joining sports matches, managing your agenda, connecting with friends, and discovering fitness activities. Built with **Firebase** and **Riverpod**, targeting **Android**.
📊 [Project presentation (Canva)](https://www.canva.com/design/DAG4Y5H7bbE/VCXIx9GDslnIZmqYtGY2Ww/edit?utm_content=DAG4Y5H7bbE&utm_campaign=designshare&utm_medium=link2&utm_source=sharebutton)


---

## Features

- **Matches** — Create, join, and manage pick-up matches; discover games and view your own
- **Agenda** — Calendar view of your events with optional device calendar sync
- **Friends** — Add friends and send/accept requests; friend-based notifications
- **Activities** — Fitness stations and water fountains (with maps)
- **Maps** — Field locations and map integration
- **Notifications** — FCM + local notifications; deep links for matches and friends
- **Auth** — Google Sign-In with Firebase Auth
- **Profile & settings** — Profile, notification preferences, legal (privacy, terms)
- **Localisation** — Multi-language support (e.g. EN/NL) via `easy_localization`

---

## Tech stack

| Layer        | Choice                |
|-------------|------------------------|
| Framework   | Flutter                |
| State       | Riverpod               |
| Backend     | Firebase (Auth, Realtime DB, Firestore, Messaging, Crashlytics, App Check) |
| Maps        | Google Maps Flutter    |
| Notifications | Firebase Cloud Messaging, flutter_local_notifications |
| Calendar    | device_calendar        |

---

## Prerequisites

- **Git**
- **Flutter SDK** (stable)
- **Android Studio** (Android SDK + emulator)
- **Node.js** (LTS), e.g. via [nvm-windows](https://github.com/coreybutler/nvm-windows/releases)
- **Firebase CLI** (`npm install -g firebase-tools`)

---

## Getting started

### 1. Clone and install

```powershell
git clone <your-repo-url>
cd smart_player
flutter pub get
```

### 2. Firebase

- Create or use an existing Firebase project and add an Android app.
- Download `google-services.json` into `android/app/`.
- Log in with the Firebase CLI: `firebase login`.

### 3. Run the app

**Physical device (USB debugging enabled):**

```powershell
flutter devices
flutter run -d <DEVICE_ID>
```

**Android emulator:**

```powershell
# Start an emulator from Android Studio (Device Manager), then:
flutter devices
flutter run -d emulator-5554
```

Use **Hot Reload** (`r`) and **Hot Restart** (`R`) during development.

---

## Detailed setup (Windows)

For a full Windows setup (Flutter, Android Studio, Node/nvm, Firebase CLI, licenses), see **[SETUP.md](SETUP.md)**.

---

## Project structure

```
lib/
├── config/           # App bootstrap and config
├── db/               # Local DB / persistence
├── features/         # Feature modules
│   ├── activities/   # Fitness, fields, water fountains
│   ├── agenda/       # Events and calendar
│   ├── auth/         # Sign-in and auth state
│   ├── friends/      # Friends list and requests
│   ├── games/        # Game form logic
│   ├── help/         # Help screen
│   ├── home/         # Home screen
│   ├── legal/        # Privacy and terms
│   ├── maps/         # Map screen
│   ├── matches/      # Match create/join/my and services
│   ├── profile/      # Profile and profile settings
│   ├── settings/     # App and notification settings
│   └── welcome/      # Welcome / onboarding
├── navigation/       # Routes, deep links, main scaffold
├── providers/       # Riverpod providers (locale, infra)
├── services/         # Notifications, calendar, sync, weather, etc.
├── theme/            # Theming and tokens
├── utils/            # Helpers, formatters, logging
└── widgets/          # Shared UI (offline banner, error retry, etc.)
```

---

## Scripts

- `scripts/setup_emulators.sh` / `scripts/start_emulators.bat` — Start Firebase emulators for local development.

---

## License

Private repository. All rights reserved.
