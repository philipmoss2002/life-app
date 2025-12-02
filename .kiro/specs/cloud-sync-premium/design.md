# Design Document

## Overview

The Cloud Sync Premium feature transforms the Household Docs App from a local-only application into a multi-device cloud-enabled solution. This design maintains the existing local-first architecture while adding optional cloud synchronization for premium users. The system uses AWS services for authentication, storage, and synchronization, ensuring data security and privacy while providing seamless cross-device access.

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Mobile Device A                          │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Household Docs App                                     │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │ │
│  │  │   UI Layer   │  │  Sync Layer  │  │ Local Storage│ │ │
│  │  │              │  │              │  │   (SQLite)   │ │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS/TLS 1.3
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Cognito    │  │   DynamoDB   │  │      S3      │     │
│  │ (Auth/Users) │  │  (Metadata)  │  │   (Files)    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │  API Gateway │  │    Lambda    │                        │
│  │              │  │  (Sync Logic)│                        │
│  └──────────────┘  └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ HTTPS/TLS 1.3
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Mobile Device B                          │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Household Docs App                                     │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │ │
│  │  │   UI Layer   │  │  Sync Layer  │  │ Local Storage│ │ │
│  │  │              │  │              │  │   (SQLite)   │ │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Sync Strategy

The system uses a **last-write-wins with conflict detection** strategy:
- Each document has a `lastModified` timestamp and `version` number
- Changes are synced with timestamps to determine order
- Conflicts are detected when versions diverge
- Users are prompted to resolve conflicts manually

## Components and Interfaces

### 1. Authentication Service

**Purpose:** Manages user authentication and authorization using AWS Cognito.

**Interface:**
```dart
class AuthenticationService {
  Future<User> signUp(String email, String password);
  Future<User> signIn(String email, String password);
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<bool> isAuthenticated();
  Future<String> getAuthToken();
  Stream<AuthState> get authStateChanges;
}
```

**Responsibilities:**
- User registration and email verification
- Secure authentication with AWS Cognito
- Token management and refresh
- Session persistence

### 2. Subscription Service

**Purpose:** Manages premium subscriptions and payment processing.

**Interface:**
```dart
class SubscriptionService {
  Future<List<SubscriptionPlan>> getAvailablePlans();
  Future<PurchaseResult> purchaseSubscription(String planId);
  Future<SubscriptionStatus> getSubscriptionStatus();
  Future<void> cancelSubscription();
  Future<void> restorePurchases();
  Stream<SubscriptionStatus> get subscriptionChanges;
}
```

**Responsibilities:**
- Integration with in-app purchase platforms (Google Play, App Store)
- Subscription validation and verification
- Grace period and expiration handling
- Purchase restoration across devices

### 3. Cloud Sync Service

**Purpose:** Core synchronization engine that manages data flow between local and remote storage.

**Interface:**
```dart
class CloudSyncService {
  Future<void> initialize();
  Future<void> startSync();
  Future<void> stopSync();
  Future<void> syncNow();
  Future<SyncStatus> getSyncStatus();
  Future<void> resolveConflict(String documentId, ConflictResolution resolution);
  Stream<SyncEvent> get syncEvents;
}
```

**Responsibilities:**
- Orchestrates synchronization between local and remote
- Manages sync queue and retry logic
- Detects and reports conflicts
- Handles network connectivity changes

### 4. Document Sync Manager

**Purpose:** Handles synchronization of document metadata.

**Interface:**
```dart
class DocumentSyncManager {
  Future<void> uploadDocument(Document document);
  Future<void> downloadDocument(String documentId);
  Future<void> updateDocument(Document document);
  Future<void> deleteDocument(String documentId);
  Future<List<Document>> fetchAllDocuments();
  Future<SyncState> getDocumentSyncState(String documentId);
}
```

**Responsibilities:**
- CRUD operations for documents in DynamoDB
- Version tracking and conflict detection
- Metadata synchronization
- Batch operations for efficiency

### 5. File Sync Manager

**Purpose:** Handles synchronization of file attachments to/from S3.

**Interface:**
```dart
class FileSyncManager {
  Future<void> uploadFile(String filePath, String documentId);
  Future<String> downloadFile(String fileId, String documentId);
  Future<void> deleteFile(String fileId);
  Future<UploadProgress> getUploadProgress(String fileId);
  Stream<DownloadProgress> downloadFileWithProgress(String fileId);
}
```

