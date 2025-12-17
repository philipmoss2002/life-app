# Design Document

## Overview

This design addresses the critical gap between the existing cloud sync service architecture and its actual implementation. While the high-level CloudSyncService orchestration is well-designed, the underlying DocumentSyncManager and FileSyncManager contain placeholder implementations that simulate operations rather than performing real AWS/Amplify operations. This design provides the concrete implementation details needed to make cloud synchronization actually work.

## Architecture

### Current vs Target Architecture

**Current State (Broken):**
```
CloudSyncService (✅ Working)
    ↓
DocumentSyncManager (❌ Placeholder)
    ↓
_putItemToDynamoDB() → Future.delayed() // Simulation!
```

**Target State (Fixed):**
```
CloudSyncService (✅ Working)
    ↓
DocumentSyncManager (✅ Real Implementation)
    ↓
Amplify.API.mutate() → DynamoDB // Real operations!
```

### AWS Amplify Integration

The implementation will use the existing Amplify configuration but replace placeholder methods with actual Amplify API calls:

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              CloudSyncService                           ││
│  │  ┌─────────────────┐  ┌─────────────────────────────────┐││
│  │  │DocumentSyncMgr  │  │    FileSyncManager              │││
│  │  │                 │  │                                 │││
│  │  │ ✅ Real Amplify │  │ ✅ Real Amplify Storage        │││
│  │  │    API calls    │  │    operations                   │││
│  │  └─────────────────┘  └─────────────────────────────────┘││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
                              │
                              │ GraphQL/REST + S3
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │  API Gateway │  │   DynamoDB   │  │      S3      │     │
│  │   (GraphQL)  │  │  (Documents) │  │   (Files)    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │   Cognito    │  │    Lambda    │                        │
│  │    (Auth)    │  │ (Resolvers)  │                        │
│  └──────────────┘  └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. GraphQL Schema Definition

**Purpose:** Define the data structure and operations for document synchronization.

**Schema:**
```graphql
type Document @model @auth(rules: [{allow: owner}]) {
  id: ID!
  userId: String! @index(name: "byUserId")
  title: String!
  category: String!
  filePaths: [String!]!
  renewalDate: AWSDateTime
  notes: String
  createdAt: AWSDateTime!
  lastModified: AWSDateTime!
  version: Int!
  syncState: String!
  conflictId: String
  deleted: Boolean
  deletedAt: AWSDateTime
}

type FileAttachment @model @auth(rules: [{allow: owner}]) {
  id: ID!
  documentId: ID! @index(name: "byDocumentId")
  filePath: String!
  fileName: String!
  label: String
  fileSize: Int!
  s3Key: String!
  addedAt: AWSDateTime!
  syncState: String!
}
```

### 2. Enhanced DocumentSyncManager

**Purpose:** Replace placeholder implementations with real Amplify API operations.

**Key Methods Implementation:**

```dart
class DocumentSyncManager {
  // Real DynamoDB operations using Amplify API
  Future<void> uploadDocument(Document document) async {
    final request = ModelMutations.create(document.toAmplifyModel());
    final response = await Amplify.API.mutate(request: request).response;
    
    if (response.hasErrors) {
      throw Exception('Upload failed: ${response.errors}');
    }
  }

  Future<Document> downloadDocument(String documentId) async {
    final request = ModelQueries.get(Document.classType, documentId);
    final response = await Amplify.API.query(request: request).response;
    
    if (response.data == null) {
      throw Exception('Document not found: $documentId');
    }
    
    return Document.fromAmplifyModel(response.data!);
  }

  Future<void> updateDocument(Document document) async {
    // Check for version conflicts first
    final remote = await downloadDocument(document.id.toString());
    if (remote.version != document.version) {
      throw VersionConflictException(
        message: 'Version conflict',
        localDocument: document,
        remoteDocument: remote,
      );
    }

    final updatedDoc = document.incrementVersion();
    final request = ModelMutations.update(updatedDoc.toAmplifyModel());
    final response = await Amplify.API.mutate(request: request).response;
    
    if (response.hasErrors) {
      throw Exception('Update failed: ${response.errors}');
    }
  }
}
```

### 3. Enhanced FileSyncManager

**Purpose:** Replace placeholder implementations with real Amplify Storage operations.

**Key Methods Implementation:**

