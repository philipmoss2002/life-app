# Design Document - Authentication & Sync Rewrite

## Overview

This design document outlines the technical architecture for a complete rewrite of the authentication and file synchronization system. The design follows AWS best practices, implements a clean architecture with clear separation of concerns, and uses a simple UUID-based sync model. The system eliminates all technical debt from previous iterations and provides a maintainable, testable codebase.

### Key Design Principles

1. **Simplicity First**: Minimal services, straightforward logic, no over-engineering
2. **AWS Best Practices**: Proper User Pool → Identity Pool federation for persistent file access
3. **Clean Architecture**: Clear separation between UI, business logic, and data layers
4. **UUID-Based Sync**: SyncId as the single source of truth for document identity
5. **No Migration**: Fresh start with no backward compatibility requirements

---

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                             │
│  (Screens, Widgets, State Management)                       │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Service Layer                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Auth       │  │    Sync      │  │    File      │     │
│  │  Service     │  │   Service    │  │   Service    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │   Document   │  │     Log      │                        │
│  │  Repository  │  │   Service    │                        │
│  └──────────────┘  └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    External Services                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Cognito    │  │      S3      │  │    SQLite    │     │
│  │  User Pool   │  │   Storage    │  │   Database   │     │
│  │ Identity Pool│  │              │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### Component Interaction Flow

**Authentication Flow:**
```
User → AuthService → Cognito User Pool → Cognito Identity Pool → Identity Pool ID
```

**File Upload Flow:**
```
User → UI → SyncService → FileService → S3 (private/{identityPoolId}/documents/{syncId}/{fileName})
                ↓
         DocumentRepository → SQLite (store S3 key with syncId)
```

**File Download Flow:**
```
User → UI → SyncService → DocumentRepository → Get S3 key
                ↓
         FileService → S3 → Download file → Store local path
                ↓
         DocumentRepository → Update local path
```

---

## Components and Interfaces

### 1. AuthenticationService

**Responsibility**: Manage user authentication via AWS Cognito User Pool and Identity Pool

**Interface**:
```dart
class AuthenticationService {
  // Sign up new user
  Future<AuthResult> signUp(String email, String password);
  
  // Sign in existing user
  Future<AuthResult> signIn(String email, String password);
  
  // Sign out current user
  Future<void> signOut();
  
  // Get current authentication state
  Future<AuthState> getAuthState();
  
  // Get persistent Identity Pool ID
  Future<String> getIdentityPoolId();
  
  // Check if user is authenticated
  Future<bool> isAuthenticated();
  
  // Refresh authentication credentials
  Future<void> refreshCredentials();
}
```

**Key Behaviors**:
- On sign in, automatically obtains Identity Pool credentials via federation
- Caches Identity Pool ID locally for quick access
- Validates that Identity Pool ID is persistent (tied to User Pool identity)
- Provides authentication state stream for UI reactivity

---

### 2. FileService

**Responsibility**: Handle all S3 file operations using Identity Pool ID for paths

**Interface**:
```dart
class FileService {
  // Upload file to S3
  Future<String> uploadFile({
    required String localFilePath,
    required String syncId,
    required String identityPoolId,
  });
  
  // Download file from S3
  Future<String> downloadFile({
    required String s3Key,
    required String syncId,
  });
  
  // Delete file from S3
  Future<void> deleteFile(String s3Key);
  
  // Delete all files for a document
  Future<void> deleteDocumentFiles(String syncId);
  
  // Generate S3 path
  String generateS3Path({
    required String identityPoolId,
    required String syncId,
    required String fileName,
  });
  
  // Validate S3 key ownership
  bool validateS3KeyOwnership(String s3Key, String identityPoolId);
}
```

**Key Behaviors**:
- Generates S3 paths: `private/{identityPoolId}/documents/{syncId}/{fileName}`
- Uses Amplify Storage with private access level
- Validates Identity Pool ID in paths matches current user
- Implements simple retry logic (3 attempts with exponential backoff)
- Logs all operations for debugging

---

### 3. SyncService

**Responsibility**: Coordinate document synchronization between local and remote storage

