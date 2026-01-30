# File Attachment Sync Implementation

## Status: ✅ COMPLETE

File attachments are now properly synced to DynamoDB after S3 upload.

## Problem

Files were being uploaded to S3 successfully, but no FileAttachment records were being created in DynamoDB. This meant:
- Files were not queryable via GraphQL
- Files were not visible in AWS console
- No metadata tracking in the database

## Root Cause

The `sync_service.dart` only handled:
1. Document metadata sync (via `document_sync_service.dart`)
2. S3 file upload/download (via `file_service.dart`)
3. Local database updates

But it was **missing** the step to create FileAttachment records in DynamoDB using GraphQL mutations.

## Solution Implemented

### 1. Created `file_attachment_sync_service.dart`

New service that handles FileAttachment GraphQL operations:

**Methods:**
- `createRemoteFileAttachment()` - Creates FileAttachment record in DynamoDB
- `updateRemoteFileAttachment()` - Updates FileAttachment metadata (label, syncState)
- `deleteRemoteFileAttachment()` - Deletes FileAttachment record
- `fetchRemoteFileAttachments()` - Fetches all FileAttachments for a document

**GraphQL Mutations:**
```graphql
mutation CreateFileAttachment(
  $syncId: String!,
  $documentSyncId: String!,
  $userId: String!,
  $fileName: String!,
  $label: String,
  $fileSize: Int!,
  $s3Key: String!,
  $filePath: String!,
  $addedAt: AWSDateTime!,
  $contentType: String,
  $checksum: String,
  $syncState: String!
)
```

### 2. Updated `sync_service.dart`

Modified `uploadDocumentFiles()` method to:

1. Upload file to S3 (existing)
2. Update local database with S3 key (existing)
3. **NEW:** Create FileAttachment record in DynamoDB

```dart
// After S3 upload
final s3Key = await _fileService.uploadFile(...);

// Update local DB
await _documentRepository.updateFileS3Key(...);

// Create DynamoDB record
await _fileAttachmentSyncService.createRemoteFileAttachment(
  syncId: '${syncId}_${file.fileName}',  // Unique ID
  documentSyncId: syncId,                 // Parent document
  userId: userId,                         // Cognito sub
  fileName: file.fileName,
  label: file.label,
  fileSize: file.fileSize ?? 0,
  s3Key: s3Key,
  filePath: s3Key,
  addedAt: file.addedAt,
  contentType: null,
  checksum: null,
  syncState: 'synced',
);
```

### 3. FileAttachment Sync ID Generation

Each FileAttachment gets a unique `syncId` composed of:
```dart
final fileAttachmentSyncId = '${documentSyncId}_${fileName}';
```

This ensures:
- Unique identification
- Easy association with parent document
- Consistent across devices

## Schema Alignment

The FileAttachment schema in DynamoDB:

```graphql
type FileAttachment @model @auth(rules: [{allow: owner, ownerField: "userId", identityClaim: "sub"}]) {
  syncId: String! @primaryKey
  documentSyncId: String! @index(name: "byDocumentSyncId", sortKeyFields: ["addedAt"])
  userId: String! @index(name: "byUserId", sortKeyFields: ["addedAt"])
  fileName: String!
  label: String
  fileSize: Int!
  s3Key: String!
  filePath: String!
  addedAt: AWSDateTime!
  contentType: String
  checksum: String
  syncState: String!
  
  document: Document @belongsTo(fields: ["documentSyncId"])
}
```

## Files Modified

1. **Created:** `lib/services/file_attachment_sync_service.dart`
   - New service for FileAttachment GraphQL operations
   - Handles create, update, delete, and fetch operations

2. **Modified:** `lib/services/sync_service.dart`
   - Added import for `file_attachment_sync_service.dart`
   - Added `_fileAttachmentSyncService` instance
   - Updated `uploadDocumentFiles()` to create DynamoDB records
   - Fixed onError handler warning

## Testing

After implementation:
1. Create a document with file attachments
2. Trigger sync
3. Verify in AWS Console:
   - Files appear in S3 bucket
   - FileAttachment records appear in DynamoDB
   - Records have correct `documentSyncId` linking to parent document
   - Records have correct `userId` for authorization

## Benefits

✅ Files are now queryable via GraphQL
✅ Files visible in AWS AppSync console
✅ Proper metadata tracking in DynamoDB
✅ Enables future features:
  - Cross-device file sync
  - File sharing
  - File search
  - Storage quota tracking

## Next Steps

Consider implementing:
1. File deletion sync (delete from DynamoDB when deleted locally)
2. File label update sync (update DynamoDB when label changes)
3. Pull remote file attachments on document sync
4. Conflict resolution for file attachments
