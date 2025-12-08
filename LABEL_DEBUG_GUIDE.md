# Label Persistence Debug Guide

## Current Situation
Labels are not saving for both new and existing documents despite multiple fixes being applied.

## What We've Fixed So Far

### 1. Database Schema (SAVE_DOCUMENT_FIX.md)
- Added missing cloud sync columns to documents table
- Upgraded database to version 4
- This fixed the "Save Document" button

### 2. Label Creation (SAVE_DOCUMENT_FIX.md)
- Created `createDocumentWithLabels()` method
- Labels are now passed during document creation instead of being updated afterwards
- This should have fixed labels for new documents

### 3. Label Updates (EXISTING_DOCUMENT_LABEL_FIX.md)
- Made `updateFileLabel()` return the number of rows affected
- Added error handling and user feedback
- This should have fixed labels for existing documents

## Why Labels Still Aren't Saving

There are several possible reasons:

### 1. Database Not Upgraded
The app might still be using the old database version (3) instead of the new version (4). This would happen if:
- The app wasn't fully restarted after the code changes
- The database file is cached
- The version upgrade logic didn't run

**Solution**: Uninstall and reinstall the app to force a fresh database creation.

### 2. File Path Mismatch
The file paths stored in the database might not match the paths being queried. For example:
- Stored: `/storage/emulated/0/Download/file.pdf`
- Queried: `/data/user/0/com.example.app/cache/file.pdf`

This would cause `updateFileLabel()` to return 0 rows affected.

**Solution**: Use the debug tool to check actual file paths in the database.

### 3. Labels Not Being Loaded
Labels might be saving correctly but not being loaded when the document is opened.

**Solution**: Check the `_loadFileLabels()` method and verify it's being called.

## Debug Steps

### Step 1: Check Database Version
1. Open any document in the app
2. Tap the bug icon (🐛) in the top right
3. Check the console output for "Database version"
4. It should show version 4

If it shows version 3 or lower:
- Uninstall the app completely
- Reinstall and test again

### Step 2: Check Table Schema
Look at the console output after tapping the bug icon:

```
--- FILE_ATTACHMENTS TABLE SCHEMA ---
  id: INTEGER (nullable: false)
  documentId: INTEGER (nullable: false)
  filePath: TEXT (nullable: false)
  fileName: TEXT (nullable: false)
  label: TEXT (nullable: true)  ← This should exist
  addedAt: TEXT (nullable: false)
```

If the `label` column is missing:
- The database wasn't upgraded properly
- Uninstall and reinstall the app

### Step 3: Test Label Saving
1. Create a new document with a file
2. Add a label to the file
3. Save the document
4. Open the document again
5. Tap the bug icon
6. Check the console output under "ALL FILE ATTACHMENTS"
7. Look for your file and check if the label is there

Example output if working:
```
--- ALL FILE ATTACHMENTS ---
  ID: 1
    Document ID: 1
    File: test.pdf
    Label: My Test File  ← Label should be here
    Path: /storage/emulated/0/Download/test.pdf
```

Example output if NOT working:
```
--- ALL FILE ATTACHMENTS ---
  ID: 1
    Document ID: 1
    File: test.pdf
    Label: (null)  ← Label is null
    Path: /storage/emulated/0/Download/test.pdf
```

### Step 4: Check for Warnings
When you edit a label in an existing document, you should see one of these messages:
- ✅ Green: "Label saved successfully" - It worked!
- ⚠️ Orange: "Warning: Label may not have been saved" - File path mismatch
- ❌ Red: "Failed to save label: [error]" - Database error

If you see the orange warning:
- There's a file path mismatch
- The file path in the database doesn't match the current file path
- This can happen if files are moved or the app storage location changes

## Quick Fix: Force Database Recreation

If nothing else works, force the app to recreate the database:

1. **Uninstall the app completely**
   ```bash
   flutter clean
   ```

2. **Delete the app from your device**
   - Long press the app icon
   - Select "Uninstall"

3. **Rebuild and install**
   ```bash
   flutter run
   ```

This will create a fresh database with version 4 and all the correct columns.

## Testing Checklist

After applying fixes, test these scenarios:

### New Documents
- [ ] Create a new document
- [ ] Add a file
- [ ] Add a label to the file
- [ ] Save the document
- [ ] Navigate away
- [ ] Open the document again
- [ ] Verify the label is still there

### Existing Documents
- [ ] Open an existing document
- [ ] Click Edit
- [ ] Add or edit a label on a file
- [ ] You should see "Label saved successfully"
- [ ] Click Save Changes
- [ ] Navigate away
- [ ] Open the document again
- [ ] Verify the label is still there

### Multiple Files
- [ ] Create a document with multiple files
- [ ] Add different labels to each file
- [ ] Save and reopen
- [ ] Verify all labels are correct

## Debug Tool Usage

The debug tool (`database_debug.dart`) provides two functions:

### 1. Print Database Info
```dart
await DatabaseDebug.printDatabaseInfo();
```
Shows:
- Database version
- Table schemas
- Record counts
- All file attachments with labels

### 2. Test Label Update
```dart
await DatabaseDebug.testLabelUpdate(documentId, filePath, 'New Label');
```
Tests updating a specific label and shows:
- Whether the file attachment exists
- Current label value
- Rows affected by update
- New label value after update

## Next Steps

1. **First**: Uninstall and reinstall the app to get a fresh database
2. **Then**: Test label saving on a new document
3. **If still failing**: Use the debug tool to check what's in the database
4. **Report back**: Share the console output from the debug tool

The debug output will tell us exactly what's wrong and we can fix it from there.
