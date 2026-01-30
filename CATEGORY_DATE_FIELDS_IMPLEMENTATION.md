# Category and Date Fields Implementation

**Date**: January 18, 2026  
**Status**: In Progress

## Overview
Added Category (mandatory) and Date (optional) fields to the Document model with dynamic date field labels based on category selection.

## Changes Made

### 1. Document Model (`lib/models/new_document.dart`)
- Added `DocumentCategory` enum with 5 categories:
  - Car Insurance
  - Home Insurance
  - Holiday
  - Expenses
  - Other
- Added `category` field (required)
- Added `date` field (optional DateTime)
- Each category has a `dateLabel` property:
  - Car/Home Insurance → "Renewal Date"
  - Holiday → "Payment Due"
  - Expenses/Other → "Date"
- Updated all serialization methods (toJson, fromJson, toDatabase, fromDatabase)
- Updated copyWith to support clearing date field
- Updated equality, hashCode, and toString methods

### 2. Document Detail Screen (`lib/screens/new_document_detail_screen.dart`)
- Added category dropdown selector
- Added date picker with dynamic label based on selected category
- Date field shows appropriate label:
  - "Renewal Date (optional)" for insurance categories
  - "Payment Due (optional)" for holiday category
  - "Date (optional)" for expenses/other categories
- Added clear date button (X icon)
- Updated save logic to include category and date
- Updated view mode to display category and date fields

### 3. Document Repository (`lib/repositories/document_repository.dart`)
- Updated `createDocument` method to require `category` parameter
- Added optional `date` parameter
- All document creation now includes category

### 4. Database Service (`lib/services/new_database_service.dart`)
- Updated documents table schema:
  - Added `category TEXT NOT NULL` column
  - Added `date INTEGER` column (nullable, stored as milliseconds since epoch)
  - Removed old `description` column (replaced with `notes`)

### 5. Tests (`test/models/new_document_test.dart`)
- Updated all test cases to include required `category` parameter
- Added tests for category enum functionality
- Added tests for date field handling
- Added tests for dynamic date labels
- Added test for clearDate functionality
- All 71 document model tests passing

## Remaining Work

### Test Files to Update
The following integration and screen test files need updating to add the `category` parameter:

1. `test/integration/data_consistency_test.dart` - Replace `description` with `notes`, add `category`
2. `test/integration/document_sync_flow_test.dart` - Add `category` parameter
3. `test/integration/error_recovery_test.dart` - Add `category` parameter
4. `test/integration/offline_handling_test.dart` - Replace `description`, add `category`
5. `test/screens/new_document_detail_screen_test.dart` - Update Document constructor calls

### Database Migration
- Current implementation creates new schema (v1)
- Existing users will need database migration if upgrading from old version
- Consider adding migration logic or documenting clean install requirement

### GraphQL Schema Update
- Update `schema.graphql` to match new model:
  - Change `category: String!` to use enum type
  - Add `date: AWSDateTime` field
  - Remove or rename fields as needed

## UI Behavior

### Creating New Document
1. User selects category from dropdown (required)
2. Date field label updates dynamically based on category
3. User can optionally select a date
4. User can clear selected date with X button

### Editing Existing Document
1. Category dropdown shows current category
2. Date field shows current date (if set)
3. Changing category updates date field label
4. User can change or clear date

### Viewing Document
1. Category displayed with friendly name
2. Date displayed with appropriate label (if set)
3. All other fields displayed as before

## Testing Status
- ✅ Document model tests: 71/71 passing
- ⏳ Integration tests: Need category parameter added
- ⏳ Screen tests: Need Document constructor updates
- ⏳ Repository tests: Need verification
- ⏳ End-to-end tests: Need full flow testing

## Next Steps
1. Update remaining test files with category parameter
2. Run full test suite to verify all tests pass
3. Test UI manually to verify date label changes
4. Update GraphQL schema if using cloud sync
5. Document any breaking changes for existing users
