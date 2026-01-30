# API Reference

Complete API documentation for all services, repositories, and models in the Household Documents App.

---

## AuthenticationService

Singleton service for user authentication and Identity Pool management.

### Constructor

```dart
AuthenticationService()
```

Returns the singleton instance.

### Methods

#### signUp

```dart
Future<void> signUp(String email, String password)
```

Create a new user account with AWS Cognito User Pool.

**Parameters:**
- `email` (String) - User's email address
- `password` (String) - User's password (min 8 characters)

**Returns:** Future<void>

**Throws:**
- `AuthenticationException` - If sign up fails

**Example:**
```dart
try {
  await authService.signUp('user@example.com', 'SecurePass123!');
  // Show success message, prompt for email verification
} on AuthenticationException catch (e) {
  // Show error message
}
```

---

#### signIn

```dart
Future<void> signIn(String email, String password)
```

Authenticate user with AWS Cognito User Pool.

**Parameters:**
- `email` (String) - User's email address
- `password` (String) - User's password

**Returns:** Future<void>

**Throws:**
- `AuthenticationException` - If sign in fails

**Example:**
```dart
try {
  await authService.signIn('user@example.com', 'SecurePass123!');
  final identityPoolId = await authService.getIdentityPoolId();
  // Navigate to home screen
} on AuthenticationException catch (e) {
  // Show error message
}
```

---

#### signOut

```dart
Future<void> signOut()
```

Sign out current user and clear all credentials.

**Returns:** Future<void>

**Throws:**
- `AuthenticationException` - If sign out fails

**Example:**
```dart
await authService.signOut();
// Navigate to sign in screen
```

---

#### isAuthenticated

```dart
Future<bool> isAuthenticated()
```

Check if user is currently authenticated.

**Returns:** Future<bool> - true if authenticated, false otherwise

**Example:**
```dart
if (await authService.isAuthenticated()) {
  // User is signed in
} else {
  // User is signed out
}
```

---

#### getIdentityPoolId

```dart
Future<String> getIdentityPoolId()
```

Retrieve and cache the user's Identity Pool ID from AWS Cognito.

**Returns:** Future<String> - Identity Pool ID

**Throws:**
- `AuthenticationException` - If not authenticated or retrieval fails

**Example:**
```dart
final identityPoolId = await authService.getIdentityPoolId();
// Use for S3 path generation
```

---

#### getAuthState

```dart
Future<AuthState> getAuthState()
```

Get current authentication state.

**Returns:** Future<AuthState> - Current auth state

**Example:**
```dart
final authState = await authService.getAuthState();
print('User: ${authState.userEmail}');
print('Identity Pool ID: ${authState.identityPoolId}');
```

---

#### authStateStream

```dart
Stream<AuthState> get authStateStream
```

Stream of authentication state changes.

**Returns:** Stream<AuthState>

**Example:**
```dart
authService.authStateStream.listen((state) {
  if (state.isAuthenticated) {
    // User signed in
  } else {
    // User signed out
  }
});
```

---

## FileService

Singleton service for file operations with AWS S3.

### Constructor

```dart
FileService()
```

Returns the singleton instance.

### Methods

#### generateS3Path

```dart
String generateS3Path(String identityPoolId, String syncId, String fileName)
```

Generate S3 key for file storage.

**Parameters:**
- `identityPoolId` (String) - User's Identity Pool ID
- `syncId` (String) - Document's sync ID (UUID)
- `fileName` (String) - Original file name

**Returns:** String - S3 key in format: `private/{identityPoolId}/documents/{syncId}/{fileName}`

**Example:**
```dart
final s3Key = fileService.generateS3Path(
  'us-east-1:12345678-1234-1234-1234-123456789abc',
  '550e8400-e29b-41d4-a716-446655440000',
  'insurance_policy.pdf'
);
// Returns: private/us-east-1:12345678-1234-1234-1234-123456789abc/documents/550e8400-e29b-41d4-a716-446655440000/insurance_policy.pdf
```

---

#### uploadFile

```dart
Future<void> uploadFile(String localPath, String s3Key, {Function(double)? onProgress})
```

Upload file to AWS S3 with retry logic.

**Parameters:**
- `localPath` (String) - Local file path
- `s3Key` (String) - S3 object key (from generateS3Path)
- `onProgress` (Function(double)?) - Optional progress callback (0.0 to 1.0)

**Returns:** Future<void>

**Throws:**
- `FileUploadException` - If upload fails after retries

**Retry Logic:** 3 attempts with exponential backoff (1s, 2s, 4s)

**Example:**
```dart
try {
  await fileService.uploadFile(
    '/path/to/local/file.pdf',
    s3Key,
    onProgress: (progress) {
      print('Upload progress: ${(progress * 100).toStringAsFixed(0)}%');
    }
  );
} on FileUploadException catch (e) {
  // Handle upload failure
}
```