```dart
class FileSyncManager {
  Future<String> uploadFile(String filePath, String documentId) async {
    final file = File(filePath);
    final fileName = path.basename(filePath);
    final s3Key = 'documents/$documentId/${DateTime.now().millisecondsSinceEpoch}-$fileName';
    
    final uploadTask = Amplify.Storage.uploadFile(
      localFile: AWSFile.fromPath(filePath),
      key: s3Key,
      onProgress: (progress) {
        _progressController.add(UploadProgress(
          s3Key: s3Key,
          bytesTransferred: progress.transferredBytes,
          totalBytes: progress.totalBytes,
        ));
      },
    );
    
    final result = await uploadTask.result;
    return result.uploadedItem.key;
  }

  Future<String> downloadFile(String s3Key, String documentId) async {
    final localDir = await getApplicationDocumentsDirectory();
    final localPath = path.join(localDir.path, 'downloads', s3Key);
    
    final downloadTask = Amplify.Storage.downloadFile(
      key: s3Key,
      localFile: AWSFile.fromPath(localPath),
      onProgress: (progress) {
        _progressController.add(DownloadProgress(
          s3Key: s3Key,
          bytesTransferred: progress.transferredBytes,
          totalBytes: progress.totalBytes,
        ));
      },
    );
    
    await downloadTask.result;
    return localPath;
  }
}
```

### 4. Real-time Synchronization

**Purpose:** Implement GraphQL subscriptions for real-time updates.

**Implementation:**
```dart
class RealtimeSyncService {
  StreamSubscription<GraphQLResponse<Document>>? _subscription;

  Future<void> startRealtimeSync(String userId) async {
    final subscriptionRequest = ModelSubscriptions.onCreate(Document.classType)
        .where(Document.USERID.eq(userId));
    
    _subscription = Amplify.API.subscribe(
      request: subscriptionRequest,
      onEstablished: () => safePrint('Subscription established'),
    ).listen(
      (event) => _handleRealtimeUpdate(event.data),
      onError: (error) => safePrint('Subscription error: $error'),
    );
  }

  void _handleRealtimeUpdate(Document? document) async {
    if (document != null) {
      // Update local database
      await _databaseService.updateDocument(document);
      
      // Notify UI
      _syncEventController.add(SyncEvent(
        type: SyncEventType.documentUpdated,
        documentId: document.id.toString(),
        message: 'Document updated from another device',
      ));
    }
  }
}
```

## Data Models

### Amplify Model Extensions

**Document Model for Amplify:**
```dart
extension DocumentAmplify on Document {
  // Convert to Amplify model
  AmplifyDocument toAmplifyModel() {
    return AmplifyDocument(
      id: id?.toString(),
      userId: userId ?? '',
      title: title,
      category: category,
      filePaths: filePaths,
      renewalDate: renewalDate?.toUtc(),
      notes: notes,
      createdAt: createdAt.toUtc(),
      lastModified: lastModified.toUtc(),
      version: version,
      syncState: syncState.name,
      conflictId: conflictId,
      deleted: false,
    );
  }

  // Create from Amplify model
  static Document fromAmplifyModel(AmplifyDocument model) {
    return Document(
      id: int.tryParse(model.id ?? ''),
      userId: model.userId,
      title: model.title,
      category: model.category,
      filePaths: model.filePaths ?? [],
      renewalDate: model.renewalDate?.toLocal(),
      notes: model.notes,
      createdAt: model.createdAt.toLocal(),
      lastModified: model.lastModified.toLocal(),
      version: model.version,
      syncState: SyncState.values.firstWhere(
        (state) => state.name == model.syncState,
        orElse: () => SyncState.notSynced,
      ),
      conflictId: model.conflictId,
    );
  }
}
```

### Progress Tracking Models

```dart
class UploadProgress {
  final String s3Key;
  final int bytesTransferred;
  final int totalBytes;
  final double percentage;

  UploadProgress({
    required this.s3Key,
    required this.bytesTransferred,
    required this.totalBytes,
  }) : percentage = totalBytes > 0 ? bytesTransferred / totalBytes : 0.0;
}

class DownloadProgress {
  final String s3Key;
  final int bytesTransferred;
  final int totalBytes;
  final double percentage;

  DownloadProgress({
    required this.s3Key,
    required this.bytesTransferred,
    required this.totalBytes,
  }) : percentage = totalBytes > 0 ? bytesTransferred / totalBytes : 0.0;
}
```
## Corr
ectness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Document Upload Persistence
*For any* valid document, uploading it to DynamoDB should result in the document being retrievable with identical metadata.
**Validates: Requirements 1.1, 1.2**

### Property 2: Document Update Consistency
*For any* existing document, updating it should result in the new version being stored in DynamoDB with an incremented version number.
**Validates: Requirements 1.3**

### Property 3: Document Soft Delete
*For any* document, deleting it should mark it as deleted in DynamoDB without removing the record.
**Validates: Requirements 1.4**

