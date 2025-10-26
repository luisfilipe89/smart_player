# Golden Tests

This directory contains visual regression (golden) tests for the MoveYoung app. Golden tests capture screenshots of widgets and compare them against baseline images to catch unintended visual changes.

## Overview

Golden tests use the `golden_toolkit` package to capture and compare images of widgets. When a test runs, it:
1. Renders the widget to an image
2. Compares the image against the stored "golden" reference image
3. Fails if there are any pixel differences

## Running Golden Tests

### Generate/Update Golden Files

When you make intentional visual changes, update the golden files:

```bash
flutter test test/golden/ --update-goldens
```

### Run Golden Tests

```bash
# Run all golden tests
flutter test test/golden/

# Run specific test file
flutter test test/golden/activity_card_golden_test.dart
```

### Troubleshooting

If a golden test fails:
1. Review the failure image to see what changed
2. If the change is intentional, run with `--update-goldens` to update the baseline
3. If the change is unintentional, fix the bug that caused it

## Test Structure

### Files

- `activity_card_golden_test.dart` - Tests for ActivityCard widget
- `home_screen_golden_test.dart` - Tests for home screen layout
- `game_card_golden_test.dart` - Tests for game card widget
- `offline_banner_golden_test.dart` - Tests for offline/online banner
- `loading_overlay_golden_test.dart` - Tests for loading overlay
- `sync_status_indicator_golden_test.dart` - Tests for sync status indicator
- `auth_screen_golden_test.dart` - Tests for authentication screen
- `friends_screen_golden_test.dart` - Tests for friends screen
- `games_screen_golden_test.dart` - Tests for games screen

### Golden Images

Reference images are stored in `test/golden/goldens/` directory. These are committed to git and serve as the baseline for visual regression testing.

## Coverage

Current golden tests cover:
- **Widgets**: ActivityCard, LoadingOverlay, SyncStatusIndicator, OfflineBanner
- **Screens**: Home, Auth, Friends, Games
- **States**: Empty states, loading states, error states, favorite states

## Configuration

- **Device Size**: iPhone 11 (414x896)
- **Theme**: Light theme only
- **Tool**: golden_toolkit package

## Helper Functions

The `test/helpers/golden_test_helper.dart` provides:
- `goldenSurfaceSize()` - Standard phone size for golden tests
- `goldenMaterialAppWrapper()` - Wrapper for MaterialApp with consistent theme

