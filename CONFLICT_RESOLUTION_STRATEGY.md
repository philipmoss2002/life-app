# Conflict Resolution Strategy

## Overview

This document explains the conflict resolution strategy for the Household Documents App authentication and sync rewrite.

## Architecture Summary

The app uses a **UUID-based sync model** with the following characteristics:

- **SyncId**: Each document has a globally unique UUID (v4) as its primary identifier
- **Local Storage**: SQLite database stores document metadata
- **Remote Storage**: AWS S3 stores file attachments
- **No Central Metadata Store**: S3 only stores files, not document metadata
- **Single-Device Primary Usage**: Each device creates and manages its own documents

## Conflict Scenarios

### Scenario 1: Document Creation Conflicts
**Situation:** Two devices create documents simultaneously

**Resolution:** ✅ NO CONFLICT
- Each device generates a unique UUID for the syncId
- UUIDs are globally unique (collision probability: ~10^-18)
- Both documents coexist as separate entities
- No conflict possible

### Scenario 2: Document Metadata Modification
**Situation:** Same document modified on multiple devices

**Resolution:** ⚠️ UNLIKELY IN CURRENT ARCHITECTURE
- Current design assumes single-device usage
- No mechanism to sync metadata between devices
- S3 only stores files, not metadata
- If implemented later, would use last-write-wins based on `updatedAt` timestamp

### Scenario 3: File Upload Conflicts
**Situation:** Same file uploaded from multiple devices

**Resolution:** ✅ NO CONFLICT
- S3 paths include syncId: `private/{identityPoolId}/documents/{syncId}/{fileName}`
- Each document has unique syncId
- Files are immutable once uploaded
- Overwriting same file path is idempotent (last write wins)

### Scenario 4: Document Deletion Conflicts
**Situation:** Document deleted on one device, modified on another

**Resolution:** ⚠️ UNLIKELY IN CURRENT ARCHITECTURE
- No metadata sync means devices don't know about each other's deletions
- S3 files are deleted when document is deleted locally
- If device A deletes and device B modifies, they operate independently
- No conflict resolution needed in current design

## Last-Write-Wins Strategy

### When It Would Apply

If metadata synchronization is added in the future, last-write-wins would work as follows:

1. **Timestamp Comparison**: Compare `updatedAt` timestamps
2. **Keep Newer**: Keep the version with the later timestamp
3. **Discard Older**: Discard the version with the earlier timestamp
4. **Update Sync State**: Mark document for re-sync if needed

### Implementation (Future)

```dart
Document resolveConflict(Document local, Document remote) {
  // Compare timestamps
  if (local.updatedAt.isAfter(remote.updatedAt)) {
    return local;  // Local is newer
  } else {
    return remote;  // Remote is newer or same
  }
}
```

## Current Implementation

### What's Implemented

1. ✅ **SyncId Uniqueness**: UUID v4 + PRIMARY KEY constraint
2. ✅ **Timestamp Tracking**: `updatedAt` field on all documents
3. ✅ **File Immutability**: S3 files are write-once
4. ✅ **Deletion Propagation**: S3 files deleted when document deleted

### What's NOT Implemented (By Design)

1. ❌ **Metadata Sync**: No server-side metadata storage
2. ❌ **Conflict Detection**: No mechanism to detect conflicts
3. ❌ **Conflict Resolution**: No automatic resolution logic
4. ❌ **Multi-Device Coordination**: No device-to-device communication

## Design Rationale

### Why No Conflict Resolution?

1. **Simple Architecture**: UUID-based model avoids conflicts by design
2. **Single-Device Usage**: App designed for single-device primary usage
3. **No Central Metadata**: S3 stores files only, not metadata
4. **Reduced Complexity**: Avoiding complex conflict resolution logic
5. **Future-Proof**: Can add later if needed

### When Would Conflicts Occur?

Conflicts would only occur if:
1. Metadata is synced to a central store (e.g., DynamoDB)
2. Multiple devices actively modify the same document
3. Devices sync metadata bidirectionally

None of these are in the current design.

## Future Enhancements

If metadata synchronization is added later:

### Option 1: Last-Write-Wins (Simple)
- Compare `updatedAt` timestamps
- Keep newer version
- Simple but may lose data

### Option 2: Operational Transform (Complex)
- Merge changes from both versions
- Preserve all modifications
- Complex implementation

### Option 3: Manual Resolution (User-Driven)
- Detect conflicts
- Present both versions to user
- Let user choose or merge manually
- Best user experience but requires UI

## Recommendation

**Current:** No conflict resolution needed - architecture prevents conflicts

**Future:** If metadata sync is added, implement last-write-wins as the first step, then consider more sophisticated approaches based on user feedback.

## Testing Strategy

### Current Tests

1. ✅ SyncId uniqueness (unit tests)
2. ✅ Timestamp updates (unit tests)
3. ✅ File deletion propagation (integration tests)

### Future Tests (If Conflict Resolution Added)

1. Conflict detection tests
2. Last-write-wins resolution tests
3. Multi-device simulation tests
4. Timestamp comparison edge cases

## Conclusion

The current architecture **prevents conflicts by design** through:
- Globally unique UUIDs
- No central metadata store
- Immutable file storage
- Single-device primary usage

Conflict resolution is **not needed** in the current implementation and would only be required if the architecture changes to support bidirectional metadata synchronization.

---

**Document Version:** 1.0  
**Last Updated:** 2026-01-17  
**Related Requirements:** 11.1, 11.2, 11.3, 11.4, 11.5
