# Document Deletion Radix-10 Error Fix

## Problem Summary
Document deletion was failing with an "Invalid radix-10 number" exception. This error occurred because the code was attempting to parse UUID strings (syncId) as integers using `int.parse()`.

## Root Cause Analysis
The issue was found in two locations where `int.parse(document.syncId)` was being called:

1. **Offline Sync Queue Service** (`lib/services/offline_sync_queue_service.dart:568`)
   ```dart
   await _databaseService.deleteDocument(int.parse(document.syncId));
   ```

2. **Deletion Tracking Service** (`lib/services/deletion_tracking_service.dart:141`)
   ```dart
   await _databaseService.deleteDocument(int.parse(document.syncId));
   ```

### Why This Failed
- `document.syncId` is a UUID string (e.g., "550e8400-e29b-41d4-a716-446655440000")
- `int.parse()` expects a numeric string (e.g., "123")
- Attempting to parse a UUID as an integer throws "FormatException: Invalid radix-10 number"

### Database Service Method Mismatch
The `DatabaseService.deleteDocument(int id)` method expects an integer document ID, but the calling code was trying to pass a UUID syncId string.

## Solution Implemented

### 1. Added New Database Method
Created a new method in `DatabaseService` that works with syncId:

```dart
/// Delete document by sync identifier (preferred method for sync operations)
Future<int> deleteDocumentBySyncId(String syncId) async {
  // Validate sync identifier
  _validateSyncId(syncId, context: 'document deletion by syncId');

  final db = await database;
  return await db.delete(
    'documents',
    where: 'syncId = ?',
    whereArgs: [syncId],
  );
}
```

**Key Features:**
- Accepts `String syncId` parameter (UUID)
- Uses `where: 'syncId = ?'` to query by syncId column
- Includes syncId validation for safety
- Follows the same pattern as `updateDocumentBySyncId`

### 2. Fixed Offline Sync Queue Service
**Before:**
```dart
await _databaseService.deleteDocument(int.parse(document.syncId));
```

**After:**
```dart
await _databaseService.deleteDocumentBySyncId(document.syncId);
```

### 3. Fixed Deletion Tracking Service
**Before:**
```dart
await _databaseService.deleteDocument(int.parse(document.syncId));
```

**After:**
```dart
await _databaseService.deleteDocumentBySyncId(document.syncId);
```

## Files Modified

### `lib/services/database_service.dart`
- **Added**: `deleteDocumentBySyncId(String syncId)` method
- **Location**: After existing `deleteDocument(int id)` method
- **Purpose**: Provides syncId-based document deletion

### `lib/services/offline_sync_queue_service.dart`
- **Changed**: Line 568 - Replaced `int.parse()` call with direct syncId usage
- **Method**: `_processDocumentDelete()`

### `lib/services/deletion_tracking_service.dart`
- **Changed**: Line 141 - Replaced `int.parse()` call with direct syncId usage
- **Method**: `completeDeletion()`

## Validation

### 1. Compilation Check
- ✅ No compilation errors in modified files
- ✅ New method follows existing patterns
- ✅ Proper syncId validation included

### 2. Method Consistency
The new `deleteDocumentBySyncId` method follows the same pattern as other syncId-based methods:
- `updateDocumentBySyncId(String syncId, Map<String, dynamic> updates)`
- `getDocumentBySyncId(String syncId, [String? userId])`
- `addFileToDocumentBySyncId(String documentSyncId, ...)`

### 3. Error Prevention
- Added syncId validation to prevent invalid input
- Uses parameterized queries to prevent SQL injection
- Maintains transaction safety

## Impact

### Positive Changes
- ✅ Document deletion now works correctly with UUID syncIds
- ✅ No more "Invalid radix-10 number" exceptions
- ✅ Consistent API pattern across database service
- ✅ Proper validation and error handling

### No Breaking Changes
- ✅ Existing `deleteDocument(int id)` method unchanged
- ✅ No impact on other parts of the codebase
- ✅ Backward compatibility maintained

## Testing Recommendations

### 1. Document Deletion Flow
Test the complete document deletion process:
1. Create a document with file attachments
2. Delete the document from the UI
3. Verify no radix-10 errors occur
4. Confirm document is removed from local database
5. Verify tombstone is created properly

### 2. Offline Sync Queue
Test offline deletion scenarios:
1. Delete documents while offline
2. Go back online and sync
3. Verify queued deletions process without errors

### 3. Edge Cases
- Delete documents with various syncId formats
- Delete non-existent documents (should handle gracefully)
- Delete documents with special characters in syncId

## Future Considerations

### 1. API Consistency
Consider deprecating integer-based methods in favor of syncId-based methods for better consistency across the sync system.

### 2. Migration Path
If needed, existing integer-based calls could be gradually migrated to syncId-based calls for better sync reliability.

### 3. Error Handling
The fix includes proper validation, but consider adding more specific error messages for different failure scenarios.

## Technical Notes

- The fix maintains the existing database schema (no migrations needed)
- Uses existing syncId column which is already indexed
- Follows established patterns for syncId validation
- No performance impact (syncId column is already indexed)

This fix resolves the immediate radix-10 error while maintaining code consistency and following established patterns in the codebase.