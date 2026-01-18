# Architecture Documentation

## Overview

The Household Documents App follows clean architecture principles with clear separation of concerns across layers. This document provides detailed information about the application architecture, design patterns, and implementation details.

---

## Architecture Layers

### 1. Presentation Layer (UI)

**Location:** `lib/screens/`, `lib/widgets/`

**Responsibility:** Display data and handle user interactions

**Components:**
- Screens (full-page views)
- Widgets (reusable UI components)
- State management (using StatefulWidget and setState)

**Key Screens:**
- `SignInScreen` - User authentication
- `SignUpScreen` - New user registration
- `DocumentListScreen` - Main document list with sync indicators
- `DocumentDetailScreen` - Document view/edit with file management
- `SettingsScreen` - Account settings and app info
- `LogsViewerScreen` - Application logs for debugging

**Design Principles:**
- Screens should be thin, delegating business logic to services
- Widgets should be reusable and composable
- State should be managed locally when possible
- Services injected via constructors for testability

---

### 2. Business Logic Layer (Services)

**Location:** `lib/services/`

**Responsibility:** Implement business rules and coordinate operations

**Services:**

#### AuthenticationService
- **Purpose:** User authentication and Identity Pool management
- **Pattern:** Singleton
- **Key Methods:**
  - `signUp(email, password)` - Create new user account
  - `signIn(email, password)` - Authenticate user
  - `signOut()` - Sign out and clear credentials
  - `getIdentityPoolId()` - Retrieve and cache Identity Pool ID
  - `isAuthenticated()` - Check authentication status
- **Dependencies:** AWS Amplify Auth
- **State:** Authentication state stream for UI reactivity

#### FileService
- **Purpose:** File operations with AWS S3
- **Pattern:** Singleton
- **Key Methods:**
  - `generateS3Path(identityPoolId, syncId, fileName)` - Generate S3 key
  - `uploadFile(localPath, s3Key)` - Upload file to S3
  - `downloadFile(s3Key, localPath)` - Download file from S3
  - `deleteFile(s3Key)` - Delete file from S3
  - `deleteDocumentFiles(identityPoolId, syncId)` - Delete all files for document
  - `validateS3KeyOwnership(s3Key, identityPoolId)` - Verify ownership
- **Dependencies:** AWS Amplify Storage, AuthenticationService
- **Features:** Retry logic, progress tracking, ownership validation

#### SyncService
- **Purpose:** Coordinate synchronization between local and cloud
- **Pattern:** Singleton
- **Key Methods:**
  - `performSync()` - Execute full sync operation
  - `uploadDocumentFiles(document)` - Upload specific document
  - `downloadDocumentFiles(document)` - Download specific document
  - `isSyncing` - Check if sync is in progress
- **Dependencies:** DocumentRepository, FileService, AuthenticationService
- **Features:** Automatic triggers, debouncing, sync state management

#### LogService
- **Purpose:** Application logging and debugging
- **Pattern:** Singleton
- **Key Methods:**
  - `log(message, level)` - Log message with level
  - `logError(message, error, stackTrace)` - Log error with details
  - `getRecentLogs(limit)` - Retrieve recent logs
  - `getLogsByLevel(level)` - Filter logs by level
  - `clearLogs()` - Remove all logs
  - `exportLogs()` - Generate shareable log string
- **Dependencies:** DatabaseService
- **Features:** SQLite storage, log rotation, sensitive data exclusion

#### ConnectivityService
- **Purpose:** Network connectivity monitoring
- **Pattern:** Singleton
- **Key Methods:**
  - `hasConnectivity()` - Check current connectivity status
  - `connectivityStream` - Stream of connectivity changes
- **Dependencies:** connectivity_plus package
- **Features:** Real-time connectivity monitoring, automatic sync triggers

---

### 3. Data Access Layer (Repositories)

**Location:** `lib/repositories/`

**Responsibility:** Abstract data storage and retrieval

**Repositories:**

#### DocumentRepository
- **Purpose:** Manage document data in SQLite
- **Pattern:** Singleton
- **Key Methods:**
  - `createDocument(document)` - Insert new document
  - `getDocument(syncId)` - Retrieve document by ID
  - `getAllDocuments()` - Retrieve all documents
  - `updateDocument(document)` - Update existing document
  - `deleteDocument(syncId)` - Delete document and files
  - `addFileAttachment(syncId, file)` - Add file to document
  - `updateFileS3Key(syncId, fileName, s3Key)` - Update S3 key
  - `updateSyncState(syncId, state)` - Update sync state
  - `getDocumentsBySyncState(state)` - Query by sync state
