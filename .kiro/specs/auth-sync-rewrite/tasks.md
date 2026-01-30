# Implementation Tasks - Authentication & Sync Rewrite

## Overview

This task list provides a step-by-step implementation plan for the authentication and sync rewrite. Tasks are organized into phases, with each task building incrementally on previous work. The implementation follows clean architecture principles and eliminates all technical debt from previous iterations.

---

## Phase 1: Project Setup and Cleanup

### ✅ Task 1.1: Remove Legacy Services and Files

Remove all obsolete services, utilities, and test files from previous iterations.

- Remove legacy migration services: `PersistentFileService`, `FileMigrationMapping`, `UserPoolSubValidator`
- Remove obsolete sync services: `DocumentSyncManager`, `FileAttachmentSyncManager`, `SyncAwareFileManager`, `OfflineSyncQueueService`, `DeletionTrackingService`
- Remove legacy utilities: `FileOperationErrorHandler`, `RetryManager`, `DataIntegrityValidator`, `SecurityValidator`, `FileOperationLogger`
- Remove obsolete models: `FilePath`, `FileMigrationMapping`
- Remove monitoring services: `MonitoringService`, `SyncIdentifierAnalyticsService`, `DataCleanupService`, `FileCacheService`
- Remove test screens: `api_test_screen.dart`, `s3_test_screen.dart`, `upload_download_test_screen.dart`, `minimal_sync_test_screen.dart`
- Remove test utilities: complex `test_helpers.dart`, `*.mocks.dart` files
- Remove obsolete test files for deleted services
- Remove legacy documentation files: `USERNAME_BASED_PATHS_IMPLEMENTATION_COMPLETE.md`, `PERSISTENT_FILE_ACCESS_SPEC_COMPLETE.md`, `S3_ACCESS_DENIED_*.md`, etc.
- Update navigation routes to remove references to deleted screens
- Clean up imports and dependencies

_Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.6, 14.7, 14.8, 14.9, 14.10_

### ✅ Task 1.2: Update Amplify Configuration

Ensure Amplify configuration uses correct settings for Identity Pool integration.

- Verify `amplifyconfiguration.dart` has `defaultAccessLevel: "private"`
- Verify User Pool and Identity Pool are properly configured
- Verify Identity Pool has User Pool as authentication provider
- Test that Identity Pool ID is persistent across app reinstalls
- Document configuration requirements

_Requirements: 2.1, 2.2, 7.2_

### ✅ Task 1.3: Set Up Database Schema

Create clean SQLite database schema for documents and logs.

- Create `documents` table with syncId as primary key
- Create `file_attachments` table with foreign key to documents
- Create `logs` table for application logging
- Add indexes on syncId and sync_state columns
- Create database migration helper
- Test database creation and schema

_Requirements: 3.1, 9.2_

---

## Phase 2: Core Data Models

### ✅ Task 2.1: Create Document Model

Implement the Document data model with all required fields.

- Create `Document` class with syncId, title, description, labels, timestamps, syncState, files
- Add `toJson()` and `fromJson()` methods for serialization
- Add `copyWith()` method for immutable updates
- Add validation logic for required fields
- Create unit tests for Document model

_Requirements: 3.1, 3.3, 11.1_

### ✅ Task 2.2: Create FileAttachment Model

Implement the FileAttachment data model.

- Create `FileAttachment` class with fileName, localPath, s3Key, fileSize, addedAt
- Add `toJson()` and `fromJson()` methods
- Add `copyWith()` method
- Create unit tests for FileAttachment model

_Requirements: 3.2, 4.2_

### ✅ Task 2.3: Create Supporting Models

Implement enums and supporting data models.

- Create `SyncState` enum (synced, pendingUpload, pendingDownload, uploading, downloading, error)
- Create `AuthState` model (isAuthenticated, userEmail, identityPoolId, lastAuthTime)
- Create `SyncResult` model (uploadedCount, downloadedCount, failedCount, errors, duration)
- Create `LogEntry` model (timestamp, level, message, errorDetails, stackTrace)
- Create unit tests for all models

_Requirements: 1.4, 6.4, 9.2_

---

## Phase 3: Authentication Service

### ✅ Task 3.1: Implement AuthenticationService Core

Create the authentication service with User Pool integration.

- Create `AuthenticationService` class as singleton
- Implement `signUp()` method using Amplify Auth
- Implement `signIn()` method using Amplify Auth
- Implement `signOut()` method with credential cleanup
- Implement `isAuthenticated()` check
- Add error handling with custom exceptions
- Create unit tests for authentication methods

_Requirements: 1.1, 1.2, 1.5, 15.1_

### ✅ Task 3.2: Implement Identity Pool Integration