### Property 4: User Document Isolation
*For any* user, fetching all documents should return only documents belonging to that user and no deleted documents.
**Validates: Requirements 1.5**

### Property 5: File Upload Round Trip
*For any* file, uploading it to S3 and then downloading it should produce a byte-for-byte identical file.
**Validates: Requirements 2.1, 2.2**

### Property 6: File Deletion Completeness
*For any* file in S3, deleting it should make the file no longer accessible via download operations.
**Validates: Requirements 2.3**

### Property 7: Large File Multipart Upload
*For any* file larger than 5MB, uploading should use multipart upload and provide progress tracking.
**Validates: Requirements 2.4**

### Property 8: File Download Progress
*For any* file download, progress events should be emitted and the file should be cached locally after completion.
**Validates: Requirements 2.5**

### Property 9: GraphQL Operation Routing
*For any* CRUD operation, the system should use the appropriate GraphQL mutation or query rather than direct API calls.
**Validates: Requirements 3.2, 3.3**

### Property 10: Real-time Update Delivery
*For any* document modification, other devices should receive real-time notifications via GraphQL subscriptions.
**Validates: Requirements 3.4, 6.1**

### Property 11: Authorization Enforcement
*For any* GraphQL operation, only the document owner should be able to access or modify their documents.
**Validates: Requirements 3.5**

### Property 12: Network Error Retry
*For any* operation that fails due to network errors, it should be retried with exponential backoff up to 5 times.
**Validates: Requirements 4.1**

### Property 13: Authentication Token Refresh
*For any* operation that fails due to expired tokens, the tokens should be refreshed and the operation retried.
**Validates: Requirements 4.2**

### Property 14: Version Conflict Detection
*For any* document update where the local version differs from the remote version, a VersionConflictException should be thrown.
**Validates: Requirements 4.3**

### Property 15: Error State Marking
*For any* operation that exhausts all retries, the document should be marked with error sync state.
**Validates: Requirements 4.5**

### Property 16: Batch Upload Efficiency
*For any* set of up to 25 documents, batch upload should complete faster than individual uploads.
**Validates: Requirements 5.1**

### Property 17: Batch Operation Partial Failure Handling
*For any* batch operation where some items fail, the successful items should still be processed.
**Validates: Requirements 5.4**

### Property 18: Batch Progress Tracking
*For any* batch operation, progress should be reported as individual items complete.
**Validates: Requirements 5.5**

### Property 19: Real-time Local Update
*For any* real-time notification received, the local database should be updated with the remote changes.
**Validates: Requirements 6.2**

### Property 20: Conflict Notification
*For any* conflict detected during sync, the user should be notified immediately.
**Validates: Requirements 6.3**

### Property 21: Background Notification Queuing
*For any* notification received while the app is in background, it should be queued and processed when the app becomes active.
**Validates: Requirements 6.4**

### Property 22: Authentication Token Validity
*For any* sync operation, valid Cognito authentication tokens should be included in the request.
**Validates: Requirements 7.1**

### Property 23: Sign-out Sync Termination
*For any* user sign-out event, all ongoing sync operations should be stopped immediately.
**Validates: Requirements 7.4**

### Property 24: API Authorization Headers
*For any* API call, proper authorization headers should be included.
**Validates: Requirements 7.5**

### Property 25: Document Validation
*For any* document upload, all required fields should be validated before the operation proceeds.
**Validates: Requirements 8.1**

### Property 26: Data Structure Validation
*For any* document download, the received data should be validated against the expected structure.
**Validates: Requirements 8.2**

### Property 27: File Integrity Verification
*For any* file upload, the integrity should be verified using checksums after upload completion.
**Validates: Requirements 8.3**

### Property 28: Invalid Data Rejection
*For any* data that fails validation, the operation should be rejected and an error logged.
**Validates: Requirements 8.4**

### Property 29: Input Sanitization
*For any* user input, it should be sanitized before being stored in the cloud.
**Validates: Requirements 8.5**

### Property 30: Performance Metrics Collection
*For any* sync operation, latency and success rate metrics should be tracked.
**Validates: Requirements 9.1**

### Property 31: Bandwidth Usage Tracking
*For any* file operation, bandwidth usage should be measured and tracked.
**Validates: Requirements 9.4**

### Property 32: Offline Queue Processing Order
*For any* set of queued operations, they should be processed in the order they were queued when connectivity is restored.
**Validates: Requirements 10.1**

### Property 33: Offline Conflict Handling
*For any* operations queued while offline, conflicts should be detected and handled when processing the queue.
**Validates: Requirements 10.2**

