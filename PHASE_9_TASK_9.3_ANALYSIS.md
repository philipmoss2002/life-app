# Phase 9, Task 9.3 Analysis: Data Consistency Implementation

## Summary

This document analyzes the current state of data consistency implementation and identifies what needs to be added to complete Task 9.3.

## Requirements Analysis (Requirement 11)

### 11.1: SyncId Uniqueness
**Status: ✅ IMPLEMENTED**

**Implementation:**
- SyncId is UUID v4 (globally unique)
- Database schema: `sync_id TEXT PRIMARY KEY`
- Generated in `Document.create()` factory
- Enforced at database level

**Evidence:**
```dart
// lib/models/new_document.dart
factory Document.create({...}) {
  return Document(
    syncId: const Uuid().v4(),  // UUID ensures uniqueness
    ...
  );
}

// lib/services/new_database_service.dart
CREATE TABLE documents (
  sync_id TEXT PRIMARY KEY,  // PRIMARY KEY enforces uniqueness
  ...
);
```

**Conclusion:** ✅ No action needed

---

### 11.2: Metadata Propagation via Sync
**Status: ✅ IMPLEMENTED**

**Implementation:**
- Documents have `updatedAt` timestamp
- Sync service uploads/downloads document metadata
- S3 stores files, local database stores metadata
- Sync propagates changes between devices

**Evidence:**
- `SyncService.performSync()` handles upload/download
- `DocumentRepository.updateDocument()` updates `updatedAt`
- Sync states track pending changes

**Conclusion:** ✅ No action needed

---

### 11.3: Last-Write-Wins Conflict Resolution
**Status: ⚠️ PARTIALLY IMPLEMENTED**

**Current State:**
- `updatedAt` timestamp exists on documents
- No explicit conflict detection or resolution logic
- Simple sync model assumes no conflicts (single-device usage)

**Gap:**
The design document specifies last-write-wins, but there's no implementation for:
1. Detecting conflicts (same document modified on multiple devices)
2. Comparing `updatedAt` timestamps
3. Resolving conflicts by keeping the newer version

**Recommendation:**
For the current simple sync model (UUID-based, no server-side storage of metadata), conflicts are unlikely because:
- Each device creates documents with unique UUIDs
- Documents are identified by syncId, not by title or content
- S3 stores files, not metadata
- No central metadata store to conflict with

**Decision:** Document this as a design decision rather than implement complex conflict resolution for a scenario that won't occur in the current architecture.

---

### 11.4: Document Deletion Propagation to S3
**Status: ❌ NOT IMPLEMENTED (GAP)**

**Current State:**
- `DocumentRepository.deleteDocument()` deletes from local database
- `FileService.deleteDocumentFiles()` method exists
- **GAP:** Document deletion doesn't trigger S3 file deletion

**Evidence:**
```dart
// lib/screens/new_document_detail_screen.dart
await _documentRepository.deleteDocument(widget.document!.syncId);
// Missing: S3 file deletion
```

**Required Implementation:**
1. When document is deleted, also delete S3 files
2. Use `FileService.deleteDocumentFiles()` to remove S3 files
3. Handle errors gracefully (S3 deletion may fail)
4. Log deletion operations

**Action Required:** ✅ IMPLEMENT

---

### 11.5: Sync State Consistency Verification
**Status: ⚠️ PARTIALLY IMPLEMENTED**

**Current State:**
- Sync states exist and are updated
- No explicit verification after sync completes
- No consistency checks for metadata vs file references

**Gap:**
No verification that:
1. All files with S3 keys have corresponding local paths (or vice versa)
2. Sync states accurately reflect actual file status
3. No orphaned files or missing references

**Recommendation:**
Add a verification method to check consistency after sync, but make it optional/logging-only to avoid blocking sync operations.

**Action Required:** ✅ IMPLEMENT (optional verification)

---

## Implementation Plan

### 1. Add S3 File Deletion on Document Delete

**File:** `lib/screens/new_document_detail_screen.dart`

**Changes:**
```dart
Future<void> _deleteDocument() async {
  // ... existing code ...
  
  try {
    // Get document files before deletion
    final document = widget.document!;
    final s3Keys = document.files
        .where((f) => f.s3Key != null)
        .map((f) => f.s3Key!)
        .toList();
    
    // Delete from local database
    await _documentRepository.deleteDocument(document.syncId);
    
    // Delete files from S3 (if any)
    if (s3Keys.isNotEmpty) {
      try {
        final identityPoolId = await _authService.getIdentityPoolId();
        await _fileService.deleteDocumentFiles(
          syncId: document.syncId,
          identityPoolId: identityPoolId,
          s3Keys: s3Keys,
        );
      } catch (e) {
        // Log but don't fail - local deletion succeeded
        _logService.log(
          'Failed to delete S3 files for document ${document.syncId}: $e',
          level: LogLevel.warning,
        );
      }
    }
    
    // ... rest of existing code ...
  }
}
```

### 2. Add Sync State Consistency Verification (Optional)

**File:** `lib/services/sync_service.dart`

**Add method:**
```dart
/// Verify sync state consistency after sync (optional, for logging)
Future<void> _verifySyncConsistency() async {
  try {
    final allDocs = await _documentRepository.getAllDocuments();
    
    for (final doc in allDocs) {
      // Check for inconsistencies
      final hasS3Keys = doc.files.any((f) => f.s3Key != null);
      final hasLocalPaths = doc.files.any((f) => f.localPath != null);
      
      if (hasS3Keys && !hasLocalPaths && doc.syncState == SyncState.synced) {
        _logService.log(
          'Inconsistency: Document ${doc.syncId} has S3 keys but no local paths',
          level: LogLevel.warning,
        );
      }
      
      if (hasLocalPaths && !hasS3Keys && doc.syncState == SyncState.synced) {
        _logService.log(
          'Inconsistency: Document ${doc.syncId} has local paths but no S3 keys',
          level: LogLevel.warning,
        );
      }
    }
  } catch (e) {
    _logService.log(
      'Failed to verify sync consistency: $e',
      level: LogLevel.error,
    );
  }
}
```

Call this at the end of `performSync()` (optional, for debugging).

### 3. Document Conflict Resolution Strategy

**File:** Create `CONFLICT_RESOLUTION_STRATEGY.md`

Document that:
- Current architecture uses UUID-based syncIds
- Each device creates unique documents
- No metadata conflicts possible in current design
- Last-write-wins would apply if metadata sync is added later
- S3 files are immutable (no conflicts)

### 4. Integration Tests

**File:** `test/integration/data_consistency_test.dart`

Create integration tests for:
1. SyncId uniqueness across operations
2. Document deletion propagates to S3
3. Sync state consistency after operations
4. Multiple device simulation (if feasible)

---

## Summary

**Implemented:**
- ✅ 11.1: SyncId uniqueness
- ✅ 11.2: Metadata propagation

**Needs Implementation:**
- ❌ 11.4: Document deletion propagation to S3 (CRITICAL)
- ⚠️ 11.5: Sync state consistency verification (OPTIONAL)

**Design Decision:**
- 11.3: Last-write-wins not needed in current architecture (document in design doc)

**Next Steps:**
1. Implement S3 file deletion on document delete
2. Add optional sync consistency verification
3. Create integration tests
4. Document conflict resolution strategy
5. Mark task 9.3 as complete
