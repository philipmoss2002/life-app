# Multiple Files Feature

## Overview
Documents now support multiple file attachments instead of just a single file.

## What Changed

### Database Schema
- **New table**: `file_attachments` stores multiple files per document
- **Database version**: Upgraded from v1 to v2 with automatic migration
- **Backward compatibility**: Old documents with single files are automatically migrated

### Document Model
- Added `filePaths` property (List<String>) for multiple files
- Kept `filePath` property for backward compatibility
- Added `copyWith()` method for easier document updates

### User Interface

#### Add Document Screen
- Users can now select multiple files at once
- File picker shows "allowMultiple: true"
- Selected files are displayed in a list with remove buttons
- Each file shows its name and can be individually removed

#### Document Detail Screen
- **View mode**: Shows all attached files in a card with file count
- **Edit mode**: Can add more files or remove existing ones
- All files are clickable to open with the system's default app

### Database Service
New methods added:
- `addFileToDocument(documentId, filePath)` - Add a file to existing document
- `removeFileFromDocument(documentId, filePath)` - Remove a specific file
- `_getFileAttachments(documentId)` - Retrieve all files for a document
- `_addFileAttachment(documentId, filePath)` - Internal method to store file

## Usage

### Adding Files When Creating a Document
1. Tap "Attach Files" button
2. Select one or multiple files from the file picker
3. Files appear in a list below the button
4. Remove any file by tapping the X icon
5. Save the document

### Adding Files to Existing Document
1. Open document details
2. Tap "Edit" button
3. Tap "Attach Files" to add more files
4. Remove unwanted files with X icon
5. Save changes

### Opening Files
- In view mode, tap any file name to open it
- Files open with the system's default application

## Technical Details

### Migration Strategy
- Existing documents with `filePath` are automatically handled
- The `filePath` field is kept in the database for backward compatibility
- When loading documents, file attachments are fetched from the new table
- The first file in `filePaths` is stored in `filePath` for legacy support

### File Storage
Each file attachment stores:
- `documentId` - Links to parent document
- `filePath` - Full path to the file
- `fileName` - Display name extracted from path
- `addedAt` - Timestamp when file was attached

### Foreign Key Constraint
File attachments use `ON DELETE CASCADE`, so when a document is deleted, all its file attachments are automatically removed.
