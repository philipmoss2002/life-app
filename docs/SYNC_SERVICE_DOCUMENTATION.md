# Sync Service Documentation

## Overview

The Household Docs App sync service provides seamless synchronization of documents and file attachments across multiple devices using AWS Amplify, DynamoDB, and S3. This document covers the architecture, implementation details, and usage patterns of the sync services.

## Architecture

### Service Hierarchy

```
CloudSyncService (Orchestrator)
├── DocumentSyncManager (Document metadata sync)
├── FileSyncManager (File attachment sync)
├── RealtimeSyncService (Real-time updates)
├── OfflineSyncQueueService (Offline operation queuing)
├── ConflictResolutionService (Conflict handling)
├── AuthTokenManager (Authentication)
├── RetryManager (Error handling and retries)
├── PerformanceMonitor (Metrics and analytics)
└── ErrorStateManager (Error state tracking)
```

### Data Flow

```
Local Database ←→ CloudSyncService ←→ AWS Amplify ←→ AWS Services
                                                    ├── DynamoDB (Documents)
                                                    ├── S3 (Files)
                                                    ├── Cognito (Auth)
                                                    └── AppSync (GraphQL)
```

## Core Services

### CloudSyncService

The main orchestrator that coordinates all sync operations.

**Key Methods:**
```dart
class CloudSyncService {
  Future<void> syncDocument(Document document);
  Future<void> syncAllDocuments();
  Future<void> uploadFile(String filePath, String documentId);
  Future<String> downloadFile(String s3Key, String documentId);
  Future<void> startRealtimeSync();
  Future<void> stopRealtimeSync();
  Stream<SyncEvent> get syncEvents;
}
```

**Usage Example:**
```dart
final cloudSync = CloudSyncService();

// Sync a single document
await cloudSync.syncDocument(document);

// Start real-time synchronization
await cloudSync.startRealtimeSync();

// Listen for sync events
cloudSync.syncEvents.listen((event) {
  print('Sync event: ${event.type} - ${event.message}');
});
```

### DocumentSyncManager

Handles document metadata synchronization with DynamoDB.

**Key Methods:**
```dart
class DocumentSyncManager {
  Future<void> uploadDocument(Document document);
  Future<Document> downloadDocument(String documentId);
  Future<void> updateDocument(Document document);
  Future<void> deleteDocument(String documentId);
  Future<List<Document>> fetchAllDocuments(String userId);
  Future<void> batchUploadDocuments(List<Document> documents);
}
```

**Implementation Details:**

#### Upload Document
```dart
Future<void> uploadDocument(Document document) async {
  try {
    // Convert to Amplify model
    final amplifyDoc = document.toAmplifyModel();
    
    // Create mutation request
    final request = ModelMutations.create(amplifyDoc);
    
    // Execute mutation
    final response = await Amplify.API.mutate(request: request).response;
    
    if (response.hasErrors) {
      throw SyncException('Upload failed: ${response.errors}');
    }
    
    // Update local sync state
    await _updateLocalSyncState(document.id!, SyncState.synced);
    
  } catch (e) {
    await _handleSyncError(document.id!, e);
    rethrow;
  }
}
```

#### Download Document
```dart
Future<Document> downloadDocument(String documentId) async {
  try {
    // Create query request
    final request = ModelQueries.get(AmplifyDocument.classType, documentId);
    
    // Execute query
    final response = await Amplify.API.query(request: request).response;
    
    if (response.data == null) {
      throw DocumentNotFoundException('Document not found: $documentId');
    }
    
    // Convert from Amplify model
    return Document.fromAmplifyModel(response.data!);
    
  } catch (e) {
    await _logError('Download failed for document $documentId', e);
    rethrow;
  }
}
```

