# Quick Start Guide - Critical Fixes

## 🚨 URGENT: Fix These Before Production

### 1. Firebase Security Rules (30 minutes)

**File:** `database.rules.json`

Replace lines 8-26 with:

```json
"games": {
  "$gameId": {
    ".read": "auth != null && (data.child('organizerId').val() == auth.uid || data.child('players').hasChild(auth.uid))",
    ".write": "auth != null && (root.child('games').child($gameId).child('organizerId').val() == auth.uid || !data.exists())",
    ".validate": "newData.hasChildren(['sport', 'dateTime', 'organizerId', 'location', 'maxPlayers']) && newData.child('sport').isString() && newData.child('dateTime').isString() && newData.child('organizerId').val() == auth.uid && newData.child('maxPlayers').isNumber() && newData.child('maxPlayers').val() > 0 && newData.child('maxPlayers').val() <= 50"
  }
}
```

**Why:** Prevents any authenticated user from reading/writing ALL games.

---

### 2. Add Crashlytics (1 hour)

**Add to pubspec.yaml:**
```yaml
dependencies:
  firebase_crashlytics: ^5.0.6
```

**Update lib/services/error_handler/error_handler_service_instance.dart:**

Change:
```dart
if (kReleaseMode) {
  // TODO: Send to crash reporting service
}
```

To:
```dart
if (kReleaseMode) {
  FirebaseCrashlytics.instance.recordError(error, stackTrace);
}
```

---

### 3. Safe DateTime Parsing (30 minutes)

**File:** `lib/services/games/games_service_instance.dart`

Add this helper method:

```dart
DateTime _parseDateTime(dynamic value) {
  try {
    if (value is String) {
      return DateTime.parse(value);
    } else if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else {
      throw ValidationException('Invalid dateTime format: $value');
    }
  } catch (e) {
    debugPrint('Error parsing DateTime: $e');
    throw ServiceException('Invalid dateTime format: $value', originalError: e);
  }
}
```

Then replace:
- Line 375: `dateTime: DateTime.parse(map['dateTime'])` → `dateTime: _parseDateTime(map['dateTime'])`
- Line 383: `createdAt: DateTime.parse(map['createdAt'])` → `createdAt: _parseDateTime(map['createdAt'])`

---

## These 3 fixes are CRITICAL and can be done in 2 hours!

See FIX_PLAN.md for complete implementation guide.