Add Identity Pool ID retrieval and caching.

- Implement `getIdentityPoolId()` method using `Amplify.Auth.fetchAuthSession()`
- Add Identity Pool ID caching with validation
- Implement `getAuthState()` to return current authentication state
- Implement `refreshCredentials()` for token refresh
- Add validation that Identity Pool ID is persistent
- Create unit tests for Identity Pool integration

_Requirements: 1.3, 2.1, 2.2, 2.3, 2.4, 2.5_

### ✅ Task 3.3: Add Authentication State Management

Implement authentication state stream for UI reactivity.

- Create `authStateStream` using StreamController
- Emit auth state changes on sign in/out
- Implement listeners for Amplify auth events
- Add error handling for auth state changes
- Create unit tests for state management

_Requirements: 1.4, 15.1_

---

## Phase 4: Database Repository

### ✅ Task 4.1: Implement DocumentRepository Core

Create the document repository with basic CRUD operations.

- Create `DocumentRepository` class as singleton
- Implement `createDocument()` with UUID generation for syncId
- Implement `getDocument()` by syncId
- Implement `getAllDocuments()` with sorting
- Implement `updateDocument()` with transaction
- Implement `deleteDocument()` with cascade delete
- Add error handling with custom exceptions
- Create unit tests for CRUD operations

_Requirements: 3.1, 3.3, 3.4, 3.5, 15.4_

### ✅ Task 4.2: Implement File Attachment Management

Add file attachment operations to repository.

- Implement `addFileAttachment()` to associate files with documents
- Implement `updateFileS3Key()` to store S3 keys after upload
- Implement `getFileAttachments()` for a document
- Implement `deleteFileAttachment()` for removing files
- Add transaction support for atomic operations
- Create unit tests for file attachment operations

_Requirements: 3.2, 4.2, 5.3_

### ✅ Task 4.3: Implement Sync State Management

Add sync state tracking to repository.

- Implement `updateSyncState()` to change document sync state
- Implement `getDocumentsBySyncState()` to query by state
- Add indexes for efficient sync state queries
- Create unit tests for sync state operations

_Requirements: 4.3, 4.4, 5.4, 6.5, 11.1_

---

## Phase 5: File Service

### ✅ Task 5.1: Implement FileService Core

Create the file service with S3 path generation.

- Create `FileService` class as singleton
- Implement `generateS3Path()` using format: `private/{identityPoolId}/documents/{syncId}/{fileName}`
- Implement `validateS3KeyOwnership()` to verify Identity Pool ID in path
- Add path validation to prevent path traversal
- Create unit tests for path generation and validation

_Requirements: 4.1, 7.1, 7.3, 13.3, 13.4, 15.2_

### ✅ Task 5.2: Implement File Upload

Add S3 file upload functionality.

- Implement `uploadFile()` using Amplify Storage with private access
- Add retry logic with exponential backoff (3 attempts)
- Add progress tracking for uploads
- Add error handling with custom exceptions
- Log all upload operations
- Create unit tests for upload functionality

_Requirements: 4.1, 4.3, 4.4, 7.2, 8.1, 8.3, 15.2_

### ✅ Task 5.3: Implement File Download

Add S3 file download functionality.

- Implement `downloadFile()` using Amplify Storage
- Add retry logic with exponential backoff (3 attempts)
- Add progress tracking for downloads
- Validate S3 key ownership before download
- Add error handling with custom exceptions
- Log all download operations
- Create unit tests for download functionality

_Requirements: 5.1, 5.2, 5.3, 5.4, 7.3, 8.1, 8.3, 15.2_

### ✅ Task 5.4: Implement File Deletion

Add S3 file deletion functionality.

- Implement `deleteFile()` for single file deletion
- Implement `deleteDocumentFiles()` to delete all files for a syncId
- Add retry logic with exponential backoff (3 attempts)
- Add error handling with custom exceptions
- Log all delete operations
- Create unit tests for deletion functionality

_Requirements: 3.5, 7.4, 8.1, 8.3, 15.2_

---

## Phase 6: Sync Service

### ✅ Task 6.1: Implement SyncService Core

Create the sync service with coordination logic.

- Create `SyncService` class as singleton
- Implement `performSync()` to coordinate full sync operation
- Add sync status tracking with StreamController
- Implement `isSyncing` getter
- Add error handling for sync operations
- Create unit tests for sync coordination

_Requirements: 6.1, 6.4, 15.3_

### ✅ Task 6.2: Implement Upload Sync Logic

Add logic to upload pending documents.

- Implement `uploadDocumentFiles()` for specific document
- Query documents with "pendingUpload" state
- Upload files using FileService
- Update S3 keys in DocumentRepository
- Update sync state to "synced" on success
- Update sync state to "error" on failure
- Log sync operations
- Create unit tests for upload sync

