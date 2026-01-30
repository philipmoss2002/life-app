# DocumentDB Sync Implementation Plan

## Problem Identified

The current sync process only handles S3 file uploads/downloads but **NEVER syncs document metadata to DocumentDB** (AWS AppSync/DynamoDB).

### Current State
- ✅ GraphQL schema defined (`schema.graphql`)
- ✅ Amplify API plugin configured
- ✅ Generated Amplify models (Document, FileAttachment, etc.)
- ❌ **NO GraphQL mutation/query calls in codebase**
- ❌ Document metadata never pushed to DocumentDB
- ❌ Remote documents never pulled from DocumentDB

## Solution: Add GraphQL Sync Layer

### Architecture

```
Local SQLite (new_document.dart) <---> DocumentSyncService <---> DocumentDB (document.dart)
                                              |
                                              v
                                        GraphQL API
                                        (AppSync)
```

### Implementation Steps

#### 1. Create `document_sync_service.dart`

**Purpose**: Bridge between local SQLite models and remote Amplify models

**Key Methods**:

```dart
class DocumentSyncService {
  // Push local document to DocumentDB
  Future<void> pushDocumentToRemote(local.Document localDoc);
  
  // Pull all remote documents and merge with local
  Future<void> pullRemoteDocuments();
  
  // Delete document from DocumentDB (soft delete with tombstone)
  Future<void> deleteRemoteDocument(String syncId);
  
  // Private helpers
  Future<void> _createRemoteDocument(local.Document localDoc, String userId);
  Future<void> _updateRemoteDocument(local.Document localDoc, String userId);
  Future<remote.Document?> _fetchRemoteDocument(String syncId);
  Future<List<remote.Document>> _fetchAllRemoteDocuments(String userId);
  Future<void> _createLocalDocument(remote.Document remoteDoc);
  Future<void> _updateLocalDocument(remote.Document remoteDoc, local.Document localDoc);
  Future<void> _createTombstone(String syncId, String userId);
}
```

**Model Mapping**:
- Local `DocumentCategory` enum → Remote `CAR_INSURANCE`, `HOME_INSURANCE`, etc.
- Local `DateTime` → Remote `TemporalDateTime`
- Local `SyncState` enum → Remote `syncState` string
- Use `getIdentityPoolId()` as `userId` in DocumentDB

#### 2. Update `sync_service.dart`

**Add to `performSync()`**:

```dart
// Phase 1: Pull remote document changes (NEW)
await _documentSyncService.pullRemoteDocuments();

// Phase 2: Upload pending documents (MODIFIED)
for (final doc in pendingDocs) {
  // Push document metadata to DocumentDB (NEW)
  await _documentSyncService.pushDocumentToRemote(doc);
  
  // Upload files to S3 (EXISTING)
  await uploadDocumentFiles(doc.syncId, identityPoolId);
}

// Phase 3: Download missing files (EXISTING)
await downloadDocumentFiles(doc.syncId, identityPoolId);
```

**Add to `syncDocument()`**:

```dart
if (doc.syncState == SyncState.pendingUpload) {
  // Push document metadata to DocumentDB (NEW)
  await _documentSyncService.pushDocumentToRemote(doc);
  
  // Upload files to S3 (EXISTING)
  await uploadDocumentFiles(syncId, identityPoolId);
}
```

#### 3. Update `document_repository.dart`

**Add method**:

```dart
/// Insert a document from remote sync (with existing syncId and timestamps)
Future<void> insertRemoteDocument(Document document) async {
  final db = await _dbService.database;
  await db.insert('documents', document.toDatabase());
}
```

#### 4. Handle File Attachments Sync

Create `file_attachment_sync_service.dart` (similar pattern):

```dart
class FileAttachmentSyncService {
  Future<void> pushFileAttachmentToRemote(local_file.FileAttachment file, String syncId);
  Future<void> pullFileAttachmentsForDocument(String syncId);
  Future<void> deleteRemoteFileAttachment(String syncId, String fileName);
}
```

