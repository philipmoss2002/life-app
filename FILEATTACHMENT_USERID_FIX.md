# FileAttachment userId and documentSyncId Fix - Complete Resolution

## Problem
User reported "not authorized to access createFileAttachment on type mutation" error with logs showing empty User ID and S3 key. The issue was that FileAttachment records were being created without the required `userId` and `documentSyncId` fields, causing GraphQL authorization to fail.

## Root Cause
The `file_attachments` table in the local SQLite database was missing both the `userId` and `documentSyncId` columns. When FileAttachment objects were created from database records, they had empty values for these fields, which caused the GraphQL authorization rule `{allow: owner, ownerField: "userId"}` to fail.

## Solution
Added the missing `userId` and `documentSyncId` columns to the `file_attachments` table and updated the code to populate them properly.

### Changes Made

#### 1. Updated Database Schema
**File**: `lib/services/database_service.dart`

- **Increased database version** from 5 to 6
- **Added `userId` and `documentSyncId` columns** to the `file_attachments` table in the `CREATE TABLE` statement
- **Added migration for version 6** to add both columns to existing databases
- **Updated existing records** with `userId` and `documentSyncId` from their parent documents

#### 2. Updated File Attachment Creation
**File**: `lib/services/database_service.dart`

- **Modified `_addFileAttachment` method** to query the parent document for both `userId` and `syncId` (as `documentSyncId`) and store them in the file attachment record
- This ensures all new FileAttachment records have the correct `userId` and `documentSyncId` from their parent document

#### 3. Updated Model Extensions
**File**: `lib/models/model_extensions.dart`

- **Updated `toMap` method** to include `documentSyncId` field for completeness
- The `fromMap` method already handled missing fields with default values

#### 4. Database Migration Details
The version 6 migration:
1. Adds both `userId` and `documentSyncId` columns to the `file_attachments` table
2. Updates existing file attachment records by copying the `userId` and `syncId` from their parent documents
3. Handles errors gracefully if the columns already exist

### Database Schema Changes

**Before:**
```sql
CREATE TABLE file_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  documentId INTEGER NOT NULL,
  syncId TEXT,
  filePath TEXT NOT NULL,
  fileName TEXT NOT NULL,
  label TEXT,
  addedAt TEXT NOT NULL,
  fileSize INTEGER,
  s3Key TEXT,
  contentType TEXT,
  checksum TEXT,
  -- Missing userId and documentSyncId columns
);
```

**After:**
```sql
CREATE TABLE file_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  documentId INTEGER NOT NULL,
  syncId TEXT,
  documentSyncId TEXT,  -- Added documentSyncId column
  userId TEXT,          -- Added userId column
  filePath TEXT NOT NULL,
  fileName TEXT NOT NULL,
  label TEXT,
  addedAt TEXT NOT NULL,
  fileSize INTEGER,
  s3Key TEXT,
  contentType TEXT,
  checksum TEXT,
);
```

### Code Changes

**Updated `_addFileAttachment` method:**
```dart
Future<void> _addFileAttachment(
    int documentId, String filePath, String? label,
    {String? syncId, String? s3Key}) async {
  final db = await database;
  final fileName = filePath.split('/').last;
  
  // Get the userId and syncId from the parent document
  final docResult = await db.query(
    'documents',
    columns: ['userId', 'syncId'],
    where: 'id = ?',
    whereArgs: [documentId],
  );
  
  final userId = docResult.isNotEmpty ? docResult.first['userId'] as String? : null;
  final documentSyncId = docResult.isNotEmpty ? docResult.first['syncId'] as String? : null;
  
  await db.insert('file_attachments', {
    'documentId': documentId,
    'syncId': syncId,
    'documentSyncId': documentSyncId,  // Now includes documentSyncId
    'userId': userId,                  // Now includes userId
    'filePath': filePath,
    'fileName': fileName,
    'label': label,
    's3Key': s3Key,
    'addedAt': DateTime.now().toIso8601String(),
  });
}
```

## Testing
- Database migration will run automatically when the app starts
- Existing FileAttachment records will be updated with the correct `userId` and `documentSyncId`
- New FileAttachment records will include both fields from their parent document
- GraphQL authorization should now work properly

## Benefits
1. **Proper authorization**: FileAttachment records now have the required `userId` for GraphQL authorization
2. **Correct relationships**: FileAttachment records now have the `documentSyncId` for proper document linking
3. **Data consistency**: All FileAttachment records are properly linked to their owning user and parent document
4. **Backward compatibility**: Existing data is migrated automatically
5. **Future-proof**: New FileAttachment records will always include the correct fields

## Files Modified
- `lib/services/database_service.dart` (database schema, migration, and file attachment creation)
- `lib/models/model_extensions.dart` (model conversion methods)

The fix ensures that all FileAttachment records have the proper `userId` and `documentSyncId` fields required for GraphQL authorization and relationships, resolving the "not authorized to access createFileAttachment" error.