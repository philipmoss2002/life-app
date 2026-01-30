# Design Document - File Attachment Labels

## Overview

This design document outlines the technical architecture for moving labels from the Document model to the FileAttachment model. This change allows users to assign descriptive labels to individual files (e.g., "Policy", "Renewal Notice", "Receipt") rather than applying generic labels to entire documents. The design maintains backward compatibility through database migration while providing a cleaner, more intuitive user experience.

### Key Design Principles

1. **User-Centric**: Labels describe what each file contains, not the document
2. **Simplicity**: Optional labels with free-form text input
3. **Display Priority**: Labels replace filenames in UI when provided
4. **Clean Migration**: Automatic database upgrade with no data loss
5. **Sync Compatible**: Labels sync to cloud via GraphQL

---

## Architecture Changes

### Data Model Evolution

**Current (v2.0.0)**:
```
Document
├── labels: List<String>  ❌ Wrong level
└── files: List<FileAttachment>
    └── fileName: String
```

**New (v3.0.0)**:
```
Document
└── files: List<FileAttachment>
    ├── fileName: String
    └── label: String?  ✅ Correct level
```

### Component Impact

```
┌─────────────────────────────────────────────────────────────┐
│                         UI Layer                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Document Detail Screen                               │  │
│  │  - Add Label Dialog (NEW)                            │  │
│  │  - Edit Label Dialog (NEW)                           │  │
│  │  - File List (UPDATED: show label instead of name)   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Model Layer                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Document (UPDATED: remove labels field)             │  │
│  │  FileAttachment (UPDATED: add label field)           │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Data Layer                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  SQLite Database (MIGRATION: v2 → v3)                │  │
│  │  - documents: DROP labels column                     │  │
│  │  - file_attachments: ADD label column                │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  GraphQL Schema (UPDATED)                            │  │
│  │  - Document: remove labels field                     │  │
│  │  - FileAttachment: add label field                   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Component Details

### 1. FileAttachment Model

**Changes**:
- Add `String? label` field
- Update all serialization methods
- Update equality and hashCode

**Interface**:
```dart
class FileAttachment {
  final String fileName;
  final String? label;        // ✅ NEW: Optional descriptive label
  final String? localPath;
  final String? s3Key;
  final int? fileSize;
  final DateTime addedAt;

  FileAttachment({
    required this.fileName,
    this.label,               // ✅ NEW
    this.localPath,
    this.s3Key,
    this.fileSize,
    required this.addedAt,
  });

  // Display name: label if provided, otherwise fileName
  String get displayName => label ?? fileName;

  FileAttachment copyWith({
    String? fileName,
    String? label,            // ✅ NEW
    String? localPath,
    String? s3Key,
    int? fileSize,
    DateTime? addedAt,
  });

  Map<String, dynamic> toJson();
  factory FileAttachment.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toDatabase(String syncId);
  factory FileAttachment.fromDatabase(Map<String, dynamic> map);
}
```

**Key Behaviors**:
- `displayName` getter returns label if present, otherwise fileName
- Label is optional (nullable)
- Label is free-form text (no validation beyond non-empty)
- Serialization includes label in all formats (JSON, Database, GraphQL)

---

### 2. Document Model

**Changes**:
- Remove `List<String> labels` field
- Update all serialization methods
- Update equality and hashCode

**Interface**:
```dart
class Document {
  final String syncId;
  final String title;
  final DocumentCategory category;
  final DateTime? date;
  final String? notes;
  // ❌ REMOVED: final List<String> labels;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncState syncState;
  final List<FileAttachment> files;

  Document({
    required this.syncId,
    required this.title,
    required this.category,
    this.date,
    this.notes,
    // ❌ REMOVED: this.labels = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.syncState,
    this.files = const [],
  });

  Document copyWith({
    String? syncId,
    String? title,
    DocumentCategory? category,
    DateTime? date,
    bool clearDate = false,
    String? notes,
    // ❌ REMOVED: List<String>? labels,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncState? syncState,
    List<FileAttachment>? files,
  });

