# Implementation Tasks - File Attachment Labels

## Overview

This task list provides a step-by-step implementation plan for moving labels from the Document model to the FileAttachment model. Tasks are organized into phases following the design document, with each task building incrementally. The implementation includes model updates, database migration, UI changes, and GraphQL schema updates.

**Version**: 3.0.0 (Breaking Change)  
**Estimated Total Time**: 12 hours

---

## Phase 1: Model Updates

### Task 1.1: Update FileAttachment Model

Add label field to FileAttachment model with all supporting methods.

**Changes**:
- Add `String? label` field to FileAttachment class
- Add `label` parameter to constructor
- Update `copyWith()` method to include label parameter
- Update `toJson()` to serialize label field
- Update `fromJson()` to deserialize label field
- Update `toDatabase()` to include label in database map
- Update `fromDatabase()` to read label from database map
- Add `displayName` getter that returns label if present, otherwise fileName
- Update equality operator to include label
- Update hashCode to include label
- Update toString() to include label

**Testing**:
- Test FileAttachment creation with label
- Test FileAttachment creation without label (null)
- Test displayName returns label when present
- Test displayName returns fileName when label is null
- Test copyWith updates label correctly
- Test toJson/fromJson with label
- Test toDatabase/fromDatabase with label
- Test equality with label field

