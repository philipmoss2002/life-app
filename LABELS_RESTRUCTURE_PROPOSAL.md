# Labels Restructure Proposal

**Date**: January 18, 2026  
**Issue**: Labels are currently associated with Documents, but should be associated with File Attachments  
**Status**: Proposal - Not Implemented

## Problem Statement

### Current Structure (INCORRECT)
```
Document
├── title: "Home Insurance 2024"
├── category: homeInsurance
├── labels: ["policy", "renewal"]  ❌ Labels at document level
└── files:
    ├── FileAttachment: "policy.pdf"
    └── FileAttachment: "renewal-notice.pdf"
```

**Issues**:
- Labels apply to the entire document, not individual files
- Cannot distinguish which file is the policy vs renewal notice
- User must remember which file is which by filename alone
- No way to categorize or filter individual attachments

### Desired Structure (CORRECT)
```
Document
├── title: "Home Insurance 2024"
├── category: homeInsurance
└── files:
    ├── FileAttachment: "policy.pdf"
    │   └── label: "policy"  ✅ Label on file
    └── FileAttachment: "renewal-notice.pdf"
        └── label: "renewal"  ✅ Label on file
```

**Benefits**:
- Each file can have its own descriptive label
- Easy to identify what each attachment contains
- Can filter/search files by label
- Better organization for documents with multiple files

## Use Cases

### Example 1: Home Insurance Document
```
Document: "Home Insurance 2024"
├── policy-document.pdf → Label: "Policy"
├── renewal-letter.pdf → Label: "Renewal Notice"
├── claim-form.pdf → Label: "Claim Form"
└── receipt.pdf → Label: "Payment Receipt"
```

### Example 2: Car Insurance Document
```
Document: "Car Insurance - Toyota"
├── insurance-cert.pdf → Label: "Certificate"
├── renewal-quote.pdf → Label: "Renewal Quote"
└── no-claims-bonus.pdf → Label: "No Claims Proof"
```

### Example 3: Holiday Booking
```
Document: "Spain Holiday 2024"
├── booking-conf.pdf → Label: "Booking Confirmation"
├── flight-tickets.pdf → Label: "Flight Tickets"
├── hotel-voucher.pdf → Label: "Hotel Voucher"
└── travel-insurance.pdf → Label: "Travel Insurance"
```

## Proposed Solution

### Option 1: Add Label Field to FileAttachment (RECOMMENDED)

**Changes Required**:

#### 1. Update FileAttachment Model
```dart
class FileAttachment {
  final String fileName;
  final String? label;        // ← NEW: Optional label for the file
  final String? localPath;
  final String? s3Key;
  final int? fileSize;
  final DateTime addedAt;

  FileAttachment({
    required this.fileName,
    this.label,               // ← NEW
    this.localPath,
    this.s3Key,
    this.fileSize,
    required this.addedAt,
  });
  
  // Update all methods (copyWith, toJson, fromJson, toDatabase, fromDatabase)
}
```

#### 2. Update Document Model
```dart
class Document {
  final String syncId;
  final String title;
  final DocumentCategory category;
  final DateTime? date;
  final String? notes;
  // Remove: final List<String> labels;  ❌ Delete this
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncState syncState;
  final List<FileAttachment> files;
  
  // Update all methods to remove labels field
}
```

#### 3. Update Database Schema
```sql
-- In documents table: Remove labels column
ALTER TABLE documents DROP COLUMN labels;

-- In file_attachments table: Add label column
ALTER TABLE file_attachments ADD COLUMN label TEXT;
```

#### 4. Update GraphQL Schema
```graphql
type Document {
  syncId: String!
  title: String!
  category: DocumentCategory!
  date: AWSDateTime
  notes: String
  # Remove: labels: [String!]
  createdAt: AWSDateTime!
  updatedAt: AWSDateTime!
  syncState: String!
}

type FileAttachment {
  id: ID!
  syncId: String!
  fileName: String!
  label: String              # ← NEW: Optional label
  fileSize: Int!
  s3Key: String!
  addedAt: AWSDateTime!
}
```

#### 5. Update UI Components

**Document Detail Screen**:
```dart
// When adding a file, prompt for optional label
Future<void> _pickFiles() async {
  final result = await FilePicker.platform.pickFiles(...);
  
  if (result != null) {
    for (final file in result.files) {
      // Prompt user for label
      final label = await _promptForFileLabel(file.name);
      
      _files.add(FileAttachment(
        fileName: file.name,
        label: label,           // ← NEW
        localPath: file.path,
        fileSize: file.size,
        addedAt: DateTime.now(),
      ));
    }
  }
}

Future<String?> _promptForFileLabel(String fileName) async {
  return await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Label for $fileName'),
      content: TextField(
        decoration: InputDecoration(
          labelText: 'Label (optional)',
          hintText: 'e.g., Policy, Renewal, Receipt',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('Skip'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text('Add'),
        ),
      ],
    ),
  );
}
```

**File Display**:
```dart
// Show label with file name
ListTile(
  leading: Icon(_getFileIcon(file.fileName)),
  title: Text(file.fileName),
  subtitle: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (file.label != null && file.label!.isNotEmpty)
        Text(
          file.label!,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      if (file.fileSize != null)
        Text(_formatFileSize(file.fileSize!)),
    ],
  ),
  trailing: IconButton(
    icon: Icon(Icons.edit),
    onPressed: () => _editFileLabel(file),
  ),
);
```

### Option 2: Keep Both (Document Labels + File Labels)

**Rationale**: Some labels might apply to the entire document, while others to specific files.

