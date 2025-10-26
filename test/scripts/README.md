# Test Scripts

This directory contains scripts to run different types of tests for the MoveYoung app.

## Available Scripts

### `run_tests.sh` (macOS/Linux)
```bash
# Run all tests
./test/scripts/run_tests.sh

# Run specific test types
./test/scripts/run_tests.sh unit
./test/scripts/run_tests.sh widget
./test/scripts/run_tests.sh integration
./test/scripts/run_tests.sh golden
./test/scripts/run_tests.sh coverage
./test/scripts/run_tests.sh watch
./test/scripts/run_tests.sh verbose
./test/scripts/run_tests.sh help
```

### `run_tests.bat` (Windows)
```cmd
REM Run all tests
test\scripts\run_tests.bat

REM Run specific test types
test\scripts\run_tests.bat unit
test\scripts\run_tests.bat widget
test\scripts\run_tests.bat integration
test\scripts\run_tests.bat golden
test\scripts\run_tests.bat coverage
test\scripts\run_tests.bat watch
test\scripts\run_tests.bat verbose
test\scripts\run_tests.bat help
```

## Test Types

- **unit**: Model, utility, and service tests
- **widget**: UI component tests
- **integration**: End-to-end flow tests
- **golden**: Visual regression tests
- **coverage**: All tests with coverage report
- **watch**: Continuous testing mode
- **verbose**: Detailed test output

## Prerequisites

- Flutter SDK installed
- Dependencies installed (`flutter pub get`)
- For coverage reports: `lcov` installed (optional)

## Coverage Reports

When running with coverage, reports are generated in:
- `coverage/lcov.info` - Raw coverage data
- `coverage/html/` - HTML coverage report (if lcov is installed)