- **Dependencies:** DatabaseService
- **Features:** Transaction support, cascade deletes, foreign keys

---

### 4. Data Layer (Models)

**Location:** `lib/models/`

**Responsibility:** Define data structures and serialization

**Models:**

#### Document
```dart
class Document {
  final String syncId;           // UUID, primary key
  final String title;            // Document title
  final String description;      // Document description
  final List<String> labels;     // Document labels/tags
  final DateTime createdAt;      // Creation timestamp
  final DateTime updatedAt;      // Last update timestamp
  final SyncState syncState;     // Current sync state
  final List<FileAttachment> files; // Attached files
}
```

**Methods:**
- `toJson()` - Serialize to JSON
- `fromJson(json)` - Deserialize from JSON
- `copyWith()` - Create modified copy

#### FileAttachment
```dart
class FileAttachment {
  final String fileName;         // Original file name
  final String? localPath;       // Local file path
  final String? s3Key;           // S3 object key
  final int? fileSize;           // File size in bytes
  final DateTime addedAt;        // Attachment timestamp
}
```

**Methods:**
- `toJson()` - Serialize to JSON
- `fromJson(json)` - Deserialize from JSON
- `copyWith()` - Create modified copy

#### SyncState (Enum)
```dart
enum SyncState {
  synced,           // Fully synced with cloud
  pendingUpload,    // Waiting to upload
  pendingDownload,  // Waiting to download
  uploading,        // Currently uploading
  downloading,      // Currently downloading
  error             // Sync error
}
```

#### SyncResult
```dart
class SyncResult {
  final int uploadedCount;       // Number of documents uploaded
  final int downloadedCount;     // Number of documents downloaded
  final int failedCount;         // Number of failed operations
  final List<String> errors;     // Error messages
  final Duration duration;       // Sync duration
}
```

#### LogEntry
```dart
class LogEntry {
  final int id;                  // Auto-increment ID
  final DateTime timestamp;      // Log timestamp
  final String level;            // Log level (info, warning, error)
  final String message;          // Log message
  final String? errorDetails;    // Error details (if error)
  final String? stackTrace;      // Stack trace (if error)
}
```

---

## Design Patterns

### 1. Singleton Pattern

**Used For:** Services and repositories

**Rationale:** 
- Ensures single instance across app
- Simplifies dependency management
- Prevents resource duplication

**Implementation:**
```dart
class AuthenticationService {
  static final AuthenticationService _instance = AuthenticationService._internal();
  factory AuthenticationService() => _instance;
  AuthenticationService._internal();
}
```

### 2. Repository Pattern

**Used For:** Data access abstraction

**Rationale:**
- Separates data access from business logic
- Enables easy testing with mocks
- Allows data source changes without affecting business logic

**Implementation:**
```dart
class DocumentRepository {
  Future<Document> getDocument(String syncId) async {
    // Abstract database access
  }
}
```

### 3. Service Layer Pattern

**Used For:** Business logic encapsulation

**Rationale:**
- Centralizes business rules
- Coordinates multiple repositories
- Provides clear API for UI layer

**Implementation:**
```dart
class SyncService {
  Future<SyncResult> performSync() async {
    // Coordinate sync operations
  }
}
```

### 4. Observer Pattern

**Used For:** State change notifications

**Rationale:**
- Enables reactive UI updates
- Decouples state producers from consumers
- Supports multiple listeners

**Implementation:**
```dart
class AuthenticationService {
  final StreamController<AuthState> _authStateController = StreamController.broadcast();
  Stream<AuthState> get authStateStream => _authStateController.stream;
}
```

---

## Data Flow

### Document Creation Flow

```
User Input (UI)
    ↓
DocumentDetailScreen
    ↓
DocumentRepository.createDocument()
    ↓
DatabaseService (SQLite)
    ↓
SyncService.performSync() [triggered]
    ↓
FileService.uploadFile()
    ↓
AWS S3
    ↓
DocumentRepository.updateSyncState()
    ↓
UI Update (sync indicator)
```

### Authentication Flow

```
User Input (UI)
    ↓
SignInScreen
    ↓
AuthenticationService.signIn()
    ↓
AWS Cognito User Pool
    ↓
AuthenticationService.getIdentityPoolId()
    ↓
AWS Cognito Identity Pool
    ↓
Cache Identity Pool ID
    ↓
Emit Auth State Change
    ↓
Navigate to DocumentListScreen
```

### Sync Flow