_Requirements: 4.1, 4.2, 4.3, 4.4, 6.2, 6.5, 15.3_

### ✅ Task 6.3: Implement Download Sync Logic

Add logic to download missing files.

- Implement `downloadDocumentFiles()` for specific document
- Query documents with S3 keys but no local files
- Download files using FileService
- Update local paths in DocumentRepository
- Update sync state to "synced" on success
- Update sync state to "error" on failure
- Log sync operations
- Create unit tests for download sync

_Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 6.2, 6.5, 15.3_

### ✅ Task 6.4: Implement Automatic Sync Triggers

Add automatic sync triggers for various events.

- Trigger sync on app launch after authentication
- Trigger sync on document creation/modification
- Trigger sync on network connectivity restoration
- Add debouncing to prevent excessive sync operations
- Create unit tests for sync triggers

_Requirements: 6.1, 6.2, 6.3, 15.3_

---

## Phase 7: Logging Service

### ✅ Task 7.1: Implement LogService

Create the logging service for application logs.

- Create `LogService` class as singleton
- Implement `log()` method with log levels (info, warning, error)
- Implement `logError()` with error and stack trace support
- Store logs in SQLite database (last 1000 entries)
- Exclude sensitive information from logs
- Create unit tests for logging

_Requirements: 8.3, 9.1, 9.2, 13.5, 15.5_

### ✅ Task 7.2: Implement Log Retrieval and Export

Add log viewing and export functionality.

- Implement `getRecentLogs()` with limit parameter
- Implement `getLogsByLevel()` for filtering
- Implement `clearLogs()` to remove old entries
- Implement `exportLogs()` to generate shareable log string
- Create unit tests for log retrieval

_Requirements: 9.2, 9.3, 9.4, 15.5_

---

## Phase 8: UI Implementation

### ✅ Task 8.1: Implement Authentication Screens

Create sign up and sign in screens.

- Create `SignUpScreen` with email/password form
- Create `SignInScreen` with email/password form
- Add form validation for email and password
- Integrate with AuthenticationService
- Show loading indicators during authentication
- Display error messages for failed authentication
- Navigate to home screen on successful authentication
- Create widget tests for auth screens

_Requirements: 1.1, 1.2, 12.1_

### ✅ Task 8.2: Implement Document List Screen

Create the main document list screen.

- Create `DocumentListScreen` to display all documents
- Show document title, labels, and sync status
- Add sync status indicators (synced, uploading, downloading, error)
- Add pull-to-refresh for manual sync
- Add floating action button to create new document
- Integrate with DocumentRepository and SyncService
- Create widget tests for document list

_Requirements: 3.3, 6.4, 12.2_

### ✅ Task 8.3: Implement Document Detail Screen

Create document detail and edit screen.

- Create `DocumentDetailScreen` to view/edit document
- Display document metadata (title, description, labels)
- Display attached files with download status
- Add edit functionality for metadata
- Add file attachment functionality (pick files)
- Add delete document functionality
- Integrate with DocumentRepository, FileService, and SyncService
- Create widget tests for document detail

_Requirements: 3.2, 3.3, 3.4, 3.5, 5.5, 12.2_

### ✅ Task 8.4: Implement Settings Screen

Create clean settings screen without test features.

- Create `SettingsScreen` with account information
- Display user email and app version
- Add "View Logs" button to navigate to logs screen
- Add "Sign Out" button with confirmation dialog
- Remove all test features and debug options
- Integrate with AuthenticationService
- Create widget tests for settings screen

_Requirements: 9.1, 9.5, 10.1-10.10, 12.1_

### Task 8.5: Implement Logs Viewer Screen

✅ Create logs viewer screen for debugging.

- Create `LogsViewerScreen` to display app logs
- Show logs with timestamps and severity levels
- Add filtering by log level (info, warning, error)
- Add "Copy Logs" button to copy to clipboard
- Add "Share Logs" button to share via platform share
- Add "Clear Logs" button with confirmation
- Integrate with LogService
- Create widget tests for logs viewer

_Requirements: 9.1, 9.2, 9.3, 9.4, 12.1_

---

## Phase 9: Integration and Error Handling

### Task 9.1: Implement Error Handling

✅ Add comprehensive error handling across all services.

- Create custom exception classes (AuthenticationException, FileUploadException, etc.)
- Implement retry logic with exponential backoff in FileService
- Implement credential refresh on authentication expiration
- Add transaction rollback in DocumentRepository on errors
- Display user-friendly error messages in UI
- Log all errors with context
- Create unit tests for error handling

_Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 15.8_

