# Household Documents App

A Flutter mobile app for managing household documents with cloud sync, built on AWS Amplify with clean architecture principles.

## Features

### Core Functionality
- **Document Management** - Create, edit, and delete documents with titles, descriptions, and labels
- **File Attachments** - Attach multiple files to each document with automatic cloud backup
- **Cloud Sync** - Automatic synchronization across devices using AWS S3 and DynamoDB
- **Offline Support** - Full offline functionality with automatic sync when connectivity is restored
- **User Authentication** - Secure sign up and sign in with AWS Cognito User Pools
- **Multi-Device Support** - Access your documents from any device with the same account

### Technical Features
- **Clean Architecture** - Separation of concerns with services, repositories, and models
- **Identity Pool Integration** - Persistent user identity across app reinstalls
- **Private S3 Storage** - Each user's files are isolated using Identity Pool ID-based paths
- **Sync State Management** - Visual indicators for sync status (synced, uploading, downloading, error)
- **Comprehensive Logging** - Built-in logging system for debugging and support
- **Error Handling** - Robust error handling with retry logic and user-friendly messages

---

## Getting Started

### Prerequisites

- Flutter SDK (3.0.6 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio / Xcode for mobile development
- AWS Account with Amplify configured
- Physical device or emulator

### AWS Setup

This app requires AWS Amplify configuration with:
- **Cognito User Pool** - For user authentication
- **Cognito Identity Pool** - For AWS credential management
- **S3 Bucket** - For file storage with private access
- **DynamoDB** - For document metadata sync (optional, future enhancement)

See `AWS_SETUP_GUIDE.md` for detailed AWS configuration instructions.

### Installation

1. Clone the repository and navigate to the project directory:
```bash
cd household_docs_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Amplify:
   - Ensure `lib/amplifyconfiguration.dart` is present with your AWS configuration
   - Verify User Pool and Identity Pool are properly configured
   - Verify S3 bucket has correct IAM policies for private access

4. Run the app:
```bash
flutter run
```

---

## Architecture

### Clean Architecture Principles

The app follows clean architecture with clear separation of concerns:

```
lib/
├── models/              # Data models (Document, FileAttachment, SyncState)
├── repositories/        # Data access layer (DocumentRepository)
├── services/            # Business logic layer
│   ├── authentication_service.dart
│   ├── file_service.dart
│   ├── sync_service.dart
│   ├── log_service.dart
│   └── connectivity_service.dart
├── screens/             # UI layer (presentation)
└── widgets/             # Reusable UI components
```

### Key Services

#### AuthenticationService
Handles user authentication with AWS Cognito:
- Sign up with email verification
- Sign in with email and password
- Sign out with credential cleanup
- Identity Pool ID retrieval and caching
- Authentication state management

#### FileService
Manages file operations with AWS S3:
- S3 path generation using format: `private/{identityPoolId}/documents/{syncId}/{fileName}`
- File upload with retry logic
- File download with ownership validation
- File deletion with cascade support
- Progress tracking for uploads/downloads

#### SyncService
Coordinates synchronization between local and cloud:
- Automatic sync on app launch
- Automatic sync on document changes
- Automatic sync on connectivity restoration
- Upload pending documents
- Download missing files
- Sync state management

#### DocumentRepository
Manages local SQLite database:
- CRUD operations for documents
- File attachment management
- Sync state tracking
- Transaction support for atomic operations

#### LogService
Provides application logging:
- Log levels (info, warning, error)
- SQLite storage (last 1000 entries)
- Log filtering and export
- Sensitive information exclusion

---

## Data Models

### Document
```dart
class Document {
  final String syncId;           // UUID, primary key
  final String title;
  final String description;
  final List<String> labels;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncState syncState;
  final List<FileAttachment> files;
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
}
```

### SyncState
```dart
enum SyncState {
  synced,           // Fully synced with cloud
  pendingUpload,    // Waiting to upload to cloud
  pendingDownload,  // Waiting to download from cloud
  uploading,        // Currently uploading
  downloading,      // Currently downloading
  error             // Sync error occurred
}
```

---

## Authentication Flow

### Sign Up
1. User enters email and password
2. AWS Cognito creates user account
3. Verification email sent to user
4. User verifies email (required before sign in)

### Sign In
1. User enters email and password
2. AWS Cognito validates credentials
3. Identity Pool ID retrieved and cached
4. User navigated to document list

### Identity Pool ID
- Retrieved from AWS Cognito Identity Pool
- Cached locally for performance
- Used in S3 paths for file isolation
- Persistent across app reinstalls (tied to user account)

---

## Sync Model

### Sync States

Documents transition through sync states based on operations:

```
New Document → pendingUpload → uploading → synced
Downloaded → pendingDownload → downloading → synced
Modified → pendingUpload → uploading → synced
Error → error (can retry)
```

### Sync Triggers

Automatic sync is triggered by:
1. **App Launch** - After successful authentication
2. **Document Changes** - Create, update, or delete operations
3. **Connectivity Restoration** - When network becomes available
4. **Manual Refresh** - Pull-to-refresh on document list

### Conflict Resolution

The app uses **last-write-wins** strategy:
- Timestamps determine which version is newer
- Local changes always take precedence during upload
- Downloads only occur for documents without local changes

---

## S3 File Organization

### Path Format

Files are stored in S3 using this path format:
```
private/{identityPoolId}/documents/{syncId}/{fileName}
```

**Example:**
```
private/us-east-1:12345678-1234-1234-1234-123456789abc/documents/550e8400-e29b-41d4-a716-446655440000/insurance_policy.pdf
```

### Path Components

- **private/** - S3 access level (enforced by IAM policies)
- **{identityPoolId}** - User's Identity Pool ID (ensures isolation)
- **documents/** - Document namespace
- **{syncId}** - Document's unique identifier (UUID)
- **{fileName}** - Original file name

### Security

- Each user can only access files under their Identity Pool ID
- IAM policies enforce path-based access control
- S3 keys are validated before download to prevent unauthorized access
- HTTPS used for all S3 operations

---

## Database Schema

### documents Table
```sql
CREATE TABLE documents (
  syncId TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  labels TEXT,
  createdAt INTEGER NOT NULL,
  updatedAt INTEGER NOT NULL,
  syncState TEXT NOT NULL
);
```

### file_attachments Table
```sql
CREATE TABLE file_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  documentSyncId TEXT NOT NULL,
  fileName TEXT NOT NULL,
  localPath TEXT,
  s3Key TEXT,
  fileSize INTEGER,
  addedAt INTEGER NOT NULL,
  FOREIGN KEY (documentSyncId) REFERENCES documents(syncId) ON DELETE CASCADE
);
```

### logs Table
```sql
CREATE TABLE logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp INTEGER NOT NULL,
  level TEXT NOT NULL,
  message TEXT NOT NULL,
  errorDetails TEXT,
  stackTrace TEXT
);
```

---

## Error Handling

### Retry Logic

File operations use exponential backoff retry logic:
- **Attempts:** 3 retries
- **Initial Delay:** 1 second
- **Backoff Factor:** 2x (1s, 2s, 4s)
- **Applies To:** Upload, download, delete operations

### Error Types

- **AuthenticationException** - Authentication failures
- **FileUploadException** - File upload failures
- **FileDownloadException** - File download failures
- **DatabaseException** - Database operation failures
- **NetworkException** - Network connectivity issues

### User-Friendly Messages

All errors are translated to user-friendly messages:
- Technical details logged for debugging
- Simple explanations shown to users
- Actionable suggestions provided when possible

---

## Testing

### Test Coverage

The app has comprehensive test coverage:
- **Unit Tests:** 192+ tests (>85% coverage)
- **Integration Tests:** 38 tests
- **Widget Tests:** 50 tests
- **Total:** 280+ automated tests

### Running Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test suite
flutter test test/services/
flutter test test/integration/
flutter test test/screens/
```