#### Version Conflict Detection
```dart
Future<void> updateDocument(Document document) async {
  try {
    // Check for version conflicts
    final remote = await downloadDocument(document.id.toString());
    
    if (remote.version != document.version) {
      throw VersionConflictException(
        message: 'Version conflict detected',
        localDocument: document,
        remoteDocument: remote,
      );
    }
    
    // Increment version and update
    final updatedDoc = document.incrementVersion();
    final request = ModelMutations.update(updatedDoc.toAmplifyModel());
    
    final response = await Amplify.API.mutate(request: request).response;
    
    if (response.hasErrors) {
      throw SyncException('Update failed: ${response.errors}');
    }
    
  } catch (e) {
    if (e is VersionConflictException) {
      await _handleVersionConflict(e);
    }
    rethrow;
  }
}
```

### FileSyncManager

Handles file attachment synchronization with S3.

**Key Methods:**
```dart
class FileSyncManager {
  Future<String> uploadFile(String filePath, String documentId);
  Future<String> downloadFile(String s3Key, String documentId);
  Future<void> deleteFile(String s3Key);
  Stream<UploadProgress> get uploadProgress;
  Stream<DownloadProgress> get downloadProgress;
}
```

**Implementation Details:**

#### File Upload with Progress
```dart
Future<String> uploadFile(String filePath, String documentId) async {
  final file = File(filePath);
  final fileName = path.basename(filePath);
  final s3Key = _generateS3Key(documentId, fileName);
  
  try {
    // Calculate checksum for integrity verification
    final checksum = await _calculateChecksum(file);
    
    // Start upload with progress tracking
    final uploadTask = Amplify.Storage.uploadFile(
      localFile: AWSFile.fromPath(filePath),
      key: s3Key,
      options: StorageUploadFileOptions(
        accessLevel: StorageAccessLevel.private,
        metadata: {
          'checksum': checksum,
          'documentId': documentId,
          'originalName': fileName,
        },
      ),
      onProgress: (progress) {
        _uploadProgressController.add(UploadProgress(
          s3Key: s3Key,
          bytesTransferred: progress.transferredBytes,
          totalBytes: progress.totalBytes,
        ));
      },
    );
    
    final result = await uploadTask.result;
    
    // Verify upload integrity
    await _verifyUploadIntegrity(s3Key, checksum);
    
    return result.uploadedItem.key;
    
  } catch (e) {
    await _logError('File upload failed: $filePath', e);
    rethrow;
  }
}
```

#### Multipart Upload for Large Files
```dart
Future<String> _uploadLargeFile(String filePath, String s3Key) async {
  const chunkSize = 5 * 1024 * 1024; // 5MB chunks
  final file = File(filePath);
  final fileSize = await file.length();
  
  if (fileSize <= chunkSize) {
    return _uploadSmallFile(filePath, s3Key);
  }
  
  // Initiate multipart upload
  final uploadId = await _initiateMultipartUpload(s3Key);
  final parts = <CompletedPart>[];
  
  try {
    // Upload parts
    for (int i = 0; i < (fileSize / chunkSize).ceil(); i++) {
      final start = i * chunkSize;
      final end = math.min(start + chunkSize, fileSize);
      
      final partNumber = i + 1;
      final chunk = await _readFileChunk(file, start, end);
      
      final etag = await _uploadPart(s3Key, uploadId, partNumber, chunk);
      parts.add(CompletedPart(partNumber: partNumber, etag: etag));
      
      // Report progress
      _uploadProgressController.add(UploadProgress(
        s3Key: s3Key,
        bytesTransferred: end,
        totalBytes: fileSize,
      ));
    }
    
    // Complete multipart upload
    await _completeMultipartUpload(s3Key, uploadId, parts);
    return s3Key;
    
  } catch (e) {
    // Abort multipart upload on error
    await _abortMultipartUpload(s3Key, uploadId);
    rethrow;
  }
}
```

### RealtimeSyncService

Provides real-time synchronization using GraphQL subscriptions.

**Key Methods:**
```dart
class RealtimeSyncService {
  Future<void> startRealtimeSync(String userId);
  Future<void> stopRealtimeSync();
  Stream<SyncEvent> get syncEvents;
}
```