  Map<String, dynamic> toJson();
  factory Document.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toDatabase();
  factory Document.fromDatabase(Map<String, dynamic> map);
}
```

**Key Behaviors**:
- No breaking changes to existing Document functionality
- Labels field completely removed from all methods
- Existing tests updated to remove label assertions

---

### 3. Database Service

**Changes**:
- Increment database version from 2 to 3
- Add migration logic in `_upgradeDB`
- Update schema for both tables

**Migration Strategy**:
```dart
class NewDatabaseService {
  static const int _databaseVersion = 3;  // ✅ Increment from 2

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Existing migrations (v1 → v2)
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE documents ADD COLUMN category TEXT DEFAULT "other"');
      await db.execute('ALTER TABLE documents ADD COLUMN date INTEGER');
    }

    // ✅ NEW: Migration v2 → v3
    if (oldVersion < 3) {
      // Step 1: Recreate documents table without labels column
      // (SQLite doesn't support DROP COLUMN)
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

      // Step 2: Copy data (excluding labels)
      await db.execute('''
        INSERT INTO documents_new 
        SELECT sync_id, title, category, date, notes, 
               created_at, updated_at, sync_state
        FROM documents
      ''');

      // Step 3: Replace old table
      await db.execute('DROP TABLE documents');
      await db.execute('ALTER TABLE documents_new RENAME TO documents');

      // Step 4: Add label column to file_attachments
      await db.execute('ALTER TABLE file_attachments ADD COLUMN label TEXT');

      print('✅ Database upgraded to v3: Labels moved to file attachments');
    }
  }
}
```

**Schema Changes**:

**documents table (v3)**:
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
)
```

**file_attachments table (v3)**:
```sql
CREATE TABLE file_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sync_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  label TEXT,              -- ✅ NEW: Optional label
  local_path TEXT,
  s3_key TEXT,
  file_size INTEGER,
  added_at INTEGER NOT NULL,
  FOREIGN KEY (sync_id) REFERENCES documents (sync_id) ON DELETE CASCADE
)
```

**Key Behaviors**:
- Migration runs automatically on first app launch after update
- No data loss: all documents and files preserved
- Existing document labels are dropped (they were incorrectly structured)
- Migration is idempotent (safe to run multiple times)
- Logs migration success for debugging

---

### 4. Document Repository

**Changes**:
- Update `createDocument` to handle FileAttachment labels
- Update `updateDocument` to handle FileAttachment labels
- Remove any label-specific queries

**Interface** (unchanged, but implementation updated):
```dart
class DocumentRepository {
  Future<Document> createDocument(Document document);
  Future<Document> updateDocument(Document document);
  Future<void> deleteDocument(String syncId);
  Future<Document?> getDocument(String syncId);
  Future<List<Document>> getAllDocuments();
  
  // File operations now handle labels
  Future<void> saveFileAttachments(String syncId, List<FileAttachment> files);
  Future<List<FileAttachment>> getFileAttachments(String syncId);
}
```

**Key Behaviors**:
- FileAttachment serialization includes label field
- Label is persisted to database on save
- Label is loaded from database on read
- No special handling needed (label is just another field)

---

### 5. GraphQL Schema

**Changes**:
- Remove `labels` field from Document type
- Add `label` field to FileAttachment type

**Schema**:
```graphql
type Document @model @auth(rules: [{allow: owner}]) {
  syncId: String! @primaryKey
  title: String!
  category: DocumentCategory!
  date: AWSDateTime
  notes: String
  # ❌ REMOVED: labels: [String!]
  createdAt: AWSDateTime!
  updatedAt: AWSDateTime!
  syncState: String!
}

type FileAttachment @model @auth(rules: [{allow: owner}]) {
  id: ID!
  syncId: String! @index(name: "byDocument")
  fileName: String!
  label: String              # ✅ NEW: Optional label
  fileSize: Int!
  s3Key: String!
  addedAt: AWSDateTime!
}

enum DocumentCategory {
  carInsurance
  homeInsurance
  holiday
  expenses
  other
}
```

**Deployment**:
```bash
# Update schema.graphql file
# Run Amplify push
amplify push

# This will:
# 1. Update DynamoDB tables
# 2. Update AppSync API
# 3. Generate new GraphQL queries/mutations
```

