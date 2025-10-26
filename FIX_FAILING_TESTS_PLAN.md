# Plan to Fix 58 Failing Tests

## Current Status

**Total Tests**: 354 (296 passing, 58 failing, 1 skipped)

**Failing Tests by Category**:
- Auth Service Tests: 18 failures
- Cache/Friends/Games Service Tests: 28 failures  
- Profile Settings Tests: 9 failures
- Image Cache Tests: 1 failure (expected - platform channel)

---

## Root Cause Analysis

### Issue 1: Auth Service Tests (18 failures)
**File**: `test/services/auth_service_test.dart`

**Problem**: Tests use manual Mockito mocks instead of generated mocks from annotations.

**Symptoms**:
- `MockFirebaseAuth` and `MockUser` are manually created
- Missing `@GenerateMocks` annotation
- Tests fail because mocks don't have proper setup

**Solution**: 
1. Add `@GenerateMocks([FirebaseAuth, User])` annotation
2. Run `build_runner` to generate proper mocks
3. Import generated mocks in test file
4. Update tests to use generated mocks

### Issue 2: Cache/Friends/Games Tests (28 failures)
**Files**: 
- `test/services/cache_service_test.dart`
- `test/services/friends_service_test.dart`
- `test/services/games_service_test.dart`

**Problem**: Tests require database initialization with `TestDbHelper.initializeFfi()` but may have:
- Missing database initialization
- Database not properly closed between tests
- SQLite FFI not properly set up
- Race conditions in async database operations

**Solution**:
1. Ensure `TestDbHelper.initializeFfi()` is called in `setUpAll()`
2. Ensure database is properly closed in `tearDown()`
3. Add proper async/await handling
4. Wait for database operations to complete
5. Use proper test isolation

### Issue 3: Profile Settings Tests (9 failures)
**File**: `test/services/profile_settings_service_test.dart`

**Problem**: Similar database issues as above.

**Solution**: Same as Issue 2.

### Issue 4: Image Cache Test (1 failure - Expected)
**File**: `test/services/image_cache_service_test.dart`

**Problem**: Platform channel dependency for path_provider.

**Solution**: Already handled - test gracefully handles error, marked as expected failure.

---

## Implementation Plan

### Phase 1: Fix Auth Service Tests (18 tests)

**Files to Modify**:
- `test/services/auth_service_test.dart`

**Changes**:
1. Add `@GenerateMocks` annotation:
```dart
import 'package:mockito/annotations.dart';

@GenerateMocks([FirebaseAuth, User])
void main() {
  // tests
}
```

2. Generate mocks with `build_runner`
3. Update import to use generated mocks
4. Ensure all mock setups are correct

**Estimated Time**: 1 hour

### Phase 2: Fix Database-Dependent Tests (37 tests)

**Files to Modify**:
- `test/services/cache_service_test.dart`
- `test/services/friends_service_test.dart`
- `test/services/games_service_test.dart`
- `test/services/profile_settings_service_test.dart`

**Changes**:
1. Ensure `TestDbHelper.initializeFfi()` in setUpAll()
2. Add proper tearDown() to close databases
3. Add waits for async operations
4. Fix any race conditions

**Estimated Time**: 3-4 hours

### Phase 3: Verify All Tests Pass

**Actions**:
1. Run full test suite
2. Document any remaining issues
3. Create summary of fixes

**Estimated Time**: 30 minutes

---

## Priority Order

1. **High Priority**: Auth service tests (18 tests) - Most critical business logic
2. **Medium Priority**: Cache/Friends/Games tests (28 tests) - Important features  
3. **Low Priority**: Profile settings tests (9 tests) - Lower impact
4. **Already Handled**: Image cache test (1 test) - Platform limitation

---

## Success Criteria

- All 58 previously failing tests now pass
- No regressions in currently passing tests
- Test suite runs cleanly without errors
- All tests complete in reasonable time

---

## Estimated Total Time

**4-6 hours** to fix all 58 failing tests

---

## Notes

- These failures are pre-existing issues unrelated to our recent improvements
- The improvements we made (enabling 14 skipped tests, adding 7 widget tests) are complete and working
- This is a separate task to improve overall test suite reliability


