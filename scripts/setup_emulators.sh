#!/bin/bash

# Setup Firebase emulators for the first time
# Usage: ./scripts/setup_emulators.sh

set -e

echo "🔧 Setting up Firebase Emulators..."

# Install Firebase CLI if not present
if ! command -v firebase &> /dev/null; then
    echo "📦 Installing Firebase CLI..."
    npm install -g firebase-tools
fi

# Login to Firebase (optional, for production deployment)
# firebase login

# Initialize emulators (run only once)
echo "⚠️  Run this if firebase.json doesn't exist or is outdated:"
echo "   firebase init emulators"

echo "✅ Setup complete!"
echo ""
echo "To start emulators, run:"
echo "   ./scripts/start_emulators.sh"
echo ""
echo "Or manually:"
echo "   firebase emulators:start"

