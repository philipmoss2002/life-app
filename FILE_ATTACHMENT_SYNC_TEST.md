# File Attachment Labels Sync Implementation

## Summary

Successfully implemented file attachment labels synchronization between local SQLite database and remote DynamoDB. This ensures that when users add labels to file attachments, those labels are properly synced to the cloud and available across all devices.

## Changes Made

### 1. CloudSyncService._uploadDocument() Method Enhanced

**File**: `household_docs_app/lib/services/cloud_sync_service.dart`

- **Added file attachment loading**: Retrieves file attachments with labels from local database using `_databaseService.getFileAttachmentsWithLabels()`
- **Enhanced S3 key assignment**: Updates FileAttachment objects with S3 keys and file sizes after successful file upload
- **DynamoDB FileAttachment creation**: Creates FileAttachment records in DynamoDB with labels using `_createFileAttachmentInDynamoDB()`
- **Improved logging**: Added detailed logging for file attachment processing

### 2. CloudSyncService._downloadDocument() Method Enhanced

**File**: `household_docs_app/lib/services/cloud_sync_service.dart`

- **FileAttachment fetching**: Retrieves FileAttachment records from DynamoDB using `_fetchFileAttachmentsFromDynamoDB()`
- **Local database sync**: Syncs downloaded file attachments with labels back to local SQLite database
- **Fallback handling**: Gracefully handles cases where FileAttachments are not included in document response

### 3. New Helper Methods Added

**File**: `household_docs_app/lib/services/cloud_sync_service.dart`

#### `_createFileAttachmentInDynamoDB()`
- Creates FileAttachment records in DynamoDB via GraphQL mutation
- Links FileAttachments to their parent Document
- Includes all metadata: filePath, fileName, label, fileSize, s3Key, etc.

#### `_fetchFileAttachmentsFromDynamoDB()`
- Queries DynamoDB for FileAttachments belonging to a specific document
- Returns list of FileAttachment objects with labels
- Handles errors gracefully to allow sync to continue

### 4. DocumentSyncManager GraphQL Queries Enhanced

**File**: `household_docs_app/lib/services/document_sync_manager.dart`

- **fetchAllDocuments()**: Updated to include FileAttachments in GraphQL query
- **downloadDocument()**: Updated to include FileAttachments in GraphQL query
- Both methods now retrieve complete document data including file attachment labels

### 5. File Size Calculation Added

**File**: `household_docs_app/lib/services/cloud_sync_service.dart`

- Added automatic file size calculation for FileAttachment objects
- Uses `File.length()` to get actual file sizes before upload
- Handles cases where file size cannot be determined

## How It Works

### Upload Flow (Local → Cloud)

1. **Document Creation**: User creates document with files and labels locally
2. **File Upload**: Files are uploaded to S3 and S3 keys are obtained
3. **FileAttachment Update**: Local FileAttachment objects are updated with S3 keys and file sizes
4. **Document Upload**: Document metadata is uploaded to DynamoDB
5. **FileAttachment Creation**: Individual FileAttachment records are created in DynamoDB with labels
6. **Local Update**: Local database is updated with DynamoDB-generated IDs

### Download Flow (Cloud → Local)

1. **Document Fetch**: Document is fetched from DynamoDB
2. **FileAttachment Fetch**: FileAttachments are fetched (either included in document or separately)
3. **File Download**: Files are downloaded from S3 using S3 keys
4. **Local Sync**: Document and FileAttachments are synced to local SQLite database
5. **Label Preservation**: File attachment labels are preserved in local database

## Testing

### Manual Testing Steps

1. **Create Document with Labeled Files**:
   ```
   - Add document with multiple files
   - Add labels to each file attachment
   - Save document locally
   ```

2. **Trigger Sync**:
   ```
   - Go to Settings → Cloud Sync
   - Tap "Sync Now" or wait for automatic sync
   - Check logs for file attachment processing
   ```

