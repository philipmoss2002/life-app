# Requirements Document

## Introduction

This specification addresses a critical architectural issue in the cloud synchronization system where document identification relies on database-specific identifiers (local SQLite integer IDs vs remote DynamoDB UUIDs). This causes sync failures, document duplication, deletion issues, and file path mismatches. The refactor introduces a universal sync identifier that is independent of storage implementation, enabling reliable document matching and synchronization across local and remote storage systems.

## Glossary

- **Sync Identifier**: A universally unique identifier (UUID) assigned to each document at creation time, independent of database implementation
- **Local Database**: SQLite database storing documents with auto-increment integer primary keys
- **Remote Database**: AWS DynamoDB storing documents with UUID primary keys
- **Document Matching**: The process of determining if a local document and remote document represent the same logical entity
- **Duplicate Detection**: Identifying when multiple database records represent the same logical document
- **Sync State**: The current synchronization status of a document (notSynced, pending, syncing, synced, conflict, error, pendingDeletion)
- **File Attachment**: Files associated with a document, stored in local file system and S3
- **S3 Key**: The path identifier for files stored in AWS S3
- **Content Hash**: A cryptographic hash of document content used for change detection
- **Tombstone**: A deletion marker that indicates a document has been deleted but needs to be tracked for sync purposes

## Requirements

### Requirement 1: Universal Sync Identifier

**User Story:** As a developer, I want every document to have a universal sync identifier, so that the system can reliably match documents across local and remote storage regardless of database implementation.

#### Acceptance Criteria

1. WHEN a document is created, THE system SHALL generate a UUID v4 sync identifier
2. WHEN a document is stored locally, THE system SHALL persist the sync identifier in the local database
3. WHEN a document is uploaded to remote storage, THE system SHALL include the sync identifier in the remote record
4. WHEN comparing documents, THE system SHALL use the sync identifier as the primary matching criterion
5. THE sync identifier SHALL remain immutable throughout the document's lifetime

### Requirement 2: Document Matching Logic

**User Story:** As a premium user, I want the sync system to correctly identify when local and remote documents are the same, so that I don't get duplicate documents or sync failures.

#### Acceptance Criteria

1. WHEN syncing from remote, THE system SHALL match documents by sync identifier first
2. IF no sync identifier match is found, THEN THE system SHALL use content-based matching as a fallback
3. WHEN content-based matching is used, THE system SHALL compare userId, title, category, and creation timestamp
4. WHEN a match is found, THE system SHALL update the local document with the remote sync identifier
5. WHEN no match is found, THE system SHALL create a new local document with the remote sync identifier

### Requirement 3: Database Schema Migration

**User Story:** As a developer, I want the local database schema updated to include the sync identifier, so that existing documents can be migrated without data loss.

#### Acceptance Criteria

1. WHEN the app updates, THE system SHALL add a syncId column to the documents table
2. WHEN migrating existing documents, THE system SHALL generate sync identifiers for documents without one
3. WHEN a document has been synced previously, THE system SHALL attempt to retrieve the sync identifier from remote storage
4. WHEN migration completes, THE system SHALL create a unique index on the syncId column
5. THE migration SHALL preserve all existing document data and relationships

### Requirement 4: File Path Independence

**User Story:** As a premium user, I want file attachments to sync correctly regardless of local document ID changes, so that my files are always accessible.

#### Acceptance Criteria

1. WHEN generating S3 keys for files, THE system SHALL use the sync identifier instead of the local database ID
2. WHEN downloading files, THE system SHALL construct S3 keys using the sync identifier
3. WHEN a document's local ID changes, THE file paths SHALL remain valid using the sync identifier
4. WHEN storing file attachments locally, THE system SHALL record both the local path and the S3 key
5. THE FileAttachment table SHALL reference documents by sync identifier

### Requirement 5: Deletion Tracking

**User Story:** As a premium user, I want deleted documents to stay deleted across all devices, so that documents I remove don't reappear during sync.

