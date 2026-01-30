# Sync Exception: Document Not Found - Root Cause Analysis

**Error**: `SyncException: Document not found: <syncId>`  
**Location**: `lib/services/sync_service.dart` - `syncDocument()` method  
**Date**: January 18, 2026

## Problem Description

When saving a new document, the app throws a `SyncException` with message "Document not found" during the sync operation.

## Root Cause

There's a **timing/transaction issue** in the document creation flow:

### Current Flow (BROKEN)
```dart
// In new_document_detail_screen.dart - _saveDocument()

1. Create Document object in memory
   doc = Document.create(title: ..., category: ..., date: ...)
   // doc.syncId is generated here (e.g., "abc-123")

2. Save to repository
   await _documentRepository.createDocument(...)
   // This inserts the document into SQLite

3. Add file attachments
   for (final file in _files) {
     await _documentRepository.addFileAttachment(
       syncId: doc.syncId,  // Using the syncId from step 1
       ...
     )
   }

4. Trigger sync
   await _syncService.syncDocument(doc.syncId)
   // ❌ PROBLEM: This queries the database for doc.syncId
   //    but the syncId might not match what was actually saved!
```

### The Issue

**In `document_repository.dart` - `createDocument()`**:
```dart
Future<Document> createDocument({
  required String title,
  required DocumentCategory category,
  DateTime? date,
  String? notes,
  List<String>? labels,
}) async {
  try {
    final document = Document.create(  // ← Generates NEW syncId here!
      title: title,
      category: category,
      date: date,
      notes: notes,
      labels: labels ?? [],
    );

    final db = await _dbService.database;
    await db.insert('documents', document.toDatabase());

    return document;  // Returns the document with its syncId
  } catch (e) {
    throw DatabaseException('Failed to create document: $e');
  }
}
```

**The problem**: 
1. Screen creates a `Document` object with syncId "abc-123"
2. Repository's `createDocument()` creates a **NEW** `Document` object with a **DIFFERENT** syncId "xyz-789"
3. Repository inserts the document with syncId "xyz-789" into database
4. Screen tries to add file attachments using syncId "abc-123" (from step 1)
5. Screen tries to sync using syncId "abc-123"
6. Sync service queries database for "abc-123" → **NOT FOUND!**

## Why This Happens

The screen creates a `Document` object before calling `createDocument()`, but the repository **ignores** that object and creates its own. The screen then uses the original (unsaved) syncId for subsequent operations.

## Evidence

### In `new_document_detail_screen.dart`:
```dart
// Line ~165: Create document object
doc = Document.create(
  title: _titleController.text.trim(),
  category: _selectedCategory,
  date: _selectedDate,
  notes: ...,
  labels: _labels,
);

// Line ~195: Call repository (which creates ANOTHER document)
await _documentRepository.createDocument(
  title: doc.title,      // ← Passing fields, not the document
  category: doc.category,
  date: doc.date,
  notes: doc.notes,
  labels: doc.labels,
);

// Line ~203: Use original doc.syncId (which was never saved!)
await _documentRepository.addFileAttachment(
  syncId: doc.syncId,  // ❌ Wrong syncId!
  ...
);

// Line ~214: Try to sync with wrong syncId
await _syncService.syncDocument(doc.syncId);  // ❌ Not found!
```

## Solutions

### Solution 1: Use Returned Document (RECOMMENDED)

**Change the screen to use the document returned by the repository:**

```dart
// In new_document_detail_screen.dart - _saveDocument()

Future<void> _saveDocument() async {
  // ... validation ...

  try {
    Document savedDoc;  // ← Store the returned document

    if (widget.document == null) {
      // Create new document - USE THE RETURNED DOCUMENT
      savedDoc = await _documentRepository.createDocument(
        title: _titleController.text.trim(),
        category: _selectedCategory,
        date: _selectedDate,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        labels: _labels,
      );
    } else {
      // Update existing document
      final doc = widget.document!.copyWith(
        title: _titleController.text.trim(),
        category: _selectedCategory,
        date: _selectedDate,
        clearDate: _selectedDate == null && widget.document!.date != null,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        labels: _labels,
        updatedAt: DateTime.now(),
        files: _files,
      );
      
      await _documentRepository.updateDocument(doc);
      savedDoc = doc;
    }

    // Add file attachments using CORRECT syncId
    for (final file in _files) {
      if (file.localPath != null && file.s3Key == null) {
        await _documentRepository.addFileAttachment(
          syncId: savedDoc.syncId,  // ✅ Use returned document's syncId
          fileName: file.fileName,
          localPath: file.localPath!,
          s3Key: null,
          fileSize: file.fileSize,
        );
      }
    }

    // Trigger sync with CORRECT syncId
    await _syncService.syncDocument(savedDoc.syncId);  // ✅ Correct!

    // ... rest of the code ...
  } catch (e) {
    // ... error handling ...
  }
}
```

