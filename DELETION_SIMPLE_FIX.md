# Document Deletion - Simple Fix Required

## Current Status
The cloud_sync_service.dart file has been corrupted during editing attempts. The file needs to be restored to a working state.

## Core Issue Identified
From the logs, the main problem is **Document ID mismatch in file paths**:

- Local document ID: `71`
- File path in S3: `documents/.../58/...` (contains old ID `58`)
- Result: Files cannot be found for deletion

## Simple Fix Needed

### Step 1: Restore cloud_sync_service.dart
The file needs to be restored to a working state from the last known good version.

### Step 2: Fix Sync State Check
Change the deletion condition from:
```dart
if (syncState == SyncState.synced || syncState == SyncState.conflict)
```

To:
```dart
if (syncState == SyncState.synced || syncState == SyncState.conflict || syncState == SyncState.pendingDeletion)
```

This ensures that documents marked for deletion are actually deleted from the remote.

### Step 3: Use FileAttachment Records for File Deletion
Instead of using `document.filePaths`, use the FileAttachment records from the database:

```dart
// Get file attachments from database
final fileAttachments = await _databaseService.getFileAttachmentsWithLabels(int.parse(document.id));

// Delete using actual stored S3 keys
for (final attachment in fileAttachments) {
  final s3Key = attachment.s3Key.isNotEmpty ? attachment.s3Key : attachment.filePath;
  await _fileSyncManager.deleteFile(s3Key);
}
```

## Why This Will Work

1. **Correct Sync State**: Documents with `pendingDeletion` state will be processed for remote deletion
2. **Accurate File Paths**: FileAttachment records contain the actual S3 keys used when files were uploaded
3. **No ID Mismatch**: Using stored S3 keys avoids the document ID mismatch issue

## Expected Result

- ✅ Documents marked for deletion will be deleted from DynamoDB
- ✅ Files will be deleted from S3 using correct paths
- ✅ Documents won't be reinstated during sync
- ✅ Deletion process will complete successfully

## Files to Modify
- `household_docs_app/lib/services/cloud_sync_service.dart` (restore and apply simple fixes)

## Priority
**HIGH** - Document deletion is currently completely broken and needs immediate fix.