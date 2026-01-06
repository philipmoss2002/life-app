# Design Document

## Overview

This design document outlines the architectural refactor of the cloud synchronization system to use universal sync identifiers instead of database-specific IDs. The current system suffers from ID mismatches between local SQLite (integer IDs) and remote DynamoDB (UUID IDs), causing sync failures, duplicates, and file path issues. The new design introduces a UUID-based sync identifier that serves as the universal document identifier across all storage systems.

## Architecture

### Current Architecture Issues

The existing sync system has several critical flaws:

1. **ID Mismatch**: Local documents use auto-increment integers while remote uses UUIDs
2. **File Path Dependencies**: S3 keys embed local document IDs, breaking when IDs change
3. **Duplicate Detection**: Relies on fragile content matching instead of stable identifiers
4. **Deletion Tracking**: Cannot reliably identify which remote document to delete
5. **Conflict Resolution**: Struggles to match conflicting versions of the same document

### New Architecture

The refactored architecture introduces a **Sync Identifier Layer** that abstracts document identity from storage implementation:

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
├─────────────────────────────────────────────────────────────┤
│                 Sync Identifier Layer                       │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ Document Matcher│  │ Sync Coordinator│  │ ID Generator│ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                    Storage Layer                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ Local Storage   │  │ Remote Storage  │  │ File Storage│ │
│  │ (SQLite)        │  │ (DynamoDB)      │  │ (S3)        │ │
│  │ syncId: UUID    │  │ syncId: UUID    │  │ Key: syncId │ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Sync Identifier Generator

**Purpose**: Generate and validate universal sync identifiers

```dart
class SyncIdentifierGenerator {
  /// Generate a new UUID v4 sync identifier
  static String generate() => const Uuid().v4();
  
  /// Validate sync identifier format
  static bool isValid(String syncId) => 
    RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
      .hasMatch(syncId.toLowerCase());
  
  /// Normalize sync identifier format
  static String normalize(String syncId) => syncId.toLowerCase();
}
```

### 2. Document Matcher

**Purpose**: Match documents across storage systems using sync identifiers

```dart
class DocumentMatcher {
  /// Match documents by sync identifier (primary method)
  static Document? matchBySyncId(List<Document> documents, String syncId);
  
  /// Calculate content hash for change detection
  static String calculateContentHash(Document document);
}
```

### 3. Sync Coordinator

**Purpose**: Orchestrate sync operations using sync identifiers

```dart
class SyncCoordinator {
  /// Sync a document using its sync identifier
  Future<void> syncDocument(String syncId, SyncOperationType operation);
  
  /// Process sync queue with sync identifier consolidation
  Future<void> processSyncQueue();
  
  /// Resolve conflicts using sync identifiers
  Future<void> resolveConflict(String syncId, ConflictResolution strategy);
  
  /// Track deletion using tombstones
  Future<void> trackDeletion(String syncId);
}
```

### 4. Migration Manager

**Purpose**: Migrate existing data to use sync identifiers

```dart
class MigrationManager {
  /// Migrate local documents to include sync identifiers
  Future<MigrationResult> migrateLocalDocuments();
  
  /// Re-create previously synced documents in remote storage with sync identifiers
  Future<MigrationResult> recreateRemoteDocuments();
  
  /// Migrate file attachments to use sync identifier paths
  Future<MigrationResult> migrateFileAttachments();
  
  /// Validate migration completeness
  Future<bool> validateMigration();
}
```

## Data Models

### Enhanced Document Model

```dart
class Document extends amplify_core.Model {
  final String id;              // Local database ID (SQLite auto-increment)
  final String syncId;          // Universal sync identifier (UUID v4)
  final String userId;          // User identifier
  final String title;           // Document title
  final String category;        // Document category
  final List<String> filePaths; // File attachment paths (S3 keys)
  final TemporalDateTime createdAt;
  final TemporalDateTime lastModified;
  final int version;            // Version for conflict detection
  final String syncState;       // Current sync state
  final String? conflictId;     // Conflict tracking identifier
  final bool deleted;           // Soft deletion flag
  final TemporalDateTime? deletedAt;
  final String contentHash;     // Hash for change detection
}
```

### Tombstone Model

```dart
class DocumentTombstone {
  final String syncId;          // Sync identifier of deleted document
  final String userId;          // User who deleted the document
  final TemporalDateTime deletedAt;
  final String deletedBy;       // Device/session that performed deletion
  final String reason;          // Deletion reason (user, system, etc.)
}
```

### File Attachment Model

```dart
class FileAttachment {
  final String id;              // Local attachment ID
  final String syncId;          // Document sync identifier (foreign key)
  final String fileName;        // Original file name
  final String localPath;       // Local file system path
  final String s3Key;           // S3 storage key (includes syncId)
  final String? label;          // User-defined label
  final TemporalDateTime addedAt;
  final int fileSize;           // File size in bytes
  final String contentType;     // MIME type
  final String checksum;        // File integrity checksum
}
```

