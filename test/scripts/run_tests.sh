#!/bin/bash

# Comprehensive Testing Script for MoveYoung App
# This script runs all types of tests with proper configuration

set -e  # Exit on any error

echo "🧪 Starting MoveYoung Test Suite"
echo "================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

# Check Flutter version
FLUTTER_VERSION=$(flutter --version | head -n 1)
print_status "Using $FLUTTER_VERSION"

# Get dependencies
print_status "Getting dependencies..."
flutter pub get

# Clean previous test results
print_status "Cleaning previous test results..."
flutter clean
flutter pub get

# Run tests based on arguments
if [ $# -eq 0 ]; then
    # Run all tests
    print_status "Running all tests..."
    
    # Unit tests
    print_status "Running unit tests..."
    flutter test test/models/ test/utils/ test/services/ --coverage
    
    # Widget tests
    print_status "Running widget tests..."
    flutter test test/widgets/ --coverage
    
    # Integration tests
    print_status "Running integration tests..."
    flutter test test/integration/ --coverage
    
    # Golden tests
    print_status "Running golden tests..."
    flutter test test/golden/ --coverage
    
    # Generate coverage report
    print_status "Generating coverage report..."
    if command -v lcov &> /dev/null; then
        lcov --capture --directory coverage --output-file coverage/lcov.info
        genhtml coverage/lcov.info --output-directory coverage/html
        print_success "Coverage report generated in coverage/html/index.html"
    else
        print_warning "lcov not installed. Install with: brew install lcov (macOS) or apt-get install lcov (Ubuntu)"
    fi
    
else
    case $1 in
        "unit")
            print_status "Running unit tests only..."
            flutter test test/models/ test/utils/ test/services/ --coverage
            ;;
        "widget")
            print_status "Running widget tests only..."
            flutter test test/widgets/ --coverage
            ;;
        "integration")
            print_status "Running integration tests only..."
            flutter test test/integration/ --coverage
            ;;
        "golden")
            print_status "Running golden tests only..."
            flutter test test/golden/ --coverage
            ;;
        "coverage")
            print_status "Running all tests with coverage..."
            flutter test --coverage
            if command -v lcov &> /dev/null; then
                lcov --capture --directory coverage --output-file coverage/lcov.info
                genhtml coverage/lcov.info --output-directory coverage/html
                print_success "Coverage report generated in coverage/html/index.html"
            fi
            ;;
        "watch")
            print_status "Running tests in watch mode..."
            flutter test --watch
            ;;
        "verbose")
            print_status "Running tests with verbose output..."
            flutter test --verbose
            ;;
        "help")
            echo "Usage: $0 [test_type]"
            echo ""
            echo "Test types:"
            echo "  unit        - Run unit tests only"
            echo "  widget      - Run widget tests only"
            echo "  integration - Run integration tests only"
            echo "  golden      - Run golden tests only"
            echo "  coverage    - Run all tests with coverage report"
            echo "  watch       - Run tests in watch mode"
            echo "  verbose     - Run tests with verbose output"
            echo "  help        - Show this help message"
            echo ""
            echo "If no argument is provided, all tests will be run."
            ;;
        *)
            print_error "Unknown test type: $1"
            echo "Use '$0 help' to see available options"
            exit 1
            ;;
    esac
fi

print_success "Test suite completed!"
