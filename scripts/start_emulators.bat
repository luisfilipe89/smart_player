@echo off
REM Start Firebase emulators for testing
REM Usage: scripts\start_emulators.bat

echo 🔥 Starting Firebase Emulators...

REM Check if Firebase CLI is installed
where firebase >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Firebase CLI not found. Please install it first.
    echo Run: npm install -g firebase-tools
    exit /b 1
)

REM Start emulators
firebase emulators:start --only auth,database,functions,storage --project demo-test

echo.
echo ✅ Emulators running!
echo    Auth:     http://localhost:9099
echo    Database: http://localhost:9000
echo    Functions: http://localhost:5001
echo    Storage:  http://localhost:9199
echo    UI:       http://localhost:4000


