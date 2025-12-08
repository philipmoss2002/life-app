# Performance Optimizations

This document describes the performance optimizations implemented for the cloud sync feature.

## Overview

The following optimizations have been implemented to improve sync performance, reduce bandwidth usage, and enhance user experience:

1. **Batch Document Updates**
2. **Parallel File Uploads**
3. **Delta Sync for Changed Fields**
4. **File Compression Before Upload**
5. **Thumbnail Caching**

## 1. Batch Document Updates

### Implementation
- Location: `lib/services/document_sync_manager.dart`
- Method: `batchUploadDocuments(List<Document> documents)`

### Description
Instead of uploading documents one at a time, documents are now batched and uploaded in groups of up to 25 (DynamoDB's batch write limit). This significantly reduces the number of API calls and improves sync performance.

### Benefits
- Reduces API calls by up to 25x
- Faster initial sync for users with many documents
- Lower latency for bulk operations
- Reduced AWS costs due to fewer API requests

### Usage
```dart
final documents = [doc1, doc2, doc3, ...];
await documentSyncManager.batchUploadDocuments(documents);
```

## 2. Parallel File Uploads

### Implementation
- Location: `lib/services/file_sync_manager.dart`
- Method: `uploadFilesParallel(List<String> filePaths, String documentId)`
- Concurrency Limit: 3 simultaneous uploads

### Description
Files are now uploaded in parallel with a maximum of 3 concurrent uploads. This takes advantage of modern network capabilities while avoiding overwhelming the device or network.

### Benefits
- Up to 3x faster file upload times
- Better utilization of available bandwidth
- Improved user experience with faster sync completion

### Usage
```dart
final filePaths = ['path/to/file1.pdf', 'path/to/file2.jpg'];
final s3Keys = await fileSyncManager.uploadFilesParallel(filePaths, documentId);
```

## 3. Delta Sync for Changed Fields

### Implementation
- Location: `lib/services/document_sync_manager.dart`
- Method: `updateDocumentDelta(Document document, Map<String, dynamic> changedFields)`

### Description
Instead of uploading the entire document on every change, only the fields that have changed are sent to the server. This dramatically reduces bandwidth usage for document updates.

### Benefits
- Reduces bandwidth usage by 50-90% for updates
- Faster sync times for small changes
- Lower AWS costs for DynamoDB operations
- Better performance on slow networks

### Usage
```dart
final changedFields = {
  'title': 'Updated Title',
  'notes': 'New notes',
};
await documentSyncManager.updateDocumentDelta(document, changedFields);
```

## 4. File Compression Before Upload

### Implementation
- Location: `lib/services/file_sync_manager.dart`
- Method: `_compressFileIfNeeded(String filePath)`
- Compression Threshold: 1 MB
- Algorithm: GZip

### Description
Files larger than 1 MB are automatically compressed using GZip before upload (except for already-compressed formats like JPG, PNG, ZIP, MP4, etc.). The compression is only applied if it actually reduces the file size.

### Benefits
- Reduces bandwidth usage by 30-70% for compressible files
- Faster upload times
- Lower storage costs in S3
- Better experience on metered connections

### Behavior
- Files < 1 MB: No compression
- Already compressed formats (JPG, PNG, ZIP, MP4, etc.): No compression
- Other files > 1 MB: GZip compression applied
- Only uses compressed version if it's actually smaller

## 5. Thumbnail Caching

### Implementation
- Location: `lib/services/file_sync_manager.dart`
- Methods:
  - `cacheThumbnail(String s3Key, List<int> thumbnailBytes)`
  - `getCachedThumbnail(String s3Key)`
  - `clearThumbnailCache()`

### Description
Thumbnails are cached locally to avoid re-downloading them every time a document is viewed. This provides instant thumbnail display and reduces bandwidth usage.

### Benefits
- Instant thumbnail display (no loading time)
- Reduced bandwidth usage
- Better offline experience
- Lower S3 costs

### Usage
```dart
// Cache a thumbnail
await fileSyncManager.cacheThumbnail(s3Key, thumbnailBytes);

// Get cached thumbnail
final cachedPath = await fileSyncManager.getCachedThumbnail(s3Key);

// Clear cache
await fileSyncManager.clearThumbnailCache();
```

## Performance Impact

### Expected Improvements

| Operation | Before | After | Improvement |
|-----------|--------|-------|-------------|
| Initial sync (100 docs) | ~100 API calls | ~4 API calls | 96% reduction |
| Document update | Full document | Changed fields only | 50-90% less data |
| File upload (3 files) | Sequential | Parallel | 3x faster |
| Large file upload | Uncompressed | Compressed | 30-70% less data |
| Thumbnail display | Download each time | Cached | Instant |

### Bandwidth Savings

For a typical user with:
- 50 documents
- 100 file attachments
- 10 document updates per week

Expected bandwidth savings: **60-80% reduction** in data transfer

## Testing

Performance optimization tests are located in:
- `test/services/performance_optimization_test.dart`

Run tests with:
```bash
flutter test test/services/performance_optimization_test.dart
```

## Future Enhancements

Potential future optimizations:
1. **Incremental sync**: Only sync documents modified since last sync
2. **Predictive prefetching**: Preload likely-to-be-viewed documents
3. **Smart compression**: Use different algorithms based on file type
4. **Background sync**: Sync during idle times to avoid impacting user
5. **Adaptive quality**: Adjust thumbnail quality based on network speed

## Requirements Validated

These optimizations address the following requirements:
- **Requirement 3.5**: Synchronize changes within 30 seconds (improved with batch operations)
- **Requirement 4.5**: Display upload progress (maintained with parallel uploads)

## Notes

- All optimizations are backward compatible with existing code
- Compression is transparent to the user
- Batch operations automatically handle splitting into appropriate sizes
- Parallel uploads respect system resources with concurrency limits
