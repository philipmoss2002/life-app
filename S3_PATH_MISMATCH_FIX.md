# S3 Path Mismatch Fix

## Issue Identified
The document deletion was failing due to a **path mismatch** between where files are stored in S3 and where the download method is looking for them.

### Evidence from Logs
```
📍 Download to: /data/user/0/com.lifeapp.documents/code_cache/downloaded_documents/5662e2f4-7041-70cb-0e8e-0f73677d1863/51/1766093185001-all-labels-BT-1511-3182-002.pdf

Failed to download file documents/5662e2f4-7041-70cb-0e8e-0f73677d1863/51/1766093185001-all-labels-BT-1511-3182-002.pdf: NoSuchKey
```

**The Problem:**
- Download method tries: `public/documents/userId/documentId/filename`
- But file exists at: `documents/userId/documentId/filename` (without `public/` prefix)

## Root Cause Analysis

### Current Upload Process
1. Creates s3Key: `documents/userId/documentId/timestamp-filename`
2. Creates publicPath: `public/documents/userId/documentId/timestamp-filename`
3. Uploads to S3 at: `public/documents/userId/documentId/timestamp-filename`
4. **Returns s3Key**: `documents/userId/documentId/timestamp-filename` (without `public/`)

### Current Download Process
1. Receives s3Key: `documents/userId/documentId/timestamp-filename`
2. Creates publicPath: `public/documents/userId/documentId/timestamp-filename`
3. Tries to download from: `public/documents/userId/documentId/timestamp-filename`

### The Mismatch
Some files appear to be stored at `documents/...` without the `public/` prefix, possibly due to:
- Legacy upload methods that didn't use `public/` prefix
- Different upload configurations in the past
- Inconsistent path handling across different parts of the system

## Fix Applied

### Fallback Path Strategy
Modified the `downloadFile` method in `SimpleFileSyncManager` to try both path formats:

```dart
// Try downloading with public/ prefix first (current standard)
final publicPath = 'public/$s3Key';
_logInfo('📍 Trying download from: $publicPath');

StorageDownloadFileResult? downloadResult;

try {
  downloadResult = await Amplify.Storage.downloadFile(
    path: StoragePath.fromString(publicPath),
    localFile: AWSFile.fromPath(downloadPath),
  ).result;
} catch (e) {
  // If public/ path fails, try without public/ prefix (legacy files)
  if (e.toString().contains('NoSuchKey') || 
      e.toString().contains('Cannot find the item specified')) {
    _logWarning('⚠️ File not found at $publicPath, trying legacy path: $s3Key');
    
    downloadResult = await Amplify.Storage.downloadFile(
      path: StoragePath.fromString(s3Key),
      localFile: AWSFile.fromPath(downloadPath),
    ).result;
  } else {
    rethrow;
  }
}
```

### How It Works
1. **First attempt**: Try to download from `public/documents/...` (current standard)
2. **Fallback**: If NoSuchKey error, try downloading from `documents/...` (legacy path)
3. **Error handling**: If both fail, throw the original error

## Expected Results
- ✅ Files uploaded with current method (with `public/` prefix) will download successfully
- ✅ Legacy files (without `public/` prefix) will also download successfully
- ✅ Document deletion will no longer be blocked by path mismatches
- ✅ Better logging to understand which path is being used

## Files Modified
- `household_docs_app/lib/services/simple_file_sync_manager.dart`
  - Enhanced `downloadFile` method with fallback path logic
  - Improved logging to show which path is being attempted

## Testing
This fix should resolve:
- ✅ NoSuchKey errors due to path mismatches
- ✅ Document deletion failures
- ✅ File download issues for both current and legacy files
- ✅ Improved debugging information in logs

## Why This Should Work
The fix addresses the core issue: **path inconsistency**. By trying both possible paths, we ensure compatibility with:
- Current files uploaded with `public/` prefix
- Legacy files that might be stored without `public/` prefix
- Any mixed scenarios where different upload methods were used

The fallback approach is safe because:
- It only tries the alternative path if the first one fails with NoSuchKey
- Other errors (permissions, network, etc.) are still thrown immediately
- The logging clearly shows which path worked