#### Acceptance Criteria

1. WHEN a document is deleted locally, THE system SHALL mark it with pendingDeletion state and preserve the sync identifier
2. WHEN syncing deletions, THE system SHALL use the sync identifier to identify the remote document to delete
3. WHEN a deletion is confirmed remotely, THE system SHALL create a tombstone record with the sync identifier
4. WHEN syncing from remote, THE system SHALL check tombstones to prevent reinstating deleted documents
5. THE system SHALL purge tombstones older than 90 days to prevent unbounded growth

### Requirement 6: Conflict Resolution

**User Story:** As a premium user, I want conflicts resolved correctly when I edit the same document on multiple devices, so that I don't lose changes or create duplicates.

#### Acceptance Criteria

1. WHEN detecting conflicts, THE system SHALL compare documents by sync identifier
2. WHEN a conflict is detected, THE system SHALL compare version numbers and last modified timestamps
3. WHEN resolving conflicts, THE system SHALL preserve the sync identifier of the original document
4. WHEN creating conflict copies, THE system SHALL generate new sync identifiers for the copies
5. THE system SHALL notify the user of conflicts using the document's sync identifier for tracking

### Requirement 7: Sync Queue Operations

**User Story:** As a premium user, I want sync operations to be queued and processed reliably, so that my changes are eventually synchronized even with intermittent connectivity.

#### Acceptance Criteria

1. WHEN queueing sync operations, THE system SHALL reference documents by sync identifier
2. WHEN processing the sync queue, THE system SHALL use sync identifiers to locate documents
3. WHEN a document is deleted before sync completes, THE system SHALL still process the deletion using the sync identifier
4. WHEN retrying failed operations, THE system SHALL use the sync identifier to ensure idempotency
5. THE sync queue SHALL consolidate multiple operations for the same sync identifier

### Requirement 8: Remote Document Model

**User Story:** As a developer, I want the remote document model to use sync identifiers as the primary key, so that document identification is consistent across the system.

#### Acceptance Criteria

1. WHEN creating the DynamoDB schema, THE system SHALL use syncId as the partition key
2. WHEN uploading documents, THE system SHALL set the syncId field in DynamoDB
3. WHEN querying documents, THE system SHALL filter by userId and use syncId for specific lookups
4. WHEN updating documents, THE system SHALL use syncId to identify the document to update
5. THE DynamoDB schema SHALL include a global secondary index on userId for efficient user queries

### Requirement 9: Migration Strategy for Existing Data

**User Story:** As a premium user with existing synced documents, I want my data migrated to the new sync identifier system, so that I don't lose access to my documents or create duplicates.

#### Acceptance Criteria

1. WHEN the app updates, THE system SHALL detect documents without sync identifiers
2. WHEN migrating synced documents, THE system SHALL query remote storage using the current document ID
3. IF a remote document is found, THEN THE system SHALL extract and store its sync identifier locally
4. IF no remote document is found, THEN THE system SHALL generate a new sync identifier and mark the document as notSynced
5. THE migration SHALL run in the background and provide progress feedback to the user

### Requirement 10: Sync Identifier Validation

**User Story:** As a developer, I want sync identifiers validated to ensure data integrity, so that invalid identifiers don't cause sync failures.

#### Acceptance Criteria

1. WHEN receiving a sync identifier, THE system SHALL validate it is a valid UUID v4 format
2. WHEN a sync identifier is invalid, THE system SHALL reject the operation and log an error
3. WHEN generating sync identifiers, THE system SHALL use a cryptographically secure random number generator
4. WHEN storing sync identifiers, THE system SHALL normalize the format (lowercase, with hyphens)
5. THE system SHALL prevent duplicate sync identifiers within a user's document collection

### Requirement 11: Analytics and Monitoring

**User Story:** As a developer, I want detailed analytics on sync identifier usage, so that I can monitor the migration and identify issues.

#### Acceptance Criteria