```
Trigger (app launch, connectivity, manual)
    ↓
SyncService.performSync()
    ↓
Query documents with pendingUpload state
    ↓
For each document:
    ↓
    FileService.uploadFile()
    ↓
    Update S3 key in database
    ↓
    Update sync state to synced
    ↓
Query documents with pendingDownload state
    ↓
For each document:
    ↓
    FileService.downloadFile()
    ↓
    Update local path in database
    ↓
    Update sync state to synced
    ↓
Return SyncResult
    ↓
UI Update (sync indicators)
```

---

## State Management

### Authentication State

**Managed By:** AuthenticationService

**State Model:**
```dart
class AuthState {
  final bool isAuthenticated;
  final String? userEmail;
  final String? identityPoolId;
  final DateTime? lastAuthTime;
}
```

**State Changes:**
- Sign in → isAuthenticated = true
- Sign out → isAuthenticated = false
- Token refresh → lastAuthTime updated

**Consumers:**
- Main app (routing)
- Settings screen (user info)
- File service (Identity Pool ID)

### Sync State

**Managed By:** SyncService

**State Model:**
```dart
enum SyncState {
  synced, pendingUpload, pendingDownload, 
  uploading, downloading, error
}
```

**State Transitions:**
```
New Document → pendingUpload
pendingUpload → uploading (sync started)
uploading → synced (upload success)
uploading → error (upload failed)
error → pendingUpload (retry)
```

**Consumers:**
- Document list screen (sync indicators)
- Document detail screen (sync status)

### Connectivity State

**Managed By:** ConnectivityService

**State Model:**
```dart
bool hasConnectivity
```

**State Changes:**
- Network available → hasConnectivity = true
- Network unavailable → hasConnectivity = false

**Consumers:**
- Sync service (auto-sync trigger)
- UI (connectivity indicator)

---

## Error Handling Strategy

### Error Types

1. **Authentication Errors**
   - Invalid credentials
   - Email not verified
   - Token expired
   - Network failure

2. **File Operation Errors**
   - Upload failed
   - Download failed
   - File not found
   - Insufficient permissions

3. **Database Errors**
   - Constraint violation
   - Transaction failed
   - Database locked

4. **Network Errors**
   - No connectivity
   - Timeout
   - Server error

### Error Handling Approach

1. **Catch at Service Layer**
   - Services catch and handle errors
   - Convert to custom exceptions
   - Log error details

2. **Retry Logic**
   - File operations: 3 retries with exponential backoff
   - Authentication: No automatic retry (user action required)
   - Database: Transaction rollback

3. **User Notification**
   - Show user-friendly error messages
   - Provide actionable suggestions
   - Log technical details for debugging

4. **Error Recovery**
   - Sync errors: Mark as error state, allow retry
   - Auth errors: Sign out and require re-authentication
   - Database errors: Rollback transaction, preserve data

### Example Error Handling

```dart
try {
  await fileService.uploadFile(localPath, s3Key);
} on FileUploadException catch (e) {
  logService.logError('Upload failed', e, StackTrace.current);
  await documentRepository.updateSyncState(syncId, SyncState.error);
  rethrow; // Let UI handle user notification
}
```

---

## Security Architecture

### Authentication Security

- **User Pool:** AWS Cognito User Pool for authentication
- **Identity Pool:** AWS Cognito Identity Pool for AWS credentials
- **Token Management:** Automatic token refresh by Amplify
- **Credential Storage:** Secure storage by Amplify (platform keychain)
- **Sign Out:** Complete credential cleanup

### File Access Security

- **S3 Access Level:** Private (enforced by IAM)
- **Path Format:** `private/{identityPoolId}/documents/{syncId}/{fileName}`
- **Ownership Validation:** S3 keys validated before download
- **IAM Policies:** Restrict access to user's Identity Pool ID path
- **HTTPS:** All S3 operations use HTTPS

### Data Security

- **Local Database:** SQLite (not encrypted)
- **Logs:** Sensitive information excluded
- **Error Messages:** No PII in error messages
- **Network:** HTTPS for all AWS operations

### Future Enhancements

- Local database encryption
- Biometric authentication
- File encryption at rest
- End-to-end encryption

---

## Performance Considerations

### Database Optimization

- **Indexes:** syncId, syncState columns indexed
- **Transactions:** Atomic operations for consistency
- **Batch Operations:** Multiple inserts in single transaction
- **Connection Pooling:** Singleton database service

### Network Optimization

- **Retry Logic:** Exponential backoff prevents server overload
- **Debouncing:** Sync operations debounced (1 second)
- **Parallel Uploads:** Multiple files uploaded concurrently
- **Progress Tracking:** Real-time progress for large files

