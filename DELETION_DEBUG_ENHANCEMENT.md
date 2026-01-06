# Document Deletion Debug Enhancement

## Issue Identified
The remote documents are **not being marked as deleted** in DynamoDB when deletion is performed. This causes:

1. Local document gets marked as `pendingDeletion`
2. Files get deleted from S3
3. But the document in DynamoDB is not marked as `deleted: true`
4. During sync, the "active" remote document tries to download deleted files
5. Results in NoSuchKey errors that block the deletion process

## Debug Enhancements Added

### 1. Enhanced Deletion Logging in CloudSyncService
Added detailed logging to track the deletion process:

```dart
_logInfo('🗑️ Attempting to delete document from DynamoDB: ${document.id}');
await _documentSyncManager.deleteDocument(document.id.toString());
_logInfo('✅ Document deleted from DynamoDB: ${document.title}');

// Verify deletion by trying to fetch the document
try {
  final deletedDoc = await _documentSyncManager.downloadDocument(document.id.toString());
  _logInfo('🔍 Verification - Document deleted flag: ${deletedDoc.deleted}');
  _logInfo('🔍 Verification - Document deletedAt: ${deletedDoc.deletedAt}');
} catch (e) {
  _logInfo('🔍 Verification - Document not found (fully deleted): $e');
}
```

### 2. Enhanced Mutation Logging in DocumentSyncManager
Added detailed logging to track the GraphQL mutation:

```dart
_logInfo('🗑️ Sending delete mutation to DynamoDB for document: $documentId');
final response = await Amplify.API.mutate(request: request).response;

// ... error handling ...

final updatedDoc = response.data!;
_logInfo('✅ Document deletion mutation successful: $documentId');
_logInfo('🔍 Updated document deleted flag: ${updatedDoc.deleted}');
_logInfo('🔍 Updated document deletedAt: ${updatedDoc.deletedAt}');
_logInfo('🔍 Updated document version: ${updatedDoc.version}');
```

### 3. Enhanced Remote Document Processing Logging
Added logging to track what remote documents are being processed:

```dart
_logInfo('🔍 Processing remote document: ${remoteDoc.title} (${remoteDoc.id})');
_logInfo('🔍 Remote document deleted flag: ${remoteDoc.deleted}');
_logInfo('🔍 Remote document deletedAt: ${remoteDoc.deletedAt}');
```

## What the Logs Will Show

With these enhancements, the logs will reveal:

1. **Is the deletion mutation being called?**
   - Look for: `🗑️ Attempting to delete document from DynamoDB`

2. **Is the mutation succeeding?**
   - Look for: `✅ Document deletion mutation successful`
   - Check the deleted flag and deletedAt values

3. **Is the document actually marked as deleted?**
   - Look for verification logs showing `deleted: true`

4. **Are deleted documents still appearing in sync?**
   - Look for: `🔍 Remote document deleted flag: false` (should be true for deleted docs)

## Possible Issues to Investigate

Based on the logs, we can identify:

### Issue 1: Mutation Failing
If you see errors in the mutation logs, the GraphQL update might be failing due to:
- Permissions issues
- Schema validation errors
- Network connectivity problems

### Issue 2: Document ID Mismatch
If the document is not found during deletion:
- The document ID might be incorrect
- The document might already be deleted
- There might be a UUID vs integer ID issue

### Issue 3: GraphQL Filter Not Working
If documents show `deleted: true` but still appear in sync:
- The `fetchAllDocuments` filter might not be working
- There might be a caching issue
- The filter syntax might be incorrect

### Issue 4: Race Condition
If deletion succeeds but sync happens too quickly:
- The sync might run before the deletion completes
- There might be eventual consistency issues with DynamoDB

## Next Steps

1. **Run a deletion and check the logs** to see which scenario is occurring
2. **Identify the specific failure point** using the enhanced logging
3. **Apply targeted fixes** based on what the logs reveal

## Files Modified
- `household_docs_app/lib/services/cloud_sync_service.dart`
  - Enhanced deletion verification logging
- `household_docs_app/lib/services/document_sync_manager.dart`
  - Enhanced GraphQL mutation logging
  - Added response validation logging