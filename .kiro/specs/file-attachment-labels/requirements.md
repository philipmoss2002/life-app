# File Attachment Labels - Requirements

**Spec ID**: file-attachment-labels  
**Created**: January 21, 2026  
**Status**: Draft  
**Version**: 3.0.0 (Breaking Change)

## Overview

Restructure the labeling system to associate labels with individual file attachments rather than documents. This allows users to identify what each file contains (e.g., "Policy", "Renewal Notice", "Receipt") rather than applying generic labels to the entire document.

## Problem Statement

Currently, labels are associated with documents, but users need to label individual files within a document. For example, a home insurance document might have multiple files: the policy document, renewal notice, claim form, and payment receipt. Users need to distinguish between these files.

### Current Behavior (Incorrect)
- Labels exist on the Document model as `List<String> labels`
- Labels apply to the entire document, not individual files
- Users cannot identify which file is which without relying on filenames
- No way to categorize or filter individual attachments

### Desired Behavior (Correct)
- Each FileAttachment has an optional `String? label` field
- Users can assign descriptive labels when adding files
- Labels are displayed alongside file names in the UI
- Users can edit labels after files are added
- Document model no longer has a labels field

## User Stories

### US-1: Add Label When Picking File
**As a** user  
**I want to** assign a label to a file when I add it to a document  
**So that** I can identify what the file contains