**Implementation:**
```dart
Future<void> startRealtimeSync(String userId) async {
  try {
    // Subscribe to document changes
    final docSubscription = ModelSubscriptions.onCreate(AmplifyDocument.classType)
        .where(AmplifyDocument.USERID.eq(userId));
    
    _documentSubscription = Amplify.API.subscribe(
      request: docSubscription,
      onEstablished: () => _onSubscriptionEstablished('documents'),
    ).listen(
      (event) => _handleDocumentUpdate(event.data),
      onError: (error) => _handleSubscriptionError('documents', error),
    );
    
    // Subscribe to file attachment changes
    final fileSubscription = ModelSubscriptions.onCreate(AmplifyFileAttachment.classType);
    
    _fileSubscription = Amplify.API.subscribe(
      request: fileSubscription,
      onEstablished: () => _onSubscriptionEstablished('files'),
    ).listen(
      (event) => _handleFileUpdate(event.data),
      onError: (error) => _handleSubscriptionError('files', error),
    );
    
  } catch (e) {
    await _logError('Failed to start real-time sync', e);
    rethrow;
  }
}

void _handleDocumentUpdate(AmplifyDocument? document) async {
  if (document == null) return;
  
  try {
    // Convert to local document
    final localDoc = Document.fromAmplifyModel(document);
    
    // Update local database
    await _databaseService.updateDocument(localDoc);
    
    // Emit sync event
    _syncEventController.add(SyncEvent(
      type: SyncEventType.documentUpdated,
      documentId: document.id,
      message: 'Document updated from another device',
      timestamp: DateTime.now(),
    ));
    
  } catch (e) {
    await _logError('Failed to handle document update', e);
  }
}
```

### OfflineSyncQueueService

Manages sync operations when offline and processes them when connectivity is restored.

**Key Methods:**
```dart
class OfflineSyncQueueService {
  Future<void> queueOperation(SyncOperation operation);
  Future<void> processQueue();
  Future<void> clearQueue();
  Stream<QueueProcessingProgress> get processingProgress;
}
```

**Queue Operation Types:**
```dart
enum SyncOperationType {
  uploadDocument,
  updateDocument,
  deleteDocument,
  uploadFile,
  deleteFile,
}

class SyncOperation {
  final String id;
  final SyncOperationType type;
  final Map<String, dynamic> data;
  final DateTime queuedAt;
  final int retryCount;
  
  SyncOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.queuedAt,
    this.retryCount = 0,
  });
}
```

**Queue Processing:**
```dart
Future<void> processQueue() async {
  final operations = await _getQueuedOperations();
  
  if (operations.isEmpty) return;
  
  // Sort by queue time to maintain order
  operations.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
  
  // Consolidate operations on same document
  final consolidatedOps = _consolidateOperations(operations);
  
  for (final operation in consolidatedOps) {
    try {
      await _executeOperation(operation);
      await _removeFromQueue(operation.id);
      
      _progressController.add(QueueProcessingProgress(
        completed: consolidatedOps.indexOf(operation) + 1,
        total: consolidatedOps.length,
      ));
      
    } catch (e) {
      if (operation.retryCount < _maxRetries) {
        await _requeueOperation(operation);
      } else {
        await _markOperationFailed(operation, e);
      }
    }
  }
}
```

### ConflictResolutionService

Handles version conflicts and provides resolution strategies.

**Key Methods:**
```dart
class ConflictResolutionService {
  Future<ConflictResolution> detectConflict(Document local, Document remote);
  Future<Document> resolveConflict(ConflictResolution resolution);
  Future<void> notifyUserOfConflict(String documentId);
}
```

**Conflict Resolution Strategies:**
```dart
enum ConflictResolutionStrategy {
  keepLocal,      // Keep local version
  keepRemote,     // Keep remote version
  merge,          // Merge both versions
  userChoice,     // Let user decide
}

class ConflictResolution {
  final String conflictId;
  final Document localDocument;
  final Document remoteDocument;
  final ConflictResolutionStrategy strategy;
  final DateTime detectedAt;
  
  ConflictResolution({
    required this.conflictId,
    required this.localDocument,
    required this.remoteDocument,
    required this.strategy,
    required this.detectedAt,
  });
}
```

## Error Handling

### Retry Logic

All sync operations implement exponential backoff retry logic:

```dart
class RetryManager {
  static const List<Duration> _backoffDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
  ];
  
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation,
    {int maxRetries = 5}
  ) async {
    Exception? lastException;
    
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        if (attempt == maxRetries || !_isRetryableError(e)) {
          break;
        }
        
        await Future.delayed(_backoffDelays[attempt]);
      }
    }
    
    throw lastException!;
  }
  
  bool _isRetryableError(dynamic error) {
    if (error is NetworkException) return true;
    if (error is TimeoutException) return true;
    if (error is HttpException && error.statusCode >= 500) return true;
    return false;
  }
}
```

### Error Categories

1. **Network Errors**: Connection timeouts, DNS failures
2. **Authentication Errors**: Token expiration, invalid credentials
3. **Authorization Errors**: Insufficient permissions
4. **Validation Errors**: Invalid data format, missing fields
5. **Conflict Errors**: Version conflicts, concurrent modifications
6. **Storage Errors**: S3 upload failures, insufficient storage
7. **System Errors**: Internal server errors, service unavailable

### Error Recovery

```dart
class ErrorStateManager {
  Future<void> handleSyncError(String documentId, Exception error) async {
    final errorState = ErrorState(
      documentId: documentId,
      errorType: _categorizeError(error),
      errorMessage: error.toString(),
      occurredAt: DateTime.now(),
      retryCount: 0,
    );
    
    await _saveErrorState(errorState);
    
    // Determine recovery strategy
    switch (errorState.errorType) {
      case ErrorType.network:
        await _scheduleRetry(errorState);
        break;
      case ErrorType.authentication:
        await _refreshTokenAndRetry(errorState);
        break;
      case ErrorType.conflict:
        await _initiateConflictResolution(errorState);
        break;
      case ErrorType.validation:
        await _markForManualReview(errorState);
        break;
      default:
        await _logForInvestigation(errorState);
    }
  }
}
```

## Performance Optimization

### Caching Strategy

```dart
class SyncCache {
  static const Duration _cacheExpiry = Duration(hours: 1);
  final Map<String, CacheEntry> _cache = {};
  
  Future<Document?> getCachedDocument(String documentId) async {
    final entry = _cache[documentId];
    
    if (entry == null || entry.isExpired) {
      return null;
    }
    
    return entry.document;
  }
  
  void cacheDocument(Document document) {
    _cache[document.id.toString()] = CacheEntry(
      document: document,
      cachedAt: DateTime.now(),
    );
  }
  
  void invalidateCache(String documentId) {
    _cache.remove(documentId);
  }
}
```

### Batch Operations

```dart
class BatchOperationManager {
  static const int _maxBatchSize = 25;
  
  Future<List<BatchResult>> batchUploadDocuments(
    List<Document> documents
  ) async {
    final batches = _createBatches(documents, _maxBatchSize);
    final results = <BatchResult>[];
    
    for (final batch in batches) {
      final batchResults = await _executeBatch(batch);
      results.addAll(batchResults);
    }
    
    return results;
  }
  
  Future<List<BatchResult>> _executeBatch(List<Document> documents) async {
    final futures = documents.map((doc) => _uploadSingleDocument(doc));
    final results = await Future.wait(futures, eagerError: false);
    
    return results.map((result) {
      if (result.isSuccess) {
        return BatchResult.success(result.documentId);
      } else {
        return BatchResult.failure(result.documentId, result.error);
      }
    }).toList();
  }
}
```

## Monitoring and Analytics

### Performance Metrics

```dart
class PerformanceMonitor {
  Future<void> trackOperation(
    String operationType,
    Future<void> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    Exception? error;
    
    try {
      await operation();
    } catch (e) {
      error = e is Exception ? e : Exception(e.toString());
      rethrow;
    } finally {
      stopwatch.stop();
      
      await _recordMetric(PerformanceMetric(
        operationType: operationType,
        duration: stopwatch.elapsed,
        success: error == null,
        error: error?.toString(),
        timestamp: DateTime.now(),
      ));
    }
  }
}
```

### Sync Events

All sync operations generate events for monitoring:

