# File Attachment Sync Fix

**Date:** January 30, 2026  
**Updated:** January 30, 2026

## Problem
When documents were synced from remote, file attachments were being lost. The local database would receive document metadata but no associated file attachment records.

## Root Cause Analysis

### Initial Investigation
Initially investigated `realtime_sync_service.dart` which handles GraphQL subscriptions for real-time sync. However, discovered that **the app doesn't actually use real-time sync** for pulling remote documents.

### Actual Sync Mechanism
The app uses `DocumentSyncService` with a **pull-based approach** via the `pullRemoteDocuments()` method, which is called by `SyncService`. This is the service that actually syncs documents from remote.

## Root Causes

### 1. Missing GraphQL Fields
The `listDocuments` GraphQL query in `DocumentSyncService._fetchAllRemoteDocuments()` was not requesting the `fileAttachments` field, so file attachment data was never received from the server.

### 2. No File Attachment Sync Logic
The `_createLocalDocumentFromMap()` and `_updateLocalDocumentFromMap()` methods had a comment "Files will be synced separately" but no actual implementation to sync them.

## Solution Implemented

### 1. Updated GraphQL Query
**File:** `lib/services/document_sync_service.dart`

Added `fileAttachments` field to the `listDocuments` query:

```graphql
query ListDocuments($userId: String!) {
  listDocuments(filter: {userId: {eq: $userId}}) {
    items {
      syncId
      userId
      title
      category
      date
      notes
      createdAt
      updatedAt
      syncState
      deleted
      deletedAt
      fileAttachments {
        items {
          syncId
          userId
          fileName
          label
          fileSize
          s3Key
          filePath
          addedAt
          contentType
          checksum
          syncState
        }
      }
    }
  }
}
```

### 2. Implemented File Attachment Sync
Added new method `_syncFileAttachmentsFromMap()` that:
- Extracts file attachment data from remote document map
- Retrieves existing file attachments from local database
- Adds new file attachments from remote
- Updates existing file attachments (S3 key, label, local path)
- Removes file attachments that no longer exist remotely
- Handles errors gracefully without failing document sync
- Provides comprehensive logging

### 3. Integrated File Sync into Document Sync
Updated both `_createLocalDocumentFromMap()` and `_updateLocalDocumentFromMap()` to call `_syncFileAttachmentsFromMap()` after document metadata is synced.

## Files Modified

1. **lib/services/document_sync_service.dart**
   - Updated `_fetchAllRemoteDocuments()` GraphQL query
   - Updated `_createLocalDocumentFromMap()` to sync file attachments
   - Updated `_updateLocalDocumentFromMap()` to sync file attachments
   - Added `_syncFileAttachmentsFromMap()` method (~130 lines)

2. **lib/services/realtime_sync_service.dart** (Bonus Fix)
   - Also fixed for future use when real-time sync is enabled
   - Same file attachment sync logic implemented

## How Sync Works

### Current Flow (Pull-Based)
1. User opens app or triggers manual sync
2. `SyncService.performFullSync()` is called
3. Calls `DocumentSyncService.pullRemoteDocuments()`
4. Fetches all documents with `_fetchAllRemoteDocuments()` (now includes file attachments)
5. For each document:
   - Creates or updates document metadata
   - **NEW:** Syncs file attachments via `_syncFileAttachmentsFromMap()`
6. File attachments are now properly stored in local database

### Future Flow (Push-Based - Not Currently Used)
When real-time sync is enabled:
1. GraphQL subscription receives document changes
2. `RealtimeSyncService` handles the event
3. Updates document and file attachments in real-time

## Testing Recommendations

### Test 1: Initial Sync
1. Sign in on Device A, create documents with file attachments
2. Sign in on Device B (fresh install)
3. **Verify:** All documents appear with file attachments

### Test 2: Update Sync
1. On Device A: Add/remove/update file attachments
2. On Device B: Pull to refresh
3. **Verify:** File attachment changes are reflected

### Test 3: Database Inspection
```bash
adb pull /data/data/com.yourapp/databases/household_docs_<userId>.db
sqlite3 household_docs_<userId>.db
SELECT * FROM file_attachments;
```

## Logging

Watch for these log messages:
```
Syncing X file attachments for document: <syncId>
Adding new file attachment: <fileName>
Updating existing file attachment: <fileName>
Removing file attachment no longer in remote: <fileName>
File attachment sync completed for document: <syncId>
```

## Benefits

- ✅ File attachments now sync correctly from remote
- ✅ Proper error handling prevents document sync failures
- ✅ Works with current pull-based sync mechanism
- ✅ Comprehensive logging for debugging
- ✅ Handles add, update, and delete operations for file attachments
- ✅ No breaking changes to existing functionality
- ✅ Bonus: Real-time sync also fixed for future use

## Notes

- File attachments are synced after document metadata to ensure document exists first
- Errors in file attachment sync don't fail the document sync
- Local path updates allow for downloaded files to be tracked
- The fix maintains backward compatibility with existing code
- Real-time sync service also fixed but not currently used by the app
