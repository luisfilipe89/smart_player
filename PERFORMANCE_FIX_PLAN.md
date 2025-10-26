# Performance Fix Implementation Plan

## Overview
This document outlines a systematic approach to fix the performance issues identified in the Flutter app.

## Fix Priority Matrix

### 🔴 Critical (Fix First - Causes Memory Leaks)
- Firebase Stream Listener Disposal
- Global Timer Issue
- QR Stream Subscription Memory Leak

### 🟡 High Priority (Improves Performance)
- Memoize Heavy Computations in Build
- Add SQLite Indexes
- Refactor Nested FutureBuilder

### 🟢 Medium Priority (Code Quality)
- Add Missing const Constructors
- Add Query Limits

---

## Detailed Implementation Plan

### Phase 1: Critical Memory Leak Fixes

#### Fix 1.1: Firebase Stream Listeners in FriendsServiceInstance

**File:** `lib/services/friends/friends_service_instance.dart`

**Current Issue:**
- Streams (Lines 401-434) don't have cancellation mechanism
- Usage in `friends_screen.dart` creates leak

**Solution:**
1. Update service to return cancellable subscriptions
2. Update UI to properly manage subscriptions

**Files to Modify:**
```
lib/services/friends/friends_service_instance.dart
lib/screens/friends/friends_screen.dart
```

**Implementation Steps:**
1. Add subscription tracking to widget state
2. Store subscriptions in widget
3. Cancel in dispose()
4. Add mounted checks before setState

**Estimated Impact:** High - Prevents memory leaks

---

#### Fix 1.2: Firebase Stream Listeners in CloudGamesServiceInstance

**File:** `lib/services/games/cloud_games_service_instance.dart`

**Current Issue:**
- `watchPendingInvitesCount()` (Lines 371-387) stream not cancelled
- Used in `home_screen.dart` (Lines 89-98)

**Solution:**
Same approach as Fix 1.1

**Files to Modify:**
```
lib/services/games/cloud_games_service_instance.dart
lib/screens/home/home_screen.dart
```

**Note:** This file already has some subscription handling (Line 35, 54) but needs improvement

**Implementation Steps:**
1. Verify subscription is properly cancelled in dispose
2. Add error handling
3. Add mounted checks

**Estimated Impact:** High - Prevents memory leaks

---

#### Fix 1.3: Global Timer Not Working

**File:** `lib/main.dart`

**Current Issue:**
- Timer created (Line 24, 57-63) but cache cleanup commented out
- Timer cancels on dispose but never does anything useful

**Solution Options:**
A. Implement the cache cleanup
B. Remove the timer if not needed
C. Move to provider-based periodic task

**Files to Modify:**
```
lib/main.dart
lib/services/cache/cache_service_instance.dart (if implementing cleanup)
```

**Recommended Approach:** Option B (Remove) unless cache cleanup is actually needed

**Implementation Steps:**
1. Uncomment and implement cache cleanup logic
2. OR remove the timer entirely
3. Test app startup time

**Estimated Impact:** Low - Minor resource waste, but not critical

---

#### Fix 1.4: QR Stream Subscription Memory Leak

**File:** `lib/screens/friends/friends_screen.dart` Lines 288-313

**Current Issue:**
- Subscription created in `_showMyQr()` method
- Only cancelled when dialog closes
- Widget can dispose before dialog closes

**Solution:**
Move subscription to widget state

**Files to Modify:**
```
lib/screens/friends/friends_screen.dart
```

**Implementation Steps:**
1. Add `StreamSubscription? _qrAutoCloseSub;` to widget state
2. Create subscription in `initState` or dedicated method
3. Cancel in `dispose()`
4. Check mounted before setState calls
5. Move dialog to separate widget if needed

**Estimated Impact:** Medium - Prevents potential memory leak

---

### Phase 2: Performance Optimizations

#### Fix 2.1: Memoize Heavy Computations in Games Screen

**File:** `lib/screens/games/games_my_screen.dart`

**Current Issue:**
- Lines 494-506: `.where()` and `.toList()` called in every build
- Filtering happens on every rebuild even when data unchanged

**Solution:**
Store filtered results in state, recompute only when needed

**Files to Modify:**
```
lib/screens/games/games_my_screen.dart
```

**Implementation Steps:**
1. Add state variables for joined and created games
2. Use `ref.listenManual` to watch provider changes
3. Filter data when provider updates, store in state
4. Use cached results in build method
5. Repeat pattern for all heavy computations

**Estimated Impact:** High - Reduces unnecessary work on rebuild

---

#### Fix 2.2: Memoize Heavy Computations in Generic Sport Screen

**File:** `lib/screens/activities/sports_screens/generic_sport_screen.dart`

**Current Issue:**
- Filtering happens in build (Lines 400-500)
- Multiple complex filter operations

**Solution:**
Use same pattern as Fix 2.1

**Files to Modify:**
```
lib/screens/activities/sports_screens/generic_sport_screen.dart
```

**Implementation Steps:**
1. Store filtered results in state
2. Create `_applyFilters()` method that updates state
3. Call `_applyFilters()` only when:
   - Data loads
   - Search query changes
   - Filter selection changes
4. Use cached filtered list in build

**Estimated Impact:** High - Improves scrolling performance

---

#### Fix 2.3: Add SQLite Indexes

