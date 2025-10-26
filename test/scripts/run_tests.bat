@echo off
REM Comprehensive Testing Script for MoveYoung App (Windows)
REM This script runs all types of tests with proper configuration

setlocal enabledelayedexpansion

echo 🧪 Starting MoveYoung Test Suite
echo =================================

REM Check if Flutter is installed
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Flutter is not installed or not in PATH
    exit /b 1
)

REM Check Flutter version
for /f "tokens=*" %%i in ('flutter --version ^| findstr /r "Flutter"') do set FLUTTER_VERSION=%%i
echo [INFO] Using !FLUTTER_VERSION!

REM Get dependencies
echo [INFO] Getting dependencies...
flutter pub get

REM Clean previous test results
echo [INFO] Cleaning previous test results...
flutter clean
flutter pub get

REM Run tests based on arguments
if "%1"=="" (
    REM Run all tests
    echo [INFO] Running all tests...
    
    REM Unit tests
    echo [INFO] Running unit tests...
    flutter test test/models/ test/utils/ test/services/ --coverage
    
    REM Widget tests
    echo [INFO] Running widget tests...
    flutter test test/widgets/ --coverage
    
    REM Integration tests
    echo [INFO] Running integration tests...
    flutter test test/integration/ --coverage
    
    REM Golden tests
    echo [INFO] Running golden tests...
    flutter test test/golden/ --coverage
    
    echo [SUCCESS] All tests completed!
    
) else if "%1"=="unit" (
    echo [INFO] Running unit tests only...
    flutter test test/models/ test/utils/ test/services/ --coverage
    
) else if "%1"=="widget" (
    echo [INFO] Running widget tests only...
    flutter test test/widgets/ --coverage
    
) else if "%1"=="integration" (
    echo [INFO] Running integration tests only...
    flutter test test/integration/ --coverage
    
) else if "%1"=="golden" (
    echo [INFO] Running golden tests only...
    flutter test test/golden/ --coverage
    
) else if "%1"=="coverage" (
    echo [INFO] Running all tests with coverage...
    flutter test --coverage
    echo [SUCCESS] Coverage data generated in coverage/lcov.info
    
) else if "%1"=="watch" (
    echo [INFO] Running tests in watch mode...
    flutter test --watch
    
) else if "%1"=="verbose" (
    echo [INFO] Running tests with verbose output...
    flutter test --verbose
    
) else if "%1"=="help" (
    echo Usage: %0 [test_type]
    echo.
    echo Test types:
    echo   unit        - Run unit tests only
    echo   widget      - Run widget tests only
    echo   integration - Run integration tests only
    echo   golden      - Run golden tests only
    echo   coverage    - Run all tests with coverage report
    echo   watch       - Run tests in watch mode
    echo   verbose     - Run tests with verbose output
    echo   help        - Show this help message
    echo.
    echo If no argument is provided, all tests will be run.
    
) else (
    echo [ERROR] Unknown test type: %1
    echo Use '%0 help' to see available options
    exit /b 1
)

echo [SUCCESS] Test suite completed!