**Interface**:
```dart
class SyncService {
  // Perform full sync (upload pending, download new)
  Future<SyncResult> performSync();
  
  // Sync specific document
  Future<void> syncDocument(String syncId);
  
  // Upload document files
  Future<void> uploadDocumentFiles(String syncId);
  
  // Download document files
  Future<void> downloadDocumentFiles(String syncId);
  
  // Get sync status
  Stream<SyncStatus> get syncStatusStream;
  
  // Check if sync is in progress
  bool get isSyncing;
}
```

**Key Behaviors**:
- Triggered automatically on app launch, document changes, and network restoration
- Uploads files for documents with "pending upload" state
- Downloads files for documents with S3 keys but no local files
- Updates document sync states in database
- Provides sync progress updates via stream
- Handles errors gracefully with retry logic

---

### 4. DocumentRepository

**Responsibility**: Manage document metadata in local SQLite database

**Interface**:
```dart
class DocumentRepository {
  // Create new document
  Future<Document> createDocument({
    required String title,
    String? description,
    List<String>? labels,
  });
  
  // Get document by syncId
  Future<Document?> getDocument(String syncId);
  
  // Get all documents
  Future<List<Document>> getAllDocuments();
  
  // Update document
  Future<void> updateDocument(Document document);
  
  // Delete document
  Future<void> deleteDocument(String syncId);
  
  // Add file attachment to document
  Future<void> addFileAttachment({
    required String syncId,
    required String localPath,
    String? s3Key,
  });
  
  // Update file attachment S3 key
  Future<void> updateFileS3Key({
    required String syncId,
    required String fileName,
    required String s3Key,
  });
  
  // Update document sync state
  Future<void> updateSyncState(String syncId, SyncState state);
  
  // Get documents by sync state
  Future<List<Document>> getDocumentsBySyncState(SyncState state);
}
```

**Key Behaviors**:
- Generates UUID for syncId on document creation
- Stores document metadata and file references
- Tracks sync state for each document
- Provides transactional operations for data integrity
- Uses SQLite for local storage

---

### 5. LogService

**Responsibility**: Provide application logging for debugging and monitoring

**Interface**:
```dart
class LogService {
  // Log message with level
  void log(String message, {LogLevel level = LogLevel.info});
  
  // Log error with stack trace
  void logError(String message, {Object? error, StackTrace? stackTrace});
  
  // Get recent logs
  Future<List<LogEntry>> getRecentLogs({int limit = 100});
  
  // Get logs by level
  Future<List<LogEntry>> getLogsByLevel(LogLevel level);
  
  // Clear logs
  Future<void> clearLogs();
  
  // Export logs as string
  Future<String> exportLogs();
}
```

**Key Behaviors**:
- Logs to console and persistent storage
- Supports filtering by log level (info, warning, error)
- Stores recent logs (last 1000 entries)
- Excludes sensitive information (passwords, tokens)
- Provides export functionality for support

---

## Data Models

### Document Model

```dart
class Document {
  final String syncId;           // UUID - unique identifier
  final String title;            // Document title
  final String? description;     // Optional description
  final List<String> labels;     // Document labels/tags
  final DateTime createdAt;      // Creation timestamp
  final DateTime updatedAt;      // Last update timestamp
  final SyncState syncState;     // Current sync state
  final List<FileAttachment> files; // Attached files
  
  Document({
    required this.syncId,
    required this.title,
    this.description,
    this.labels = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.syncState,
    this.files = const [],
  });
}
```

### FileAttachment Model

```dart
class FileAttachment {
  final String fileName;         // Original file name
  final String? localPath;       // Local file path (if downloaded)
  final String? s3Key;           // S3 key (if uploaded)
  final int? fileSize;           // File size in bytes
  final DateTime addedAt;        // When file was attached
  
  FileAttachment({
    required this.fileName,
    this.localPath,
    this.s3Key,
    this.fileSize,
    required this.addedAt,
  });
}
```

### SyncState Enum

```dart
enum SyncState {
  synced,           // File is synced (uploaded and available)
  pendingUpload,    // File needs to be uploaded
  pendingDownload,  // File needs to be downloaded
  uploading,        // Upload in progress
  downloading,      // Download in progress
  error,            // Sync error occurred
}
```

### AuthState Model