---

#### downloadFile

```dart
Future<void> downloadFile(String s3Key, String localPath, {Function(double)? onProgress})
```

Download file from AWS S3 with ownership validation.

**Parameters:**
- `s3Key` (String) - S3 object key
- `localPath` (String) - Local destination path
- `onProgress` (Function(double)?) - Optional progress callback (0.0 to 1.0)

**Returns:** Future<void>

**Throws:**
- `FileDownloadException` - If download fails after retries
- `SecurityException` - If S3 key ownership validation fails

**Retry Logic:** 3 attempts with exponential backoff (1s, 2s, 4s)

**Example:**
```dart
try {
  await fileService.downloadFile(
    s3Key,
    '/path/to/local/destination.pdf',
    onProgress: (progress) {
      print('Download progress: ${(progress * 100).toStringAsFixed(0)}%');
    }
  );
} on FileDownloadException catch (e) {
  // Handle download failure
}
```

---

#### deleteFile

```dart
Future<void> deleteFile(String s3Key)
```

Delete single file from AWS S3.

**Parameters:**
- `s3Key` (String) - S3 object key

**Returns:** Future<void>

**Throws:**
- `FileDeleteException` - If deletion fails after retries

**Retry Logic:** 3 attempts with exponential backoff (1s, 2s, 4s)

**Example:**
```dart
await fileService.deleteFile(s3Key);
```

---

#### deleteDocumentFiles

```dart
Future<void> deleteDocumentFiles(String identityPoolId, String syncId)
```

Delete all files for a document from AWS S3.

**Parameters:**
- `identityPoolId` (String) - User's Identity Pool ID
- `syncId` (String) - Document's sync ID

**Returns:** Future<void>

**Throws:**
- `FileDeleteException` - If deletion fails

**Example:**
```dart
await fileService.deleteDocumentFiles(identityPoolId, document.syncId);
```

---

#### validateS3KeyOwnership

```dart
bool validateS3KeyOwnership(String s3Key, String identityPoolId)
```

Validate that S3 key belongs to user's Identity Pool ID.

**Parameters:**
- `s3Key` (String) - S3 object key to validate
- `identityPoolId` (String) - User's Identity Pool ID

**Returns:** bool - true if valid, false otherwise

**Example:**
```dart
if (fileService.validateS3KeyOwnership(s3Key, identityPoolId)) {
  // Safe to download
} else {
  // Unauthorized access attempt
}
```

---

## SyncService

Singleton service for synchronization coordination.

### Constructor

```dart
SyncService()
```

Returns the singleton instance.

### Methods

#### performSync

```dart
Future<SyncResult> performSync()
```

Perform full synchronization of all documents.

**Returns:** Future<SyncResult> - Sync operation results

**Process:**
1. Query documents with pendingUpload state
2. Upload files for each document
3. Update S3 keys and sync state
4. Query documents with pendingDownload state
5. Download files for each document
6. Update local paths and sync state

**Example:**
```dart
final result = await syncService.performSync();
print('Uploaded: ${result.uploadedCount}');
print('Downloaded: ${result.downloadedCount}');
print('Failed: ${result.failedCount}');
print('Duration: ${result.duration}');
```

---

#### uploadDocumentFiles

```dart
Future<void> uploadDocumentFiles(Document document)
```

Upload files for specific document.

**Parameters:**
- `document` (Document) - Document to upload

**Returns:** Future<void>

**Throws:**
- `FileUploadException` - If upload fails

**Example:**
```dart
await syncService.uploadDocumentFiles(document);
```

---

#### downloadDocumentFiles

```dart
Future<void> downloadDocumentFiles(Document document)
```

Download files for specific document.

**Parameters:**
- `document` (Document) - Document to download

**Returns:** Future<void>

**Throws:**
- `FileDownloadException` - If download fails

**Example:**
```dart
await syncService.downloadDocumentFiles(document);
```

---

#### isSyncing

```dart
bool get isSyncing
```

Check if sync operation is currently in progress.

**Returns:** bool - true if syncing, false otherwise

**Example:**
```dart
if (syncService.isSyncing) {
  // Show loading indicator
}
```

---

#### syncStatusStream

```dart
Stream<SyncStatus> get syncStatusStream
```

Stream of sync status updates.

**Returns:** Stream<SyncStatus>

**Example:**
```dart
syncService.syncStatusStream.listen((status) {
  if (status.isActive) {
    print('Syncing: ${status.progress}%');
  }
});
```

---

## DocumentRepository

Singleton repository for document data access.

### Constructor

```dart
DocumentRepository()
```

