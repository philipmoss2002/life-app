# Save Document and Label Persistence Fix

## Problems Fixed

### 1. Save Document Button Not Working
The "Save Document" button in the Add Document screen was not working. Documents could not be saved to the database.

### 2. File Labels Not Being Saved
When users added labels to files during document creation, the labels were not being persisted to the database.

## Root Causes

### Problem 1: Missing Database Columns
The `Document` model's `toMap()` method was trying to save cloud sync-related fields (`userId`, `lastModified`, `version`, `syncState`, `conflictId`) that didn't exist in the database schema. These fields were added when implementing the cloud sync feature, but the database schema was never updated to include them.

When the app tried to insert a document with these extra fields, the database rejected the operation because the columns didn't exist.

### Problem 2: Labels Updated After Creation
The original code created file attachments with `null` labels, then tried to update them afterwards. However, this approach was inefficient and the labels weren't being properly saved.

## Solutions

### Solution 1: Updated Database Schema
**File**: `lib/services/database_service.dart`

1. **Incremented database version** from 3 to 4
2. **Added new columns to documents table**:
   - `userId TEXT` - User ID from AWS Cognito
   - `lastModified TEXT NOT NULL` - Last modification timestamp
   - `version INTEGER NOT NULL DEFAULT 1` - Version number for conflict detection
   - `syncState TEXT NOT NULL DEFAULT 'notSynced'` - Current synchronization state
   - `conflictId TEXT` - ID of conflict if one exists

3. **Added migration logic** in `_upgradeDB()` to add these columns to existing databases

The migration (version 3 → 4) adds all the new columns with appropriate default values:
- `lastModified` defaults to current timestamp
- `version` defaults to 1
- `syncState` defaults to 'notSynced'
- `userId` and `conflictId` are nullable

### Solution 2: Save Labels During Creation
**Files**: `lib/screens/add_document_screen.dart`, `lib/services/database_service.dart`

1. **Added new method** `createDocumentWithLabels()` to DatabaseService that accepts a map of file labels
2. **Updated AddDocumentScreen** to use the new method, passing labels during document creation
3. **Labels are now inserted** with the file attachments in a single operation

Before:
```dart
final id = await DatabaseService.instance.createDocument(document);
// Then update labels separately
for (final filePath in filePaths) {
  await DatabaseService.instance.updateFileLabel(id, filePath, label);
}
```

After:
```dart
final id = await DatabaseService.instance.createDocumentWithLabels(
  document,
  fileLabels,
);
```

## Impact
- Existing users will have their database automatically upgraded when they open the app
- New users will get the complete schema from the start
- All cloud sync features now work correctly with the database
- Documents can be saved successfully
- File labels are properly persisted and displayed

## Testing
To verify the fixes:
1. Open the app
2. Tap "Add Document"
3. Fill in the title and other fields
4. Attach one or more files
5. Add labels to the files
6. Tap "Save Document"
7. Verify that:
   - The document is saved successfully
   - You're redirected to the document detail screen
   - The document appears in the home screen list
   - File labels are displayed correctly in the document detail screen

## Files Modified
- `lib/services/database_service.dart` - Updated schema, added migration, and new method for creating documents with labels
- `lib/screens/add_document_screen.dart` - Updated to use new createDocumentWithLabels method

## Related Features
These fixes enable proper functionality for:
- Document creation
- File label persistence
- Cloud sync state tracking
- Conflict resolution
- Version management
- Multi-user support