1. WHEN documents are created, THE system SHALL track whether they have sync identifiers
2. WHEN sync operations complete, THE system SHALL log the sync identifier used
3. WHEN migration runs, THE system SHALL track success and failure rates
4. WHEN sync failures occur, THE system SHALL include the sync identifier in error logs
5. THE system SHALL provide metrics on documents with and without sync identifiers

### Requirement 12: Backward Compatibility

**User Story:** As a user, I want the app to continue working during the migration period, so that I can access my documents without interruption.

#### Acceptance Criteria

1. WHEN a document lacks a sync identifier, THE system SHALL fall back to legacy matching logic
2. WHEN syncing with older app versions, THE system SHALL handle documents without sync identifiers gracefully
3. WHEN the migration is incomplete, THE system SHALL continue to support both identifier schemes
4. WHEN all documents have sync identifiers, THE system SHALL disable legacy matching logic
5. THE system SHALL provide a migration status indicator in settings

### Requirement 13: Content-Based Duplicate Detection

**User Story:** As a premium user, I want the system to detect duplicates created before sync identifiers were implemented, so that I can merge or remove duplicate documents.

#### Acceptance Criteria

1. WHEN scanning for duplicates, THE system SHALL compare documents by userId, title, category, and creation date
2. WHEN duplicates are detected, THE system SHALL present them to the user for review
3. WHEN the user merges duplicates, THE system SHALL preserve the sync identifier of the kept document
4. WHEN the user deletes a duplicate, THE system SHALL ensure the deletion is synced using the correct sync identifier
5. THE system SHALL provide a duplicate detection tool in settings

### Requirement 14: Sync Identifier in File Attachments

**User Story:** As a premium user, I want file attachments to be associated with documents using sync identifiers, so that files remain correctly linked even when document IDs change.

#### Acceptance Criteria

1. WHEN creating file attachments, THE system SHALL store the document's sync identifier
2. WHEN querying file attachments, THE system SHALL use the sync identifier to find associated files
3. WHEN a document's local ID changes, THE file attachments SHALL remain accessible via sync identifier
4. WHEN syncing file attachments, THE system SHALL use the sync identifier in S3 key paths
5. THE FileAttachment table SHALL have a foreign key relationship using sync identifier

### Requirement 15: Sync State Transitions

**User Story:** As a premium user, I want sync state transitions to be tracked correctly using sync identifiers, so that I can see accurate sync status for my documents.

#### Acceptance Criteria

1. WHEN updating sync state, THE system SHALL identify documents by sync identifier
2. WHEN a document transitions to pendingDeletion, THE system SHALL preserve the sync identifier for remote deletion
3. WHEN sync state changes, THE system SHALL emit events including the sync identifier
4. WHEN querying documents by sync state, THE system SHALL use sync identifiers for filtering
5. THE sync state history SHALL be tracked using sync identifiers for debugging

### Requirement 16: API Contract Updates

**User Story:** As a developer, I want the sync API contracts updated to use sync identifiers, so that all sync operations are consistent and reliable.

#### Acceptance Criteria

1. WHEN calling sync methods, THE API SHALL accept sync identifiers as parameters
2. WHEN returning sync results, THE API SHALL include sync identifiers in response objects
3. WHEN emitting sync events, THE system SHALL include sync identifiers in event payloads
4. WHEN handling errors, THE system SHALL reference documents by sync identifier in error messages
5. THE API documentation SHALL specify sync identifier requirements for all methods

### Requirement 17: Testing and Validation

**User Story:** As a developer, I want comprehensive tests for sync identifier functionality, so that I can ensure the refactor works correctly.

#### Acceptance Criteria

1. WHEN running unit tests, THE system SHALL verify sync identifier generation and validation
2. WHEN running integration tests, THE system SHALL verify document matching using sync identifiers
3. WHEN running migration tests, THE system SHALL verify existing data is migrated correctly
4. WHEN running sync tests, THE system SHALL verify operations work with sync identifiers
5. THE test suite SHALL include property-based tests for sync identifier uniqueness and format
