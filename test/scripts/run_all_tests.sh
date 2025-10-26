#!/bin/bash

# Comprehensive test runner script
# Usage: ./test/scripts/run_all_tests.sh [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default options
COVERAGE=false
VERBOSE=false
CLEAN=false
WATCH=false
INTEGRATION=false
GOLDEN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --coverage)
      COVERAGE=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --clean)
      CLEAN=true
      shift
      ;;
    --watch)
      WATCH=true
      shift
      ;;
    --integration)
      INTEGRATION=true
      shift
      ;;
    --golden)
      GOLDEN=true
      shift
      ;;
    --help)
      echo "Usage: ./test/scripts/run_all_tests.sh [options]"
      echo ""
      echo "Options:"
      echo "  --coverage      Run tests with coverage"
      echo "  --verbose       Verbose output"
      echo "  --clean         Clean before running"
      echo "  --watch         Watch mode"
      echo "  --integration   Run integration tests"
      echo "  --golden        Run golden tests"
      echo "  --help          Show this help"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}🧪 SmartPlayer Test Runner${NC}"
echo "=================="

# Clean if requested
if [ "$CLEAN" = true ]; then
  echo -e "${YELLOW}🧹 Cleaning...${NC}"
  flutter clean
  flutter pub get
fi

# Build arguments
FLAGS=""
if [ "$COVERAGE" = true ]; then
  FLAGS="$FLAGS --coverage"
fi

if [ "$VERBOSE" = true ]; then
  FLAGS="$FLAGS --verbose"
fi

if [ "$WATCH" = true ]; then
  FLAGS="$FLAGS --watch"
fi

# Run tests
echo ""
echo -e "${BLUE}📦 Running unit tests...${NC}"
if [ "$COVERAGE" = true ]; then
  flutter test $FLAGS test/models/ test/utils/ test/services/ test/providers/
else
  flutter test $FLAGS test/models/ test/utils/ test/services/ test/providers/
fi

echo ""
echo -e "${BLUE}🎨 Running widget tests...${NC}"
flutter test $FLAGS test/widgets/

# Integration tests
if [ "$INTEGRATION" = true ]; then
  echo ""
  echo -e "${BLUE}🔄 Running integration tests...${NC}"
  flutter test $FLAGS test/integration/
fi

# Golden tests
if [ "$GOLDEN" = true ]; then
  echo ""
  echo -e "${BLUE}✨ Running golden tests...${NC}"
  flutter test $FLAGS test/golden/
fi

# Coverage report
if [ "$COVERAGE" = true ]; then
  echo ""
  echo -e "${BLUE}📊 Generating coverage report...${NC}"
  
  # Check if genhtml is available
  if command -v genhtml &> /dev/null; then
    genhtml coverage/lcov.info -o coverage/html
    echo -e "${GREEN}✅ Coverage report generated in coverage/html/${NC}"
    echo -e "${YELLOW}Open coverage/html/index.html to view the report${NC}"
  else
    echo -e "${YELLOW}⚠️ genhtml not found. Install lcov to generate HTML report${NC}"
    echo "Run: sudo apt-get install lcov"
  fi
fi

echo ""
echo -e "${GREEN}✅ All tests completed!${NC}"