3. **Verify Upload**:
   ```
   - Check S3 bucket for uploaded files
   - Check DynamoDB Document table for document record
   - Check DynamoDB FileAttachment table for attachment records with labels
   ```

4. **Test Download on Another Device**:
   ```
   - Sign in with same account on different device
   - Trigger sync to download documents
   - Verify files are downloaded with correct labels
   ```

### Log Messages to Look For

**Upload Success**:
```
📎 Found X file attachments with labels
📤 Uploading X files...
✅ Files uploaded successfully
📎 Updated X file attachments with S3 keys
📎 Creating X FileAttachment records in DynamoDB...
✅ FileAttachment created: filename.pdf with label: Important Document
✅ All FileAttachment records processed
```

**Download Success**:
```
📎 Document has X file attachments, downloading...
📎 Fetched X file attachments from DynamoDB
📎 Syncing X file attachments to local database...
✅ Synced file attachment: filename.pdf with label: Important Document
✅ File attachments synced to local database
```

## Database Schema

### Local SQLite (file_attachments table)
```sql
CREATE TABLE file_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  documentId INTEGER NOT NULL,
  filePath TEXT NOT NULL,
  fileName TEXT NOT NULL,
  label TEXT,                    -- User-defined label
  addedAt TEXT NOT NULL,
  FOREIGN KEY (documentId) REFERENCES documents (id) ON DELETE CASCADE
);
```

### DynamoDB FileAttachment Model
```
{
  id: String (auto-generated),
  filePath: String (local path),
  fileName: String,
  label: String (optional),      -- User-defined label
  fileSize: Int,
  s3Key: String (S3 object key),
  addedAt: TemporalDateTime,
  syncState: String,
  documentId: String (foreign key)
}
```

## Error Handling

- **File size calculation errors**: Defaults to 0 if file size cannot be determined
- **FileAttachment creation errors**: Logs warning but continues with other attachments
- **FileAttachment fetch errors**: Returns empty list to allow sync to continue
- **Local database sync errors**: Logs warning but continues with other attachments

## Performance Considerations

- FileAttachments are created individually in DynamoDB (no batch operation available)
- File size calculation is done locally before upload
- FileAttachment fetching uses separate GraphQL query if not included in document
- Local database operations use transactions for consistency

## Future Enhancements

1. **Batch FileAttachment Operations**: Implement batch create/update for better performance
2. **Conflict Resolution**: Handle cases where FileAttachment labels differ between local and remote
3. **Selective Sync**: Allow users to choose which file attachments to sync
4. **Compression**: Implement file compression before upload for large attachments
5. **Caching**: Cache FileAttachment metadata to reduce database queries

## Troubleshooting

### Common Issues

1. **FileAttachments not syncing**:
   - Check if document has `fileAttachments` field populated
   - Verify GraphQL schema includes FileAttachment relationship
   - Check DynamoDB permissions for FileAttachment table

2. **Labels not appearing**:
   - Verify local database has `label` column in `file_attachments` table
   - Check if `getFileAttachmentsWithLabels()` is returning data
   - Ensure FileAttachment creation includes label field

3. **File size errors**:
   - Check if files exist at specified paths
   - Verify file permissions allow reading
   - Check if file paths are absolute vs relative

### Debug Commands

```dart
// Enable detailed logging
CloudSyncService.enableSubscriptionBypass(); // For testing only

// Check local file attachments
final attachments = await DatabaseService.instance.getFileAttachmentsWithLabels(documentId);
print('Local attachments: ${attachments.map((a) => '${a.fileName}: ${a.label}').join(', ')}');

// Check remote file attachments
final remoteAttachments = await cloudSyncService._fetchFileAttachmentsFromDynamoDB(documentId);
print('Remote attachments: ${remoteAttachments.map((a) => '${a.fileName}: ${a.label}').join(', ')}');
```

## Conclusion

File attachment labels are now fully synchronized between local and remote storage. Users can add labels to their file attachments and those labels will be preserved across all devices when syncing is enabled. The implementation is robust with proper error handling and detailed logging for troubleshooting.