**Files**:
- `lib/models/file_attachment.dart`
- `test/models/file_attachment_test.dart` (create if doesn't exist)

**Estimated Time**: 1 hour

_Requirements: TR-1_

---

### Task 1.2: Update Document Model

Remove labels field from Document model and update all methods.

**Changes**:
- Remove `List<String> labels` field from Document class
- Remove `labels` parameter from constructor
- Remove `labels` from default value in factory constructor
- Update `copyWith()` method to remove labels parameter
- Update `toJson()` to remove labels serialization
- Update `fromJson()` to remove labels deserialization
- Update `toDatabase()` to remove labels from database map
- Update `fromDatabase()` to remove labels reading
- Update equality operator to remove labels comparison
- Update hashCode to remove labels
- Update toString() to remove labels

**Testing**:
- Test Document creation without labels field
- Test toJson does not include labels
- Test fromJson does not expect labels
- Test toDatabase does not include labels
- Test fromDatabase does not read labels
- Test equality without labels field
- Verify all existing Document tests still pass (71 tests)

**Files**:
- `lib/models/new_document.dart`
- `test/models/new_document_test.dart`

**Estimated Time**: 1 hour

_Requirements: TR-2_

---

## Phase 2: Database Updates

### Task 2.1: Update Database Schema and Migration

Increment database version and implement migration from v2 to v3.

**Changes**:
- Change `_databaseVersion` constant from 2 to 3 in NewDatabaseService
- Update `_upgradeDB()` method to handle v2 → v3 migration
- Add migration logic to recreate documents table without labels column
- Add migration logic to add label column to file_attachments table
- Add logging for migration success
- Update `_createDocumentsTable()` to exclude labels column (if used)
- Update `_createFileAttachmentsTable()` to include label column (if used)

**Migration Logic**:
```dart
if (oldVersion < 3) {
  // Step 1: Create new documents table without labels
  await db.execute('''CREATE TABLE documents_new (...)''');
  
  // Step 2: Copy data excluding labels
  await db.execute('''INSERT INTO documents_new SELECT ...''');
  
  // Step 3: Drop old table and rename new table
  await db.execute('DROP TABLE documents');
  await db.execute('ALTER TABLE documents_new RENAME TO documents');
  
  // Step 4: Add label column to file_attachments
  await db.execute('ALTER TABLE file_attachments ADD COLUMN label TEXT');
  
  print('✅ Database upgraded to v3: Labels moved to file attachments');
}
```

**Testing**:
- Test migration from v2 to v3 with existing data
- Verify documents table no longer has labels column
- Verify file_attachments table has label column
- Verify existing documents are preserved
- Verify existing file attachments are preserved
- Test migration is idempotent (can run multiple times safely)
- Test fresh database creation (no migration needed)

**Files**:
- `lib/services/new_database_service.dart`
- `test/services/new_database_service_test.dart`

**Estimated Time**: 2 hours

_Requirements: TR-3_

---

### Task 2.2: Update DocumentRepository

Update repository methods to handle FileAttachment labels.

**Changes**:
- Update `createDocument()` to save file attachments with labels
- Update `updateDocument()` to update file attachments with labels
- Update `getDocument()` to load file attachments with labels
- Update `getAllDocuments()` to load file attachments with labels
- Remove any label-specific queries or methods (if they exist)
- Ensure file attachment serialization includes label field
- Ensure file attachment deserialization reads label field

**Testing**:
- Test creating document with labeled files
- Test creating document with unlabeled files
- Test updating file labels
- Test loading document with labeled files
- Test loading document with unlabeled files
- Test deleting files with labels
- Verify all existing repository tests still pass

**Files**:
- `lib/repositories/document_repository.dart`
- `test/repositories/document_repository_test.dart`

**Estimated Time**: 1 hour

_Requirements: TR-6_

---

## Phase 3: UI Updates

### Task 3.1: Add Label Prompt Dialog

Create dialog to prompt for label when user picks files.

**Changes**:
- Add `_showAddLabelDialog()` method to DocumentDetailScreen
- Dialog shows filename for context
- Dialog has TextField for label input
- TextField has hint text: "e.g., Policy, Renewal, Receipt"
- TextField uses TextCapitalization.words
- Dialog has "Skip" button (returns null)
- Dialog has "Add" button (returns trimmed text)
- Empty text treated as null (no label)

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

**Testing**:
- Test dialog appears when file is picked
- Test "Skip" button returns null
- Test "Add" button returns entered text
- Test empty text is treated as null
- Test text is trimmed
- Test dialog shows filename

**Files**:
- `lib/screens/new_document_detail_screen.dart`

**Estimated Time**: 1 hour

_Requirements: TR-5, US-1_

---

### Task 3.2: Update File Picker to Use Label Dialog

Integrate label dialog into file picking flow.

**Changes**:
- Update `_pickFiles()` method to show label dialog for each file
- For each picked file:
  - Show add label dialog
  - Get label from dialog (or null if skipped)
  - Create FileAttachment with label
  - Add to _files list
- Ensure label is saved with FileAttachment

**Implementation**:
```dart
Future<void> _pickFiles() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.any,
  );

  if (result != null) {
    for (final file in result.files) {
      // Prompt for label
      final label = await _showAddLabelDialog(file.name);
      
      setState(() {
        _files.add(FileAttachment(
          fileName: file.name,
          label: label?.isEmpty == true ? null : label,
          localPath: file.path,
          fileSize: file.size,
          addedAt: DateTime.now(),
        ));
      });
    }
  }
}
```

**Testing**:
- Test picking single file with label
- Test picking single file without label (skip)
- Test picking multiple files with labels
- Test picking multiple files with mixed labels/no labels
- Test label is saved with FileAttachment

**Files**:
- `lib/screens/new_document_detail_screen.dart`

**Estimated Time**: 30 minutes

_Requirements: TR-5, US-1_

---

### Task 3.3: Update File List Display

Update file list to show labels instead of filenames when labels are provided.

**Changes**:
- Update `_buildFileCard()` or equivalent method
- Use `file.displayName` instead of `file.fileName` for title
- displayName returns label if present, otherwise fileName
- Keep file size display in subtitle
- Ensure visual distinction (bold/prominent style)
- Keep edit and delete buttons

**Implementation**:
```dart
Widget _buildFileCard(FileAttachment file) {
  return Card(
    child: ListTile(
      leading: Icon(_getFileIcon(file.fileName)),
      title: Text(
        file.displayName,  // Uses label if present, otherwise fileName
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

**Testing**:
- Test file with label shows label as title
- Test file without label shows fileName as title
- Test file size displays correctly
- Test edit button is visible
- Test delete button is visible

**Files**:
- `lib/screens/new_document_detail_screen.dart`

**Estimated Time**: 30 minutes

_Requirements: TR-5, US-2_

---

### Task 3.4: Add Edit Label Dialog

Create dialog to edit file labels after files are added.

**Changes**:
- Add `_editFileLabel()` method to DocumentDetailScreen
- Dialog shows filename for context
- Dialog has TextField pre-filled with current label
- TextField allows editing
- Dialog has "Clear" button (sets label to null)
- Dialog has "Save" button (updates label)
- Update FileAttachment in _files list with new label
- Call setState() to trigger UI rebuild

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
          onPressed: () => Navigator.pop(context, ''),
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

**Testing**:
- Test dialog appears when edit button tapped
- Test dialog pre-fills with current label
- Test "Clear" button removes label
- Test "Save" button updates label
- Test empty text clears label
- Test UI updates immediately after save
- Test cancel (dismiss) doesn't change label

**Files**:
- `lib/screens/new_document_detail_screen.dart`

**Estimated Time**: 1 hour

_Requirements: TR-5, US-3_

---

## Phase 4: GraphQL/Sync Updates

### Task 4.1: Update GraphQL Schema

Update schema.graphql to remove labels from Document and add label to FileAttachment.

**Changes**:
- Remove `labels: [String!]` field from Document type
- Add `label: String` field to FileAttachment type
- Verify DocumentCategory enum is present
- Verify all other fields are correct

**Schema**:
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
  label: String  # NEW
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

**Testing**:
- Verify schema is valid GraphQL
- Verify no syntax errors
- Test locally before pushing to cloud

**Files**:
- `schema.graphql`

**Estimated Time**: 15 minutes

_Requirements: TR-4_

---

### Task 4.2: Deploy GraphQL Schema

Deploy updated schema to AWS AppSync.

**Changes**:
- Run `amplify push` to deploy schema changes
- Verify DynamoDB tables are updated
- Verify AppSync API is updated
- Test GraphQL queries/mutations with new schema
- Verify existing documents in cloud still load (labels will be null)

**Commands**:
```bash
amplify push
```

**Testing**:
- Test creating document with labeled files via GraphQL
- Test querying documents (labels field should not exist)
- Test querying file attachments (label field should exist)
- Test updating file labels via GraphQL
- Verify sync works with new schema

**Files**:
- N/A (cloud deployment)

**Estimated Time**: 30 minutes

_Requirements: TR-4_

---

### Task 4.3: Update Sync Service

Update SyncService to handle file attachment labels.

**Changes**:
- Update document serialization to exclude labels field
- Update file attachment serialization to include label field
- Verify sync upload includes file labels
- Verify sync download reads file labels
- Update conflict resolution to handle file labels (last-write-wins)
- Ensure null labels are handled correctly

**Testing**:
- Test syncing document with labeled files
- Test syncing document with unlabeled files
- Test downloading document with labeled files from cloud
- Test conflict resolution with label changes
- Test bidirectional sync with labels
- Verify sync state updates correctly

**Files**:
- `lib/services/sync_service.dart`
- `test/services/sync_service_test.dart`

**Estimated Time**: 1 hour

_Requirements: TR-7_

---

## Phase 5: Testing and Validation

### Task 5.1: Update Unit Tests

Update all unit tests to reflect model changes.

**Changes**:
- Update FileAttachment tests to include label field
- Update Document tests to remove labels field
- Add tests for displayName getter
- Add tests for label serialization
- Verify all 71+ model tests pass
- Add new tests for label-specific functionality

**Test Cases**:
- FileAttachment with label
- FileAttachment without label
- FileAttachment displayName with label
- FileAttachment displayName without label
- FileAttachment copyWith label
- FileAttachment toJson/fromJson with label
- FileAttachment toDatabase/fromDatabase with label
- Document without labels field
- Document toJson does not include labels
- Document fromJson does not expect labels

**Files**:
- `test/models/file_attachment_test.dart`
- `test/models/new_document_test.dart`

**Estimated Time**: 1 hour

_Requirements: All testing requirements_

---

### Task 5.2: Add Integration Tests

Create integration tests for end-to-end label functionality.

**Changes**:
- Test creating document with labeled files
- Test loading document with labeled files
- Test updating file labels
- Test deleting files with labels
- Test database migration from v2 to v3
- Test sync with labeled files

**Test Cases**:
- Create document → Save with labeled files → Load → Verify labels
- Create document → Edit file label → Save → Load → Verify updated label
- Migrate v2 database → Verify labels column removed → Verify label column added
- Create document → Sync to cloud → Download on new device → Verify labels

**Files**:
- `test/integration/file_attachment_labels_test.dart` (create new)

**Estimated Time**: 2 hours

_Requirements: All testing requirements_

---

### Task 5.3: Add UI Tests

Create UI tests for label dialogs and display.

**Changes**:
- Test add label dialog appears
- Test add label dialog with input
- Test add label dialog skip
- Test edit label dialog appears
- Test edit label dialog with changes
- Test edit label dialog clear
- Test file list displays labels
- Test file list displays filenames when no label

**Test Cases**:
- Pick file → Dialog appears → Enter label → Verify label shown
- Pick file → Dialog appears → Skip → Verify filename shown
- Edit file → Dialog appears → Change label → Verify updated
- Edit file → Dialog appears → Clear → Verify filename shown

**Files**:
- `test/ui/document_detail_screen_test.dart` (create or update)

**Estimated Time**: 1.5 hours

_Requirements: All testing requirements_

---

### Task 5.4: Manual Testing and Validation

Perform manual testing on device/emulator.

**Test Scenarios**:
1. Fresh install (no migration)
   - Create document with labeled files
   - Verify labels display correctly
   - Verify sync to cloud works
   
2. Upgrade from v2 (with migration)
   - Install v2 app with existing documents
   - Upgrade to v3
   - Verify migration runs successfully
   - Verify existing documents still load
   - Verify no crashes or errors
   
3. Label functionality
   - Add files with labels
   - Add files without labels (skip)
   - Edit labels
   - Clear labels
   - Delete files with labels
   
4. Sync testing
   - Create document on device A with labels
   - Sync to cloud
   - Download on device B
   - Verify labels appear correctly
   - Edit label on device B
   - Sync back to device A
   - Verify label updated

**Checklist**:
- [ ] Fresh install works
- [ ] Migration from v2 works
- [ ] No data loss
- [ ] Labels display correctly
- [ ] Edit labels works
- [ ] Sync to cloud works
- [ ] Download from cloud works
- [ ] No crashes or errors

**Estimated Time**: 1 hour

_Requirements: All success criteria_

---

### Task 5.5: Update Version and Documentation

Update version number and create release documentation.

**Changes**:
- Update version in `pubspec.yaml` to 3.0.0+3
- Update CHANGELOG.md with breaking changes
- Create migration guide for users (if needed)
- Update README.md if necessary
- Create release notes

**Version Update**:
```yaml
version: 3.0.0+3
```

**Release Notes**:
```markdown
# Version 3.0.0

## Breaking Changes
- Labels moved from documents to individual file attachments
- Database migration from v2 to v3 (automatic)
- GraphQL schema updated (requires cloud sync)

## New Features
- Add labels to individual files
- Edit file labels
- Labels display instead of filenames
- Automatic database migration

## Migration
- Automatic on first launch
- No user action required
- Existing documents preserved
- Document-level labels removed
```

**Files**:
- `pubspec.yaml`
- `CHANGELOG.md`
- `README.md`

**Estimated Time**: 30 minutes

_Requirements: Version 3.0.0+3_

---

## Summary

### Task Breakdown by Phase

**Phase 1: Model Updates** (2 hours)
- Task 1.1: Update FileAttachment Model (1 hour)
- Task 1.2: Update Document Model (1 hour)

**Phase 2: Database Updates** (3 hours)
- Task 2.1: Update Database Schema and Migration (2 hours)
- Task 2.2: Update DocumentRepository (1 hour)

**Phase 3: UI Updates** (3 hours)
- Task 3.1: Add Label Prompt Dialog (1 hour)
- Task 3.2: Update File Picker to Use Label Dialog (30 minutes)
- Task 3.3: Update File List Display (30 minutes)
- Task 3.4: Add Edit Label Dialog (1 hour)

**Phase 4: GraphQL/Sync Updates** (1.75 hours)
- Task 4.1: Update GraphQL Schema (15 minutes)
- Task 4.2: Deploy GraphQL Schema (30 minutes)
- Task 4.3: Update Sync Service (1 hour)

**Phase 5: Testing and Validation** (6 hours)
- Task 5.1: Update Unit Tests (1 hour)
- Task 5.2: Add Integration Tests (2 hours)
- Task 5.3: Add UI Tests (1.5 hours)
- Task 5.4: Manual Testing and Validation (1 hour)
- Task 5.5: Update Version and Documentation (30 minutes)

**Total Estimated Time**: 15.75 hours (~2 days)

### Dependencies

- Phase 2 depends on Phase 1 (models must be updated before database)
- Phase 3 depends on Phase 1 (UI needs updated models)
- Phase 4 depends on Phase 1 and 2 (sync needs models and database)
- Phase 5 depends on all previous phases (testing requires complete implementation)

### Success Criteria

- [ ] All model tests pass (71+)
- [ ] All integration tests pass
- [ ] All UI tests pass
- [ ] Database migration works without data loss
- [ ] Labels display correctly in UI
- [ ] Labels sync to cloud successfully
- [ ] No crashes or errors
- [ ] Version bumped to 3.0.0+3
- [ ] Documentation updated

---

## References

- [Requirements Document](./requirements.md)
- [Design Document](./design.md)
- [LABELS_RESTRUCTURE_PROPOSAL.md](../../../LABELS_RESTRUCTURE_PROPOSAL.md)