### Test Organization

```
test/
├── integration/        # End-to-end flow tests
├── models/            # Data model tests
├── repositories/      # Repository tests
├── screens/           # Widget tests
└── services/          # Service unit tests
```

See `E2E_TESTING_GUIDE.md` for manual end-to-end testing procedures.

---

## Logging and Debugging

### Viewing Logs

1. Navigate to Settings screen
2. Tap "View Logs" button
3. Filter by log level (info, warning, error)
4. Copy or share logs for support

### Log Levels

- **INFO** - General information (sync started, file uploaded)
- **WARNING** - Non-critical issues (retry attempt, slow operation)
- **ERROR** - Critical failures (upload failed, authentication error)

### Log Retention

- Last 1000 log entries stored locally
- Older entries automatically removed
- Logs can be cleared manually from Logs Viewer

---

## Security

### Authentication
- AWS Cognito User Pools for secure authentication
- Passwords never stored locally
- Session tokens automatically refreshed
- Secure sign out with credential cleanup

### File Storage
- Private S3 access level enforced
- Identity Pool ID-based path isolation
- IAM policies prevent cross-user access
- HTTPS for all S3 operations

### Data Protection
- Local database not encrypted (future enhancement)
- Sensitive information excluded from logs
- No PII stored in error messages

---

