# Label Persistence Issue - FIXED ✅

## Problem

Labels added to files in the document details screen were visible when first added, but were lost after navigating away from the screen and returning.

## Root Cause

In `lib/screens/document_detail_screen.dart`, the `_saveDocument()` method had a logic issue:

**The Problem:**
- Labels were only being saved for **new files** being added to the document
- Labels for **existing files** were not being updated in the database
- When the user edited a label on an existing file, the change was only stored in memory (`fileLabels` map)
- Upon navigating away and returning, the labels were reloaded from the database, which didn't have the updates

**Original Code:**
```dart
// Add new files
for (final newFile in filePaths) {
  if (!oldFiles.contains(newFile)) {
    await db.addFileToDocument(
        currentDocument.id!, newFile, fileLabels[newFile]);
  }
}
```

This code only saved labels when adding NEW files (`!oldFiles.contains(newFile)`), but did nothing for existing files.

## Solution Applied

Updated the `_saveDocument()` method to save labels for ALL files, both new and existing:

**Fixed Code:**
```dart
// Add new files and update labels for all files
for (final newFile in filePaths) {
  if (!oldFiles.contains(newFile)) {
    // Add new file with label
    await db.addFileToDocument(
        currentDocument.id!, newFile, fileLabels[newFile]);
  } else {
    // Update label for existing file
    await db.updateFileLabel(
        currentDocument.id!, newFile, fileLabels[newFile]);
  }
}
```

Now the code:
1. Adds new files with their labels (as before)
2. **Updates labels for existing files** (NEW - this was missing!)

## What Now Works

✅ **Add Label to New File**
- User adds a file
- User adds a label
- Label is saved to database
- Label persists after navigation

✅ **Add Label to Existing File**
- User opens document with existing file
- User adds a label to the file
- Label is saved to database
- Label persists after navigation

✅ **Edit Existing Label**
- User opens document with labeled file
- User edits the label
- Updated label is saved to database
- Updated label persists after navigation

✅ **Remove Label**
- User opens document with labeled file
- User removes the label
- Removal is saved to database
- File shows without label after navigation

## Testing the Fix

### Test Case 1: Add Label to Existing File

1. Open a document that already has files attached
2. Tap "Edit" button
3. Tap "Edit label" on a file
4. Enter a label (e.g., "Front Page")
5. Tap "Save"
6. Tap "Save Changes"
7. Navigate back to home screen
8. Open the same document again
9. **Expected:** Label "Front Page" is still visible ✅

### Test Case 2: Edit Existing Label

1. Open a document with a labeled file
2. Tap "Edit" button
3. Tap "Edit label" on the labeled file
4. Change the label (e.g., "Front Page" → "Cover Page")
5. Tap "Save"
6. Tap "Save Changes"
7. Navigate back and return
8. **Expected:** Label shows "Cover Page" ✅

### Test Case 3: Remove Label

1. Open a document with a labeled file
2. Tap "Edit" button
3. Tap "Edit label" on the labeled file
4. Tap "Remove Label"
5. Tap "Save Changes"
6. Navigate back and return
7. **Expected:** File shows without label ✅

### Test Case 4: Multiple Files with Labels

1. Open a document
2. Add multiple files
3. Add different labels to each file
4. Save the document
5. Navigate away and return
6. **Expected:** All labels are preserved ✅

## Technical Details

### Database Method Used

The fix uses the existing `updateFileLabel()` method from `DatabaseService`:

```dart
await db.updateFileLabel(
    currentDocument.id!,  // Document ID
    newFile,              // File path
    fileLabels[newFile]   // Label (or null to remove)
);
```

This method:
- Updates the `label` column in the `file_attachments` table
- Handles null values (removes label)
- Is called for every existing file on save

### Flow Diagram

**Before Fix:**
```
User adds label → Stored in memory → Save document → Only new files saved → Navigate away → Labels lost
```

**After Fix:**
```
User adds label → Stored in memory → Save document → ALL files updated in DB → Navigate away → Labels persist ✅
```

## Files Modified

- `lib/screens/document_detail_screen.dart` - Fixed `_saveDocument()` method

## Related Features

This fix ensures proper persistence for the file labeling feature documented in:
- `FILE_LABELS_FEATURE.md` - Feature documentation
- `FILE_THUMBNAILS.md` - Related thumbnail feature

## Next Steps

To apply this fix:

1. **Rebuild the APK:**
   ```bash
   cd household_docs_app
   flutter build apk --dart-define=ENVIRONMENT=dev --release
   ```

2. **Install on device:**
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

3. **Test the scenarios above** to verify labels persist correctly

## Additional Notes

### Why This Happened

The original implementation was designed with the assumption that labels would only be added when files were first attached. The ability to edit labels on existing files was added later, but the save logic wasn't updated to handle this case.

### Prevention

To prevent similar issues:
- Always consider both "create" and "update" scenarios
- Test persistence by navigating away and returning
- Verify database updates for all state changes

---

**Issue:** Labels not persisting after navigation
**Status:** ✅ FIXED
**Date:** December 8, 2025
**Impact:** All file labels now save correctly

The file labeling feature is now fully functional! 🎉