Returns the singleton instance.

### Methods

#### createDocument

```dart
Future<Document> createDocument(Document document)
```

Create new document in database.

**Parameters:**
- `document` (Document) - Document to create (syncId will be generated if null)

**Returns:** Future<Document> - Created document with generated syncId

**Throws:**
- `DatabaseException` - If creation fails

**Example:**
```dart
final document = Document(
  syncId: '', // Will be generated
  title: 'Home Insurance',
  description: 'Policy details',
  labels: ['insurance', 'home'],
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  syncState: SyncState.pendingUpload,
  files: [],
);
final created = await documentRepository.createDocument(document);
```

---

#### getDocument

```dart
Future<Document?> getDocument(String syncId)
```

Retrieve document by sync ID.

**Parameters:**
- `syncId` (String) - Document's sync ID

**Returns:** Future<Document?> - Document if found, null otherwise

**Example:**
```dart
final document = await documentRepository.getDocument(syncId);
if (document != null) {
  // Document found
}
```

---

#### getAllDocuments

```dart
Future<List<Document>> getAllDocuments()
```

Retrieve all documents, sorted by updatedAt descending.

**Returns:** Future<List<Document>> - List of all documents

**Example:**
```dart
final documents = await documentRepository.getAllDocuments();
```

---

#### updateDocument

```dart
Future<void> updateDocument(Document document)
```

Update existing document.

**Parameters:**
- `document` (Document) - Document with updated fields

**Returns:** Future<void>

**Throws:**
- `DatabaseException` - If update fails

**Example:**
```dart
final updated = document.copyWith(
  title: 'Updated Title',
  updatedAt: DateTime.now(),
);
await documentRepository.updateDocument(updated);
```

---

#### deleteDocument

```dart
Future<void> deleteDocument(String syncId)
```

Delete document and all associated file attachments.

**Parameters:**
- `syncId` (String) - Document's sync ID

**Returns:** Future<void>

**Throws:**
- `DatabaseException` - If deletion fails

**Note:** Cascade deletes file attachments automatically

**Example:**
```dart
await documentRepository.deleteDocument(syncId);
```

---

#### addFileAttachment

```dart
Future<void> addFileAttachment(String syncId, FileAttachment file)
```

Add file attachment to document.

**Parameters:**
- `syncId` (String) - Document's sync ID
- `file` (FileAttachment) - File attachment to add

**Returns:** Future<void>

**Throws:**
- `DatabaseException` - If addition fails

**Example:**
```dart
final file = FileAttachment(
  fileName: 'policy.pdf',
  localPath: '/path/to/policy.pdf',
  s3Key: null,
  fileSize: 1024000,
  addedAt: DateTime.now(),
);
await documentRepository.addFileAttachment(document.syncId, file);
```

---

#### updateFileS3Key

```dart
Future<void> updateFileS3Key(String syncId, String fileName, String s3Key)
```

Update S3 key for file attachment after upload.

**Parameters:**
- `syncId` (String) - Document's sync ID
- `fileName` (String) - File name
- `s3Key` (String) - S3 object key

**Returns:** Future<void>

**Throws:**
- `DatabaseException` - If update fails

**Example:**
```dart
await documentRepository.updateFileS3Key(
  document.syncId,
  'policy.pdf',
  's3://bucket/path/to/policy.pdf'
);
```

---

#### updateSyncState

```dart
Future<void> updateSyncState(String syncId, SyncState state)
```

Update document's sync state.

**Parameters:**
- `syncId` (String) - Document's sync ID
- `state` (SyncState) - New sync state

**Returns:** Future<void>

**Throws:**
- `DatabaseException` - If update fails

**Example:**
```dart
await documentRepository.updateSyncState(
  document.syncId,
  SyncState.synced
);
```

---

#### getDocumentsBySyncState

```dart
Future<List<Document>> getDocumentsBySyncState(SyncState state)
```

Query documents by sync state.

**Parameters:**
- `state` (SyncState) - Sync state to filter by

**Returns:** Future<List<Document>> - List of matching documents

**Example:**
```dart
final pendingDocs = await documentRepository.getDocumentsBySyncState(
  SyncState.pendingUpload
);
```

---

## LogService

Singleton service for application logging.

### Constructor

```dart
LogService()
```

Returns the singleton instance.

### Methods

#### log

```dart
Future<void> log(String message, {String level = 'info'})
```

Log message with specified level.

**Parameters:**
- `message` (String) - Log message
- `level` (String) - Log level ('info', 'warning', 'error')

**Returns:** Future<void>

**Example:**
```dart
await logService.log('Sync started', level: 'info');
await logService.log('Slow operation detected', level: 'warning');
```

---

#### logError