### Property 34: Operation Consolidation
*For any* multiple operations on the same document in the queue, they should be consolidated efficiently.
**Validates: Requirements 10.3**

### Property 35: Queue Persistence on Failure
*For any* sync queue processing failure, the queue should be preserved for later retry.
**Validates: Requirements 10.4**

## Error Handling

### Network Error Handling
- **Exponential Backoff:** 1s, 2s, 4s, 8s, 16s with jitter
- **Max Retries:** 5 attempts before marking as error
- **Connection Timeout:** 30 seconds for API calls, 5 minutes for file uploads
- **Retry Conditions:** Network unreachable, timeout, 5xx server errors

### Authentication Error Handling
- **Token Expiration:** Automatic refresh using refresh token
- **Invalid Token:** Clear tokens and prompt for re-authentication
- **Refresh Failure:** Redirect to sign-in screen
- **Rate Limiting:** Exponential backoff for auth requests

### Conflict Resolution
- **Detection:** Compare version numbers and lastModified timestamps
- **Preservation:** Keep both local and remote versions
- **User Choice:** Present options to keep local, remote, or merge
- **Timeout:** Auto-resolve to most recent if no user action in 7 days

### Data Validation Errors
- **Required Fields:** Reject operations missing required fields
- **Type Validation:** Ensure data types match schema
- **Size Limits:** Enforce file size and text length limits
- **Sanitization:** Clean user input to prevent injection attacks

## Testing Strategy

### Unit Tests
- Document CRUD operations with real Amplify API
- File upload/download with real S3 operations
- Authentication token management
- Error handling and retry logic
- Batch operation efficiency

### Integration Tests
- End-to-end document synchronization
- Real-time updates via GraphQL subscriptions
- Offline-to-online transition
- Multi-device synchronization
- Conflict resolution workflows

### Property-Based Tests
- Test framework: Use `test` package with custom generators for Dart
- Minimum iterations: 100 runs per property test
- Each property test must reference its corresponding correctness property using format: **Feature: cloud-sync-implementation-fix, Property X: [property text]**

## Performance Considerations

### API Optimization
- **Batch Operations:** Use DynamoDB batch operations for multiple documents
- **Pagination:** Implement cursor-based pagination for large queries
- **Caching:** Cache frequently accessed documents locally
- **Compression:** Compress large text fields before storage

### File Transfer Optimization
- **Multipart Upload:** Use for files > 5MB
- **Parallel Transfers:** Max 3 concurrent file operations
- **Progressive Download:** Download files on-demand
- **Thumbnail Generation:** Server-side thumbnail creation

### Real-time Efficiency
- **Subscription Filtering:** Only subscribe to user's own documents
- **Batch Notifications:** Group multiple changes into single notifications
- **Background Processing:** Queue notifications when app is inactive
- **Connection Management:** Automatic reconnection with exponential backoff

## Security Implementation

### Data Encryption
- **In Transit:** TLS 1.3 for all API communications
- **At Rest:** AES-256 encryption for DynamoDB and S3
- **Key Management:** AWS KMS for encryption key management
- **Client-side:** No sensitive data stored in plain text locally

### Access Control
- **Row-level Security:** Cognito user ID isolation in DynamoDB
- **S3 Bucket Policies:** Restrict access to authenticated users only
- **API Gateway:** JWT token validation on all endpoints
- **GraphQL Authorization:** Owner-based access rules

### Input Validation
- **SQL Injection Prevention:** Parameterized queries only
- **XSS Prevention:** Sanitize all text input
- **File Type Validation:** Whitelist allowed file extensions
- **Size Limits:** Enforce maximum file and text sizes

## Deployment Strategy

### Implementation Phases
1. **Phase 1:** Replace DocumentSyncManager placeholder methods
2. **Phase 2:** Replace FileSyncManager placeholder methods  
3. **Phase 3:** Implement real-time synchronization
4. **Phase 4:** Add batch operations and performance optimizations

### Testing Approach
- **Unit Tests First:** Ensure each method works with real AWS services
- **Integration Testing:** Test complete sync workflows
- **Load Testing:** Verify performance with multiple documents
- **User Acceptance:** Beta test with existing premium users

### Rollback Plan
- **Feature Flags:** Control new implementation rollout
- **Monitoring:** Track sync success rates and error rates
- **Automatic Rollback:** Revert if error rates exceed 5%
- **Manual Override:** Admin controls to disable new implementation

### Success Metrics
- **Sync Success Rate:** > 99% for document operations
- **File Upload Success:** > 95% for file operations
- **Real-time Latency:** < 2 seconds for notifications
- **User Satisfaction:** No increase in support tickets