### Task 9.2: Implement Network Connectivity Handling

✅ Add network connectivity detection and handling.

- Add connectivity monitoring using connectivity_plus package
- Trigger sync when connectivity is restored
- Show offline indicator in UI when no connectivity
- Queue operations when offline (handled by sync states)
- Create unit tests for connectivity handling

_Requirements: 6.3, 8.1_

### Task 9.3: Implement Data Consistency

✅ Ensure data consistency across devices.

- Verify syncId uniqueness across all operations
- Implement last-write-wins for conflict resolution
- Ensure document deletion propagates to S3
- Verify sync state consistency after operations
- Create integration tests for data consistency

_Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

---

## Phase 10: Testing and Validation

### Task 10.1: Write Unit Tests

✅ Create comprehensive unit tests for all services.

- Write unit tests for AuthenticationService (sign up, sign in, sign out, Identity Pool ID)
- Write unit tests for FileService (path generation, upload, download, delete, validation)
- Write unit tests for SyncService (sync coordination, upload sync, download sync)
- Write unit tests for DocumentRepository (CRUD, file attachments, sync states)
- Write unit tests for LogService (logging, retrieval, filtering, export)
- Achieve >80% code coverage for services

_Requirements: 12.1, 12.2, 12.3, 12.4, 12.5_

### Task 10.2: Write Integration Tests

Create integration tests for end-to-end flows.

- Test authentication flow: sign up → sign in → get Identity Pool ID → sign out
- Test document creation and sync: create → attach file → upload → verify S3
- Test multi-device sync: upload on device A → download on device B (simulated)
- Test offline handling: create offline → go online → auto-sync
- Test error recovery: fail upload → retry → success

_Requirements: 1.1, 1.2, 1.3, 4.1, 5.1, 6.1, 8.1_

### Task 10.3: Write Widget Tests

Create widget tests for UI components.

- Test authentication screens (sign up, sign in, validation)
- Test document list screen (display, sync indicators, pull-to-refresh)
- Test document detail screen (view, edit, file attachments, delete)
- Test settings screen (account info, logs, sign out)
- Test logs viewer screen (display, filtering, copy, share)

_Requirements: 1.1, 3.3, 9.1, 10.9_

### Task 10.4: Perform End-to-End Testing

Test complete user workflows manually.

- Test new user sign up and first document creation
- Test document sync across app reinstall (same device)
- Test file upload and download with various file types
- Test offline mode and sync on reconnection
- Test error scenarios (network failures, authentication expiration)
- Test settings and logs functionality
- Verify no test features are visible in settings

_Requirements: All requirements_

---

## Phase 11: Documentation and Deployment

### Task 11.1: Update Documentation

Create user and developer documentation.

- Document authentication flow and Identity Pool ID persistence
- Document sync model and sync states
- Document S3 path format and file organization
- Document error handling and retry logic
- Document database schema and models
- Create API documentation for services
- Update README with setup instructions

_Requirements: 2.1, 4.1, 7.1, 8.1_

### Task 11.2: Prepare for Deployment

Finalize configuration and prepare for release.

- Verify Amplify configuration is correct
- Verify IAM policies allow private access with Identity Pool ID
- Test with production AWS resources
- Perform security audit (credential storage, HTTPS, validation)
- Perform performance testing (large file uploads, many documents)
- Create deployment checklist

_Requirements: 2.1, 7.2, 13.1, 13.2, 13.3, 13.4_

### Task 11.3: Final Validation

Perform final validation before release.

- Run all unit tests and verify passing
- Run all integration tests and verify passing
- Run all widget tests and verify passing
- Perform manual end-to-end testing
- Verify all requirements are met
- Verify all test features are removed
- Verify clean architecture is maintained

_Requirements: All requirements_

---

## Summary

**Total Tasks**: 38 tasks across 11 phases

**Phases**:
1. Project Setup and Cleanup (3 tasks)
2. Core Data Models (3 tasks)
3. Authentication Service (3 tasks)
4. Database Repository (3 tasks)
5. File Service (4 tasks)
6. Sync Service (4 tasks)
7. Logging Service (2 tasks)
8. UI Implementation (5 tasks)
9. Integration and Error Handling (3 tasks)
10. Testing and Validation (4 tasks)
11. Documentation and Deployment (3 tasks)

**Key Milestones**:
- Phase 1-2: Foundation and models
- Phase 3-7: Core services implementation
- Phase 8: UI implementation
- Phase 9: Integration and error handling
- Phase 10: Comprehensive testing
- Phase 11: Documentation and deployment

**Estimated Timeline**: 4-6 weeks for complete implementation

**Next Steps**: Begin with Phase 1, Task 1.1 - Remove legacy services and files