```dart
class AuthState {
  final bool isAuthenticated;
  final String? userEmail;
  final String? identityPoolId;
  final DateTime? lastAuthTime;
  
  AuthState({
    required this.isAuthenticated,
    this.userEmail,
    this.identityPoolId,
    this.lastAuthTime,
  });
}
```

### SyncResult Model

```dart
class SyncResult {
  final int uploadedCount;
  final int downloadedCount;
  final int failedCount;
  final List<String> errors;
  final Duration duration;
  
  SyncResult({
    required this.uploadedCount,
    required this.downloadedCount,
    required this.failedCount,
    required this.errors,
    required this.duration,
  });
}
```

---

## Database Schema

### Documents Table

```sql
CREATE TABLE documents (
  sync_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  labels TEXT,              -- JSON array of strings
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sync_state TEXT NOT NULL  -- 'synced', 'pendingUpload', etc.
);
```

### FileAttachments Table

```sql
CREATE TABLE file_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sync_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  local_path TEXT,
  s3_key TEXT,
  file_size INTEGER,
  added_at INTEGER NOT NULL,
  FOREIGN KEY (sync_id) REFERENCES documents(sync_id) ON DELETE CASCADE
);
```

### Logs Table

```sql
CREATE TABLE logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp INTEGER NOT NULL,
  level TEXT NOT NULL,      -- 'info', 'warning', 'error'
  message TEXT NOT NULL,
  error_details TEXT,
  stack_trace TEXT
);
```

---

## Error Handling

### Error Handling Strategy

**Simple and Pragmatic Approach:**

1. **Try-Catch at Service Level**: Each service method wraps operations in try-catch
2. **Retry Logic**: Simple retry with exponential backoff (3 attempts)
3. **Error Logging**: Log all errors with context
4. **User-Friendly Messages**: Convert technical errors to user-friendly messages
5. **State Recovery**: Update sync states to allow retry on next sync

**Example Pattern**:
```dart
Future<String> uploadFile(...) async {
  int attempts = 0;
  const maxAttempts = 3;
  
  while (attempts < maxAttempts) {
    try {
      // Perform upload
      final result = await Amplify.Storage.uploadFile(...);
      _logService.log('Upload successful: ${result.uploadedItem.path}');
      return result.uploadedItem.path;
    } catch (e, stackTrace) {
      attempts++;
      _logService.logError('Upload failed (attempt $attempts)', 
        error: e, stackTrace: stackTrace);
      
      if (attempts >= maxAttempts) {
        throw FileUploadException('Failed after $maxAttempts attempts: $e');
      }
      
      // Exponential backoff
      await Future.delayed(Duration(seconds: pow(2, attempts).toInt()));
    }
  }
}
```

### Error Types

```dart
// Authentication errors
class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);
}

// File operation errors
class FileUploadException implements Exception {
  final String message;
  FileUploadException(this.message);
}

class FileDownloadException implements Exception {
  final String message;
  FileDownloadException(this.message);
}

// Database errors
class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);
}

// Sync errors
class SyncException implements Exception {
  final String message;
  SyncException(this.message);
}
```

---

## Testing Strategy

### Unit Testing

**Services to Test**:
1. **AuthenticationService**: Sign up, sign in, sign out, Identity Pool ID retrieval
2. **FileService**: S3 path generation, upload, download, delete, ownership validation
3. **SyncService**: Sync coordination, state management, error handling
4. **DocumentRepository**: CRUD operations, sync state updates, file attachments
5. **LogService**: Logging, filtering, export

**Testing Approach**:
- Mock external dependencies (Amplify, SQLite)
- Test happy paths and error scenarios
- Verify retry logic and error handling
- Test state transitions

**Example Test**:
```dart
test('FileService generates correct S3 path', () {
  final fileService = FileService();
  final path = fileService.generateS3Path(
    identityPoolId: 'us-east-1:12345',
    syncId: 'abc-123',
    fileName: 'test.pdf',
  );
  
  expect(path, equals('private/us-east-1:12345/documents/abc-123/test.pdf'));
});
```

### Integration Testing

**Scenarios to Test**:
1. **End-to-End Auth Flow**: Sign up → Sign in → Get Identity Pool ID → Sign out
2. **Document Creation and Sync**: Create document → Attach file → Upload → Verify S3
3. **Multi-Device Sync**: Upload on device A → Download on device B
4. **Offline Handling**: Create document offline → Go online → Auto-sync
5. **Error Recovery**: Fail upload → Retry → Success