**Key Behaviors**:
- Breaking change: clients must update to handle new schema
- Existing documents in cloud will have null labels (acceptable)
- Sync service automatically handles label field

---

### 6. Sync Service

**Changes**:
- Update document sync to exclude labels field
- Update file attachment sync to include label field
- Handle label conflicts during sync

**Interface** (unchanged, but implementation updated):
```dart
class SyncService {
  Future<void> syncDocument(Document document);
  Future<void> syncAllDocuments();
  Future<void> downloadDocument(String syncId);
}
```

**Sync Behavior**:

**Upload Flow**:
```
1. User creates/updates document with labeled files
2. SyncService serializes Document (no labels field)
3. SyncService serializes FileAttachments (includes label field)
4. Upload to AppSync GraphQL API
5. Update local syncState to 'synced'
```

**Download Flow**:
```
1. SyncService queries AppSync for documents
2. Receives Document (no labels field)
3. Receives FileAttachments (includes label field)
4. Deserializes and saves to local database
5. UI displays labels instead of filenames
```

**Conflict Resolution**:
- Labels are file-level, so conflicts are per-file
- Last-write-wins strategy (based on updatedAt timestamp)
- No special handling needed beyond existing sync logic

---

## UI Design

### 1. Add Label Dialog

**Trigger**: When user picks a file via file picker

**Design**:
```
┌─────────────────────────────────────┐
│  Label for file                  ×  │
├─────────────────────────────────────┤
│                                     │
│  File: insurance-policy.pdf         │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ Label (optional)              │ │
│  │ e.g., Policy, Renewal, Receipt│ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌─────────┐  ┌─────────┐         │
│  │  Skip   │  │   Add   │         │
│  └─────────┘  └─────────┘         │
└─────────────────────────────────────┘
```

**Implementation**:
```dart
Future<String?> _showAddLabelDialog(String fileName) async {
  final controller = TextEditingController();
  
  return await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Label for file'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('File: $fileName'),
          SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Label (optional)',
              hintText: 'e.g., Policy, Renewal, Receipt',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('Skip'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text('Add'),
        ),
      ],
    ),
  );
}
```

**Key Behaviors**:
- Shows filename for context
- Text field with hint text
- "Skip" button returns null (no label)
- "Add" button returns trimmed text
- Empty text treated as null (no label)

---

### 2. File List Display

**Design**: Labels replace filenames when provided

**With Label**:
```
┌─────────────────────────────────────┐
│  📄  Policy                    ✏️ 🗑️ │
│      2.3 MB                          │
└─────────────────────────────────────┘
```

**Without Label**:
```
┌─────────────────────────────────────┐
│  📄  insurance-policy.pdf      ✏️ 🗑️ │
│      2.3 MB                          │
└─────────────────────────────────────┘
```

**Implementation**:
```dart
Widget _buildFileCard(FileAttachment file) {
  return Card(
    child: ListTile(
      leading: Icon(_getFileIcon(file.fileName)),
      title: Text(
        file.displayName,  // ✅ Uses label if present, otherwise fileName
        style: TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: file.fileSize != null
          ? Text(_formatFileSize(file.fileSize!))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _editFileLabel(file),
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => _deleteFile(file),
          ),
        ],
      ),
    ),
  );
}
```

**Key Behaviors**:
- `file.displayName` returns label if present, otherwise fileName
- Label displayed in bold/prominent style
- Edit button opens edit label dialog
- Delete button removes file

---

### 3. Edit Label Dialog

**Trigger**: User taps edit button on file

**Design**:
```
┌─────────────────────────────────────┐
│  Edit label                      ×  │
├─────────────────────────────────────┤
│                                     │
│  File: insurance-policy.pdf         │
│                                     │
│  ┌───────────────────────────────┐ │
│  │ Policy                        │ │
│  └───────────────────────────────┘ │
│                                     │
│  ┌─────────┐  ┌─────────┐         │
│  │ Clear   │  │  Save   │         │
│  └─────────┘  └─────────┘         │
└─────────────────────────────────────┘
```