### Solution 2: Accept Document Object in Repository (ALTERNATIVE)

**Change the repository to accept the pre-created document:**

```dart
// In document_repository.dart

Future<Document> createDocument({
  Document? document,  // ← Accept optional pre-created document
  String? title,
  DocumentCategory? category,
  DateTime? date,
  String? notes,
  List<String>? labels,
}) async {
  try {
    // Use provided document or create new one
    final doc = document ?? Document.create(
      title: title!,
      category: category!,
      date: date,
      notes: notes,
      labels: labels ?? [],
    );

    final db = await _dbService.database;
    await db.insert('documents', doc.toDatabase());

    return doc;
  } catch (e) {
    throw DatabaseException('Failed to create document: $e');
  }
}
```

Then in the screen:
```dart
// Create document once
final doc = Document.create(...);

// Save it (repository uses the same document)
await _documentRepository.createDocument(document: doc);

// Use the same syncId for everything
await _documentRepository.addFileAttachment(syncId: doc.syncId, ...);
await _syncService.syncDocument(doc.syncId);
```

### Solution 3: Return syncId from createDocument (SIMPLEST)

**Just return the syncId and use it:**

```dart
// In document_repository.dart
Future<String> createDocument(...) async {
  // ... create document ...
  await db.insert('documents', document.toDatabase());
  return document.syncId;  // ← Return just the syncId
}

// In screen
final syncId = await _documentRepository.createDocument(...);
await _documentRepository.addFileAttachment(syncId: syncId, ...);
await _syncService.syncDocument(syncId);
```

## Recommended Fix

**Solution 1** is the best approach because:
1. ✅ Minimal changes to repository (already returns Document)
2. ✅ Clear ownership: repository creates and returns the document
3. ✅ Screen uses what repository returns
4. ✅ No duplicate document creation
5. ✅ Type-safe (returns full Document object)

## Additional Issues Found

### Issue 2: File Attachments Added Before Document Exists

The current code adds file attachments immediately after creating the document, but if the document creation fails partway through, you could have orphaned file attachment records.

**Better approach**: Use a transaction:
```dart
await db.transaction((txn) async {
  // Insert document
  await txn.insert('documents', document.toDatabase());
  
  // Insert file attachments
  for (final file in files) {
    await txn.insert('file_attachments', file.toDatabase());
  }
});
```

### Issue 3: Sync Called Even If Offline

The screen calls `syncDocument()` without checking connectivity. The sync service will throw an exception if offline.

**Better approach**: Check connectivity first or catch the exception:
```dart
try {
  await _syncService.syncDocument(savedDoc.syncId);
} catch (e) {
  // Log but don't fail the save operation
  debugPrint('Sync failed (will retry later): $e');
}
```

## Testing the Fix

### Test Case 1: Create New Document
```dart
test('should create document and sync with correct syncId', () async {
  // Create document
  final savedDoc = await repository.createDocument(
    title: 'Test',
    category: DocumentCategory.other,
  );
  
  // Verify document exists with returned syncId
  final retrieved = await repository.getDocument(savedDoc.syncId);
  expect(retrieved, isNotNull);
  expect(retrieved!.syncId, equals(savedDoc.syncId));
  
  // Sync should work with returned syncId
  await syncService.syncDocument(savedDoc.syncId);
  // Should not throw "Document not found"
});
```

### Test Case 2: Add File Attachments
```dart
test('should add file attachments to created document', () async {
  // Create document
  final savedDoc = await repository.createDocument(
    title: 'Test',
    category: DocumentCategory.other,
  );
  
  // Add file attachment using returned syncId
  await repository.addFileAttachment(
    syncId: savedDoc.syncId,  // ← Use returned syncId
    fileName: 'test.pdf',
    localPath: '/path/to/file',
    fileSize: 1024,
  );
  
  // Verify attachment exists
  final files = await repository.getFileAttachments(savedDoc.syncId);
  expect(files.length, equals(1));
});
```

## Summary

**Root Cause**: Screen creates a Document object, but repository creates a different one with a different syncId. Screen uses the wrong syncId for subsequent operations.

**Fix**: Use the Document object returned by `createDocument()` for all subsequent operations.

**Impact**: 
- ✅ Fixes "Document not found" error
- ✅ Ensures syncId consistency
- ✅ Minimal code changes
- ✅ No breaking changes to API

**Priority**: HIGH - Blocks document creation functionality
