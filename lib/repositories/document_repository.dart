import 'package:uuid/uuid.dart';
import '../models/new_document.dart';
import '../models/file_attachment.dart';
import '../models/sync_state.dart';
import '../services/new_database_service.dart';

/// Custom exception for database operations
class DatabaseException implements Exception {
  final String message;
  DatabaseException(this.message);

  @override
  String toString() => 'DatabaseException: $message';
}

/// Repository for managing document metadata in local SQLite database
class DocumentRepository {
  static final DocumentRepository _instance = DocumentRepository._internal();
  factory DocumentRepository() => _instance;
  DocumentRepository._internal();

  final _dbService = NewDatabaseService.instance;
  final _uuid = const Uuid();

  /// Create a new document with generated syncId
  Future<Document> createDocument({
    required String title,
    required DocumentCategory category,
    DateTime? date,
    String? notes,
  }) async {
    try {
      final document = Document.create(
        title: title,
        category: category,
        date: date,
        notes: notes,
      );

      final db = await _dbService.database;
      await db.insert('documents', document.toDatabase());

      return document;
    } catch (e) {
      throw DatabaseException('Failed to create document: $e');
    }
  }

  /// Insert a document from remote sync (with existing syncId and timestamps)
  Future<void> insertRemoteDocument(Document document) async {
    try {
      final db = await _dbService.database;
      await db.insert('documents', document.toDatabase());
    } catch (e) {
      throw DatabaseException('Failed to insert remote document: $e');
    }
  }

  /// Get a document by syncId
  Future<Document?> getDocument(String syncId) async {
    try {
      final db = await _dbService.database;
      final results = await db.query(
        'documents',
        where: 'sync_id = ?',
        whereArgs: [syncId],
      );

      if (results.isEmpty) {
        return null;
      }

      final document = Document.fromDatabase(results.first);

      // Load file attachments
      final files = await getFileAttachments(syncId);
      return document.copyWith(files: files);
    } catch (e) {
      throw DatabaseException('Failed to get document: $e');
    }
  }

  /// Get all documents, sorted by updated date (newest first)
  Future<List<Document>> getAllDocuments() async {
    try {
      final db = await _dbService.database;
      final results = await db.query(
        'documents',
        orderBy: 'updated_at DESC',
      );

      final documents = <Document>[];
      for (final row in results) {
        final document = Document.fromDatabase(row);
        final files = await getFileAttachments(document.syncId);
        documents.add(document.copyWith(files: files));
      }

      return documents;
    } catch (e) {
      throw DatabaseException('Failed to get all documents: $e');
    }
  }

  /// Update an existing document
  Future<void> updateDocument(Document document) async {
    try {
      final db = await _dbService.database;

      // Start transaction
      await db.transaction((txn) async {
        // Update document
        final updated = document.copyWith(updatedAt: DateTime.now());
        final count = await txn.update(
          'documents',
          updated.toDatabase(),
          where: 'sync_id = ?',
          whereArgs: [document.syncId],
        );

        if (count == 0) {
          throw DatabaseException('Document not found: ${document.syncId}');
        }
      });
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to update document: $e');
    }
  }

  /// Delete a document and its file attachments (cascade)
  Future<void> deleteDocument(String syncId) async {
    try {
      final db = await _dbService.database;

      await db.transaction((txn) async {
        // Delete file attachments (cascade handled by foreign key)
        await txn.delete(
          'file_attachments',
          where: 'sync_id = ?',
          whereArgs: [syncId],
        );

        // Delete document
        final count = await txn.delete(
          'documents',
          where: 'sync_id = ?',
          whereArgs: [syncId],
        );

        if (count == 0) {
          throw DatabaseException('Document not found: $syncId');
        }
      });
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to delete document: $e');
    }
  }

  /// Add a file attachment to a document
  Future<void> addFileAttachment({
    required String syncId,
    required String fileName,
    String? localPath,
    String? s3Key,
    int? fileSize,
    String? label,
  }) async {
    try {
      final db = await _dbService.database;

      // Verify document exists
      final docExists = await _documentExists(syncId);
      if (!docExists) {
        throw DatabaseException('Document not found: $syncId');
      }

      final fileAttachment = FileAttachment(
        fileName: fileName,
        label: label,
        localPath: localPath,
        s3Key: s3Key,
        fileSize: fileSize,
        addedAt: DateTime.now(),
      );

      await db.insert('file_attachments', {
        'sync_id': syncId,
        'file_name': fileAttachment.fileName,
        'label': fileAttachment.label,
        'local_path': fileAttachment.localPath,
        's3_key': fileAttachment.s3Key,
        'file_size': fileAttachment.fileSize,
        'added_at': fileAttachment.addedAt.millisecondsSinceEpoch,
      });
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to add file attachment: $e');
    }
  }

  /// Update the S3 key for a file attachment
  Future<void> updateFileS3Key({
    required String syncId,
    required String fileName,
    required String s3Key,
  }) async {
    try {
      final db = await _dbService.database;

      final count = await db.update(
        'file_attachments',
        {'s3_key': s3Key},
        where: 'sync_id = ? AND file_name = ?',
        whereArgs: [syncId, fileName],
      );

      if (count == 0) {
        throw DatabaseException(
          'File attachment not found: $fileName in document $syncId',
        );
      }
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to update file S3 key: $e');
    }
  }

  /// Update the local path for a file attachment
  Future<void> updateFileLocalPath({
    required String syncId,
    required String fileName,
    required String localPath,
  }) async {
    try {
      final db = await _dbService.database;

      final count = await db.update(
        'file_attachments',
        {'local_path': localPath},
        where: 'sync_id = ? AND file_name = ?',
        whereArgs: [syncId, fileName],
      );

      if (count == 0) {
        throw DatabaseException(
          'File attachment not found: $fileName in document $syncId',
        );
      }
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to update file local path: $e');
    }
  }

