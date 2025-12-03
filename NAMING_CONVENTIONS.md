# Naming Conventions

This document defines the naming conventions for the Flutter application codebase. These conventions ensure consistency, improve readability, and make the codebase easier to navigate and maintain.

## Service Layer Naming

### Interfaces
- **Pattern:** `I*Service`
- **Example:** `IGamesService`, `IFriendsService`, `INotificationService`
- **Purpose:** Define contracts for service implementations
- **Location:** `lib/features/*/services/*_service.dart` or `lib/services/*/*_service.dart`

### Service Implementations
- **Pattern:** `*Service` (preferred) or `*ServiceInstance` (legacy)
- **Example:** `GamesService`, `FriendsService`, `WeatherService`
- **Note:** Legacy code uses `*ServiceInstance` suffix. New code should use `*Service` without suffix.
- **Location:** `lib/features/*/services/*_service_instance.dart` or `lib/services/*/*_service_instance.dart`

### Riverpod Providers
- **Pattern:** `*Provider` for service providers, `*ActionsProvider` for action wrappers
- **Example:** 
  - `gamesServiceProvider` - Provides service instance
  - `gamesActionsProvider` - Provides action wrapper for mutations
- **Location:** `lib/features/*/services/*_provider.dart` or `lib/services/*/*_provider.dart`

### Action Wrappers
- **Pattern:** `*Actions` class wrapped by `*ActionsProvider`
- **Example:** `GamesActions` class provided by `gamesActionsProvider`
- **Purpose:** Simplify API for UI components, encapsulate mutation operations

## Method Naming

### Data Loading Methods
- **`_load*`** - Load data from cache or local storage
  - Example: `_loadFields()`, `_loadUserDetails()`
  - Use when: Data comes from local database, cache, or SharedPreferences

- **`_fetch*`** - Fetch data from network/remote source
  - Example: `_fetchWeather()`, `_fetchUserProfile()`
  - Use when: Data comes from API, Firebase, or external service

- **`_get*`** - Get computed or derived values
  - Example: `_getAvailableTimes()`, `_getFormattedDate()`
  - Use when: Computing values from existing data, no I/O operations

### Validation Methods
- **`validate*`** - Validate input or state
  - Example: `validateRequiredFields()`, `validateFutureDateTime()`
  - Use when: Checking if data meets requirements

### Processing Methods
- **`process*`** or **`normalize*`** - Transform or normalize data
  - Example: `normalizeFields()`, `processFieldData()`
  - Use when: Transforming data structure or format

## Variable Naming

### Private Variables
- **Pattern:** `_camelCase`
- **Example:** `_selectedSport`, `_isLoading`, `_availableFields`
- **Rule:** All private instance variables must start with underscore

### Public Variables
- **Pattern:** `camelCase`
- **Example:** `selectedSport`, `isLoading`, `availableFields`
- **Rule:** Public variables should not have underscore prefix

### Constants
- **Pattern:** `camelCase` for instance constants, `SCREAMING_SNAKE_CASE` for static constants
- **Example:** 
  - Instance: `static const maxPlayers = 10`
  - Static: `static const MAX_RETRY_ATTEMPTS = 3`

## Widget Naming

### Screen Widgets
- **Pattern:** `*Screen`
- **Example:** `GameOrganizeScreen`, `FriendsScreen`, `ProfileScreen`
- **Location:** `lib/features/*/screens/*_screen.dart`

### Private Widget Builders
- **Pattern:** `_build*` for build methods, `_*Widget` for widget classes
- **Example:** 
  - `_buildSportCard()` - Build method
  - `_SportCardWidget` - Widget class

### Reusable Widgets
- **Pattern:** `*Widget` or descriptive name without suffix
- **Example:** `AppBackButton`, `SuccessCheckmarkOverlay`, `ErrorRetryWidget`
- **Location:** `lib/widgets/*.dart`

## Utility Functions

### Utility Classes
- **Pattern:** `*Helper`, `*Utils`, or `*Formatter`
- **Example:** `SnackBarHelper`, `TimeSlotUtils`, `DateFormatter`
- **Location:** `lib/utils/*.dart`