### Memory Optimization

- **File Streams:** Large files handled with streams
- **Lazy Loading:** Documents loaded on demand
- **Cache Management:** Identity Pool ID cached
- **Log Rotation:** Old logs automatically removed

### UI Optimization

- **Async Operations:** All I/O operations async
- **Loading Indicators:** Show progress during operations
- **Optimistic Updates:** UI updates before sync completes
- **Error Recovery:** Graceful degradation on errors

---

## Testing Strategy

### Unit Tests

**Coverage:** >85% for services, repositories, models

**Approach:**
- Mock dependencies using Mockito
- Test each method independently
- Test error scenarios
- Test edge cases

**Example:**
```dart
test('uploadFile should retry on failure', () async {
  // Arrange
  when(mockStorage.uploadFile(...)).thenThrow(Exception());
  
  // Act & Assert
  expect(() => fileService.uploadFile(...), throwsA(isA<FileUploadException>()));
  verify(mockStorage.uploadFile(...)).called(3); // 3 retries
});
```

### Integration Tests

**Coverage:** 38 tests across 5 files

**Approach:**
- Test service interactions
- Test data flow between layers
- Test error propagation
- Mock external dependencies (AWS)

**Example:**
```dart
test('document creation triggers sync', () async {
  // Arrange
  final document = Document(...);
  
  // Act
  await documentRepository.createDocument(document);
  await syncService.performSync();
  
  // Assert
  final updated = await documentRepository.getDocument(document.syncId);
  expect(updated.syncState, SyncState.synced);
});
```

### Widget Tests

**Coverage:** 50 tests across 6 screens

**Approach:**
- Test UI rendering
- Test user interactions
- Test form validation
- Mock service dependencies

**Example:**
```dart
testWidgets('sign in button triggers authentication', (tester) async {
  // Arrange
  await tester.pumpWidget(SignInScreen());
  
  // Act
  await tester.enterText(find.byKey(Key('email')), 'test@example.com');
  await tester.enterText(find.byKey(Key('password')), 'password123');
  await tester.tap(find.byKey(Key('signInButton')));
  await tester.pump();
  
  // Assert
  verify(mockAuthService.signIn('test@example.com', 'password123')).called(1);
});
```

---

## Deployment Architecture

### Build Configuration

**Debug Build:**
- Development AWS resources
- Verbose logging enabled
- Debug symbols included

**Release Build:**
- Production AWS resources
- Minimal logging
- Code obfuscation enabled
- Debug symbols stripped

### AWS Resources

**Development:**
- Separate User Pool
- Separate Identity Pool
- Separate S3 bucket
- Test data isolated

**Production:**
- Production User Pool
- Production Identity Pool
- Production S3 bucket
- Real user data

### CI/CD Pipeline (Future)

1. **Build:** Flutter build on commit
2. **Test:** Run all automated tests
3. **Coverage:** Generate coverage report
4. **Deploy:** Deploy to app stores
5. **Monitor:** Track errors and performance

---

## Future Enhancements

### Planned Features

1. **DynamoDB Integration**
   - Store document metadata in DynamoDB
   - Enable cross-device sync of metadata
   - Implement real-time sync with AppSync

2. **Conflict Resolution**
   - Detect concurrent modifications
   - Implement merge strategies
   - User-driven conflict resolution UI

3. **Offline Queue**
   - Persistent operation queue
   - Guaranteed delivery
   - Operation ordering

4. **File Encryption**
   - Encrypt files before upload
   - Decrypt on download
   - Key management with AWS KMS

5. **Biometric Authentication**
   - Face ID / Touch ID support
   - Quick unlock without password
   - Secure credential storage

6. **Document Sharing**
   - Share documents with other users
   - Permission management
   - Shared document sync

### Technical Debt

1. **Database Encryption**
   - Encrypt local SQLite database
   - Protect data at rest

2. **Error Recovery**
   - More sophisticated retry strategies
   - Partial upload/download resume

3. **Performance**
   - Implement pagination for large document lists
   - Optimize database queries
   - Reduce memory footprint

4. **Testing**
   - Increase widget test coverage
   - Add performance tests
   - Add security tests

---

## Conclusion

The Household Documents App architecture is designed for:
- **Maintainability:** Clear separation of concerns
- **Testability:** Dependency injection and mocking
- **Scalability:** Modular design for easy extension
- **Security:** AWS best practices for authentication and storage
- **Performance:** Optimized for mobile devices

The clean architecture approach ensures the codebase remains maintainable as features are added and requirements evolve.

---

**Last Updated:** January 17, 2026
