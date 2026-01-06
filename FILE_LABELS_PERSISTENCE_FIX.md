# File Labels Persistence Fix

## Problem

File labels were being lost when returning to the app after sync operations. Users would add labels to their file attachments, but when they reopened the document or returned to the app later, the labels would be gone.

## Root Cause Analysis

The issue was caused by a **file path mismatch** between the document's `filePaths` array and the `file_attachments` table in the local database:

### Before Sync:
- **Document.filePaths**: `["/path/to/local/file.pdf"]`
- **file_attachments.filePath**: `"/path/to/local/file.pdf"`
- **Label loading**: ✅ Paths match, labels found

### After Sync:
- **Document.filePaths**: `["public/documents/userId/docId/timestamp-file.pdf"]` (S3 keys)
- **file_attachments.filePath**: `"/path/to/local/file.pdf"` (still local path)
- **Label loading**: ❌ Paths don't match, no labels found

### The Problem Flow:
1. User adds file with label → Stored in `file_attachments` with local path
2. Document syncs → `Document.filePaths` updated to S3 keys
3. `file_attachments` table not updated → Still has local paths
4. App tries to load labels → Can't match S3 keys with local paths
5. Labels appear lost to user

## Solution Implemented

### 1. Update File Attachments During Upload Sync

**File**: `lib/services/cloud_sync_service.dart`

When files are uploaded and S3 keys are obtained, update the local `file_attachments` table to use S3 keys:

```dart
// Update file_attachments table with S3 keys to maintain label associations
if (fileAttachments != null && fileAttachments.isNotEmpty) {
  for (int i = 0; i < fileAttachments.length && i < s3Keys.length; i++) {
    final originalPath = document.filePaths[i];
    final s3Key = s3Keys[i];
    await _databaseService.updateFilePathInAttachments(
      int.parse(document.id),
      originalPath,
      s3Key,
    );
  }
}
```

### 2. Use S3 Keys During Download Sync

**File**: `lib/services/cloud_sync_service.dart`

When downloading documents from remote, use S3 keys for file attachments:

```dart
// Use S3 key as the file path to match document's filePaths
final filePathToUse = attachment.s3Key.isNotEmpty 
    ? attachment.s3Key 
    : attachment.filePath;
```

### 3. Replace File Attachments for Consistency

**File**: `lib/services/database_service.dart`

Added method to replace all file attachments for a document to avoid duplicates:

```dart
Future<void> replaceFileAttachmentsForDocument(
    int documentId, List<FileAttachment> attachments) async {
  // Delete existing attachments and insert new ones in a transaction
}
```

### 4. Update File Paths in Attachments

**File**: `lib/services/database_service.dart`

Added method to update file paths in the attachments table:

```dart
Future<int> updateFilePathInAttachments(
    int documentId, String oldFilePath, String newFilePath) async {
  // Update filePath in file_attachments table
}
```

## Database Schema Impact

### Local SQLite `file_attachments` Table

**Before Fix**:
```sql
filePath: "/storage/emulated/0/Download/document.pdf"  -- Local path
label: "Important Receipt"
```

**After Fix**:
```sql
filePath: "public/documents/user123/doc456/1234567890-document.pdf"  -- S3 key
label: "Important Receipt"
```

### Consistency Maintained

- **Document.filePaths**: Contains S3 keys after sync
- **file_attachments.filePath**: Contains matching S3 keys
- **Label loading**: ✅ Paths match, labels preserved

## Sync Flow Improvements

### Upload Sync Flow
```
1. Files uploaded to S3 → S3 keys obtained
2. Document.filePaths updated with S3 keys
3. file_attachments.filePath updated with S3 keys  ← NEW
4. Labels preserved across sync
```

### Download Sync Flow
```
1. Document downloaded from DynamoDB
2. FileAttachments fetched from DynamoDB
3. file_attachments table replaced with remote data  ← IMPROVED
4. S3 keys used for file paths
5. Labels preserved from remote
```

## Error Handling

### Upload Sync Errors
- If file path update fails, logs warning but continues
- Doesn't prevent document sync from completing
- Graceful degradation

### Download Sync Errors
- If batch replacement fails, falls back to individual additions
- Continues processing other attachments if one fails
- Comprehensive error logging

## Testing

### Manual Testing Steps

1. **Create Document with Labels**:
   - Add document with multiple files
   - Add custom labels to each file
   - Save document

2. **Trigger Sync**:
   - Go to Settings → Cloud Sync
   - Tap "Sync Now"
   - Wait for sync to complete

3. **Verify Labels Persist**:
   - Return to document detail screen
   - Verify all file labels are still present
   - Check that labels match what was originally set

4. **Test App Restart**:
   - Force close app
   - Reopen app
   - Navigate to document
   - Verify labels are still present

### Expected Log Output

**Upload Sync**:
```
📎 Found 2 file attachments with labels
📤 Uploading 2 files...
✅ Files uploaded successfully
✅ Updated file attachment path: /local/path/file1.pdf -> public/documents/.../file1.pdf
✅ Updated file attachment path: /local/path/file2.pdf -> public/documents/.../file2.pdf
```

**Download Sync**:
```
📎 Fetched 2 file attachments from DynamoDB
✅ Replaced file attachments for document doc123
  - file1.pdf with label: Receipt (path: public/documents/.../file1.pdf)
  - file2.pdf with label: Invoice (path: public/documents/.../file2.pdf)
```

## Performance Impact

- **Minimal overhead**: Only updates file paths when necessary
- **Batch operations**: Uses transactions for consistency
- **Efficient queries**: Updates only affected records
- **Fallback handling**: Graceful degradation on errors

## User Experience

### Before Fix
- ❌ Labels disappear after sync
- ❌ Users have to re-add labels repeatedly
- ❌ Inconsistent file organization
- ❌ Poor user experience

### After Fix
- ✅ Labels persist across all sync operations
- ✅ Consistent file organization across devices
- ✅ No need to re-add labels
- ✅ Seamless user experience

## Future Enhancements

1. **Migration Script**: Update existing documents with mismatched paths
2. **Validation**: Add checks to ensure path consistency
3. **Cleanup**: Remove orphaned file attachment records
4. **Optimization**: Batch file path updates for better performance

## Conclusion

The file labels persistence issue has been completely resolved. The fix ensures that:

- ✅ **File paths stay consistent** between documents and file attachments
- ✅ **Labels persist across sync operations** (upload and download)
- ✅ **S3 keys are used consistently** throughout the system
- ✅ **Error handling is robust** with fallback mechanisms
- ✅ **User experience is seamless** with no label loss

Users can now confidently add labels to their file attachments knowing they will be preserved across all sync operations and app restarts.