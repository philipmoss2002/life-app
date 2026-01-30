# Requirements Document - Authentication & Sync Rewrite

## Introduction

This specification defines a complete rewrite of the authentication and file synchronization system for the Household Documents App. The rewrite eliminates technical debt from previous iterations and implements a clean, AWS best-practice architecture. The system uses a simple sync model based on UUID-based syncIds that uniquely identify documents across local and remote storage. No migration features are required as this assumes a fresh start with no existing data.

## Glossary

- **SyncId**: UUID that uniquely identifies a document across local database and remote S3 storage
- **Identity Pool ID**: AWS Cognito federated identity identifier that persists across app reinstalls when authenticated via User Pool
- **User Pool**: AWS Cognito User Pool that manages user authentication and profiles
- **Identity Pool**: AWS Cognito Identity Pool that provides temporary AWS credentials for authenticated users
- **S3 Private Access**: AWS S3 access pattern using Identity Pool ID for user isolation
- **Local Database**: SQLite database storing document metadata and file references
- **Document Metadata**: Document information stored locally (title, description, labels, syncId, S3 key)
- **File Attachment**: Physical file associated with a document, stored in S3
- **Sync State**: Status indicating whether a document is synced, pending upload, or pending download
- **App Logs**: Application logging system for debugging and monitoring

## Requirements

### Requirement 1: User Authentication

**User Story:** As a user, I want to securely sign up and sign in to the app using my email and password, so that I can access my documents from any device.

#### Acceptance Criteria

1. WHEN a user provides valid email and password for sign up, THE system SHALL create a new User Pool account and authenticate the user
2. WHEN a user provides valid credentials for sign in, THE system SHALL authenticate via User Pool and obtain Identity Pool credentials
3. WHEN a user signs in, THE system SHALL retrieve a persistent Identity Pool ID that remains constant across app reinstalls
4. WHEN authentication succeeds, THE system SHALL cache authentication state locally for subsequent app launches
5. WHEN a user signs out, THE system SHALL clear all authentication state and cached credentials

### Requirement 2: Identity Pool Integration

**User Story:** As a system architect, I want authentication to use AWS best practices with proper Identity Pool integration, so that file access is secure and persistent across devices.

#### Acceptance Criteria

1. WHEN a user authenticates via User Pool, THE system SHALL automatically obtain federated Identity Pool credentials
2. WHEN Identity Pool credentials are obtained, THE system SHALL verify the Identity Pool ID is persistent and tied to the User Pool identity
3. WHEN file operations are performed, THE system SHALL use Identity Pool ID for S3 path generation
4. WHEN a user reinstalls the app and signs in, THE system SHALL retrieve the same Identity Pool ID as before
5. WHEN authentication state is checked, THE system SHALL validate both User Pool and Identity Pool credentials are valid

### Requirement 3: Document Management

**User Story:** As a user, I want to create, view, edit, and delete documents with file attachments, so that I can organize my household documents.

#### Acceptance Criteria

1. WHEN a user creates a document, THE system SHALL generate a unique syncId UUID and store metadata in local database
2. WHEN a user attaches a file to a document, THE system SHALL associate the file path with the document's syncId
3. WHEN a user views a document, THE system SHALL display metadata and provide access to attached files
4. WHEN a user edits a document, THE system SHALL update metadata in local database and mark for sync
5. WHEN a user deletes a document, THE system SHALL remove local metadata and mark associated files for deletion from S3

### Requirement 4: File Upload Sync

**User Story:** As a user, I want my document files to automatically upload to cloud storage, so that they are backed up and accessible from other devices.

#### Acceptance Criteria

1. WHEN a file is attached to a document, THE system SHALL upload the file to S3 using path format: `private/{identityPoolId}/documents/{syncId}/{fileName}`
2. WHEN uploading a file, THE system SHALL store the S3 key in local database associated with the document's syncId
3. WHEN a file upload succeeds, THE system SHALL update the document's sync state to "synced"
4. WHEN a file upload fails, THE system SHALL mark the document as "pending upload" and retry on next sync
5. WHEN multiple files are attached to a document, THE system SHALL upload all files and track each S3 key separately

### Requirement 5: File Download Sync

**User Story:** As a user, I want to download documents from cloud storage to my device, so that I can access files that were uploaded from other devices.

#### Acceptance Criteria

1. WHEN a document exists in local database with an S3 key but no local file, THE system SHALL download the file from S3
2. WHEN downloading a file, THE system SHALL use the stored S3 key to retrieve the file from the correct S3 path
3. WHEN a file download succeeds, THE system SHALL store the local file path and update sync state to "synced"
4. WHEN a file download fails, THE system SHALL mark the document as "pending download" and retry on next sync
5. WHEN a user opens a document with pending download, THE system SHALL prioritize downloading that document's files