### Widget Testing

**UI Components to Test**:
1. **Auth Screens**: Sign up form, sign in form, validation
2. **Document List**: Display documents, sync status indicators
3. **Document Detail**: Display metadata, file attachments, actions
4. **Settings Screen**: Display logs, filter logs, sign out

---

## Security Considerations

### Authentication Security

1. **Secure Credential Storage**: Use Flutter Secure Storage for tokens
2. **HTTPS Only**: All network communication over HTTPS
3. **Token Refresh**: Automatic refresh of expired credentials
4. **Sign Out Cleanup**: Clear all cached credentials on sign out

### File Access Security

1. **Identity Pool ID Validation**: Verify format matches AWS pattern
2. **Path Ownership Validation**: Ensure S3 key contains current user's Identity Pool ID
3. **Private Access Level**: Use S3 private access for user isolation
4. **No Path Traversal**: Validate syncId and fileName don't contain path separators

### Data Security

1. **Local Database**: SQLite database with app-level encryption
2. **Sensitive Data Exclusion**: Never log passwords, tokens, or PII
3. **S3 Encryption**: Use S3 server-side encryption (default)
4. **Certificate Validation**: Verify SSL certificates on all requests

---

## Performance Considerations

### Optimization Strategies

1. **Lazy Loading**: Load documents on-demand, not all at once
2. **Pagination**: Paginate document list for large collections
3. **Background Sync**: Perform sync operations in background isolate
4. **Caching**: Cache Identity Pool ID to avoid repeated API calls
5. **Batch Operations**: Upload/download multiple files in parallel (with limit)

### Resource Management

1. **Connection Pooling**: Reuse HTTP connections for S3 operations
2. **Memory Management**: Stream large files instead of loading into memory
3. **Database Indexing**: Index syncId and sync_state columns
4. **Log Rotation**: Keep only recent 1000 log entries

---

## Deployment Considerations

### Configuration

**Amplify Configuration** (`amplifyconfiguration.dart`):
```dart
{
  "storage": {
    "plugins": {
      "awsS3StoragePlugin": {
        "bucket": "your-bucket-name",
        "region": "your-region",
        "defaultAccessLevel": "private"  // Critical: must be private
      }
    }
  },
  "auth": {
    "plugins": {
      "awsCognitoAuthPlugin": {
        "UserPool": {
          "PoolId": "your-user-pool-id",
          "Region": "your-region"
        },
        "IdentityPool": {
          "PoolId": "your-identity-pool-id",
          "Region": "your-region"
        }
      }
    }
  }
}
```

### Environment Setup

1. **AWS Cognito**: User Pool and Identity Pool configured with proper federation
2. **S3 Bucket**: Created with private access IAM policies
3. **IAM Policies**: Configured to allow `private/{identityPoolId}/*` access
4. **App Configuration**: Amplify CLI configuration pushed to cloud

### Monitoring

1. **CloudWatch Logs**: Monitor Cognito and S3 access logs
2. **App Logs**: Review app logs for errors and performance issues
3. **Sync Metrics**: Track sync success/failure rates
4. **User Feedback**: Collect user reports of sync issues

---

## Migration from Old System

**Note**: This design assumes NO migration from the old system. Users will start fresh.

**If migration is needed later**:
1. Create separate migration service (not part of core system)
2. Run migration as one-time operation
3. Map old file paths to new syncId-based structure
4. Verify all files migrated successfully
5. Remove migration service after completion

---

## Summary

This design provides a clean, maintainable architecture for authentication and file synchronization:

**Key Features**:
- ✅ Simple 5-service architecture
- ✅ AWS best practices with Identity Pool ID
- ✅ UUID-based sync model
- ✅ Clean separation of concerns
- ✅ Comprehensive error handling
- ✅ Security-first approach
- ✅ Testable components
- ✅ No technical debt

**Services**:
1. AuthenticationService - User Pool + Identity Pool
2. FileService - S3 operations
3. SyncService - Sync coordination
4. DocumentRepository - Local database
5. LogService - Application logging

**Path Format**: `private/{identityPoolId}/documents/{syncId}/{fileName}`

**Next Steps**: Proceed to implementation tasks