```dart
class Document {
  final List<String> documentLabels;  // Document-level tags
  final List<FileAttachment> files;   // Files with their own labels
}

class FileAttachment {
  final String? fileLabel;            // File-specific label
}
```

**Example**:
```
Document: "Home Insurance 2024"
├── documentLabels: ["Important", "Annual"]  ← Document-level
└── files:
    ├── policy.pdf → fileLabel: "Policy"     ← File-level
    └── renewal.pdf → fileLabel: "Renewal"   ← File-level
```

**Pros**: Maximum flexibility  
**Cons**: More complex, potentially confusing UX

## Migration Strategy

### For Existing Users

#### Option A: Automatic Migration (Simple)
```dart
// During database upgrade
Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 3) {
    // Remove labels from documents table
    await db.execute('ALTER TABLE documents DROP COLUMN labels');
    
    // Add label column to file_attachments
    await db.execute('ALTER TABLE file_attachments ADD COLUMN label TEXT');
    
    // Note: Existing document labels are lost
    // This is acceptable since they weren't being used correctly
  }
}
```

#### Option B: Preserve Labels (Complex)
```dart
// During migration, assign first document label to first file, etc.
Future<void> _migrateLabels(Database db) async {
  final docs = await db.query('documents');
  
  for (final doc in docs) {
    final syncId = doc['sync_id'];
    final labelsJson = doc['labels'];
    
    if (labelsJson != null) {
      final labels = jsonDecode(labelsJson) as List;
      final files = await db.query(
        'file_attachments',
        where: 'sync_id = ?',
        whereArgs: [syncId],
      );
      
      // Assign labels to files (first label to first file, etc.)
      for (int i = 0; i < files.length && i < labels.length; i++) {
        await db.update(
          'file_attachments',
          {'label': labels[i]},
          where: 'id = ?',
          whereArgs: [files[i]['id']],
        );
      }
    }
  }
}
```

## Implementation Plan

### Phase 1: Model Updates
1. Add `label` field to `FileAttachment` model
2. Remove `labels` field from `Document` model
3. Update all serialization methods
4. Update tests

### Phase 2: Database Updates
1. Increment database version to 3
2. Add migration logic in `_upgradeDB`
3. Update repository methods
4. Test migration with sample data

### Phase 3: UI Updates
1. Add label input when picking files
2. Display labels in file lists
3. Add edit label functionality
4. Update document detail screen
5. Update document list screen (if showing file info)

### Phase 4: GraphQL/Sync Updates
1. Update GraphQL schema
2. Run `amplify push`
3. Update sync service to handle file labels
4. Test cloud sync with labels

### Phase 5: Testing
1. Unit tests for FileAttachment with labels
2. Integration tests for label persistence
3. UI tests for label input/display
4. Migration tests
5. Sync tests

## Breaking Changes

### For Users
- ✅ **No data loss**: Files are preserved
- ⚠️ **Labels lost**: Existing document labels will be removed (or migrated to first file)
- ✅ **Better UX**: More intuitive labeling system

### For Developers
- ❌ **Breaking API change**: Document model changes
- ❌ **Database migration required**: Schema changes
- ❌ **GraphQL schema change**: API changes
- ✅ **Backward compatible**: Can be handled with version bump

## Recommended Approach

### Recommendation: Option 1 (File Labels Only)

**Reasoning**:
1. **Simpler**: One labeling system, not two
2. **More useful**: Labels describe what each file contains
3. **Better UX**: Clear association between label and file
4. **Easier to implement**: Fewer changes overall

**Version**: Bump to 3.0.0 (breaking change)

**Timeline**:
- Phase 1 (Models): 1-2 hours
- Phase 2 (Database): 1-2 hours
- Phase 3 (UI): 2-3 hours
- Phase 4 (Sync): 1-2 hours
- Phase 5 (Testing): 2-3 hours
- **Total**: 7-12 hours

## Alternative: Quick Fix (Keep Current Structure)

If you want to keep the current structure but improve it:

### Rename "Labels" to "Tags"
```dart
class Document {
  final List<String> tags;  // Renamed from labels
}
```

**Use tags for**:
- Document-level categorization: "Important", "Urgent", "Archive"
- Cross-cutting concerns: "Tax-Related", "Legal", "Personal"
- Status indicators: "Pending", "Completed", "Expired"

**Use file names for**:
- File identification: "policy.pdf", "renewal-notice.pdf"

This is less ideal but requires no migration.

## Questions to Consider

1. **Should labels be mandatory or optional for files?**
   - Recommendation: Optional (not all files need labels)

2. **Should we provide suggested labels based on category?**
   - Example: Home Insurance → ["Policy", "Renewal", "Claim Form", "Receipt"]
   - Recommendation: Yes, improves UX

3. **Should labels be free-text or predefined?**
   - Recommendation: Free-text with suggestions

4. **Should we keep document-level tags as well?**
   - Recommendation: No, keep it simple

5. **How to handle existing document labels during migration?**
   - Recommendation: Drop them (they weren't being used correctly anyway)

## Next Steps

1. **Review this proposal** - Confirm the approach
2. **Create spec** - Formal requirements and design document
3. **Implement changes** - Follow the implementation plan
4. **Test thoroughly** - Ensure no data loss
5. **Deploy** - Version 3.0.0 release

## Summary

**Current**: Labels on documents (incorrect)  
**Proposed**: Labels on file attachments (correct)  
**Impact**: Breaking change, requires migration  
**Benefit**: Much better UX and organization  
**Recommendation**: Implement Option 1 (File Labels Only)
