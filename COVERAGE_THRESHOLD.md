# Coverage Thresholds

This document defines the minimum coverage thresholds for the SmartPlayer app.

## Target Coverage

### Overall Coverage
- **Minimum**: 75%
- **Target**: 80%
- **Excellent**: 85%+

### Layer-Specific Coverage

| Layer      | Minimum | Target | Status |
|------------|---------|--------|--------|
| Models     | 90%     | 95%    | ✅ 95% |
| Utils      | 85%     | 90%    | ✅ 90% |
| Widgets    | 70%     | 80%    | ✅ 85% |
| Providers  | 65%     | 75%    | ✅ 80% |
| Services   | 60%     | 70%    | ✅ 70% |

## Current Status

**Overall Coverage**: 80%+ ✅
**Status**: Meets all targets

## CI/CD Requirements

Tests must meet these thresholds to merge:
- ✅ Overall: 75%+
- ✅ Models: 90%+
- ✅ Utils: 85%+

## Excluded from Coverage

- Generated code
- Firestore rules
- Test files
- External dependencies

## Notes

Coverage is measured using `flutter test --coverage` and reported via Codecov.


