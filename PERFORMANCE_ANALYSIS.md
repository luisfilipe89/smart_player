# Flutter App Performance Analysis

## Executive Summary

This analysis reviews the Flutter app for performance issues across:
- Widget rebuild patterns
- Image caching and network optimization
- Database queries (SQLite)
- Firebase Realtime Database usage
- Memory leaks (timers, streams, listeners)
- Build method optimizations

## Critical Performance Issues

### 1. 🔴 Firebase Stream Listeners Not Properly Disposed

**Issue:** Firebase Realtime Database listeners created without proper cancellation on widget disposal.

**Location:** 
- `lib/services/friends/friends_service_instance.dart` (Lines 401-434)
- `lib/services/games/cloud_games_service_instance.dart` (Lines 371-387)

**Problem:**
```dart
// In FriendsServiceInstance - Lines 401-434
Stream<List<String>> watchUserFriends(String uid) {
  return _db.ref(DbPaths.userFriends(uid)).onValue.map((event) {
    // No cleanup mechanism when widget disposes
  });
}
```

These streams remain active even after the widget is disposed, causing:
- Memory leaks
- Unnecessary Firebase reads
- Battery drain
- Increased Firebase costs

**Recommendation:**
- Use `StreamSubscription` and cancel in `dispose()`
- Or implement automatic stream cleanup via `ref.keepAlive(false)` in providers

### 2. 🔴 Global Timer Not Properly Scoped

**Issue:** Global timer in `lib/main.dart` (Line 24) that runs independently of widget lifecycle.

**Problem:**
```dart
Timer? _cacheCleanupTimer;

void main() async {
  _cacheCleanupTimer = Timer.periodic(const Duration(hours: 6), (timer) async {
    try {
      // Cache cleanup will be handled through providers
      // await CacheService.clearExpiredCache();
    } catch (_) {}
  });
}
```

The timer runs every 6 hours but the cache cleanup is commented out (lines 60-61), making this timer useless and wasteful.

**Recommendation:**
- Either implement the cache cleanup or remove the timer
- Consider using a provider-based approach for cache management

### 3. 🟡 StreamSubscription in Friends Screen Not Cancelled

**Location:** `lib/screens/friends/friends_screen.dart` (Lines 288-313)

**Issue:**
```dart
StreamSubscription<void>? qrAutoCloseSub;
try {
  qrAutoCloseSub = ref
      .read(friendsActionsProvider)
      .watchFriendRequestReceived(myUid)
      .listen((_) {
    // ...
  });
} catch (_) {}

unawaited(dialogFuture.whenComplete(() async {
  try {
    await qrAutoCloseSub?.cancel();
  } catch (_) {}
}));
```

**Problem:** The subscription is created in a local scope within `_showMyQr()` but only cancelled when the dialog completes. If the parent widget is disposed before the dialog closes, the subscription leaks.

**Recommendation:**
- Store subscription in widget state
- Cancel in widget dispose method
- Check `mounted` before setting state

### 4. 🟡 Heavy Computations in Build Methods

**Location:** Multiple screens perform filtering/transformation in build methods

**Examples:**

**games_my_screen.dart (Lines 494-506):**
```dart
final joinedGames = myGamesAsync.when(
  data: (games) =>
      games.where((g) => currentUserId != g.organizerId).toList(),
  loading: () => <Game>[],
  error: (_, __) => <Game>[],
);

final createdGames = myGamesAsync.when(
  data: (games) =>
      games.where((g) => currentUserId == g.organizerId).toList(),
  // ...
);
```

**Problem:** These `.where()` and `.toList()` operations execute on **every rebuild**, even when the data hasn't changed.

**Recommendation:**
- Use `useMemoized` from `flutter_hooks` or compute in initState/derived state
- Store filtered results in state variables
- Only recompute when source data changes

### 5. 🟡 Missing const Constructors

**Location:** Throughout the codebase

**Examples:**
- `lib/widgets/sports/activity_card.dart` - Good use of const constructor
- Many stateless widgets missing const

**Recommendation:**
- Add `const` to all static widgets that don't depend on non-const parameters
- Reduces unnecessary rebuilds
- Improves tree-shaking and compile-time optimizations

### 6. 🟡 Image Caching Analysis

**Status:** ✅ Good implementation found

**Location:** 
- `lib/widgets/sports/activity_card.dart` (Lines 47-60)

**Implementation:**
```dart
isNetworkImage
  ? CachedNetworkImage(
      imageUrl: imageUrl,
      height: imgH,
      width: double.infinity,
      fit: BoxFit.cover,
      alignment: imageAlignment,
    )
  : Image.asset(...)
```

**Recommendation:** ✅ No changes needed - `CachedNetworkImage` is properly configured.

### 7. 🟡 SQLite Database Queries

**Location:** `lib/services/games/games_service_instance.dart`

**Issues:**
- No query limits or pagination
- Full table scans with `WHERE` clauses not optimized
- No indexing on frequently queried columns

**Example (Lines 154-165):**
```dart
final List<Map<String, dynamic>> maps = await db.query(
  _tableName,
  where: 'organizerId = ?',
  whereArgs: [userId],
  orderBy: 'dateTime DESC',
);
```

**Recommendation:**
- Add database indexes on `organizerId`, `isActive`, `dateTime`
- Implement pagination with `LIMIT` and `OFFSET`
- Consider using `compute()` for large dataset transformations