**Implementation**:
```dart
Future<void> _editFileLabel(FileAttachment file) async {
  final controller = TextEditingController(text: file.label ?? '');
  
  final newLabel = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Edit label'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('File: ${file.fileName}'),
          SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Label',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''),  // Empty = clear
          child: Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: Text('Save'),
        ),
      ],
    ),
  );

  if (newLabel != null) {
    setState(() {
      final index = _files.indexOf(file);
      _files[index] = file.copyWith(
        label: newLabel.isEmpty ? null : newLabel,
      );
    });
  }
}
```

**Key Behaviors**:
- Pre-fills with current label
- "Clear" button removes label (sets to null)
- "Save" button updates label
- Empty text treated as null (no label)
- UI updates immediately

---

## Data Flow

### Add File with Label Flow

```
1. User taps "Add Files" button
   ↓
2. File picker opens
   ↓
3. User selects file(s)
   ↓
4. For each file:
   a. Show add label dialog
   b. User enters label or skips
   c. Create FileAttachment with label
   d. Add to _files list
   ↓
5. User taps "Save" on document
   ↓
6. DocumentRepository.createDocument()
   ↓
7. Save document to SQLite (no labels field)
   ↓
8. Save file attachments to SQLite (with label field)
   ↓
9. SyncService.syncDocument()
   ↓
10. Upload to AppSync (FileAttachment includes label)
    ↓
11. Update syncState to 'synced'
```

### Edit Label Flow

```
1. User taps edit button on file
   ↓
2. Show edit label dialog with current label
   ↓
3. User edits label or clears it
   ↓
4. Update FileAttachment in _files list
   ↓
5. setState() triggers UI rebuild
   ↓
6. Display updated label immediately
   ↓
7. User taps "Save" on document
   ↓
8. DocumentRepository.updateDocument()
   ↓
9. Update file attachments in SQLite
   ↓
10. SyncService.syncDocument()
    ↓
11. Upload updated FileAttachment to AppSync
```

### Load Document Flow

```
1. User opens document detail screen
   ↓
2. DocumentRepository.getDocument(syncId)
   ↓
3. Load document from SQLite
   ↓
4. Load file attachments from SQLite (includes labels)
   ↓
5. Build Document with FileAttachment list
   ↓
6. UI displays files using file.displayName
   ↓
7. Labels shown instead of filenames (when present)
```

---

## Testing Strategy

### Unit Tests

**FileAttachment Model**:
```dart
test('FileAttachment with label', () {
  final file = FileAttachment(
    fileName: 'policy.pdf',
    label: 'Policy',
    addedAt: DateTime.now(),
  );
  
  expect(file.displayName, 'Policy');
  expect(file.label, 'Policy');
});

test('FileAttachment without label', () {
  final file = FileAttachment(
    fileName: 'policy.pdf',
    addedAt: DateTime.now(),
  );
  
  expect(file.displayName, 'policy.pdf');
  expect(file.label, null);
});

test('FileAttachment serialization with label', () {
  final file = FileAttachment(
    fileName: 'policy.pdf',
    label: 'Policy',
    addedAt: DateTime.now(),
  );
  
  final json = file.toJson();
  expect(json['label'], 'Policy');
  
  final restored = FileAttachment.fromJson(json);
  expect(restored.label, 'Policy');
});
```

**Document Model**:
```dart
test('Document without labels field', () {
  final doc = Document.create(
    title: 'Test',
    category: DocumentCategory.other,
  );
  
  final json = doc.toJson();
  expect(json.containsKey('labels'), false);
});
```

### Integration Tests

**Database Migration**:
```dart
test('Migrate from v2 to v3', () async {
  // Create v2 database with labels
  final dbV2 = await _createV2Database();
  await dbV2.insert('documents', {
    'sync_id': 'test-123',
    'title': 'Test Doc',
    'labels': '["label1", "label2"]',
    // ... other fields
  });
  
  // Run migration
  final dbV3 = await NewDatabaseService().database;
  
  // Verify labels column removed
  final doc = await dbV3.query('documents', where: 'sync_id = ?', whereArgs: ['test-123']);
  expect(doc.first.containsKey('labels'), false);
  
  // Verify label column added to file_attachments
  final columns = await dbV3.rawQuery('PRAGMA table_info(file_attachments)');
  expect(columns.any((col) => col['name'] == 'label'), true);
});
```