**Responsibilities:**
- File upload to S3 with multipart for large files
- File download with caching
- Progress tracking for uploads/downloads
- Automatic retry on failure

### 6. Conflict Resolution Service

**Purpose:** Detects and helps resolve synchronization conflicts.

**Interface:**
```dart
class ConflictResolutionService {
  Future<List<Conflict>> getActiveConflicts();
  Future<void> resolveConflict(Conflict conflict, ConflictResolution resolution);
  Future<Document> mergeDocuments(Document local, Document remote);
  Stream<Conflict> get conflictStream;
}
```

**Responsibilities:**
- Conflict detection based on version vectors
- Presenting conflict options to users
- Applying user-selected resolutions
- Automatic merge for non-conflicting fields

### 7. Storage Manager

**Purpose:** Tracks and manages cloud storage usage.

**Interface:**
```dart
class StorageManager {
  Future<StorageInfo> getStorageInfo();
  Future<void> calculateUsage();
  Future<bool> hasAvailableSpace(int bytes);
  Future<void> cleanupDeletedFiles();
  Stream<StorageInfo> get storageUpdates;
}
```

**Responsibilities:**
- Calculate total storage used
- Track quota limits
- Warn users approaching limits
- Cleanup deleted files

## Data Models

### User Model
```dart
class User {
  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final SubscriptionStatus subscriptionStatus;
  final List<Device> devices;
}
```

### Document Model (Extended)
```dart
class Document {
  final String id;
  final String userId;
  final String title;
  final String category;
  final List<String> filePaths;
  final DateTime? renewalDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime lastModified;
  final int version;
  final SyncState syncState;
  final String? conflictId;
}
```

### FileAttachment Model (Extended)
```dart
class FileAttachment {
  final String id;
  final String documentId;
  final String filePath;
  final String fileName;
  final String? label;
  final int fileSize;
  final String s3Key;
  final String? localPath;
  final DateTime addedAt;
  final SyncState syncState;
}
```

### SyncState Enum
```dart
enum SyncState {
  synced,      // Fully synchronized
  pending,     // Changes waiting to sync
  syncing,     // Currently synchronizing
  conflict,    // Conflict detected
  error,       // Sync error occurred
  notSynced    // Not yet synchronized
}
```