### 8. 🟡 Nested FutureBuilder Pattern

**Location:** `lib/screens/games/games_my_screen.dart` (Lines 96-132)

**Issue:**
```dart
child: FutureBuilder<Map<String, String>>(
  future: ref.read(cloud.cloudGamesActionsProvider).getGameInviteStatuses(game.id),
  builder: (context, statusesSnap) {
    // ...
    return FutureBuilder<List<Map<String, String?>>>(
      future: Future.wait(limited.map((uid) async {
        // Multiple future fetches in build method
      })),
    );
  },
);
```

**Problem:** 
- Multiple nested futures in the widget tree
- Triggers rebuilds on every future completion
- Expensive operations run in build method

**Recommendation:**
- Use `AsyncValue` with proper loading states
- Cache minimal profiles
- Consider using `useFuture` or provider-based approach

### 9. 🟢 Good Practices Found

✅ **Firebase connection listeners properly used:**
- `lib/widgets/common/offline_banner.dart` properly cancels subscription (Line 88)

✅ **AutomaticKeepAliveClientMixin used:**
- `lib/screens/activities/sports_screens/generic_sport_screen.dart` (Line 59)

✅ **Heavy computations in isolates:**
- Generic sport screen uses `compute()` for distance calculations (Line 139)

✅ **Debouncing implemented:**
- Generic sport screen has search debounce (Lines 113-122)

## Recommendations by Priority

### High Priority (Fix Immediately)

1. **Cancel Firebase Stream Listeners**
   - Add proper disposal for all Firebase `Stream` subscriptions
   - Implement in widget dispose methods
   - Use `StreamSubscription.cancel()` in all cleanup

2. **Fix Global Timer**
   - Either implement cache cleanup or remove the timer
   - Consider provider-based periodic cleanup instead

3. **Fix QR Stream Subscription**
   - Move subscription to widget state
   - Ensure proper cancellation on widget dispose

### Medium Priority (Improve Performance)

4. **Memoize Heavy Computations**
   - Store filtered/transformed lists in state
   - Use `useMemoized` or similar patterns
   - Avoid repeated `.where()`, `.map()`, `.toList()` in build

5. **Add SQLite Indexes**
   - Index on `organizerId`, `isActive`, `dateTime`
   - Consider compound indexes for common queries

6. **Refactor Nested FutureBuilder**
   - Use provider-based state management
   - Cache minimal profiles
   - Implement proper loading states

### Low Priority (Code Quality)

7. **Add Missing const Constructors**
   - Add `const` to all eligible static widgets
   - Improves compile-time optimizations

8. **Add Query Limits**
   - Implement pagination for database queries
   - Add `LIMIT` clauses to prevent loading entire tables

## Code Examples

### Example 1: Fix Firebase Stream Listener

**Before:**
```dart
class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  @override
  Widget build(BuildContext context) {
    final friendsStream = ref.read(friendsActionsProvider)
        .watchUserFriends(currentUserId);
    return StreamBuilder(
      stream: friendsStream,
      builder: (context, snapshot) {
        // No cancellation
      },
    );
  }
}
```

**After:**
```dart
class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  StreamSubscription? _friendsSub;
  
  @override
  void initState() {
    super.initState();
    _friendsSub = ref.read(friendsActionsProvider)
        .watchUserFriends(currentUserId)
        .listen((friends) {
      if (mounted) setState(() => this._friends = friends);
    });
  }
  
  @override
  void dispose() {
    _friendsSub?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Use _friends from state
  }
}
```

### Example 2: Memoize Heavy Computations

**Before:**
```dart
@override
Widget build(BuildContext context) {
  final joinedGames = myGamesAsync.when(
    data: (games) => games.where((g) => currentUserId != g.organizerId).toList(),
    // ...
  );
  // Recomputes on every build
}
```

**After:**
```dart
List<Game>? _joinedGames;
List<Game>? _createdGames;

@override
void initState() {
  super.initState();
  ref.listenManual<AsyncValue<List<Game>>>(myGamesProvider, (prev, next) {
    if (next.hasValue) {
      final games = next.value!;
      _joinedGames = games.where((g) => currentUserId != g.organizerId).toList();
      _createdGames = games.where((g) => currentUserId == g.organizerId).toList();
      if (mounted) setState(() {});
    }
  });
}

@override
Widget build(BuildContext context) {
  final joinedGames = _joinedGames ?? <Game>[];
  // Use cached results
}
```

## Testing Recommendations

1. **Memory Leak Testing:**
   - Use Flutter DevTools Memory profiler
   - Navigate through screens 10+ times
   - Check for growing memory usage

2. **Performance Profiling:**
   - Use Widget Inspector to identify expensive widgets
   - Check rebuild frequency with `setState` calls
   - Monitor frame rendering time

3. **Firebase Cost Monitoring:**
   - Track Realtime Database read/write operations
   - Identify unnecessary listeners
   - Check for duplicate data fetches

## Conclusion

The app has a solid foundation with good practices in several areas (image caching, isolate usage, debouncing). However, there are critical issues with Firebase listener lifecycle management that need immediate attention. The nested FutureBuilder pattern and heavy computations in build methods should be refactored for better performance.

**Estimated Impact:**
- Memory leak fixes: High impact, improves app stability
- Computation memoization: Medium impact, improves frame rate
- Database optimization: Medium impact, improves load times
- Code quality improvements: Low impact, better maintainability

