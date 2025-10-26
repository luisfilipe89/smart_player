@echo off
REM Comprehensive test runner script for Windows
REM Usage: test\scripts\run_all_tests.bat [options]

setlocal enabledelayedexpansion

 REM Generate timestamp for filename
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "timestamp=%YY%-%MM%-%DD%_%HH%-%Min%-%Sec%"
set "outputFile=test-results_%timestamp%.txt"

echo Test results will be saved to: %outputFile%
echo.

REM Default options
set COVERAGE=false
set VERBOSE=false
set CLEAN=false
set WATCH=false
set INTEGRATION=false
set GOLDEN=false

REM Parse arguments
:parse
if "%~1"=="" goto :run
if /i "%~1"=="--coverage" (set COVERAGE=true) & shift & goto :parse
if /i "%~1"=="--verbose" (set VERBOSE=true) & shift & goto :parse
if /i "%~1"=="--clean" (set CLEAN=true) & shift & goto :parse
if /i "%~1"=="--watch" (set WATCH=true) & shift & goto :parse
if /i "%~1"=="--integration" (set INTEGRATION=true) & shift & goto :parse
if /i "%~1"=="--golden" (set GOLDEN=true) & shift & goto :parse
if /i "%~1"=="--help" goto :help
echo Unknown option: %~1
exit /b 1

:help
echo Usage: test\scripts\run_all_tests.bat [options]
echo.
echo Options:
echo   --coverage      Run tests with coverage
echo   --verbose       Verbose output
echo   --clean         Clean before running
echo   --watch         Watch mode
echo   --integration   Run integration tests
echo   --golden        Run golden tests
echo   --help          Show this help
exit /b 0

:run
echo 🧪 SmartPlayer Test Runner
echo ==================
echo.

REM Clean if requested
if "%CLEAN%"=="true" (
    echo 🧹 Cleaning...
    flutter clean
    flutter pub get
)

REM Build flags
set FLAGS=
if "%COVERAGE%"=="true" set FLAGS=%FLAGS% --coverage
if "%VERBOSE%"=="true" set FLAGS=%FLAGS% --verbose
if "%WATCH%"=="true" set FLAGS=%FLAGS% --watch

REM Debug: Show which tests will run
echo.
echo Config: INTEGRATION=%INTEGRATION%, GOLDEN=%GOLDEN%

REM Run tests and redirect all output to file
echo.
echo 📦 Running unit tests...
call flutter test %FLAGS% test\models test\utils test\services test\providers >> "%outputFile%" 2>&1
echo. >> "%outputFile%" 2>&1
echo === Unit tests completed === >> "%outputFile%" 2>&1
echo.

echo 🎨 Running widget tests...
call flutter test %FLAGS% test\widgets >> "%outputFile%" 2>&1
echo. >> "%outputFile%" 2>&1
echo === Widget tests completed === >> "%outputFile%" 2>&1
echo.

REM Integration tests
set INTEGRATION=%INTEGRATION: =%
if "%INTEGRATION%"=="true" (
    echo 🔄 Running integration tests...
    call flutter test %FLAGS% test\integration >> "%outputFile%" 2>&1
    echo. >> "%outputFile%" 2>&1
    echo === Integration tests completed === >> "%outputFile%" 2>&1
    echo.
) else (
    echo ⏭️  Skipping integration tests (use --integration to run)
    echo.
)

REM Golden tests
set GOLDEN=%GOLDEN: =%
if "%GOLDEN%"=="true" (
    echo ✨ Running golden tests...
    call flutter test %FLAGS% test\golden >> "%outputFile%" 2>&1
    echo. >> "%outputFile%" 2>&1
    echo === Golden tests completed === >> "%outputFile%" 2>&1
    echo.
) else (
    echo ⏭️  Skipping golden tests (use --golden to run)
    echo.
)

echo.
echo ✅ All tests completed!
echo.
echo Results saved to: %outputFile%
echo.
type "%outputFile%"

endlocal

