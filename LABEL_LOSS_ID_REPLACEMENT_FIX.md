# File Labels Loss During ID Replacement - Fix Implementation

## Issue Description

When a local document (with integer ID like "29") gets uploaded to DynamoDB and receives a new UUID (like "a1b2c3d4-..."), the file attachment labels were being lost. This happened because:

1. **Document ID Changes**: Local integer ID → DynamoDB UUID
2. **Database Constraint**: `file_attachments.documentId` has foreign key to `documents.id`
3. **Type Mismatch**: Trying to store UUID string in integer field
4. **Orphaned Records**: File attachments couldn't find their parent document

## Root Cause

The original implementation tried to update the document ID in place:

```dart
// PROBLEMATIC: Trying to store UUID in integer field
await _databaseService.updateDocument(uploadedDocument); // uploadedDocument.id = UUID
```

This caused the file_attachments table to lose the reference to the document, making labels disappear.

## Solution Implemented

Instead of updating the document ID in place, we now:

### 1. **Preserve File Attachments**
```dart
// Get file attachments with labels BEFORE deleting old document
List<FileAttachment> existingAttachments = [];
existingAttachments = await _databaseService
    .getFileAttachmentsWithLabels(int.parse(document.id));
```

### 2. **Replace Document Completely**
```dart
// Delete old document (cascades to file_attachments)
await _databaseService.deleteDocument(int.parse(document.id));

// Create new document with DynamoDB UUID
final newDocumentId = await _databaseService.createDocument(uploadedDocument);
```

### 3. **Recreate File Attachments with Labels**
```dart
// Recreate each file attachment with its original label
for (final attachment in existingAttachments) {
  final filePathToUse = attachment.s3Key.isNotEmpty 
      ? attachment.s3Key 
      : attachment.filePath;
  
  await _databaseService.addFileToDocument(
    newDocumentId,
    filePathToUse,
    attachment.label, // ✅ Label preserved!
  );
}
```

## Key Benefits

✅ **Labels Preserved**: File attachment labels are maintained during ID transition  
✅ **Clean Database**: No orphaned records or type mismatches  
✅ **S3 Path Support**: Uses S3 keys for synced files  
✅ **Error Resilient**: Continues if individual attachments fail  
✅ **No Migration**: Works with existing database schema  

## Flow Diagram

```
Local Document (ID: 29) + File Attachments with Labels
                    ↓
            Upload to DynamoDB
                    ↓
        DynamoDB assigns UUID (a1b2c3d4-...)
                    ↓
    1. Save existing file attachments with labels
    2. Delete old document (ID: 29) - cascades to file_attachments
    3. Create new document (ID: a1b2c3d4-...)
    4. Recreate file attachments with preserved labels
                    ↓
        ✅ Labels preserved in new document
```

## Testing

To verify the fix works:

1. **Create local document** with files and labels
2. **Upload to sync** - triggers ID replacement
3. **Check labels persist** after sync completes
4. **Restart app** - labels should still be visible

## Log Messages

Expected log output during ID replacement:

```
🔄 Replacing local document with DynamoDB ID: a1b2c3d4-...
📝 Original local ID was: 29
📎 Found 2 file attachments to preserve
🗑️ Deleted old local document with ID: 29
✅ Created new document with DynamoDB ID: a1b2c3d4-...
🔄 Recreating 2 file attachments with labels...
✅ Recreated file attachment: document.pdf with label: Important Contract
✅ Recreated file attachment: receipt.jpg with label: Payment Proof
✅ All file attachments recreated with labels preserved
```

This fix ensures that file attachment labels are never lost during the local-to-remote ID transition process.