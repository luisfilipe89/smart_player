# Firebase Emulators - Setup Guide

## What Are Firebase Emulators?

Firebase emulators allow you to test Firebase features locally without:
- Using production resources
- Incurring Firebase costs
- Requiring internet connection
- Affecting live data

## Setup Instructions

### 1. Prerequisites

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools

# Verify installation
firebase --version
```

### 2. Configuration

The emulator configuration is already set in `firebase.json`:

```json
{
  "emulators": {
    "auth": { "port": 9099 },
    "database": { "port": 9000 },
    "functions": { "port": 5001 },
    "storage": { "port": 9199 },
    "ui": { "enabled": true, "port": 4000 }
  }
}
```

### 3. Start Emulators

#### Using Scripts (Recommended)
```bash
# Linux/macOS
./scripts/start_emulators.sh

# Windows
scripts\start_emulators.bat
```

#### Manual Start
```bash
firebase emulators:start
```

### 4. Access Emulator UI

Once running, open:
- **Emulator UI**: http://localhost:4000
- **Auth**: http://localhost:9099
- **Database**: http://localhost:9000
- **Functions**: http://localhost:5001
- **Storage**: http://localhost:9199

---

## Using Emulators in Tests

### 1. Initialize in Tests

```dart
import 'test/helpers/firebase_test_helpers.dart';

void main() {
  setUpAll(() async {
    await FirebaseTestHelpers.initializeFirebaseEmulators();
  });

  tearDownAll(() async {
    await FirebaseTestHelpers.cleanup();
  });
}
```

### 2. Run Integration Tests

```bash
# Run integration tests with emulators
flutter test test/integration/
```

---

## Emulator Features

### Auth Emulator
- ✅ User authentication
- ✅ User management
- ✅ Sign-in/sign-out flows
- ✅ User profile data

### Database Emulator
- ✅ Realtime Database
- ✅ Data synchronization
- ✅ Offline support
- ✅ Rules validation

### Functions Emulator
- ✅ Cloud Functions
- ✅ HTTP triggers
- ✅ Scheduled functions

### Storage Emulator
- ✅ File uploads
- ✅ File downloads
- ✅ Metadata management

---

## Running Tests

### Start Emulators First
```bash
# Terminal 1: Start emulators
./scripts/start_emulators.sh

# Terminal 2: Run tests
flutter test test/integration/
```

### Automated (Future)
```bash
# Will start emulators automatically
flutter test --dart-define=USE_EMULATORS=true
```

---

## Troubleshooting

### Emulators Won't Start
1. **Check ports**: Ensure ports 9099, 9000, 5001, 9199 are available
2. **Firebase CLI**: Verify installation with `firebase --version`
3. **Configuration**: Check `firebase.json` exists

### Tests Can't Connect
1. **Start emulators**: Always start emulators before running tests
2. **Port configuration**: Ensure test helpers use correct ports
3. **Firebase options**: Check emulator configuration in test helpers

---

## Benefits

### Development ✅
- ✅ Test without quotas
- ✅ Faster iteration
- ✅ Offline testing
- ✅ No costs

### Testing ✅
- ✅ Complete integration tests
- ✅ Real Firebase features
- ✅ Isolated environment
- ✅ Reproducible tests

### Production ✅
- ✅ Confident deployments
- ✅ Better quality
- ✅ Fewer production bugs

---

## Next Steps

1. **Start emulators**: Run `./scripts/start_emulators.sh`
2. **Update tests**: Use `FirebaseTestHelpers` in integration tests
3. **Run tests**: Execute `flutter test test/integration/`
4. **Verify**: Check test results and emulator UI

---

*Firebase emulators ready for testing!* 🔥