## Performance

### Optimization Strategies

- **Lazy Loading** - Documents loaded on demand
- **Debouncing** - Sync operations debounced to prevent excessive calls
- **Caching** - Identity Pool ID cached locally
- **Batch Operations** - Multiple files uploaded in parallel
- **Progress Tracking** - Real-time progress for uploads/downloads

### Resource Management

- **Database Connections** - Singleton pattern for database service
- **Network Requests** - Automatic retry with exponential backoff
- **Memory** - File streams used for large file operations
- **Storage** - Old logs automatically cleaned up

---

## Deployment

### Build for Android

```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release

# App bundle for Google Play
flutter build appbundle --release
```

### Build for iOS

```bash
# Debug build
flutter build ios --debug

# Release build
flutter build ios --release
```

### Pre-Deployment Checklist

- [ ] AWS Amplify configuration verified
- [ ] IAM policies tested with production resources
- [ ] All tests passing
- [ ] Security audit completed
- [ ] Performance testing completed
- [ ] Privacy policy updated
- [ ] App store assets prepared

See `DEPLOYMENT_GUIDE.md` for detailed deployment instructions.

---

## Troubleshooting

### Common Issues

**Authentication fails after app reinstall**
- Identity Pool ID is persistent, no action needed
- User must sign in again with same credentials

**Files not syncing**
- Check network connectivity
- Verify AWS credentials are valid
- Check logs for specific error messages

**Upload/download stuck**
- Pull to refresh to retry sync
- Check file size limits (S3 has 5GB limit per file)
- Verify IAM policies allow S3 access

**App crashes on startup**
- Verify Amplify configuration is present
- Check for database migration issues
- Review logs for error details

### Getting Help

1. Check logs in Settings → View Logs
2. Copy logs and share with support
3. Include device info and app version
4. Describe steps to reproduce issue

---

## Contributing

This is a personal project, but contributions are welcome:
1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

---

## License

This project is open source and available for personal use.

---

## Version History

### v2.0.0 (Current)
- Complete rewrite with clean architecture
- AWS Amplify integration
- Cloud sync with S3 and Identity Pool
- Offline support with automatic sync
- Comprehensive testing (280+ tests)
- Improved error handling and logging

### v1.0.0 (Legacy)
- Basic document management
- Local SQLite storage
- File attachments
- Renewal reminders

---

## Contact

For questions or support, please check the logs first, then contact support with log details.

---

**Last Updated:** January 17, 2026
