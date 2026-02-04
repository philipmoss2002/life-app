# File Download on Tap Fix

**Date:** January 30, 2026

## Problem
When viewing documents synced from remote, file attachments showed a cloud download icon but were not clickable. Users couldn't view files that had been synced but not yet downloaded locally.

## Root Cause
The file list item's `onTap` handler was set to `null` when `localPath` was null:
```dart
onTap: file.localPath != null
    ? () => _openFile(file.localPath!)
    : null,  // ❌ Not clickable!
```

This meant files synced from remote (which have S3 keys but no local paths) couldn't be tapped to download.

## Solution

### 1. Made All Files Tappable
Changed the `onTap` handler to always be active:
```dart
onTap: () => _handleFileTap(file),  // ✅ Always clickable
```

### 2. Added Smart File Handler
Created `_handleFileTap()` method that:
- **If file is downloaded:** Opens it immediately
- **If file needs download:** 
  - Shows "Downloading..." message
  - Downloads from S3 to app-scoped storage
  - Updates database with local path
  - Refreshes file list
  - Opens the downloaded file
  - Shows success message
- **If file unavailable:** Shows error message

### 3. No Special Permissions Needed
The app uses `getApplicationDocumentsDirectory()` which is app-scoped storage and doesn't require `MANAGE_EXTERNAL_STORAGE` or any special permissions on Android.

## Implementation Details

### File Handler Logic
```dart
Future<void> _handleFileTap(FileAttachment file) async {
  // Already downloaded? Open it
  if (file.localPath != null) {
    await _openFile(file.localPath!);
    return;
  }

  // No S3 key? Can't download
  if (file.s3Key == null) {
    // Show error
    return;
  }

  // Download the file
  final identityPoolId = await _authService.getIdentityPoolId();
  final localPath = await _fileService.downloadFile(
    s3Key: file.s3Key!,
    syncId: widget.document!.syncId,
    identityPoolId: identityPoolId,
  );

  // Update database
  await _documentRepository.updateFileLocalPath(
    syncId: widget.document!.syncId,
    fileName: file.fileName,
    localPath: localPath,
  );

  // Refresh UI
  final updatedDoc = await _documentRepository.getDocument(widget.document!.syncId);
  setState(() {
    _files = List.from(updatedDoc.files);
  });

  // Open file
  await _openFile(localPath);
}
```

## User Experience

### Before Fix
1. User opens document synced from remote
2. Sees file attachments with cloud download icon
3. Taps on file → Nothing happens ❌
4. File is not clickable

### After Fix
1. User opens document synced from remote
2. Sees file attachments with cloud download icon
3. Taps on file → "Downloading..." message appears
4. File downloads automatically
5. File opens in default viewer
6. Icon changes to green checkmark ✅
7. Next tap opens file immediately (already downloaded)

## Visual Indicators

| State | Icon | Color | Clickable |
|-------|------|-------|-----------|
| Downloaded | ✓ check_circle | Green | Yes - Opens immediately |
| Not Downloaded | ☁ cloud_download | Orange | Yes - Downloads then opens |
| No S3 Key | ☁ cloud_download | Orange | Yes - Shows error |

## Files Modified

**lib/screens/new_document_detail_screen.dart**
- Changed `onTap` handler to always call `_handleFileTap()`
- Added `_handleFileTap()` method (~90 lines)
- Handles download, database update, UI refresh, and file opening

## Testing

### Test Scenario 1: View Synced File
1. Device A: Create document with file attachment
2. Device B: Sign in, pull documents
3. Open document
4. Tap on file attachment
5. **Expected:** File downloads and opens automatically

### Test Scenario 2: View Already Downloaded File
1. Tap on file that was previously downloaded
2. **Expected:** Opens immediately without downloading again

### Test Scenario 3: Error Handling
1. Turn off internet
2. Tap on undownloaded file
3. **Expected:** Shows error message

## Benefits

- ✅ Files synced from remote are now viewable
- ✅ Automatic download on first tap
- ✅ Subsequent taps open immediately
- ✅ No special permissions required
- ✅ Clear user feedback (downloading, success, error)
- ✅ Database stays in sync with local file state
- ✅ Works with app-scoped storage (Android best practice)

## Notes

- Downloads happen to app-scoped storage (`getApplicationDocumentsDirectory()`)
- No `MANAGE_EXTERNAL_STORAGE` permission needed
- Files are user-specific and isolated
- Download errors don't crash the app
- UI updates automatically after download
- Green checkmark indicates file is ready to open offline