  /// Update the label for a file attachment
  Future<void> updateFileLabel({
    required String syncId,
    required String fileName,
    required String? label,
  }) async {
    try {
      final db = await _dbService.database;

      final count = await db.update(
        'file_attachments',
        {'label': label},
        where: 'sync_id = ? AND file_name = ?',
        whereArgs: [syncId, fileName],
      );

      if (count == 0) {
        throw DatabaseException(
          'File attachment not found: $fileName in document $syncId',
        );
      }
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to update file label: $e');
    }
  }

  /// Get all file attachments for a document
  Future<List<FileAttachment>> getFileAttachments(String syncId) async {
    try {
      final db = await _dbService.database;
      final results = await db.query(
        'file_attachments',
        where: 'sync_id = ?',
        whereArgs: [syncId],
        orderBy: 'added_at ASC',
      );

      return results.map((row) => FileAttachment.fromDatabase(row)).toList();
    } catch (e) {
      throw DatabaseException('Failed to get file attachments: $e');
    }
  }

  /// Delete a specific file attachment
  Future<void> deleteFileAttachment({
    required String syncId,
    required String fileName,
  }) async {
    try {
      final db = await _dbService.database;

      final count = await db.delete(
        'file_attachments',
        where: 'sync_id = ? AND file_name = ?',
        whereArgs: [syncId, fileName],
      );

      if (count == 0) {
        throw DatabaseException(
          'File attachment not found: $fileName in document $syncId',
        );
      }
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to delete file attachment: $e');
    }
  }

  /// Update the sync state of a document
  Future<void> updateSyncState(String syncId, SyncState state) async {
    try {
      final db = await _dbService.database;

      final count = await db.update(
        'documents',
        {
          'sync_state': state.name,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'sync_id = ?',
        whereArgs: [syncId],
      );

      if (count == 0) {
        throw DatabaseException('Document not found: $syncId');
      }
    } catch (e) {
      if (e is DatabaseException) rethrow;
      throw DatabaseException('Failed to update sync state: $e');
    }
  }

  /// Get documents by sync state
  Future<List<Document>> getDocumentsBySyncState(SyncState state) async {
    try {
      final db = await _dbService.database;
      final results = await db.query(
        'documents',
        where: 'sync_state = ?',
        whereArgs: [state.name],
        orderBy: 'updated_at DESC',
      );

      final documents = <Document>[];
      for (final row in results) {
        final document = Document.fromDatabase(row);
        final files = await getFileAttachments(document.syncId);
        documents.add(document.copyWith(files: files));
      }

      return documents;
    } catch (e) {
      throw DatabaseException('Failed to get documents by sync state: $e');
    }
  }

  /// Get documents that need to be uploaded (pendingUpload or error state)
  Future<List<Document>> getDocumentsNeedingUpload() async {
    try {
      final db = await _dbService.database;
      final results = await db.query(
        'documents',
        where: 'sync_state IN (?, ?)',
        whereArgs: [SyncState.pendingUpload.name, SyncState.error.name],
        orderBy: 'updated_at DESC',
      );

      final documents = <Document>[];
      for (final row in results) {
        final document = Document.fromDatabase(row);
        final files = await getFileAttachments(document.syncId);
        documents.add(document.copyWith(files: files));
      }

      return documents;
    } catch (e) {
      throw DatabaseException('Failed to get documents needing upload: $e');
    }
  }

  /// Get documents that need to be downloaded (have S3 key but no local path)
  Future<List<Document>> getDocumentsNeedingDownload() async {
    try {
      final db = await _dbService.database;

      // Get documents with file attachments that have S3 key but no local path
      final results = await db.rawQuery('''
        SELECT DISTINCT d.*
        FROM documents d
        INNER JOIN file_attachments f ON d.sync_id = f.sync_id
        WHERE f.s3_key IS NOT NULL AND f.local_path IS NULL
        ORDER BY d.updated_at DESC
      ''');

      final documents = <Document>[];
      for (final row in results) {
        final document = Document.fromDatabase(row);
        final files = await getFileAttachments(document.syncId);
        documents.add(document.copyWith(files: files));
      }

      return documents;
    } catch (e) {
      throw DatabaseException('Failed to get documents needing download: $e');
    }
  }

  /// Check if a document exists
  Future<bool> _documentExists(String syncId) async {
    final db = await _dbService.database;
    final results = await db.query(
      'documents',
      where: 'sync_id = ?',
      whereArgs: [syncId],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  /// Get document count
  Future<int> getDocumentCount() async {
    try {
      final db = await _dbService.database;
      final result =
          await db.rawQuery('SELECT COUNT(*) as count FROM documents');
      return result.first['count'] as int;
    } catch (e) {
      throw DatabaseException('Failed to get document count: $e');
    }
  }

  /// Get count of documents by sync state
  Future<Map<SyncState, int>> getDocumentCountsBySyncState() async {
    try {
      final db = await _dbService.database;
      final results = await db.rawQuery('''
        SELECT sync_state, COUNT(*) as count
        FROM documents
        GROUP BY sync_state
      ''');

      final counts = <SyncState, int>{};
      for (final row in results) {
        final stateName = row['sync_state'] as String;
        final count = row['count'] as int;
        final state = SyncState.values.firstWhere((s) => s.name == stateName);
        counts[state] = count;
      }

      return counts;
    } catch (e) {
      throw DatabaseException(
          'Failed to get document counts by sync state: $e');
    }
  }
}