### Requirement 6: Sync Coordination

**User Story:** As a user, I want the app to automatically sync my documents in the background, so that my files are always up to date without manual intervention.

#### Acceptance Criteria

1. WHEN the app launches and user is authenticated, THE system SHALL perform a sync operation to upload pending files and download new metadata
2. WHEN a document is created or modified, THE system SHALL automatically trigger a sync operation
3. WHEN network connectivity is restored after being offline, THE system SHALL automatically resume sync operations
4. WHEN sync operations are in progress, THE system SHALL display sync status indicators in the UI
5. WHEN sync operations complete, THE system SHALL update all document sync states accordingly

### Requirement 7: S3 File Operations

**User Story:** As a system architect, I want file operations to follow AWS best practices using Identity Pool ID for path generation, so that files are properly isolated per user and accessible across devices.

#### Acceptance Criteria

1. WHEN generating S3 paths, THE system SHALL use format: `private/{identityPoolId}/documents/{syncId}/{fileName}`
2. WHEN uploading files to S3, THE system SHALL use private access level with Identity Pool credentials
3. WHEN downloading files from S3, THE system SHALL validate the Identity Pool ID in the path matches the current user
4. WHEN deleting files from S3, THE system SHALL remove all files associated with a document's syncId
5. WHEN S3 operations fail with access denied, THE system SHALL log detailed error information and retry with exponential backoff

### Requirement 8: Error Handling and Resilience

**User Story:** As a user, I want the app to handle errors gracefully and retry failed operations, so that temporary issues don't result in data loss.

#### Acceptance Criteria

1. WHEN network errors occur during sync, THE system SHALL retry operations with exponential backoff up to 3 attempts
2. WHEN authentication expires during operations, THE system SHALL refresh credentials and retry the operation
3. WHEN S3 operations fail, THE system SHALL log the error with context and mark the operation for retry
4. WHEN local database operations fail, THE system SHALL rollback transactions and preserve data integrity
5. WHEN unrecoverable errors occur, THE system SHALL display user-friendly error messages and log detailed diagnostics

### Requirement 9: Settings and Logging

**User Story:** As a user and developer, I want to view app logs for debugging purposes without clutter from test features, so that I can troubleshoot issues efficiently.

#### Acceptance Criteria

1. WHEN a user navigates to settings, THE system SHALL display options for viewing app logs
2. WHEN app logs are viewed, THE system SHALL display recent log entries with timestamps and severity levels
3. WHEN log entries are displayed, THE system SHALL support filtering by severity level (info, warning, error)
4. WHEN logs are viewed, THE system SHALL provide options to copy or share logs for support purposes
5. WHEN the settings screen is displayed, THE system SHALL NOT include any test or debug features

### Requirement 10: Remove Test Features

**User Story:** As a user, I want a clean settings interface without test features, so that I only see production-ready functionality.

#### Acceptance Criteria

1. WHEN the settings screen is implemented, THE system SHALL NOT include "Subscription Debug" test feature
2. WHEN the settings screen is implemented, THE system SHALL NOT include "API Test" test feature
3. WHEN the settings screen is implemented, THE system SHALL NOT include "Detailed Sync Debug" test feature
4. WHEN the settings screen is implemented, THE system SHALL NOT include "S3 Direct Test" test feature
5. WHEN the settings screen is implemented, THE system SHALL NOT include "S3 Path Debug" test feature
6. WHEN the settings screen is implemented, THE system SHALL NOT include "Upload Download Test" test feature
7. WHEN the settings screen is implemented, THE system SHALL NOT include "Error Trace" test feature
8. WHEN the settings screen is implemented, THE system SHALL NOT include "Minimal Sync Test" test feature
9. WHEN the settings screen is implemented, THE system SHALL only display: account information, app logs viewer, sign out option, and app version
10. WHEN test screens exist in the codebase, THE system SHALL remove all test screen files and navigation routes

### Requirement 11: Data Consistency

**User Story:** As a user, I want my documents to remain consistent across devices, so that I see the same information regardless of which device I use.

#### Acceptance Criteria

1. WHEN a document is synced, THE system SHALL ensure the syncId uniquely identifies the document across all devices
2. WHEN document metadata is updated on one device, THE system SHALL propagate changes to other devices via sync
3. WHEN conflicts occur (same document modified on multiple devices), THE system SHALL use last-write-wins strategy based on modification timestamp
4. WHEN a document is deleted on one device, THE system SHALL propagate the deletion to other devices and remove S3 files
5. WHEN sync completes, THE system SHALL verify all documents have consistent metadata and file references

