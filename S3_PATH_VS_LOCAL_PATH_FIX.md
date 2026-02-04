# S3 Path vs Local Path Fix

**Date:** January 30, 2026

## Problem
When viewing file attachments synced from remote, the app showed error:
```
Exception: File not found at path: <S3_PATH>
```

The path displayed was an S3 path (e.g., `public/user123/doc456/file.pdf`) instead of a local file system path.

## Root Cause

When syncing file attachments from remote (both in `document_sync_service.dart` and `realtime_sync_service.dart`), the code was incorrectly using the `filePath` field from the GraphQL response as the `localPath` in the database.

**The Issue:**
- GraphQL `filePath` field = S3 storage path (e.g., `public/user123/doc456/file.pdf`)
- Database `localPath` field = Local file system path (e.g., `/data/user/0/com.app/files/user123/file.pdf`)

These are completely different! The S3 path is where the file is stored in the cloud, while the local path is where it's stored on the device after downloading.

## Solution

### Fixed in `document_sync_service.dart`

**Before:**
```dart
await _documentRepository.addFileAttachment(
  syncId: syncId,
  fileName: fileName,
  label: label,
  s3Key: s3Key,
  fileSize: fileSize,
  localPath: filePath,  // ❌ This is the S3 path!
);
```

**After:**
```dart
await _documentRepository.addFileAttachment(
  syncId: syncId,
  fileName: fileName,
  label: label,
  s3Key: s3Key,
  fileSize: fileSize,
  localPath: null,  // ✅ File not downloaded yet
);
```

### Fixed in `realtime_sync_service.dart`

Same fix applied to the real-time sync service.

## How It Works Now

### When File is Synced from Remote

1. **Document metadata syncs** with file attachment info
2. **File attachment record created** with:
   - `fileName`: The file name
   - `s3Key`: The S3 storage key (for downloading)
   - `fileSize`: File size in bytes
   - `label`: Optional user label
   - `localPath`: **null** (file not downloaded yet)

3. **UI shows cloud download icon** (orange) because `localPath` is null

### When User Taps File

1. **Check if downloaded:** `localPath == null` → needs download
2. **Download from S3** using the `s3Key`
3. **Save to local storage:** `/data/user/0/com.app/files/{userId}/{fileName}`
4. **Update database:** Set `localPath` to the actual local file path
5. **Open file** using the local path
6. **UI shows checkmark** (green) because `localPath` is now set

### Subsequent Taps

1. **Check if downloaded:** `localPath != null` → already downloaded
2. **Open file immediately** using the local path
3. No download needed!

## Files Modified

1. **lib/services/document_sync_service.dart**
   - `_syncFileAttachmentsFromMap()` method
   - Set `localPath: null` when syncing from remote
   - Removed code that was setting localPath from remote filePath

2. **lib/services/realtime_sync_service.dart**
   - `_syncFileAttachments()` method
   - Set `localPath: null` when syncing from remote
   - Removed code that was setting localPath from remote filePath

## Data Flow

### Device A (Original)
```
User picks file → File stored locally → localPath set → Upload to S3 → s3Key set
```

### Device B (Syncing)
```
Sync from remote → s3Key set, localPath = null → User taps → Download from S3 → localPath set
```

## Database Schema

```sql
CREATE TABLE file_attachments (
  id INTEGER PRIMARY KEY,
  sync_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  label TEXT,
  file_size INTEGER,
  s3_key TEXT,           -- S3 storage path (for cloud)
  local_path TEXT,       -- Local file system path (for device)
  added_at INTEGER NOT NULL,
  FOREIGN KEY (sync_id) REFERENCES documents(sync_id)
);
```

**Key Point:** `s3_key` and `local_path` are DIFFERENT:
- `s3_key`: Where file is in cloud (same across all devices)
- `local_path`: Where file is on THIS device (different per device, null until downloaded)

## Testing

### Test Scenario 1: Sync and Download
1. Device A: Create document with file attachment
2. Device B: Sign in, sync documents
3. Open document → See file with cloud icon
4. Tap file → Downloads and opens
5. Icon changes to green checkmark
6. Tap again → Opens immediately (no download)

### Test Scenario 2: Verify Database
```bash
adb pull /data/data/com.app/databases/household_docs_<userId>.db
sqlite3 household_docs_<userId>.db

SELECT file_name, s3_key, local_path FROM file_attachments;
```

**Expected after sync (before download):**
```
file.pdf | public/user123/doc456/file.pdf | NULL
```

**Expected after download:**
```
file.pdf | public/user123/doc456/file.pdf | /data/user/0/com.app/files/user123/file.pdf
```

## Benefits

- ✅ Files synced from remote now have correct null localPath
- ✅ Cloud download icon shows correctly (file needs download)
- ✅ Tapping file triggers download automatically
- ✅ After download, file opens immediately
- ✅ No more "file not found" errors with S3 paths
- ✅ Proper separation of cloud storage path vs local storage path

## Notes

- The `filePath` field in GraphQL is misleading - it's actually the S3 path
- We should consider renaming it in the schema to `s3Path` for clarity
- Local path is only set after successful download to device
- Each device has its own local paths (device-specific)
- S3 key is the same across all devices (cloud-specific)