**File:** `lib/services/games/games_service_instance.dart`

**Current Issue:**
- No indexes on frequently queried columns
- Full table scans on every query

**Solution:**
Add database indexes in `_onCreate` and migration in `_onUpgrade`

**Files to Modify:**
```
lib/services/games/games_service_instance.dart
```

**Implementation Steps:**
1. Add indexes in `_onCreate()` method (after table creation)
2. Add migration logic in `_onUpgrade()` for existing databases
3. Increment database version
4. Index columns:
   - `organizerId`
   - `isActive`
   - `dateTime`
   - `isPublic`
   - Compound index: `(isActive, isPublic, dateTime)`

**SQL Example:**
```dart
await db.execute('CREATE INDEX idx_organizer ON $_tableName (organizerId)');
await db.execute('CREATE INDEX idx_active ON $_tableName (isActive)');
await db.execute('CREATE INDEX idx_datetime ON $_tableName (dateTime DESC)');
await db.execute('CREATE INDEX idx_compound ON $_tableName (isActive, isPublic, dateTime)');
```

**Estimated Impact:** Medium - Improves query performance

---

#### Fix 2.4: Refactor Nested FutureBuilder in Games Screen

**File:** `lib/screens/games/games_my_screen.dart` Lines 96-132

**Current Issue:**
- Deep nesting of FutureBuilders
- Expensive operations in build method
- Rebuilds on every future completion

**Solution:**
Use provider-based state management instead of nested FutureBuilders

**Files to Modify:**
```
lib/screens/games/games_my_screen.dart
```

**Implementation Steps:**
1. Create a provider for minimal profiles cache
2. Fetch and cache profiles when game data loads
3. Use cached profiles in UI
4. Remove nested FutureBuilders
5. Update UI to use cached data

**Estimated Impact:** Medium - Reduces unnecessary rebuilds

---

### Phase 3: Code Quality Improvements

#### Fix 3.1: Add Missing const Constructors

**Files:** Various widget files

**Current Issue:**
- Many StatelessWidgets missing `const` keyword
- Missing const parameters

**Solution:**
Systematically add `const` to all eligible widgets

**Files to Modify:**
```
lib/widgets/sports/activity_card.dart
lib/widgets/sports/sport_field_card.dart
lib/widgets/common/*.dart
lib/screens/**/*.dart (various)
```

**Implementation Steps:**
1. Find all StatelessWidget classes
2. Add `const` to constructor
3. Add `const` to all parameters
4. Update parent constructors to pass `const`
5. Test for compilation errors

**Example:**
```dart
// Before
class MyWidget extends StatelessWidget {
  MyWidget({super.key});
  ...
}

// After
const MyWidget({super.key});
```

**Estimated Impact:** Low - Improves compile-time optimizations

---

#### Fix 3.2: Add Query Limits to SQLite

**File:** `lib/services/games/games_service_instance.dart`

**Current Issue:**
- Queries return all results
- No pagination
- Could load thousands of games

**Solution:**
Add LIMIT and OFFSET to queries, implement pagination

**Files to Modify:**
```
lib/services/games/games_service_instance.dart
```

**Implementation Steps:**
1. Add optional limit parameter to query methods
2. Default limit to 50 results
3. Return pagination metadata
4. Update UI to support pagination
5. Use lazy loading for scroll lists

**Example:**
```dart
// Before
final maps = await db.query(_tableName, where: '...');

// After
final maps = await db.query(
  _tableName,
  where: '...',
  limit: limit ?? 50,
  offset: offset ?? 0,
);
```

**Estimated Impact:** Medium - Prevents loading large datasets

---

## Implementation Order

### Week 1: Critical Fixes
1. Fix 1.2 - CloudGamesService stream disposal (highest impact)
2. Fix 1.1 - FriendsService stream disposal
3. Fix 1.4 - QR subscription leak
4. Fix 1.3 - Global timer

### Week 2: High Priority
5. Fix 2.1 - Memoize games screen computations
6. Fix 2.2 - Memoize sport screen computations
7. Fix 2.3 - Add SQLite indexes

### Week 3: Medium Priority
8. Fix 2.4 - Refactor nested FutureBuilder
9. Fix 3.2 - Add query limits

### Week 4: Code Quality
10. Fix 3.1 - Add const constructors (throughout codebase)

---

## Testing Checklist

After each fix, test:
- [ ] Widget disposes properly (DevTools memory profiler)
- [ ] No console warnings about disposed widgets
- [ ] App doesn't crash on navigation
- [ ] Data loads correctly
- [ ] No performance degradation
- [ ] Memory usage doesn't grow over time

---

## Rollback Plan

1. Use Git branches for each fix
2. Test thoroughly before merging
3. Keep old code commented if risky
4. Use feature flags for incremental rollout if needed

---

## Success Metrics

**Before:**
- Memory leaks causing gradual slowdown
- Frequent rebuilds of expensive operations
- Full table scans on queries

**After:**
- Stable memory usage over time
- Reduced rebuilds (measure with DevTools)
- Query performance improved (measure with logs)
- Better frame rate during scrolling
- Lower Firebase read costs

---

## Next Steps

1. Review this plan
2. Prioritize based on business needs
3. Start with Fix 1.2 (highest impact)
4. Test each fix individually
5. Monitor metrics before/after each fix

