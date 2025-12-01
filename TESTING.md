# Testing Guide

## Overview

The Life App includes comprehensive automated tests to validate user features and ensure app reliability.

## Test Structure

```
test/
├── models/
│   └── document_test.dart          # Document model unit tests
├── screens/
│   ├── home_screen_test.dart       # Home screen widget tests
│   └── add_document_screen_test.dart # Add document screen tests
└── integration/
    └── document_workflow_test.dart  # End-to-end workflow tests
```

## Test Categories

### 1. Unit Tests (Models)

**Location:** `test/models/`

Tests the Document model:
- Document creation with required/optional fields
- Conversion to/from Map (database serialization)
- Null handling for optional fields
- Date handling

**Run:**
```bash
flutter test test/models/
```

### 2. Widget Tests (Screens)

**Location:** `test/screens/`

Tests individual screens:
- UI element presence
- User interactions
- Form validation
- Navigation
- Category-specific labels

**Run:**
```bash
flutter test test/screens/
```

### 3. Integration Tests (Workflows)

**Location:** `test/integration/`

Tests complete user workflows:
- Document creation flow
- Category filtering
- Navigation between screens
- Category label changes
- Back navigation

**Run:**
```bash
flutter test test/integration/
```

## Running Tests

### Run All Tests

```bash
flutter test
```

### Run Specific Test File

```bash
flutter test test/models/document_test.dart
```

### Run Tests with Coverage

```bash
flutter test --coverage
```

View coverage report:
```bash
genhtml coverage/lcov.info -o coverage/html
```

### Run Tests in Watch Mode

```bash
flutter test --watch
```

## Test Coverage

### Current Coverage

- **Document Model:** 100%
  - Creation, serialization, deserialization
  - All field types and null handling

- **Home Screen:** ~80%
  - UI elements, navigation, filters
  - Empty state, category selection

- **Add Document Screen:** ~75%
  - Form fields, validation
  - Category-specific labels
  - Date picker interaction

- **Integration Workflows:** ~70%
  - Complete document creation
  - Navigation flows
  - Category filtering

## Key Test Scenarios

### ✅ Document Creation
- Create document with required fields only
- Create document with all fields
- Validate required field (title)
- Category selection
- Date selection
- File attachment (UI only)

### ✅ Category Labels
- Holiday → "Payment Due"
- Other → "Date"
- Insurance/Mortgage → "Renewal Date"

### ✅ Navigation
- Home → Add Document
- Add Document → Document Detail (after save)
- Document Detail → Home (Done button)
- Home → Upcoming Renewals

### ✅ Filtering
- Filter by category
- Show all documents
- Empty state when no documents

### ✅ UI Elements
- All buttons present
- All form fields present
- Icons displayed correctly
- Empty states shown

## Writing New Tests

### Unit Test Template

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Feature Name Tests', () {
    test('should do something', () {
      // Arrange
      final input = 'test';
      
      // Act
      final result = doSomething(input);
      
      // Assert
      expect(result, 'expected');
    });
  });
}
```

### Widget Test Template

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('should display widget', (WidgetTester tester) async {
    // Build widget
    await tester.pumpWidget(
      const MaterialApp(
        home: MyWidget(),
      ),
    );
    
    // Verify
    expect(find.text('Expected Text'), findsOneWidget);
  });
}
```

## Continuous Integration

### GitHub Actions (Recommended)

Create `.github/workflows/test.yml`:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.38.3'
      - run: flutter pub get
      - run: flutter test
```

## Troubleshooting

### Tests Failing Due to Database

Some tests may fail if they try to access the real database. Mock the database service:

```dart
// Use a mock database service
class MockDatabaseService extends DatabaseService {
  // Override methods
}
```

### Tests Timing Out

Increase timeout for slow tests:

```dart
testWidgets('slow test', (WidgetTester tester) async {
  // ...
}, timeout: const Timeout(Duration(seconds: 30)));
```

### Pump and Settle Issues

If widgets aren't appearing:

```dart
await tester.pumpAndSettle(const Duration(seconds: 2));
```

## Best Practices

1. **Test Naming:** Use descriptive names that explain what is being tested
2. **Arrange-Act-Assert:** Structure tests clearly
3. **One Assertion:** Focus each test on one behavior
4. **Independent Tests:** Tests should not depend on each other
5. **Clean Up:** Dispose of resources properly
6. **Mock External Dependencies:** Database, notifications, file system

## Future Test Additions

- [ ] Document editing workflow
- [ ] Document deletion with confirmation
- [ ] File attachment and opening
- [ ] Notification scheduling (mocked)
- [ ] Database operations (with mock)
- [ ] Search/filter functionality
- [ ] Upcoming renewals logic
- [ ] Date calculations for renewal warnings

## Running Tests Before Commit

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/sh
flutter test
if [ $? -ne 0 ]; then
  echo "Tests failed. Commit aborted."
  exit 1
fi
```

Make executable:
```bash
chmod +x .git/hooks/pre-commit
```

## Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Widget Testing](https://docs.flutter.dev/cookbook/testing/widget/introduction)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)