**Repository Tests**:
```dart
test('Save and load file with label', () async {
  final doc = Document.create(
    title: 'Test',
    category: DocumentCategory.other,
  );
  
  final file = FileAttachment(
    fileName: 'test.pdf',
    label: 'Test Label',
    addedAt: DateTime.now(),
  );
  
  final docWithFile = doc.copyWith(files: [file]);
  await repository.createDocument(docWithFile);
  
  final loaded = await repository.getDocument(doc.syncId);
  expect(loaded!.files.first.label, 'Test Label');
  expect(loaded.files.first.displayName, 'Test Label');
});
```

### UI Tests

**Add Label Dialog**:
```dart
testWidgets('Add label dialog', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Open document detail
  await tester.tap(find.text('Add Files'));
  await tester.pumpAndSettle();
  
  // Mock file picker
  // ... file picker returns test.pdf
  
  // Verify label dialog appears
  expect(find.text('Label for file'), findsOneWidget);
  expect(find.text('File: test.pdf'), findsOneWidget);
  
  // Enter label
  await tester.enterText(find.byType(TextField), 'Test Label');
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
  
  // Verify label displayed
  expect(find.text('Test Label'), findsOneWidget);
});
```

---

## Migration Checklist

### Pre-Migration
- [ ] Backup existing database
- [ ] Test migration on sample data
- [ ] Verify all tests pass on v2

### Migration
- [ ] Update FileAttachment model
- [ ] Update Document model
- [ ] Update database version to 3
- [ ] Implement migration logic
- [ ] Update repository methods
- [ ] Update GraphQL schema
- [ ] Run `amplify push`

### Post-Migration
- [ ] Verify database schema changes
- [ ] Test document creation with labels
- [ ] Test document loading with labels
- [ ] Test label editing
- [ ] Test sync to cloud
- [ ] Verify no data loss
- [ ] Update version to 3.0.0+3

---

## Rollout Plan

### Phase 1: Development (2 days)
- Implement model changes
- Implement database migration
- Update repository
- Update UI

### Phase 2: Testing (1 day)
- Unit tests
- Integration tests
- UI tests
- Migration tests

### Phase 3: Deployment (1 day)
- Update GraphQL schema
- Run `amplify push`
- Build and test release build
- Deploy to Google Play (internal testing)

### Phase 4: Rollout (1 week)
- Internal testing (2 days)
- Beta testing (3 days)
- Production release (2 days)

---

## Risk Mitigation

### Risk 1: Data Loss During Migration
**Mitigation**:
- Thorough testing with sample data
- Database backup before migration
- Migration is idempotent (safe to retry)
- Logs all migration steps

### Risk 2: Sync Conflicts
**Mitigation**:
- Last-write-wins strategy
- Existing sync conflict resolution applies
- Labels are optional (null is valid)

### Risk 3: User Confusion
**Mitigation**:
- Clear dialog text
- Hint text with examples
- Optional labels (can skip)
- Edit functionality for corrections

### Risk 4: Breaking Changes
**Mitigation**:
- Version bump to 3.0.0
- Clear release notes
- Automatic migration
- No user action required

---

## Success Metrics

- [ ] All 71 model tests pass
- [ ] Database migration completes without errors
- [ ] No data loss reported
- [ ] Labels display correctly in UI
- [ ] Labels sync to cloud successfully
- [ ] No crashes or errors in production
- [ ] User feedback positive

---

## References

- [Requirements Document](./requirements.md)
- [LABELS_RESTRUCTURE_PROPOSAL.md](../../../LABELS_RESTRUCTURE_PROPOSAL.md)
- [Document Model](../../../lib/models/new_document.dart)
- [FileAttachment Model](../../../lib/models/file_attachment.dart)
- [Database Service](../../../lib/services/new_database_service.dart)
- [GraphQL Schema](../../../schema.graphql)