### Sync Operation Model

```dart
class SyncOperation {
  final String id;              // Operation ID
  final String syncId;          // Document sync identifier
  final SyncOperationType type; // upload, update, delete
  final DateTime queuedAt;      // When operation was queued
  final int retryCount;         // Number of retry attempts
  final Map<String, dynamic>? metadata; // Operation-specific data
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Sync Identifier Uniqueness
*For any* user's document collection, all sync identifiers should be unique within that collection
**Validates: Requirements 9.5**

### Property 2: Sync Identifier Immutability
*For any* document, once a sync identifier is assigned, it should never change throughout the document's lifetime
**Validates: Requirements 1.5**

### Property 3: Document Matching by Sync Identifier
*For any* document with a sync identifier, matching should always use the sync identifier as the primary criterion
**Validates: Requirements 2.1**

### Property 4: File Path Sync Identifier Consistency
*For any* file attachment, the S3 key should contain the document's sync identifier, ensuring files remain accessible regardless of local ID changes
**Validates: Requirements 4.1, 4.3**

### Property 5: Deletion Tombstone Preservation
*For any* deleted document, a tombstone with the sync identifier should exist until the tombstone is purged, preventing document reinstatement
**Validates: Requirements 5.3, 5.4**

### Property 6: Migration Data Preservation
*For any* document migrated to use sync identifiers, all original document data and relationships should be preserved
**Validates: Requirements 3.5**

### Property 7: Sync Queue Consolidation
*For any* sync identifier with multiple queued operations, the operations should be consolidated into the most recent state
**Validates: Requirements 7.5**

### Property 8: Conflict Resolution Identity Preservation
*For any* conflict resolution, the original document's sync identifier should be preserved in the resolved document
**Validates: Requirements 6.3**

### Property 9: API Sync Identifier Consistency
*For any* sync API operation, if a sync identifier is provided as input, the same sync identifier should be referenced in the output or events
**Validates: Requirements 14.1, 14.3**

### Property 10: Validation Rejection
*For any* invalid sync identifier format, the system should reject the operation and not store the invalid identifier
**Validates: Requirements 9.2**

## Error Handling

### Sync Identifier Validation Errors

- **Invalid Format**: Reject operations with malformed UUIDs
- **Duplicate Detection**: Prevent duplicate sync identifiers within user collections
- **Missing Identifier**: Handle documents without sync identifiers gracefully during migration

### Migration Errors

- **Partial Migration**: Handle cases where some documents fail to migrate
- **Remote Lookup Failures**: Handle network errors during remote sync identifier retrieval
- **Data Corruption**: Detect and handle corrupted sync identifiers

### Sync Operation Errors

- **Identifier Mismatch**: Handle cases where local and remote sync identifiers don't match
- **Orphaned Files**: Handle file attachments with invalid sync identifiers
- **Tombstone Conflicts**: Handle cases where tombstones conflict with active documents

## Testing Strategy

### Unit Testing

- **Sync Identifier Generation**: Test UUID v4 format and uniqueness
- **Document Matching**: Test matching logic with various document combinations
- **Migration Logic**: Test migration of documents with and without sync identifiers
- **Validation**: Test sync identifier format validation

### Property-Based Testing

Each correctness property will be implemented as a property-based test:

1. **Property 1 Test**: Generate random document collections and verify sync identifier uniqueness
2. **Property 2 Test**: Generate document lifecycle operations and verify sync identifier immutability
3. **Property 3 Test**: Generate matching document pairs and verify consistency between matching methods
4. **Property 4 Test**: Generate file attachments and verify S3 key contains correct sync identifier
5. **Property 5 Test**: Generate deletion operations and verify tombstone creation and persistence
6. **Property 6 Test**: Generate migration scenarios and verify data preservation
7. **Property 7 Test**: Generate multiple sync operations and verify queue consolidation
8. **Property 8 Test**: Generate conflict scenarios and verify identity preservation
9. **Property 9 Test**: Generate API operations and verify sync identifier consistency
10. **Property 10 Test**: Generate invalid sync identifiers and verify rejection

### Integration Testing

- **End-to-End Sync**: Test complete sync cycles with sync identifiers
- **Migration Testing**: Test migration of real data sets
- **Conflict Resolution**: Test conflict resolution with sync identifiers
- **File Attachment Sync**: Test file sync with sync identifier-based paths

### Performance Testing

- **Sync Identifier Lookup**: Measure performance of sync identifier-based queries
- **Migration Performance**: Measure time to migrate large document collections
- **Duplicate Detection**: Measure performance of duplicate detection algorithms
- **Batch Operations**: Test batch sync operations with sync identifiers

The testing strategy ensures that the sync identifier refactor maintains data integrity while improving sync reliability and performance.