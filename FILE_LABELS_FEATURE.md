# File Labels Feature

## Overview
You can now add custom labels to file attachments, giving them meaningful names when the actual filename isn't descriptive.

## Why This Feature?
Often files have cryptic names like `IMG_20231215_143022.jpg` or `document_final_v3.pdf`. With labels, you can give them meaningful names like "Insurance Certificate" or "Policy Document" without changing the actual file.

## How It Works

### Database Schema
Added `label` column to the `file_attachments` table:
```sql
CREATE TABLE file_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  documentId INTEGER NOT NULL,
  filePath TEXT NOT NULL,
  fileName TEXT NOT NULL,
  label TEXT,  -- NEW: Custom label
  addedAt TEXT NOT NULL,
  FOREIGN KEY (documentId) REFERENCES documents (id) ON DELETE CASCADE
)
```

### New Model
Created `FileAttachment` model to represent files with labels:
```dart
class FileAttachment {
  final int? id;
  final String filePath;
  final String fileName;
  final String? label;
  final DateTime addedAt;
  
  String get displayName => label ?? fileName;
}
```

## User Experience

### Adding/Editing Labels

#### In Add Document Screen
1. Tap "Add Document"
2. Attach files using "Attach Files" button
3. Each file shows either:
   - "Add label" button (if no label)
   - "Edit label" button (if label exists)
4. Tap the button to open label dialog
5. Enter a meaningful name
6. Tap "Save"
7. Labels are saved when you save the document

#### In Edit Mode
1. Open a document
2. Tap "Edit"
3. Each file shows either:
   - "Add label" button (if no label)
   - "Edit label" button (if label exists)
4. Tap the button to open label dialog
5. Enter a meaningful name
6. Tap "Save"

#### Label Dialog
- Shows the actual filename for reference
- Text field for entering label
- "Remove Label" button (if label exists)
- "Cancel" button
- "Save" button

### Viewing Labels

#### Add Document Screen
- **With label**: Shows label in bold, filename in gray below
- **Without label**: Shows filename only, with "Add label" button
- Labels can be added/edited before saving the document

#### Edit Mode Display
- **With label**: Shows label in bold, filename in gray below
- **Without label**: Shows filename only, with "Add label" button

#### View Mode Display
- **With label**: Shows label as primary text (underlined, clickable), filename in gray below
- **Without label**: Shows filename only

## Features

### Label Management
✅ Add custom labels to any file  
✅ Edit existing labels  
✅ Remove labels (reverts to showing filename)  
✅ Labels stored in database  
✅ Labels persist across app restarts  

### Display Logic
- **Display name**: Label if exists, otherwise filename
- **Always accessible**: Original filename always visible (in gray text when label exists)
- **Clickable**: Both labeled and unlabeled files open when tapped

## Technical Implementation

### Database Migration
- Version upgraded from 2 to 3
- Added `label` column to existing `file_attachments` table
- Backward compatible with existing data

### New Database Methods
```dart
// Get files with labels
Future<List<FileAttachment>> getFileAttachmentsWithLabels(int documentId)

// Update file label
Future<void> updateFileLabel(int documentId, String filePath, String? label)

// Add file with label
Future<void> addFileToDocument(int documentId, String filePath, String? label)
```

### State Management
- `fileLabels` map stores labels: `Map<String, String?>`
- Loaded asynchronously when screen opens
- Updated immediately when label changes
- Persisted to database on save

### UI Components

#### Edit Mode File Card
```dart
ListTile(
  leading: thumbnail,
  title: Column(
    children: [
      Text(displayName, bold),
      if (label != null) Text(fileName, gray),
    ],
  ),
  subtitle: label == null 
    ? "Add label" button
    : "Edit label" button,
  trailing: Remove button,
)
```

#### View Mode File Display
```dart
InkWell(
  onTap: openFile,
  child: Row(
    children: [
      thumbnail,
      Column(
        children: [
          Text(displayName, underlined),
          if (label != null) Text(fileName, gray),
        ],
      ),
      Open icon,
    ],
  ),
)
```

## Use Cases

### Example 1: Insurance Documents
- **Filename**: `scan_20231215_143022.pdf`
- **Label**: "Home Insurance Policy 2024"
- **Display**: Shows "Home Insurance Policy 2024" prominently

### Example 2: Photos
- **Filename**: `IMG_20231220_091234.jpg`
- **Label**: "Kitchen Renovation - Before"
- **Display**: Shows "Kitchen Renovation - Before" with filename below

### Example 3: Multiple Versions
- **File 1**: `document.pdf` → Label: "Original Quote"
- **File 2**: `document_v2.pdf` → Label: "Revised Quote"
- **File 3**: `document_final.pdf` → Label: "Accepted Quote"

## Benefits

### Organization
- Quickly identify files by meaningful names
- No need to rename actual files
- Group related files with consistent naming

### Clarity
- Understand file purpose at a glance
- Reduce confusion with similar filenames
- Better documentation of attachments

### Flexibility
- Change labels without affecting files
- Original filename always accessible
- Easy to update as needs change

## Limitations

### What Labels Don't Do
❌ Don't rename the actual file  
❌ Don't change file location  
❌ Don't affect file opening  
❌ Don't modify file metadata  

### What Labels Do
✅ Provide display name in app  
✅ Stored in app database  
✅ Searchable (future feature)  
✅ Exportable (future feature)  

## Future Enhancements

Possible improvements:
- Search documents by file labels
- Auto-suggest labels based on file type
- Bulk label editing
- Label templates
- Export labels with documents
- Import labels from file metadata

## Testing

### Test in Add Document Screen
1. Tap "Add Document"
2. Attach a file
3. Tap "Add label" on the file
4. Enter "Test Label"
5. Tap "Save" in dialog
6. Verify label shows in bold
7. Verify filename shows in gray below
8. Save the document
9. Open the document
10. Verify label persists

### Test in Edit Mode
1. Open a document with files
2. Tap "Edit"
3. Tap "Add label" on a file
4. Enter "Test Label"
5. Tap "Save"
6. Verify label shows in bold
7. Verify filename shows in gray below
8. Exit edit mode
9. Verify label shows in view mode
10. Reopen document - label persists
11. Edit label again
12. Remove label - reverts to filename

## Migration Notes

### Existing Users
- Existing file attachments work without labels
- Labels are optional - files work fine without them
- No data loss during migration
- Database automatically upgrades to version 3

### New Users
- Database created with label support
- Can add labels immediately
- No migration needed
