# MoveYoung - Smart Player

A Flutter application for organizing and joining sports games with friends, built with modern architecture principles and state management.

## Architecture Overview

This application has been completely migrated to use **Riverpod** for state management, implementing clean architecture principles with dependency injection and reactive programming.

### Key Architectural Changes

- **State Management**: Migrated from static singletons to Riverpod providers
- **Dependency Injection**: Services are now injected through providers rather than using static access
- **Reactive Programming**: All state changes are automatically propagated to UI components
- **Testability**: Providers can be easily mocked and tested in isolation
- **Separation of Concerns**: Clear separation between services, providers, and UI components

### Architecture Layers

1. **UI Layer**: Flutter widgets using `ConsumerWidget` and `ConsumerStatefulWidget`
2. **Provider Layer**: Riverpod providers for state management and dependency injection
3. **Service Layer**: Instance-based services with proper dependency injection
4. **Data Layer**: Firebase Realtime Database, SQLite, and external APIs

## Project Structure

```
lib/
├── providers/           # Riverpod providers for state management
│   └── services/       # Service providers (auth, games, friends, etc.)
├── services/           # Instance-based services
│   ├── archive/        # Archived static services (legacy)
│   └── *_instance.dart # New instance-based services
├── screens/            # UI screens using Riverpod
├── models/             # Data models
├── widgets/            # Reusable widgets
└── utils/              # Utility functions
```

## Key Features

- **Authentication**: Firebase Auth with Google Sign-In and anonymous authentication
- **Games Management**: Create, join, and manage sports games
- **Friends System**: Add friends, send/accept friend requests
- **Real-time Updates**: Live updates using Firebase Realtime Database
- **Offline Support**: Local SQLite database for offline functionality
- **Notifications**: Push notifications for game invites and friend requests
- **Maps Integration**: Google Maps for location-based game discovery

## Technology Stack

- **Flutter**: Cross-platform mobile development
- **Riverpod**: State management and dependency injection
- **Firebase**: Authentication, Realtime Database, Messaging
- **SQLite**: Local database for offline support
- **Google Maps**: Location services and mapping
- **Easy Localization**: Multi-language support (EN/NL)

## Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Firebase project setup
- Google Maps API key

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Update Firebase configuration in `lib/firebase_options.dart`

4. Run the app:
   ```bash
   flutter run
   ```

## Development

### Running Tests

```bash
flutter test
```

### Building for Production

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## Architecture Benefits

### Before Migration (Static Singletons)
- Difficult to test
- Tight coupling between components
- Global state management issues
- Hard to mock dependencies

### After Migration (Riverpod Providers)
- ✅ Easy to test with provider overrides
- ✅ Loose coupling through dependency injection
- ✅ Reactive state management
- ✅ Compile-time safety
- ✅ Automatic dependency injection
- ✅ Better performance with lazy loading

## Provider Usage Examples

### Basic Provider Usage
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    return currentUser.when(
      data: (user) => Text('Welcome ${user?.displayName}'),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

### Service Actions
```dart
class GameActions {
  final Ref _ref;
  
  GameActions(this._ref);
  
  Future<void> createGame(Game game) async {
    // Implementation
    _ref.invalidate(myGamesProvider); // Refresh data
  }
}
```

## Migration Status

- ✅ Phase 1: Riverpod setup and ProviderScope configuration
- ✅ Phase 2: Core services converted to instance-based with providers
- ✅ Phase 3: UI screens migrated to use providers
- ✅ Phase 4: All services migrated to instance-based architecture
- ✅ Phase 5: All screens migrated to use providers
- ✅ Phase 6: Testing infrastructure added, old patterns cleaned up

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions, please contact the development team or create an issue in the repository.