```dart
enum SyncEventType {
  documentUploaded,
  documentDownloaded,
  documentUpdated,
  documentDeleted,
  fileUploaded,
  fileDownloaded,
  fileDeleted,
  conflictDetected,
  conflictResolved,
  errorOccurred,
  queueProcessed,
}

class SyncEvent {
  final SyncEventType type;
  final String? documentId;
  final String? fileId;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  
  SyncEvent({
    required this.type,
    this.documentId,
    this.fileId,
    required this.message,
    required this.timestamp,
    this.metadata,
  });
}
```

## Configuration

### Environment Configuration

```dart
class SyncConfiguration {
  static const int maxRetries = 5;
  static const Duration operationTimeout = Duration(minutes: 5);
  static const Duration fileUploadTimeout = Duration(minutes: 30);
  static const int maxConcurrentUploads = 3;
  static const int maxBatchSize = 25;
  static const Duration cacheExpiry = Duration(hours: 1);
  static const Duration subscriptionReconnectDelay = Duration(seconds: 5);
  
  // File size limits
  static const int maxFileSize = 100 * 1024 * 1024; // 100MB
  static const int multipartThreshold = 5 * 1024 * 1024; // 5MB
  
  // Queue settings
  static const int maxQueueSize = 1000;
  static const Duration queueProcessingInterval = Duration(minutes: 1);
}
```

### Feature Flags

```dart
class SyncFeatureFlags {
  static bool enableRealtimeSync = true;
  static bool enableBatchOperations = true;
  static bool enableOfflineQueue = true;
  static bool enableConflictResolution = true;
  static bool enablePerformanceMonitoring = true;
  static bool enableDetailedLogging = false;
}
```

## Testing

### Unit Tests

```dart
// Test document upload
test('should upload document successfully', () async {
  final document = createTestDocument();
  await documentSyncManager.uploadDocument(document);
  
  verify(() => mockAmplifyAPI.mutate(any())).called(1);
});

// Test version conflict detection
test('should detect version conflict', () async {
  final localDoc = createTestDocument(version: 1);
  final remoteDoc = createTestDocument(version: 2);
  
  when(() => mockDocumentSyncManager.downloadDocument(any()))
      .thenAnswer((_) async => remoteDoc);
  
  expect(
    () => documentSyncManager.updateDocument(localDoc),
    throwsA(isA<VersionConflictException>()),
  );
});
```

### Integration Tests

```dart
// Test end-to-end sync
testWidgets('should sync document end-to-end', (tester) async {
  // Create document locally
  final document = await createDocument();
  
  // Sync to cloud
  await cloudSyncService.syncDocument(document);
  
  // Verify document exists in cloud
  final cloudDoc = await documentSyncManager.downloadDocument(document.id!);
  expect(cloudDoc.title, equals(document.title));
});
```

## Best Practices

### Usage Guidelines

1. **Always handle errors**: Wrap sync operations in try-catch blocks
2. **Use batch operations**: For multiple documents, use batch uploads
3. **Monitor progress**: Listen to progress streams for user feedback
4. **Cache appropriately**: Use local cache to reduce API calls
5. **Handle conflicts**: Implement proper conflict resolution strategies
6. **Validate data**: Always validate data before sync operations
7. **Use retry logic**: Implement exponential backoff for transient errors
8. **Monitor performance**: Track sync operation metrics

### Common Pitfalls

1. **Not handling version conflicts**: Always check versions before updates
2. **Ignoring network errors**: Implement proper retry mechanisms
3. **Blocking UI**: Use async operations and progress indicators
4. **Memory leaks**: Properly dispose of streams and subscriptions
5. **Security issues**: Never log sensitive data or tokens
6. **Race conditions**: Use proper synchronization for concurrent operations

### Performance Tips

1. **Use pagination**: For large result sets, implement pagination
2. **Optimize queries**: Only fetch required fields
3. **Compress data**: Use compression for large text fields
4. **Parallel operations**: Use concurrent operations where safe
5. **Cache strategically**: Cache frequently accessed documents
6. **Monitor bandwidth**: Track and optimize data usage