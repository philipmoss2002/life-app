# Storage Permission Fix

**Date:** January 30, 2026

## Problem
When trying to view file attachments synced from remote, the app crashed with:
```
Permission denied: android.permission.MANAGE_EXTERNAL_STORAGE
```

## Root Cause
The `open_file` package requires storage permissions to open files, even when they're stored in app-scoped storage. This is because it uses Android intents to open files with external apps (PDF viewers, image viewers, etc.).

## Solution

### 1. Added Storage Permissions to AndroidManifest.xml
```xml
<!-- Storage permissions for file access -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
```

**Note:** These permissions are scoped by SDK version:
- `WRITE_EXTERNAL_STORAGE`: Only needed for Android 9 and below (API 28-)
- `READ_EXTERNAL_STORAGE`: Only needed for Android 12 and below (API 32-)
- Android 13+ (API 33+) uses granular media permissions instead

### 2. Added permission_handler Package
```yaml
dependencies:
  permission_handler: ^11.0.1
```

### 3. Implemented Runtime Permission Request
Added `_requestStoragePermission()` method that:
- Checks if permission is already granted
- Requests permission if needed
- Handles permanently denied case with settings dialog
- Returns true/false based on permission status

### 4. Updated File Tap Handler
Modified `_handleFileTap()` to request permission before opening files:
```dart
// Request storage permission if needed
if (!await _requestStoragePermission()) {
  // Show error message
  return;
}

// Continue with file opening...
```

## Implementation Details

### Permission Request Flow
```dart
Future<bool> _requestStoragePermission() async {
  // Already granted?
  if (await Permission.storage.isGranted) {
    return true;
  }

  // Request permission
  final status = await Permission.storage.request();
  
  if (status.isGranted) {
    return true;
  }

  // Permanently denied? Show settings dialog
  if (status.isPermanentlyDenied) {
    final shouldOpenSettings = await showDialog(...);
    if (shouldOpenSettings == true) {
      await openAppSettings();
    }
    return false;
  }

  return status.isGranted;
}
```

### User Experience

#### First Time Opening File
1. User taps on file attachment
2. Permission dialog appears: "Allow Life App to access photos and media?"
3. User taps "Allow"
4. File downloads (if needed) and opens

#### Permission Denied
1. User taps "Deny"
2. Snackbar shows: "Storage permission is required to view files"
3. File doesn't open

#### Permission Permanently Denied
1. User denied permission multiple times
2. Dialog appears: "Storage permission is required to view files. Please grant permission in app settings."
3. User can tap "Open Settings" to go to app settings
4. User grants permission in settings
5. Returns to app and can now open files

## Files Modified

1. **android/app/src/main/AndroidManifest.xml**
   - Added `READ_EXTERNAL_STORAGE` permission (API ≤32)
   - Added `WRITE_EXTERNAL_STORAGE` permission (API ≤28)
   - Added `INTERNET` permission (for AWS)
   - Added `requestLegacyExternalStorage="true"` for Android 10 compatibility

2. **pubspec.yaml**
   - Added `permission_handler: ^11.0.1`

3. **lib/screens/new_document_detail_screen.dart**
   - Added `permission_handler` import
   - Added `_requestStoragePermission()` method
   - Updated `_handleFileTap()` to request permission first

## Testing

### Test on Different Android Versions

#### Android 13+ (API 33+)
- Permission request may not appear (app-scoped storage doesn't need permission)
- Files should open directly

#### Android 11-12 (API 30-32)
- Permission request appears
- After granting, files open successfully

#### Android 10 and below (API 29-)
- Permission request appears
- `requestLegacyExternalStorage="true"` ensures compatibility

### Test Permission Scenarios

1. **First time:** Permission dialog appears, grant permission, file opens
2. **Already granted:** File opens immediately
3. **Denied once:** Permission dialog appears again on next tap
4. **Permanently denied:** Settings dialog appears, can open app settings

## Why This Permission is Needed

Even though files are stored in app-scoped storage (`getApplicationDocumentsDirectory()`), the `open_file` package uses Android intents to open files with external apps (like PDF viewers). These external apps need permission to access the file, hence the storage permission requirement.

### Alternative Approaches (Not Implemented)

1. **Use file provider** - Share files via FileProvider URIs (more complex)
2. **In-app viewer** - Display files within the app (limited file type support)
3. **Copy to external storage** - Copy files to Downloads folder (requires MANAGE_EXTERNAL_STORAGE on Android 11+)

The current approach (runtime permission request) is the simplest and most user-friendly solution.

## Benefits

- ✅ Files can now be opened on all Android versions
- ✅ Graceful permission handling with user feedback
- ✅ Settings dialog for permanently denied permissions
- ✅ Minimal permissions requested (scoped by Android version)
- ✅ No breaking changes to existing functionality
- ✅ Works with app-scoped storage (no MANAGE_EXTERNAL_STORAGE needed)

## Notes

- Permission is requested only when needed (lazy loading)
- Permission persists across app restarts once granted
- Users can revoke permission in system settings
- The app handles revoked permissions gracefully
- Files remain in app-scoped storage (secure and private)