### Static Utility Functions
- **Pattern:** `camelCase` for static methods
- **Example:** `parseTimeString()`, `normalizeFields()`, `getDayOfWeekAbbr()`
- **Rule:** Use descriptive verbs that indicate the action

## File Naming

### General Rules
- Use `snake_case` for all file names
- Match file name to primary class/function name
- Use descriptive names that indicate purpose

### Examples
- Service: `games_service.dart`, `games_service_instance.dart`
- Screen: `game_organize_screen.dart`
- Widget: `app_back_button.dart`
- Utility: `snackbar_helper.dart`, `time_slot_utils.dart`
- Model: `game.dart`, `service_error.dart`

## Provider Naming

### Service Providers
- **Pattern:** `*ServiceProvider`
- **Example:** `gamesServiceProvider`, `friendsServiceProvider`
- **Returns:** Service instance

### Stream Providers
- **Pattern:** `watch*Provider` or `*StreamProvider`
- **Example:** `watchFriendsListProvider`, `syncStatusProvider`
- **Returns:** Stream of data

### State Providers
- **Pattern:** `*StateProvider` or `*Provider`
- **Example:** `currentUserIdProvider`, `isHighContrastEnabledProvider`
- **Returns:** State value

### Action Providers
- **Pattern:** `*ActionsProvider`
- **Example:** `gamesActionsProvider`, `friendsActionsProvider`
- **Returns:** Action wrapper class

## Error Handling

### Exception Classes
- **Pattern:** `*Exception` extends `ServiceException`
- **Example:** `ValidationException`, `NetworkException`, `AuthException`
- **Location:** `lib/models/infrastructure/service_error.dart`

## Migration Notes

### Current State
- Many services use `*ServiceInstance` suffix (legacy)
- Some services use `*Service` without suffix (newer)
- Inconsistency exists but is being addressed incrementally

### Future Refactoring
When refactoring to standardize naming:
1. Update class names from `*ServiceInstance` to `*Service`
2. Update file names accordingly
3. Update all imports and references
4. Update provider names if needed
5. Ensure tests are updated

### Breaking Changes
Full standardization would require:
- Renaming ~20+ service classes
- Updating ~100+ import statements
- Updating all provider definitions
- Comprehensive testing

**Recommendation:** Apply new naming conventions to new code. Refactor existing code incrementally when touching related files.

## Examples

### Good Examples
```dart
// Interface
abstract class IGamesService { ... }

// Implementation
class GamesService implements IGamesService { ... }

// Provider
final gamesServiceProvider = Provider<IGamesService>((ref) { ... });

// Actions
class GamesActions { ... }
final gamesActionsProvider = Provider<GamesActions>((ref) { ... });

// Methods
void _loadFields() { ... }        // From cache
Future<void> _fetchWeather() { ... }  // From network
List<String> _getAvailableTimes() { ... }  // Computed
```

### Avoid
```dart
// Inconsistent naming
class GamesServiceInstance { ... }  // Should be GamesService
class CloudGamesService { ... }     // Inconsistent with GamesServiceInstance
void loadFields() { ... }           // Should be _loadFields() if private
```

## Summary

| Type | Pattern | Example |
|------|---------|---------|
| Interface | `I*Service` | `IGamesService` |
| Service Implementation | `*Service` | `GamesService` |
| Service Provider | `*ServiceProvider` | `gamesServiceProvider` |
| Actions Class | `*Actions` | `GamesActions` |
| Actions Provider | `*ActionsProvider` | `gamesActionsProvider` |
| Screen Widget | `*Screen` | `GameOrganizeScreen` |
| Private Method | `_verb*` | `_loadFields()`, `_fetchWeather()` |
| Utility Class | `*Helper`, `*Utils`, `*Formatter` | `SnackBarHelper`, `TimeSlotUtils` |

---

**Last Updated:** Generated during architecture review  
**Status:** Active guidelines for new code, legacy code to be refactored incrementally

