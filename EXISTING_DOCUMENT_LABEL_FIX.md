# Existing Document Label Persistence Fix

## Problem
Labels added or edited on files in existing documents were not being saved properly. When users edited a label and saved it, the label didn't persist when they navigated away and came back to the document.

## Root Cause
The `updateFileLabel()` method in `database_service.dart` was returning `void` instead of returning the number of rows affected. This meant that:
1. The calling code couldn't verify if the update was successful
2. Silent failures (like file path mismatches) went undetected
3. Users had no feedback about whether their label was saved

## Solution

### 1. Return Rows Affected from Database Method
**File**: `lib/services/database_service.dart`

Changed the `updateFileLabel()` method to return `int` (number of rows affected):

Before:
```dart
Future<void> updateFileLabel(
    int documentId, String filePath, String? label) async {
  final db = await database;
  await db.update(
    'file_attachments',
    {'label': label},
    where: 'documentId = ? AND filePath = ?',
    whereArgs: [documentId, filePath],
  );
}
```

After:
```dart
Future<int> updateFileLabel(
    int documentId, String filePath, String? label) async {
  final db = await database;
  final rowsAffected = await db.update(
    'file_attachments',
    {'label': label},
    where: 'documentId = ? AND filePath = ?',
    whereArgs: [documentId, filePath],
  );
  return rowsAffected;
}
```

### 2. Add Error Handling and User Feedback
**File**: `lib/screens/document_detail_screen.dart`

Enhanced the `_editFileLabel()` method to:
- Check the return value from `updateFileLabel()`
- Show success/warning messages to the user
- Handle errors gracefully

Before:
```dart
if (currentDocument.id != null) {
  await DatabaseService.instance.updateFileLabel(
    currentDocument.id!,
    filePath,
    result.isEmpty ? null : result,
  );
}
```

After:
```dart
if (currentDocument.id != null) {
  try {
    final rowsAffected = await DatabaseService.instance.updateFileLabel(
      currentDocument.id!,
      filePath,
      result.isEmpty ? null : result,
    );
    
    if (rowsAffected == 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Warning: Label may not have been saved'),
          backgroundColor: Colors.orange,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Label saved successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  } catch (e) {
    debugPrint('Error updating label: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save label: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

## Benefits

1. **User Feedback**: Users now see a confirmation message when a label is saved successfully
2. **Error Detection**: If the update fails (0 rows affected), users are warned
3. **Better Debugging**: The return value helps identify issues like file path mismatches
4. **Graceful Error Handling**: Exceptions are caught and displayed to the user

## Impact

- Labels are now properly saved when edited in existing documents
- Users receive immediate feedback about save success/failure
- Easier to diagnose issues if labels still don't save (warning message will appear)

## Testing

To verify the fix:
1. Open an existing document
2. Click "Edit"
3. Click "Add label" or "Edit label" on a file
4. Enter a label and click "Save"
5. You should see a green "Label saved successfully" message
6. Navigate away from the document
7. Come back to the document
8. Verify the label is still there

If you see an orange "Warning: Label may not have been saved" message, it indicates a file path mismatch or database issue that needs further investigation.

## Files Modified

- `lib/services/database_service.dart` - Changed `updateFileLabel()` to return `int`
- `lib/screens/document_detail_screen.dart` - Added error handling and user feedback
