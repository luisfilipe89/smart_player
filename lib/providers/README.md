# Providers

This directory contains all Riverpod providers for the application, implementing a clean architecture with dependency injection and state management.

## Architecture Overview

The provider architecture follows these principles:
- **Dependency Injection**: Services are injected through providers rather than using static singletons
- **Reactive State Management**: All state changes are automatically propagated to UI components
- **Testability**: Providers can be easily mocked and tested in isolation
- **Separation of Concerns**: Clear separation between services, providers, and UI components

## Structure

- `lib/providers/services/`: Providers that expose service instances and their actions
  - `auth_provider.dart`: Authentication state and actions
  - `games_provider.dart`: Games management state and actions
  - `friends_provider.dart`: Friends management state and actions
  - `notification_provider.dart`: Notification service and actions
  - `sync_provider.dart`: Sync service and actions
  - `connectivity_provider.dart`: Connectivity monitoring and actions
  - `cache_provider.dart`: Cache service and actions
- `lib/providers/features/`: Feature-specific providers (future expansion)
- `lib/providers/utils/`: General utility providers (future expansion)

## Provider Types

### Service Providers
Service providers expose service instances for dependency injection:
```dart
final authServiceProvider = Provider<AuthServiceInstance>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  return AuthServiceInstance(firebaseAuth);
});
```

### State Providers
State providers expose reactive data:
```dart
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.userStream;
});
```

### Action Providers
Action providers expose methods for performing operations:
```dart
final authActionsProvider = Provider<AuthActions>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthActions(authService, ref);
});
```

## Usage Patterns

### In Widgets
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final authActions = ref.read(authActionsProvider);
    
    return currentUser.when(
      data: (user) => Text('Welcome ${user?.displayName}'),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

### In Services
```dart
class SomeService {
  final AuthServiceInstance _authService;
  
  SomeService(this._authService);
  
  Future<void> doSomething() async {
    final user = _authService.currentUser;
    if (user != null) {
      // Perform operation
    }
  }
}
```

## Testing

Providers can be easily tested by overriding them with mocks:
```dart
testWidgets('should handle auth state', (tester) async {
  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(mockAuthService),
    ],
  );
  
  final user = container.read(currentUserProvider);
  expect(user, isNotNull);
  
  container.dispose();
});
```

## Best Practices

1. **Use autoDispose**: Add `.autoDispose` to providers that should clean up when not needed
2. **Use family**: Add `.family` for parameterized providers
3. **Separate Concerns**: Keep service logic in service classes, state management in providers
4. **Error Handling**: Always handle AsyncValue states (loading, data, error)
5. **Provider Invalidation**: Use `ref.invalidate()` to refresh data when needed
6. **Dependency Injection**: Inject dependencies through constructor parameters, not static access

## Migration from Static Services

The old static service pattern:
```dart
// OLD - Static singleton
class AuthService {
  static final _instance = AuthService._();
  static AuthService get instance => _instance;
  
  Future<void> signIn() async {
    // Implementation
  }
}
```

Has been replaced with:
```dart
// NEW - Instance-based with dependency injection
class AuthServiceInstance {
  final FirebaseAuth _firebaseAuth;
  
  AuthServiceInstance(this._firebaseAuth);
  
  Future<void> signIn() async {
    // Implementation
  }
}

// Provider for dependency injection
final authServiceProvider = Provider<AuthServiceInstance>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  return AuthServiceInstance(firebaseAuth);
});
```

## Performance Considerations

- Providers are lazy-loaded by default
- Use `ref.watch()` for reactive data that should trigger rebuilds
- Use `ref.read()` for one-time operations that don't need reactivity
- Use `ref.select()` for fine-grained reactivity when only part of the data changes
- Use `.autoDispose` for providers that should clean up when not needed

## Future Enhancements

- Add feature-based providers for complex features
- Implement provider caching strategies
- Add provider performance monitoring
- Create provider code generation for common patterns

## Migration Status

- Phase 1: ✅ Setup complete - Riverpod dependencies added and ProviderScope configured
- Phase 2: ✅ Core services converted to instance-based with providers
- Phase 3: ✅ UI screens migrated to use providers
- Phase 4: ✅ All services migrated to instance-based architecture
- Phase 5: ✅ All screens migrated to use providers
- Phase 6: ✅ Testing infrastructure added, old patterns cleaned up
- Phase 7: ✅ **COMPLETE** - All static services migrated to instance-based providers
  - ✅ AuthService → AuthServiceInstance with StreamProvider
  - ✅ ConnectivityService → ConnectivityServiceInstance with reactive streams
  - ✅ QRService → QRServiceInstance with provider-based actions
  - ✅ ErrorHandlerService → ErrorHandlerServiceInstance with dependency injection
  - ✅ LocationService → LocationServiceInstance with provider-based actions
  - ✅ AccessibilityService → AccessibilityServiceInstance with StreamProvider
  - ✅ HapticsService → HapticsServiceInstance with reactive settings
  - ✅ CacheService → CacheServiceInstance with proper lifecycle management
  - ✅ Navigation → Provider-managed navigation with global key for FCM callbacks
  - ✅ SharedPreferences → Centralized provider with proper dependency injection

## Architecture Completion

**100% Riverpod Migration Achieved!** 🎉

All services now use the instance-based pattern with proper dependency injection:
- **No static singletons** (except global navigator key for FCM background callbacks)
- **Consistent provider patterns** across all services
- **Reactive state management** with StreamProvider and FutureProvider
- **Proper lifecycle management** with auto-dispose providers
- **Testable architecture** with easy mocking capabilities
- **Centralized SharedPreferences** - No more direct SharedPreferences.getInstance() calls