### Conflict Model
```dart
class Conflict {
  final String id;
  final String documentId;
  final Document localVersion;
  final Document remoteVersion;
  final DateTime detectedAt;
  final ConflictType type;
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Authentication Token Validity
*For any* authenticated user session, the authentication token should remain valid until expiration or explicit sign-out, and all API requests with a valid token should be authorized.
**Validates: Requirements 1.3, 1.4**

### Property 2: Subscription Access Control
*For any* user with an active subscription, cloud sync features should be enabled, and for any user without an active subscription, cloud sync features should be disabled.
**Validates: Requirements 2.3, 2.4**

### Property 3: Document Sync Consistency
*For any* document modified on one device, after successful synchronization, the same document on all other devices should reflect the changes within the sync interval.
**Validates: Requirements 3.2, 3.5**

### Property 4: File Upload Integrity
*For any* file uploaded to S3, downloading the file should produce a byte-for-byte identical copy of the original file.
**Validates: Requirements 4.1, 4.2**

### Property 5: Offline Queue Persistence
*For any* changes made while offline, all changes should be preserved in the sync queue and successfully synchronized when connectivity is restored.
**Validates: Requirements 5.2, 5.3**

### Property 6: Conflict Detection
*For any* document modified on two different devices with divergent versions, the system should detect the conflict and preserve both versions.
**Validates: Requirements 6.1, 6.2**

### Property 7: Encryption in Transit
*For any* data transmitted between the app and AWS services, the data should be encrypted using TLS 1.3.
**Validates: Requirements 7.1**

### Property 8: Encryption at Rest
*For any* data stored in DynamoDB or S3, the data should be encrypted using AES-256.
**Validates: Requirements 7.2**

### Property 9: Sync Status Accuracy
*For any* document, the displayed sync status should accurately reflect the current synchronization state of that document.
**Validates: Requirements 8.1, 8.2, 8.3**

### Property 10: Storage Quota Enforcement
*For any* user approaching or exceeding their storage quota, the system should prevent new uploads and notify the user.
**Validates: Requirements 9.2, 9.3**

### Property 11: Device Registration
*For any* device that signs in to a user account, the device should be registered and appear in the user's device list.
**Validates: Requirements 10.1, 10.2**

### Property 12: Wi-Fi Only Sync Compliance
*For any* user with Wi-Fi only mode enabled, synchronization should only occur when connected to Wi-Fi, not cellular data.
**Validates: Requirements 11.1**

### Property 13: Migration Completeness
*For any* user upgrading to premium, all existing local documents should be successfully migrated to cloud storage or reported as failed.
**Validates: Requirements 12.2, 12.4**

## Error Handling

### Network Errors
- **Retry Strategy:** Exponential backoff with jitter (1s, 2s, 4s, 8s, 16s max)
- **Max Retries:** 5 attempts before marking as error
- **User Notification:** Show error indicator after 3 failed attempts

### Authentication Errors
- **Token Expiration:** Automatically refresh token if refresh token is valid
- **Invalid Credentials:** Prompt user to sign in again
- **Network Timeout:** Retry with exponential backoff

### Conflict Errors
- **Detection:** Compare version numbers and timestamps
- **Resolution:** Present both versions to user for manual selection
- **Fallback:** If user doesn't resolve within 7 days, keep most recent version

### Storage Errors
- **Quota Exceeded:** Block new uploads, notify user, offer upgrade
- **S3 Upload Failure:** Retry with exponential backoff, keep in queue
- **Corruption:** Verify checksums, re-upload if mismatch detected

## Testing Strategy

### Unit Tests
- Authentication service token management
- Subscription status validation
- Sync queue operations
- Conflict detection logic
- Storage calculation accuracy

### Integration Tests
- End-to-end document synchronization
- File upload and download flows
- Conflict resolution workflows
- Offline-to-online transitions
- Multi-device synchronization

### Property-Based Tests
- Test framework: Use `faker` for Dart to generate random test data
- Minimum iterations: 100 runs per property test
- Each property test must reference its corresponding correctness property

## Security Considerations

### Data Protection
- All data encrypted in transit (TLS 1.3)
- All data encrypted at rest (AES-256)
- User data isolated by Cognito user ID
- S3 bucket policies restrict access to authenticated users only

### Authentication Security
- Password requirements: minimum 8 characters, mixed case, numbers
- JWT tokens with 1-hour expiration
- Refresh tokens with 30-day expiration
- Multi-factor authentication support (future enhancement)

### Privacy
- No analytics or tracking of document content
- User data deleted within 30 days of account deletion
- Compliance with GDPR and CCPA
- Privacy policy updated to reflect cloud storage

## Performance Considerations

### Sync Performance
- Batch document metadata updates (max 25 per request)
- Parallel file uploads (max 3 concurrent)
- Delta sync: only send changed fields
- Compression for large text fields

### Caching Strategy
- Cache document metadata locally
- Cache file thumbnails
- Cache sync status for 30 seconds
- Invalidate cache on explicit sync

### Bandwidth Optimization
- Compress files before upload
- Use multipart upload for files > 5MB
- Download files on-demand, not automatically
- Thumbnail generation on server side

## Deployment Strategy

### Phased Rollout
1. **Phase 1:** Beta testing with 100 users
2. **Phase 2:** Limited release to 10% of users
3. **Phase 3:** Full release to all users
4. **Phase 4:** Monitor and optimize

### Feature Flags
- `cloud_sync_enabled`: Master switch for cloud sync
- `conflict_resolution_v2`: New conflict resolution algorithm
- `batch_sync_enabled`: Batch synchronization feature
- `storage_optimization`: Storage optimization features

### Monitoring
- Sync success/failure rates
- Average sync latency
- Storage usage trends
- Authentication failure rates
- Conflict occurrence frequency

## Future Enhancements

1. **Selective Sync:** Choose which documents to sync
2. **Shared Documents:** Share documents with family members
3. **Version History:** View and restore previous versions
4. **Advanced Search:** Search across all synced documents
5. **Backup and Export:** Export all data as ZIP file
6. **Family Plans:** Multiple users under one subscription
