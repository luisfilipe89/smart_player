#!/bin/bash

# Start Firebase emulators for testing
# Usage: ./scripts/start_emulators.sh

set -e

echo "🔥 Starting Firebase Emulators..."

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing..."
    npm install -g firebase-tools
fi

# Start emulators
firebase emulators:start \
    --only auth,database,functions,storage \
    --project demo-test

echo "✅ Emulators running!"
echo "   Auth:     http://localhost:9099"
echo "   Database: http://localhost:9000"
echo "   Functions: http://localhost:5001"
echo "   Storage:  http://localhost:9199"
echo "   UI:       http://localhost:4000"