### Conflict Resolution Strategy

**Last-Write-Wins** (based on `updatedAt` timestamp):

```dart
if (remoteDoc.lastModified > localDoc.updatedAt) {
  // Remote is newer - update local
  await _updateLocalDocument(remoteDoc, localDoc);
} else {
  // Local is newer - push to remote
  await _updateRemoteDocument(localDoc, userId);
}
```

### Deletion Handling

**Soft Delete with Tombstones**:

1. Mark document as `deleted: true` in DocumentDB
2. Set `deletedAt` timestamp
3. Create `DocumentTombstone` record
4. Prevents deleted documents from being reinstated

### Key Challenges & Solutions

#### Challenge 1: Model Mismatch
- **Problem**: Local model (`new_document.dart`) differs from Amplify model (`document.dart`)
- **Solution**: DocumentSyncService maps between models

#### Challenge 2: User ID
- **Problem**: No `getUserId()` method in AuthenticationService
- **Solution**: Use `getIdentityPoolId()` as userId (Cognito Identity ID)

#### Challenge 3: Namespace Collision
- **Problem**: Both `SyncState` (local) and `SyncState` (Amplify) exist
- **Solution**: Use import aliases: `import 'sync_state.dart' as local_sync;`

#### Challenge 4: Timestamps
- **Problem**: Local uses `DateTime`, remote uses `TemporalDateTime`
- **Solution**: Convert with `TemporalDateTime(dateTime)` and `.getDateTimeInUtc()`

### Testing Strategy

1. **Unit Tests**: Test model mapping functions
2. **Integration Tests**: Test GraphQL operations with mock data
3. **E2E Tests**: Test full sync flow with real AWS backend

### Rollout Plan

1. **Phase 1**: Implement document metadata sync (this plan)
2. **Phase 2**: Implement file attachment metadata sync
3. **Phase 3**: Add conflict resolution UI
4. **Phase 4**: Add sync progress indicators
5. **Phase 5**: Optimize with batch operations

### Required Imports

```dart
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/ModelProvider.dart'; // For ModelMutations, ModelQueries
```

### GraphQL Operations Used

```dart
// Create
final request = ModelMutations.create(remoteDoc);
final response = await Amplify.API.mutate(request: request).response;

// Update
final request = ModelMutations.update(remoteDoc);
final response = await Amplify.API.mutate(request: request).response;

// Get by ID
final request = ModelQueries.get(
  remote.Document.classType,
  remote.DocumentModelIdentifier(syncId: syncId),
);
final response = await Amplify.API.query(request: request).response;

// List with filter
final request = ModelQueries.list(
  remote.Document.classType,
  where: remote.Document.USERID.eq(userId),
);
final response = await Amplify.API.query(request: request).response;
```

### Error Handling

```dart
if (response.hasErrors) {
  throw DocumentSyncException(
    'GraphQL errors: ${response.errors.map((e) => e.message).join(", ")}',
  );
}
```

### Next Steps

1. Review this plan
2. Implement `document_sync_service.dart` with proper imports and error handling
3. Update `sync_service.dart` to integrate document sync
4. Add `insertRemoteDocument()` to repository
5. Test with real AWS backend
6. Monitor sync performance and errors
7. Implement file attachment sync (Phase 2)

## Benefits

- ✅ Multi-device sync (documents appear on all devices)
- ✅ Cloud backup (documents stored in DocumentDB)
- ✅ Conflict resolution (last-write-wins)
- ✅ Deletion tracking (tombstones prevent reinstatement)
- ✅ Audit trail (createdAt, updatedAt, deletedAt timestamps)
- ✅ Scalable (GraphQL handles pagination, filtering)

## Estimated Effort

- Document sync service: 4-6 hours
- Integration with existing sync: 2-3 hours
- Testing and debugging: 3-4 hours
- File attachment sync: 3-4 hours
- **Total: 12-17 hours**
