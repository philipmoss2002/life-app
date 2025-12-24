# Document Deletion - Targeted Fix

## Issue from Logs
The document with `syncState: SyncState.pendingDeletion` was not being processed for remote deletion, causing it to be reinstated during sync.

## Current Status
The cloud_sync_service.dart file has structural issues that need to be resolved first. However, the core logic changes needed are clear.

## Required Changes

### 1. Fix Sync State Check (CRITICAL)
The deletion logic needs to include `pendingDeletion` state:

**Current logic** (around line 867):
```dart
final needsRemoteDeletion = syncState == SyncState.synced ||
    syncState == SyncState.conflict ||
    (syncState == SyncState.pendingDeletion && _wasEverSynced(document));
```

**Simplified fix** (if _wasEverSynced is causing issues):
```dart
final needsRemoteDeletion = syncState == SyncState.synced ||
    syncState == SyncState.conflict ||
    syncState == SyncState.pendingDeletion;
```

This ensures that ANY document marked for deletion gets processed for remote deletion.

### 2. Use FileAttachment Records for File Deletion (IMPLEMENTED)
The code already tries to use FileAttachment records:
```dart
final fileAttachments = await _databaseService.getFileAttachmentsWithLabels(int.parse(document.id));
```

This should resolve the document ID mismatch issue (document ID 71 vs file path with ID 58).

### 3. Handle int.parse Errors
Add error handling for the int.parse call:
```dart
try {
  final fileAttachments = await _databaseService.getFileAttachmentsWithLabels(int.parse(document.id));
  // ... deletion logic
} catch (e) {
  _logWarning('⚠️ Could not parse document ID for file attachment deletion: ${document.id}');
  // Fall back to using document.filePaths
}
```

## Immediate Action Required

1. **Fix file structure**: Resolve the syntax errors in cloud_sync_service.dart
2. **Test the simplified fix**: Change the sync state check to include all `pendingDeletion` documents
3. **Verify FileAttachment usage**: Ensure the FileAttachment records contain correct S3 keys

## Expected Result

With these changes:
- ✅ Documents with `pendingDeletion` state will be processed for remote deletion
- ✅ FileAttachment records will provide correct S3 keys for file deletion
- ✅ Documents won't be reinstated during sync
- ✅ Both local and remote copies will be properly deleted

## Test Case

Based on the logs, test with:
- Document ID: 71 (local)
- File path: `documents/.../58/...` (S3)
- Sync state: `pendingDeletion`

Expected behavior:
1. Document should be deleted from DynamoDB
2. Files should be deleted from S3 using FileAttachment records
3. Document should not reappear during next sync

## Priority
**CRITICAL** - This is the core issue preventing document deletion from working.