```dart
Future<void> logError(String message, dynamic error, StackTrace? stackTrace)
```

Log error with details and stack trace.

**Parameters:**
- `message` (String) - Error message
- `error` (dynamic) - Error object
- `stackTrace` (StackTrace?) - Optional stack trace

**Returns:** Future<void>

**Example:**
```dart
try {
  // Some operation
} catch (e, stackTrace) {
  await logService.logError('Operation failed', e, stackTrace);
}
```

---

#### getRecentLogs

```dart
Future<List<LogEntry>> getRecentLogs({int limit = 100})
```

Retrieve recent log entries.

**Parameters:**
- `limit` (int) - Maximum number of entries (default: 100)

**Returns:** Future<List<LogEntry>> - List of log entries

**Example:**
```dart
final logs = await logService.getRecentLogs(limit: 50);
```

---

#### getLogsByLevel

```dart
Future<List<LogEntry>> getLogsByLevel(String level)
```

Retrieve logs filtered by level.

**Parameters:**
- `level` (String) - Log level to filter by

**Returns:** Future<List<LogEntry>> - List of matching log entries

**Example:**
```dart
final errors = await logService.getLogsByLevel('error');
```

---

#### clearLogs

```dart
Future<void> clearLogs()
```

Delete all log entries.

**Returns:** Future<void>

**Example:**
```dart
await logService.clearLogs();
```

---

#### exportLogs

```dart
Future<String> exportLogs()
```

Generate shareable log string.

**Returns:** Future<String> - Formatted log string

**Example:**
```dart
final logText = await logService.exportLogs();
await Share.share(logText);
```

---

## ConnectivityService

Singleton service for network connectivity monitoring.

### Constructor

```dart
ConnectivityService()
```

Returns the singleton instance.

### Methods

#### hasConnectivity

```dart
Future<bool> hasConnectivity()
```

Check current network connectivity status.

**Returns:** Future<bool> - true if connected, false otherwise

**Example:**
```dart
if (await connectivityService.hasConnectivity()) {
  // Network available
} else {
  // Offline
}
```

---

#### connectivityStream

```dart
Stream<bool> get connectivityStream
```

Stream of connectivity status changes.

**Returns:** Stream<bool>

**Example:**
```dart
connectivityService.connectivityStream.listen((hasConnection) {
  if (hasConnection) {
    // Network restored, trigger sync
  } else {
    // Network lost, show offline indicator
  }
});
```

---

## Data Models

### Document

```dart
class Document {
  final String syncId;
  final String title;
  final String description;
  final List<String> labels;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncState syncState;
  final List<FileAttachment> files;
  
  Document({
    required this.syncId,
    required this.title,
    required this.description,
    required this.labels,
    required this.createdAt,
    required this.updatedAt,
    required this.syncState,
    required this.files,
  });
  
  Map<String, dynamic> toJson();
  factory Document.fromJson(Map<String, dynamic> json);
  Document copyWith({...});
}
```

### FileAttachment

```dart
class FileAttachment {
  final String fileName;
  final String? localPath;
  final String? s3Key;
  final int? fileSize;
  final DateTime addedAt;
  
  FileAttachment({
    required this.fileName,
    this.localPath,
    this.s3Key,
    this.fileSize,
    required this.addedAt,
  });
  
  Map<String, dynamic> toJson();
  factory FileAttachment.fromJson(Map<String, dynamic> json);
  FileAttachment copyWith({...});
}
```

### SyncState

```dart
enum SyncState {
  synced,
  pendingUpload,
  pendingDownload,
  uploading,
  downloading,
  error
}
```

### SyncResult

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

### LogEntry

```dart
class LogEntry {
  final int id;
  final DateTime timestamp;
  final String level;
  final String message;
  final String? errorDetails;
  final String? stackTrace;
  
  LogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.message,
    this.errorDetails,
    this.stackTrace,
  });
}
```

---

## Exception Types

### AuthenticationException

```dart
class AuthenticationException implements Exception {
  final String message;
  final dynamic originalError;
  
  AuthenticationException(this.message, [this.originalError]);
}
```

### FileUploadException

```dart
class FileUploadException implements Exception {
  final String message;
  final String? s3Key;
  final dynamic originalError;
  
  FileUploadException(this.message, {this.s3Key, this.originalError});
}
```

### FileDownloadException

```dart
class FileDownloadException implements Exception {
  final String message;
  final String? s3Key;
  final dynamic originalError;
  
  FileDownloadException(this.message, {this.s3Key, this.originalError});
}
```

### DatabaseException

```dart
class DatabaseException implements Exception {
  final String message;
  final dynamic originalError;
  
  DatabaseException(this.message, [this.originalError]);
}
```

---

**Last Updated:** January 17, 2026
