# Document Deletion - Complete Analysis and Fixes

## Issues Identified

### Issue 1: Incorrect Sync State Check ✅ FIXED
**Problem**: Deletion logic only checked for `SyncState.synced` or `SyncState.conflict`, but documents marked for deletion have `SyncState.pendingDeletion`.

**Impact**: Documents that were previously synced but now pending deletion were not being deleted from the remote.

**Fix**: Added logic to check if a `pendingDeletion` document was ever synced:
```dart
final needsRemoteDeletion = syncState == SyncState.synced || 
                            syncState == SyncState.conflict ||
                            (syncState == SyncState.pendingDeletion && _wasEverSynced(document));
```

### Issue 2: Document ID Mismatch in File Paths ⚠️ IDENTIFIED
**Problem**: The file path contains a different document ID than the current local document ID.

**Evidence from logs**:
- Local document ID: `71`
- File path: `documents/.../58/...` (contains ID `58`)

**Why this happens**:
1. Document created locally with ID 58
2. Files uploaded to S3 with path containing `/58/`
3. Document gets new local ID 71 (after database reset, migration, or sync conflict)
4. File paths in database still reference old ID 58
5. Deletion tries to use current ID 71, but files are at `/58/`

**Impact**: Files cannot be found or deleted because the path doesn't match.

### Issue 3: S3 Access Permissions ⚠️ IDENTIFIED
**Problem**: When fallback tries to access files without `public/` prefix, it gets "Access Denied".

**Evidence**: `StorageAccessDeniedException` when trying legacy path.

**Why this happens**: Files are stored at `public/documents/...` but the fallback tries `documents/...` which requires different permissions.

## Root Cause Analysis

The fundamental issue is **document ID inconsistency**:

1. **Local Database**: Uses auto-incrementing integer IDs (58, 71, etc.)
2. **S3 File Paths**: Embed the document ID at upload time (`/58/`)
3. **ID Changes**: When documents are synced/migrated, local IDs can change
4. **Path Mismatch**: File paths become stale and don't match current document ID

## Current State

### What Works ✅
- Documents that were never synced are properly skipped for remote deletion
- Sync state checking is now more comprehensive
- Better logging to identify issues

### What Doesn't Work ❌
- Deleting documents where file paths contain old/mismatched document IDs
- Files remain in S3 because they can't be found at expected paths
- Documents get reinstated during sync because remote copy isn't deleted

## Recommended Solutions

### Solution 1: Use Remote Document ID for Deletion (Recommended)
Instead of using the local document ID, fetch the remote document and use its ID for deletion:

```dart
// Before deletion, check if document exists remotely
try {
  final remoteDoc = await _documentSyncManager.downloadDocument(document.id);
  // Use remoteDoc.id and remoteDoc.filePaths for deletion
  await deleteRemoteDocument(remoteDoc);
} catch (e) {
  // Document doesn't exist remotely, skip
}
```

### Solution 2: Store Remote ID Separately
Add a `remoteId` field to local documents to track the corresponding remote document ID:

```dart
class LocalDocument {
  final int? id;           // Local integer ID
  final String? remoteId;  // Remote UUID
  // ...
}
```

### Solution 3: Use File Attachment Records
Instead of relying on document ID in paths, use the actual file paths stored in FileAttachment records:

```dart
// Get file attachments from database
final attachments = await _databaseService.getFileAttachmentsWithLabels(document.id);

// Delete using actual stored paths
for (final attachment in attachments) {
  await _fileSyncManager.deleteFile(attachment.s3Key);
}
```

## Immediate Workaround

For now, the best approach is to:

1. **Check if document was ever synced** using `_wasEverSynced()` ✅ IMPLEMENTED
2. **Try to fetch remote document** before deletion to get correct IDs
3. **Use FileAttachment records** for file deletion instead of document.filePaths
4. **Handle errors gracefully** and continue with local deletion even if remote fails

## Files Modified
- `household_docs_app/lib/services/cloud_sync_service.dart`
  - Added `_wasEverSynced()` method
  - Updated deletion logic to check pendingDeletion state
  - Enhanced logging for debugging

## Next Steps

1. **Implement Solution 3**: Use FileAttachment records for file deletion
2. **Add remote document lookup**: Fetch remote document before deletion to get correct IDs
3. **Improve error handling**: Don't block deletion if remote cleanup fails
4. **Consider database migration**: Add remoteId field for better tracking

## Testing Recommendations

1. Test deletion of documents that were:
   - Never synced (local only)
   - Successfully synced once
   - Synced multiple times with ID changes
   - Have file attachments with different document IDs in paths

2. Verify that:
   - Local deletion always succeeds
   - Remote deletion is attempted when appropriate
   - Files are properly cleaned up from S3
   - Documents don't get reinstated during sync