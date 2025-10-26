# Testing Guide

This directory contains comprehensive tests for the MoveYoung app, organized by type and functionality.

## Test Structure

```
test/
├── helpers/                 # Test utilities and shared code
│   ├── test_helpers.dart   # Common test setup functions
│   ├── mock_services.dart  # Mock service implementations
│   ├── test_data.dart      # Reusable test fixtures
│   └── pump_app.dart       # Widget testing helpers
├── models/                 # Model unit tests
│   ├── game_test.dart      # Game model tests
│   └── activity_test.dart  # Activity model tests
├── utils/                  # Utility function tests
│   ├── profanity_test.dart # Profanity filtering tests
│   ├── validation_test.dart # Input validation tests
│   ├── retry_helpers_test.dart # Retry logic tests
│   └── timeout_helpers_test.dart # Timeout handling tests
├── services/               # Service layer tests
│   ├── cache_service_test.dart # Cache service tests
│   ├── games_service_test.dart # Games service tests
│   └── friends_service_test.dart # Friends service tests
├── providers/              # Provider tests
│   ├── auth_provider_test.dart # Auth provider tests
│   ├── games_provider_test.dart # Games provider tests
│   └── friends_provider_test.dart # Friends provider tests
├── widgets/                # Widget tests
│   ├── activity_card_test.dart # Activity card tests
│   ├── sport_field_card_test.dart # Sport field card tests
│   └── offline_banner_test.dart # Offline banner tests
├── integration/            # Integration tests
│   ├── auth_flow_test.dart # Authentication flow tests
│   ├── game_flow_test.dart # Game management flow tests
│   └── friend_flow_test.dart # Friend management flow tests
├── golden/                 # Golden/visual regression tests
│   ├── home_screen_golden_test.dart # Home screen visual tests
│   ├── game_card_golden_test.dart # Game card visual tests
│   └── friend_card_golden_test.dart # Friend card visual tests
├── coverage_helper_test.dart # Coverage helper
└── README.md              # This file
```

## Running Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test Types
```bash
# Unit tests only
flutter test test/models/ test/utils/ test/services/

# Widget tests only
flutter test test/widgets/

# Integration tests only
scripts/start_emulators.bat   # Windows (run in a separate terminal)
./scripts/start_emulators.sh  # macOS/Linux (separate terminal)

# Then in another terminal:
flutter test test/integration/

# Golden tests only
flutter test test/golden/
```

### Run Tests with Coverage
```bash
flutter test --coverage
```

### Run Tests in Watch Mode
```bash
flutter test --watch
```

### Run Tests with Verbose Output
```bash
flutter test --verbose
```

## Test Categories

### Unit Tests
- **Models**: Test data models, serialization, validation
- **Utils**: Test utility functions, helpers, validators
- **Services**: Test business logic, API calls, data processing

### Widget Tests
- **Components**: Test individual widgets in isolation
- **Interactions**: Test user interactions, form submissions
- **States**: Test loading, error, success states

### Integration Tests
- **User Flows**: Test complete user journeys
- **Cross-Service**: Test service interactions
- **Real Data**: Test with actual data and network calls

### Golden Tests
- **Visual Regression**: Catch unintended UI changes
- **Design Consistency**: Ensure UI looks correct
- **Cross-Platform**: Test on different screen sizes

## Writing Tests

### Test Naming Convention
```dart
group('Feature Name Tests', () {
  group('Method Name', () {
    test('should do something when condition', () {
      // Test implementation
    });
  });
});
```

### Test Structure
```dart
test('should return expected result when given valid input', () {
  // Arrange
  final input = 'test input';
  final expected = 'expected output';
  
  // Act
  final result = functionUnderTest(input);
  
  // Assert
  expect(result, expected);
});
```

### Async Tests
```dart
test('should handle async operation', () async {
  // Arrange
  final service = MockService();
  when(service.getData()).thenAnswer((_) async => 'data');
  
  // Act
  final result = await service.getData();
  
  // Assert
  expect(result, 'data');
  verify(service.getData()).called(1);
});
```

### Widget Tests
```dart
testWidgets('should render widget correctly', (tester) async {
  // Arrange
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: MyWidget(),
      ),
    ),
  );
  
  // Act & Assert
  expect(find.text('Expected Text'), findsOneWidget);
  expect(find.byType(ElevatedButton), findsOneWidget);
});
```

### Golden Tests
```dart
testGoldens('widget matches golden', (tester) async {
  await tester.pumpWidgetBuilder(
    MyWidget(),
    surfaceSize: Size(400, 600),
  );
  
  await screenMatchesGolden(tester, 'my_widget');
});
```

## Mocking

### Service Mocks
```dart
// Create mock
final mockService = MockMyService();

// Setup behavior
when(mockService.getData()).thenAnswer((_) async => 'data');
when(mockService.getData()).thenThrow(Exception('Error'));

// Verify calls
verify(mockService.getData()).called(1);
verifyNever(mockService.getData());
```

### Provider Mocks
```dart
// Override provider
final container = ProviderContainer(
  overrides: [
    myServiceProvider.overrideWithValue(mockService),
  ],
);

// Use in tests
final service = container.read(myServiceProvider);
```

## Test Data

### Using Test Fixtures
```dart
// Use predefined test data
final game = TestData.createSampleGame();
final user = TestData.sampleUser;
final activity = TestData.sampleActivity;
```

### Creating Custom Test Data
```dart
// Create custom test data
final customGame = TestData.createSampleGame(
  id: 'custom-id',
  sport: 'basketball',
  maxPlayers: 8,
);
```

## Best Practices

### 1. Test Organization
- Group related tests together
- Use descriptive test names
- Keep tests focused and simple
- One assertion per test when possible

### 2. Test Data
- Use consistent test data
- Create reusable fixtures
- Avoid hardcoded values
- Use realistic data

### 3. Mocking
- Mock external dependencies
- Verify interactions
- Use realistic mock data
- Don't over-mock

### 4. Async Testing
- Always await async operations
- Use proper error handling
- Test both success and failure cases
- Use timeouts when appropriate

### 5. Widget Testing
- Test user interactions
- Test different states
- Use proper widget setup
- Test accessibility

### 6. Integration Testing
- Test complete user flows
- Use real data when possible
- Test error scenarios
- Test offline scenarios

## Coverage Goals

- **Overall Coverage**: 70%+
- **Models**: 90%+
- **Utils**: 80%+
- **Services**: 75%+
- **Providers**: 70%+
- **Widgets**: 60%+

## Debugging Tests

### Running Single Test
```bash
flutter test test/models/game_test.dart
```

### Running Specific Test
```bash
flutter test --name "should create game with required parameters"
```

### Debug Mode
```bash
flutter test --debug
```

### Verbose Output
```bash
flutter test --verbose
```

## Continuous Integration

Tests are automatically run in CI/CD pipeline:
- All tests must pass before merge
- Coverage reports are generated
- Golden tests are validated
- Performance tests are monitored

## Troubleshooting

### Common Issues

1. **Test Timeout**: Increase timeout or fix async issues
2. **Mock Not Working**: Check mock setup and verify calls
3. **Widget Not Found**: Ensure proper widget setup and pumping
4. **Golden Test Fails**: Update golden files if changes are intentional

### Getting Help

- Check test logs for detailed error messages
- Use `flutter test --verbose` for more output
- Review test documentation and examples
- Ask team members for help with complex test scenarios

## Contributing

When adding new tests:
1. Follow the established patterns
2. Add appropriate test data
3. Update this documentation if needed
4. Ensure tests pass locally
5. Update coverage if applicable
