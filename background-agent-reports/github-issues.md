# GitHub Issues for Code Quality Improvements

## Critical Issues

### Issue #1: Add Riverpod State Management
**Priority:** Critical  
**Labels:** architecture, state-management, refactoring

**Description:**
The project is described as a "Flutter/Riverpod project" but has no Riverpod implementation. This is a fundamental architectural issue that needs immediate attention.

**Current State:**
- No `flutter_riverpod` dependency in pubspec.yaml
- All screens use manual StatefulWidget state management
- No dependency injection or reactive programming patterns

**Acceptance Criteria:**
- [ ] Add `flutter_riverpod` dependency to pubspec.yaml
- [ ] Wrap main app with ProviderScope
- [ ] Convert at least one screen to use Riverpod providers
- [ ] Create basic provider structure

**Files to Modify:**
- `pubspec.yaml`
- `lib/main.dart`
- Create `lib/providers/` directory

---

### Issue #2: Eliminate Code Duplication in Field Screens
**Priority:** Critical  
**Labels:** refactoring, code-quality, duplication

**Description:**
Six field screens contain nearly identical code patterns, creating a maintenance nightmare and inconsistent behavior.

**Current State:**
- `football_field_screen.dart` - 268 lines
- `basketball_court_screen.dart` - 316 lines  
- `fitness_station_screen.dart` - 202 lines
- `games_corner_screen.dart` - 246 lines
- `skate_bmx_screen.dart` - 246 lines
- All contain identical patterns for: data loading, filtering, navigation, sharing

**Acceptance Criteria:**
- [ ] Create base `FieldScreen` widget with common functionality
- [ ] Extract shared providers for data fetching
- [ ] Reduce code duplication by at least 70%
- [ ] Maintain existing functionality

**Files to Modify:**
- Create `lib/widgets/field_screen_base.dart`
- Create `lib/providers/field_providers.dart`
- Refactor all field screens

---

### Issue #3: Convert OverpassService to Provider Pattern
**Priority:** High  
**Labels:** architecture, services, dependency-injection

**Description:**
OverpassService uses static methods instead of dependency injection, making it difficult to test and violating SOLID principles.

**Current State:**
- All methods are static
- No dependency injection
- Difficult to mock for testing
- Violates single responsibility principle

**Acceptance Criteria:**
- [ ] Convert to instance-based service
- [ ] Create Riverpod provider for the service
- [ ] Add proper error handling
- [ ] Make it testable with dependency injection

**Files to Modify:**
- `lib/services/overpass_service.dart`
- Create `lib/providers/overpass_provider.dart`

---

### Issue #4: Implement Internationalization
**Priority:** High  
**Labels:** i18n, localization, user-experience

**Description:**
All UI strings are hardcoded in English, preventing support for multiple languages.

**Current State:**
- No `flutter_localizations` dependency
- All strings hardcoded in UI files
- No translation files
- Cannot support Dutch language (mentioned in knowledge items)

**Acceptance Criteria:**
- [ ] Add `flutter_localizations` dependency
- [ ] Create `lib/l10n/` directory with translation files
- [ ] Extract all hardcoded strings to translation keys
- [ ] Support English and Dutch languages
- [ ] Update all UI files to use `.tr()` method

**Files to Modify:**
- `pubspec.yaml`
- `lib/main.dart`
- Create `lib/l10n/` directory
- All UI files

---

### Issue #5: Add Comprehensive Error Handling
**Priority:** High  
**Labels:** error-handling, user-experience, robustness

**Description:**
Current error handling is minimal with generic messages and no retry mechanisms.

**Current State:**
- Generic "Failed to load data" messages
- No retry mechanisms
- No user-friendly error states
- No offline handling

**Acceptance Criteria:**
- [ ] Create error handling utilities
- [ ] Add retry mechanisms for network calls
- [ ] Implement user-friendly error messages
- [ ] Add offline state handling
- [ ] Create error recovery flows

**Files to Modify:**
- Create `lib/utils/error_handler.dart`
- Create `lib/widgets/error_widgets.dart`
- Update all field screens

---

### Issue #6: Add Testing Infrastructure
**Priority:** High  
**Labels:** testing, quality-assurance, coverage

**Description:**
No test files exist, creating significant regression risks.

**Current State:**
- No unit tests
- No widget tests
- No integration tests
- No test coverage metrics

**Acceptance Criteria:**
- [ ] Add unit tests for services
- [ ] Add widget tests for UI components
- [ ] Add integration tests for critical flows
- [ ] Achieve at least 70% test coverage
- [ ] Set up CI/CD testing pipeline

**Files to Create:**
- `test/` directory structure
- `test/services/overpass_service_test.dart`
- `test/widgets/activity_card_test.dart`
- `test/screens/field_screen_test.dart`

---

## Medium Priority Issues

### Issue #7: Create Theme System
**Priority:** Medium  
**Labels:** ui, theming, design-system

**Description:**
Hardcoded colors and styles throughout the app make it difficult to maintain consistent design.

**Acceptance Criteria:**
- [ ] Create `AppTheme` class
- [ ] Define consistent color palette
- [ ] Create text styles
- [ ] Replace hardcoded values with theme references

### Issue #8: Standardize Navigation Patterns
**Priority:** Medium  
**Labels:** navigation, consistency, architecture

**Description:**
Mix of direct navigation and utility functions creates inconsistent behavior.

**Acceptance Criteria:**
- [ ] Create centralized navigation service
- [ ] Standardize all navigation calls
- [ ] Add proper route management
- [ ] Implement deep linking support

### Issue #9: Add Documentation
**Priority:** Medium  
**Labels:** documentation, maintainability, onboarding

**Description:**
Missing documentation makes it difficult for new developers to understand the codebase.

**Acceptance Criteria:**
- [ ] Add doc comments to all public APIs
- [ ] Create README with setup instructions
- [ ] Document architecture decisions
- [ ] Add code examples

---

## Implementation Timeline

**Week 1:**
- Issues #1, #2 (Riverpod + Code Duplication)

**Week 2:**
- Issues #3, #4 (Service Provider + i18n)

**Week 3:**
- Issues #5, #6 (Error Handling + Testing)

**Week 4:**
- Issues #7, #8, #9 (Theme + Navigation + Docs)

---

**Note:** These issues should be created in the project's GitHub repository for proper tracking and assignment.