**Acceptance Criteria**:
- When user picks a file, a dialog prompts for an optional label
- Dialog shows the filename and has a text field for the label
- Dialog provides example labels based on document category (e.g., "Policy", "Renewal", "Receipt")
- User can skip adding a label (it's optional)
- Label is saved with the FileAttachment

### US-2: View File Labels
**As a** user  
**I want to** see labels displayed with file names  
**So that** I can quickly identify what each file contains

**Acceptance Criteria**:
- File labels are displayed prominently in the file list
- Labels appear instead of the filename
- Labels are visually distinct (bold, colored, or with an icon)
- Files without labels show the filename
- Labels are visible in the document detail screen

### US-3: Edit File Labels
**As a** user  
**I want to** edit a file's label after adding it  
**So that** I can correct or update the label

**Acceptance Criteria**:
- Each file in the list has an edit button/icon
- Tapping edit opens a dialog with the current label
- User can change or clear the label
- Changes are saved immediately
- UI updates to show the new label


## Technical Requirements

### TR-1: FileAttachment Model Update
- Add `String? label` field to FileAttachment class
- Update `copyWith` method to include label parameter
- Update `toJson` / `fromJson` to serialize label
- Update `toDatabase` / `fromDatabase` to persist label
- Update `validate` method if needed
- Update equality operator and hashCode

### TR-2: Document Model Update
- Remove `List<String> labels` field from Document class
- Update `copyWith` method to remove labels parameter
- Update `toJson` / `fromJson` to remove labels
- Update `toDatabase` / `fromDatabase` to remove labels
- Update equality operator and hashCode
- Update all tests

### TR-3: Database Schema Update
- Increment database version from 2 to 3
- Add migration in `_upgradeDB` method
- Drop `labels` column from `documents` table
- Add `label TEXT` column to `file_attachments` table
- Test migration with existing data

### TR-4: GraphQL Schema Update
- Remove `labels: [String!]` from Document type
- Add `label: String` to FileAttachment type
- Run `amplify push` to update cloud schema
- Update sync service to handle file labels

### TR-5: UI Updates - Document Detail Screen
- Add label prompt dialog when picking files (simple text input, no suggestions)
- Display labels instead of filenames in file list
- Show filename only when label is not provided
- Add edit label functionality
- Update file card/tile design to prioritize label display over filename

### TR-6: Repository Updates
- Update DocumentRepository to handle FileAttachment labels
- Ensure labels are saved/loaded correctly
- Update any queries that referenced document labels

### TR-7: Sync Service Updates
- Update SyncService to sync file labels to cloud
- Handle label conflicts during sync
- Test bidirectional sync with labels

## Data Model Changes

### Before (v2.0.0)
```dart
class Document {
  final String syncId;
  final String title;
  final DocumentCategory category;
  final DateTime? date;
  final String? notes;
  final List<String> labels;  // ❌ Remove this
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncState syncState;
  final List<FileAttachment> files;
}

class FileAttachment {
  final String fileName;
  final String? localPath;
  final String? s3Key;
  final int? fileSize;
  final DateTime addedAt;
}
```

### After (v3.0.0)
```dart
class Document {
  final String syncId;
  final String title;
  final DocumentCategory category;
  final DateTime? date;
  final String? notes;
  // labels field removed
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncState syncState;
  final List<FileAttachment> files;
}

class FileAttachment {
  final String fileName;
  final String? label;  // ✅ Add this
  final String? localPath;
  final String? s3Key;
  final int? fileSize;
  final DateTime addedAt;
}
```

## Database Schema Changes

### Before (v2)
```sql
CREATE TABLE documents (
  sync_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  date INTEGER,
  notes TEXT,
  labels TEXT,  -- JSON array, e.g., '["policy", "renewal"]'
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sync_state TEXT NOT NULL
);

CREATE TABLE file_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sync_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  local_path TEXT,
  s3_key TEXT,
  file_size INTEGER,
  added_at INTEGER NOT NULL,
  FOREIGN KEY (sync_id) REFERENCES documents (sync_id) ON DELETE CASCADE
);
```

### After (v3)
```sql
CREATE TABLE documents (
  sync_id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  date INTEGER,
  notes TEXT,
  -- labels column removed
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sync_state TEXT NOT NULL
);

CREATE TABLE file_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sync_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  label TEXT,  -- NEW: Optional label for the file
  local_path TEXT,
  s3_key TEXT,
  file_size INTEGER,
  added_at INTEGER NOT NULL,
  FOREIGN KEY (sync_id) REFERENCES documents (sync_id) ON DELETE CASCADE
);
```

## GraphQL Schema Changes

### Before (v2)
```graphql
type Document @model @auth(rules: [{allow: owner}]) {
  syncId: String! @primaryKey
  title: String!
  category: DocumentCategory!
  date: AWSDateTime
  notes: String
  labels: [String!]
  createdAt: AWSDateTime!
  updatedAt: AWSDateTime!
  syncState: String!
}

type FileAttachment @model @auth(rules: [{allow: owner}]) {
  id: ID!
  syncId: String! @index(name: "byDocument")
  fileName: String!
  fileSize: Int!
  s3Key: String!
  addedAt: AWSDateTime!
}
```

### After (v3)
```graphql
type Document @model @auth(rules: [{allow: owner}]) {
  syncId: String! @primaryKey
  title: String!
  category: DocumentCategory!
  date: AWSDateTime
  notes: String
  # labels field removed
  createdAt: AWSDateTime!
  updatedAt: AWSDateTime!
  syncState: String!
}

type FileAttachment @model @auth(rules: [{allow: owner}]) {
  id: ID!
  syncId: String! @index(name: "byDocument")
  fileName: String!
  label: String  # NEW: Optional label
  fileSize: Int!
  s3Key: String!
  addedAt: AWSDateTime!
}
```

## Migration Strategy

### Database Migration (v2 → v3)
```dart
Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 3) {
    // Remove labels column from documents table
    // SQLite doesn't support DROP COLUMN, so we need to recreate the table
    await db.execute('''
      CREATE TABLE documents_new (
        sync_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        date INTEGER,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_state TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      INSERT INTO documents_new 
      SELECT sync_id, title, category, date, notes, created_at, updated_at, sync_state
      FROM documents
    ''');
    
    await db.execute('DROP TABLE documents');
    await db.execute('ALTER TABLE documents_new RENAME TO documents');
    
    // Add label column to file_attachments table
    await db.execute('ALTER TABLE file_attachments ADD COLUMN label TEXT');
    
    print('Database upgraded to version 3: Labels moved to file attachments');
  }
}
```

## Testing Requirements

### Unit Tests
- [ ] FileAttachment model with label field
- [ ] FileAttachment serialization (toJson/fromJson)
- [ ] FileAttachment database persistence (toDatabase/fromDatabase)
- [ ] Document model without labels field
- [ ] Document serialization without labels
- [ ] Database migration from v2 to v3

### Integration Tests
- [ ] Create document with labeled files
- [ ] Load document with labeled files
- [ ] Update file labels
- [ ] Delete files with labels
- [ ] Sync documents with labeled files

### UI Tests
- [ ] Add file with label
- [ ] Add file without label (skip)
- [ ] Edit file label
- [ ] Display labels instead of filenames
- [ ] Display filenames when no label provided

### Migration Tests
- [ ] Migrate from v2 to v3 with existing documents
- [ ] Verify no data loss
- [ ] Verify labels column removed from documents
- [ ] Verify label column added to file_attachments

## Breaking Changes

### For Users
- ✅ No data loss: All documents and files preserved
- ⚠️ Labels removed: Existing document labels will be dropped
- ✅ Better UX: More intuitive file labeling

### For Developers
- ❌ Breaking API change: Document model changes
- ❌ Database migration required: v2 → v3
- ❌ GraphQL schema change: Requires `amplify push`
- ✅ Version bump: 3.0.0

## Implementation Phases

### Phase 1: Model Updates (2 hours)
- Update FileAttachment model
- Update Document model
- Update all serialization methods
- Update model tests

### Phase 2: Database Updates (2 hours)
- Increment database version to 3
- Implement migration logic
- Update repository methods
- Test migration

### Phase 3: UI Updates (3 hours)
- Add label prompt dialog (simple text input)
- Display labels instead of filenames
- Show filename as fallback when no label
- Add edit label functionality

### Phase 4: GraphQL/Sync Updates (2 hours)
- Update GraphQL schema
- Run `amplify push`
- Update sync service
- Test cloud sync

### Phase 5: Testing (3 hours)
- Unit tests
- Integration tests
- UI tests
- Migration tests
- End-to-end testing

**Total Estimated Time**: 12 hours

## Success Criteria

- [ ] All model tests pass (71/71)
- [ ] All integration tests pass
- [ ] Database migration works without data loss
- [ ] UI allows adding/editing file labels
- [ ] Labels display instead of filenames when provided
- [ ] Filenames display when labels are not provided
- [ ] Labels sync to cloud correctly
- [ ] No crashes or errors
- [ ] Version bumped to 3.0.0+3

## Dependencies

- Flutter SDK
- SQLite (sqflite package)
- AWS Amplify (for GraphQL sync)
- file_picker package
- uuid package

## Risks and Mitigations

### Risk 1: Data Loss During Migration
**Mitigation**: Thorough testing with sample data, backup recommendations

### Risk 2: Sync Conflicts
**Mitigation**: Proper conflict resolution in sync service

### Risk 3: User Confusion
**Mitigation**: Clear UI with suggested labels and examples

### Risk 4: Breaking Existing Workflows
**Mitigation**: Version bump to 3.0.0, clear release notes

## References

- [LABELS_RESTRUCTURE_PROPOSAL.md](../../../LABELS_RESTRUCTURE_PROPOSAL.md)
- [Document Model](../../../lib/models/new_document.dart)
- [FileAttachment Model](../../../lib/models/file_attachment.dart)
- [Database Service](../../../lib/services/new_database_service.dart)
- [GraphQL Schema](../../../schema.graphql)

## Notes

- This is a breaking change requiring version 3.0.0
- Existing document labels will be dropped (they were not being used correctly)
- File labels are optional to maintain flexibility
- Labels display instead of filenames when provided, filenames shown as fallback
- No suggested labels - users enter free-form text
- Migration is automatic on first launch after update
