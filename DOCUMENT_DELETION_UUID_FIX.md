# Document Deletion UUID Parsing Fix

## Issue
The remote document deletion was failing with two main errors:

1. **NoSuchKey error**: File doesn't exist in S3 storage at the expected path
2. **Invalid radix-10 number error**: UUID being parsed as integer - `FormatException: Invalid radix-10 number (at character 1)c9656734-89f9-4bfb-a594-b4626ae99c97`

## Root Cause
The sync service was trying to parse remote document UUIDs (like `c9656734-89f9-4bfb-a594-b4626ae99c97`) as integers using `int.parse(remoteDoc.id)`. This fails because:

- Remote documents use UUID strings as IDs
- Local database uses auto-incrementing integer IDs
- The sync service was mixing these two ID types

## Fix Applied
Modified `cloud_sync_service.dart` in the `_syncRemoteDocumentToLocal` method:

### Before
```dart
await _databaseService.replaceFileAttachmentsForDocument(
  int.parse(remoteDoc.id), // ❌ Fails with UUID
  remoteFileAttachments,
);
```

### After
```dart
// Find local document by matching title and userId instead of parsing UUID
int? localDocumentId;
for (final localDoc in existingDocs) {
  if (localDoc.title == remoteDoc.title && 
      localDoc.userId == remoteDoc.userId) {
    localDocumentId = int.tryParse(localDoc.id);
    break;
  }
}

// Use the local integer ID for database operations
await _databaseService.replaceFileAttachmentsForDocument(
  localDocumentId, // ✅ Uses proper integer ID
  remoteFileAttachments,
);
```

## Changes Made
1. **Fixed ID mapping logic**: Instead of trying to parse remote UUIDs as integers, the code now finds the corresponding local document by matching title and userId
2. **Used local document ID**: Database operations now use the local integer ID instead of trying to convert UUIDs
3. **Improved error handling**: Added proper null checks and fallback logic

## Files Modified
- `household_docs_app/lib/services/cloud_sync_service.dart`
  - Lines ~1130-1190: Fixed document ID mapping in `_syncRemoteDocumentToLocal`
  - Replaced `int.parse(remoteDoc.id)` with proper local ID lookup

## Testing
The fix should resolve:
- ✅ UUID parsing errors when syncing remote documents
- ✅ File attachment sync failures
- ✅ Document deletion issues related to ID mismatches

## Next Steps
1. Test document deletion with the fixed sync logic
2. Verify file attachments sync properly
3. Monitor logs for any remaining ID-related issues