### Requirement 12: Clean Architecture

**User Story:** As a developer, I want the codebase to follow clean architecture principles with clear separation of concerns, so that the system is maintainable and testable.

#### Acceptance Criteria

1. WHEN implementing authentication, THE system SHALL separate authentication logic from UI components
2. WHEN implementing sync, THE system SHALL use a dedicated sync service that coordinates file operations
3. WHEN implementing file operations, THE system SHALL use a file service that abstracts S3 operations
4. WHEN implementing database operations, THE system SHALL use repository pattern for data access
5. WHEN implementing business logic, THE system SHALL keep services independent and testable with minimal dependencies

### Requirement 13: Security

**User Story:** As a security-conscious user, I want my data to be protected with proper authentication and encryption, so that my documents remain private and secure.

#### Acceptance Criteria

1. WHEN storing credentials locally, THE system SHALL use secure storage mechanisms provided by the platform
2. WHEN transmitting data to S3, THE system SHALL use HTTPS with proper certificate validation
3. WHEN generating S3 paths, THE system SHALL validate Identity Pool ID format to prevent path traversal
4. WHEN accessing files, THE system SHALL verify the current user owns the files based on Identity Pool ID in path
5. WHEN logging operations, THE system SHALL exclude sensitive information such as passwords and tokens


### Requirement 14: Code Cleanup and Legacy File Removal

**User Story:** As a developer, I want to remove obsolete code and files from previous iterations, so that the codebase is clean and maintainable.

#### Acceptance Criteria

1. WHEN implementing the rewrite, THE system SHALL remove all legacy migration-related services and utilities (PersistentFileService, FileMigrationMapping, UserPoolSubValidator, etc.)
2. WHEN implementing the rewrite, THE system SHALL remove all test screen files (api_test_screen.dart, s3_test_screen.dart, upload_download_test_screen.dart, minimal_sync_test_screen.dart, etc.)
3. WHEN implementing the rewrite, THE system SHALL remove obsolete sync services (DocumentSyncManager, FileAttachmentSyncManager, SyncAwareFileManager, OfflineSyncQueueService, DeletionTrackingService, etc.)
4. WHEN implementing the rewrite, THE system SHALL remove legacy file operation utilities (FileOperationErrorHandler, RetryManager, DataIntegrityValidator, SecurityValidator, FileOperationLogger, etc.)
5. WHEN implementing the rewrite, THE system SHALL remove obsolete models (FilePath, FileMigrationMapping, etc.)
6. WHEN implementing the rewrite, THE system SHALL remove monitoring and analytics services that are not part of the core functionality (MonitoringService, SyncIdentifierAnalyticsService, etc.)
7. WHEN implementing the rewrite, THE system SHALL remove all test utility files and mock files (test_helpers.dart with complex mocking, *.mocks.dart files, etc.)
8. WHEN implementing the rewrite, THE system SHALL remove legacy documentation files related to previous implementations (USERNAME_BASED_PATHS_IMPLEMENTATION_COMPLETE.md, PERSISTENT_FILE_ACCESS_SPEC_COMPLETE.md, S3_ACCESS_DENIED_*.md, etc.)
9. WHEN implementing the rewrite, THE system SHALL remove obsolete test files for removed services
10. WHEN implementing the rewrite, THE system SHALL update or remove any navigation routes, imports, and dependencies that reference deleted files

### Requirement 15: Simplified Service Layer

**User Story:** As a developer, I want a simplified service layer with only essential services, so that the architecture is easy to understand and maintain.

#### Acceptance Criteria

1. WHEN implementing the rewrite, THE system SHALL have exactly one authentication service for User Pool and Identity Pool operations
2. WHEN implementing the rewrite, THE system SHALL have exactly one file service for S3 upload, download, and delete operations
3. WHEN implementing the rewrite, THE system SHALL have exactly one sync service for coordinating file synchronization
4. WHEN implementing the rewrite, THE system SHALL have exactly one database repository for document metadata operations
5. WHEN implementing the rewrite, THE system SHALL have exactly one logging service for app logs (no separate monitoring, analytics, or tracking services)
6. WHEN implementing the rewrite, THE system SHALL NOT include any services for migration, legacy file detection, or backward compatibility
7. WHEN implementing the rewrite, THE system SHALL NOT include any services for complex error handling frameworks (circuit breakers, operation queuing, etc.)
8. WHEN implementing the rewrite, THE system SHALL use simple try-catch with retry logic instead of complex error handling utilities
9. WHEN implementing the rewrite, THE system SHALL keep all services focused on a single responsibility
10. WHEN implementing the rewrite, THE system SHALL ensure services have minimal dependencies on each other
