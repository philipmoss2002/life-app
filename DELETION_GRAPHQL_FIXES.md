# Deletion GraphQL Fixes

## Status: ✅ COMPLETE

Fixed GraphQL schema validation errors for document and file attachment deletion.

## Issues Identified

### Issue 1: DocumentTombstone - Variable Type Mismatch

**Error:**
```
Variable type 'String' doesn't match expected type 'String!' @ 'createDocumentTombstone'
```

**Root Cause:**
- Schema defines: `reason: String!` (required, non-nullable)
- GraphQL mutation declared: `$reason: String` (optional, nullable)
- Type mismatch between variable declaration and schema requirement

**Fix Applied:**
Changed variable declaration in `document_sync_service.dart`:
```dart
// Before:
$reason: String

// After:
$reason: String!
```

### Issue 2: FileAttachment Deletion - Invalid Input Field

**Error:**
```
contains a field not in 'DeleteFileAttachmentInput': 'documentSyncId' @ 'deleteFileAttachment'
```

**Root Cause:**
- AWS AppSync auto-generated delete mutations only accept primary key fields
- FileAttachment primary key is `syncId` only (not composite)
- `documentSyncId` is not part of the primary key, so it's not in the delete input type

**Fix Applied:**

1. **Updated `file_attachment_sync_service.dart`:**
   - Removed `documentSyncId` parameter from method signature
   - Removed `documentSyncId` from GraphQL mutation
   - Only `syncId` is now passed (the primary key)

```dart
// Before:
Future<void> deleteRemoteFileAttachment({
  required String syncId,
  required String documentSyncId,  // ❌ Not needed
}) async {
  const mutation = '''
    mutation DeleteFileAttachment(
      $syncId: String!,
      $documentSyncId: String!  // ❌ Not in input type
    ) {
      deleteFileAttachment(input: {
        syncId: $syncId,
        documentSyncId: $documentSyncId  // ❌ Invalid field
      }) { ... }
    }
  ''';
}

// After:
Future<void> deleteRemoteFileAttachment({
  required String syncId,  // ✅ Only primary key needed
}) async {
  const mutation = '''
    mutation DeleteFileAttachment(
      $syncId: String!  // ✅ Only primary key
    ) {
      deleteFileAttachment(input: {
        syncId: $syncId  // ✅ Valid field
      }) { ... }
    }
  ''';
}
```

2. **Updated `new_document_detail_screen.dart`:**
   - Removed `documentSyncId` argument from method call

```dart
// Before:
await _fileAttachmentSyncService.deleteRemoteFileAttachment(
  syncId: fileAttachmentSyncId,
  documentSyncId: document.syncId,  // ❌ Removed
);

// After:
await _fileAttachmentSyncService.deleteRemoteFileAttachment(
  syncId: fileAttachmentSyncId,  // ✅ Only primary key
);
```

## Understanding AWS AppSync Delete Mutations

AWS AppSync automatically generates delete mutations based on the schema's `@primaryKey` directive:

**Schema:**
```graphql
type FileAttachment @model {
  syncId: String! @primaryKey
  documentSyncId: String!
  # ... other fields
}
```

**Auto-generated Input Type:**
```graphql
input DeleteFileAttachmentInput {
  syncId: String!  # Only the primary key field
}
```

**Key Points:**
- Delete mutations only accept primary key fields
- Non-primary-key fields are not in the delete input type
- For composite keys, all key fields would be required
- For single primary keys, only that field is needed

## Files Modified

1. **lib/services/document_sync_service.dart**
   - Fixed `_createTombstone()` method
   - Changed `$reason: String` to `$reason: String!`

2. **lib/services/file_attachment_sync_service.dart**
   - Fixed `deleteRemoteFileAttachment()` method
   - Removed `documentSyncId` parameter
   - Removed `documentSyncId` from GraphQL mutation

3. **lib/screens/new_document_detail_screen.dart**
   - Updated call to `deleteRemoteFileAttachment()`
   - Removed `documentSyncId` argument

## Testing

After these fixes, document deletion should:
1. ✅ Delete from local database
2. ✅ Mark as deleted in DynamoDB with tombstone
3. ✅ Delete FileAttachment records from DynamoDB (no errors)
4. ✅ Delete files from S3

All operations should complete without GraphQL validation errors.

## Verification

To verify the fixes work:

1. Create a document with file attachments
2. Sync to AWS
3. Delete the document
4. Check logs - should see:
   ```
   [INFO] Deleted remote document: {syncId}
   [INFO] Deleted remote file attachment: {syncId}_{fileName}
   [INFO] Deleting files from S3 for document: {syncId}
   ```
5. Verify in AWS Console:
   - Document marked as `deleted: true` in DynamoDB
   - Tombstone created in DocumentTombstone table
   - FileAttachment records removed from DynamoDB
   - Files removed from S3

No GraphQL validation errors should appear in the logs.
