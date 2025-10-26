# Detailed Plan: Fix 58 Failing Tests

## Root Cause Analysis (Confirmed)

### Issue 1: Auth Service Tests (18 failures)
**Root Cause**: Mockito's `when()` cannot be called inside a stub response. The tests are calling `when()` multiple times in succession, which causes "Cannot call `when` within a stub response" errors.

**Error Example**:
```
Bad state: Cannot call `when` within a stub response
package:mockito/src/mock.dart 1299:5       when
test\services\auth_service_test.dart 48:9  main.<fn>.<fn>.<fn>
```

**Solution**: Reset mocks between test calls or restructure mock setup.

### Issue 2: Database Tests (37 failures)
**Root Cause**: `databaseFactory` is not initialized. Tests call `TestDbHelper.initializeFfi()` but don't set the global `databaseFactory`.

**Error Example**:
```
Bad state: databaseFactory not initialized
databaseFactory is only initialized when using sqflite. When using `sqflite_common_ffi`
You must call `databaseFactory = databaseFactoryFfi;` before using global openDatabase API
```

**Solution**: Set `databaseFactory = databaseFactoryFfi` in test setup.

---

## Implementation Plan

### Phase 1: Fix Auth Service Tests (18 tests)

#### Step 1.1: Add Mock Reset
**File**: `test/services/auth_service_test.dart`

**Problem**: Multiple `when()` calls conflict with each other.

**Solution**: Use `reset()` or restructure tests to avoid conflicts.

**Changes**:
```dart
setUp(() {
  mockAuth = MockFirebaseAuth();
  mockUser = MockUser();
  
  // Reset mocks to clear any previous stubs
  reset(mockAuth);
  reset(mockUser);
  
  authService = AuthServiceInstance(mockAuth);
});
```

#### Step 1.2: Fix Mock Return Values
**Problem**: `mockUser.uid` returns null instead of String.

**Solution**: Ensure all mock properties return proper types.

**Changes**:
```dart
test('currentUser returns user when signed in', () {
  // Setup mocks BEFORE creating service or accessing properties
  when(mockUser.uid).thenReturn('test-uid-123');
  when(mockAuth.currentUser).thenReturn(mockUser);

  expect(authService.currentUser, isNotNull);
  expect(authService.isSignedIn, isTrue);
  expect(authService.currentUserId, 'test-uid-123');
});
```

**Estimated Time**: 1-2 hours

---

### Phase 2: Fix Database Tests (37 tests)

#### Step 2.1: Fix TestDbHelper
**File**: `test/helpers/test_db_helper.dart`

**Problem**: `initializeFfi()` doesn't set global `databaseFactory`.

**Solution**: Set `databaseFactory = databaseFactoryFfi`.

**Changes**:
```dart
/// Initialize FFI and set global database factory
static void initializeFfi() {
  try {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  } catch (e) {
    // Already initialized
  }
}
```

#### Step 2.2: Update Cache Service Tests
**File**: `test/services/cache_service_test.dart`

**Current Code**:
```dart
setUpAll(() {
  TestDbHelper.initializeFfi();
});
```

**Problem**: This should work after fixing TestDbHelper, but may need verification.

**Action**: Test after Phase 2.1 is complete.

#### Step 2.3: Update Friends Service Tests
**File**: `test/services/friends_service_test.dart`

**Same fix as cache service** - ensure `TestDbHelper.initializeFfi()` is called.

#### Step 2.4: Update Games Service Tests
**File**: `test/services/games_service_test.dart`

**Same fix as cache service** - ensure `TestDbHelper.initializeFfi()` is called.

#### Step 2.5: Update Profile Settings Tests
**File**: `test/services/profile_settings_service_test.dart`

**Same fix as cache service** - ensure `TestDbHelper.initializeFfi()` is called.

**Estimated Time**: 2-3 hours

---

### Phase 3: Verify and Document

#### Step 3.1: Run Full Test Suite
**Command**: `flutter test`

**Expected Result**: All 354 tests pass (or 353 with 1 expected failure for image cache).

#### Step 3.2: Document Fixes
**File**: `TEST_FIXES_SUMMARY.md`

**Content**:
- What was broken
- Root causes identified
- Solutions implemented
- Test results before/after

**Estimated Time**: 30 minutes

---

## Detailed Implementation Steps

### Step-by-Step: Auth Service Tests

1. **Add reset() calls in setUp()**
   ```dart
   setUp(() {
     mockAuth = MockFirebaseAuth();
     mockUser = MockUser();
     reset(mockAuth);
     reset(mockUser);
     authService = AuthServiceInstance(mockAuth);
   });
   ```

2. **Fix test order - setup mocks before accessing properties**
   - Move all `when()` calls to the beginning of each test
   - Ensure mocks are configured before service methods are called

3. **Add proper type returns for all mock properties**
   - `mockUser.uid` → String
   - `mockUser.displayName` → String?
   - `mockUser.email` → String?

### Step-by-Step: Database Tests

1. **Update TestDbHelper.initializeFfi()**
   ```dart
   static void initializeFfi() {
     try {
       sqfliteFfiInit();
       databaseFactory = databaseFactoryFfi;  // ADD THIS LINE
     } catch (e) {
       // Already initialized
     }
   }
   ```

2. **Verify all test files call initializeFfi() in setUpAll()**
   - cache_service_test.dart ✓ (already has it)
   - friends_service_test.dart (check)
   - games_service_test.dart (check)
   - profile_settings_service_test.dart (check)

3. **Run tests individually to verify fixes**
   ```bash
   flutter test test/services/cache_service_test.dart
   flutter test test/services/friends_service_test.dart
   flutter test test/services/games_service_test.dart
   flutter test test/services/profile_settings_service_test.dart
   ```

---

## Success Criteria

- [ ] All 18 auth service tests pass
- [ ] All 11 cache service tests pass
- [ ] All 7 friends service tests pass
- [ ] All 12 games service tests pass
- [ ] All 9 profile settings tests pass
- [ ] Total: 57/58 tests pass (1 expected failure for image cache)
- [ ] No regressions in currently passing tests
- [ ] Full test suite completes without errors

---

## Risk Assessment

### Low Risk
- Database factory fix is straightforward
- TestDbHelper change is isolated

### Medium Risk
- Auth service mock reset may affect test isolation
- Need to verify no side effects from reset()

### Mitigation
- Test each file individually after changes
- Run full suite multiple times to check for flakiness
- Document any remaining issues

---

## Estimated Total Time

- Phase 1 (Auth): 1-2 hours
- Phase 2 (Database): 2-3 hours
- Phase 3 (Verify): 30 minutes

**Total: 3.5-5.5 hours**

---

## Files to Modify

1. `test/helpers/test_db_helper.dart` - Add `databaseFactory = databaseFactoryFfi`
2. `test/services/auth_service_test.dart` - Add mock resets and fix mock setup order
3. Verify (no changes needed if TestDbHelper fix works):
   - `test/services/cache_service_test.dart`
   - `test/services/friends_service_test.dart`
   - `test/services/games_service_test.dart`
   - `test/services/profile_settings_service_test.dart`

---

## Next Steps

1. Start with Phase 1 (Auth tests) - isolated and easier to fix
2. Move to Phase 2 (Database tests) - single fix should resolve all 37
3. Run full test suite and document results
4. Create summary of improvements

---

## Notes

- These failures are pre-existing and unrelated to recent improvements
- The 14 tests we enabled and 7 widget tests we added are all passing
- This plan addresses the remaining technical debt in the test suite


