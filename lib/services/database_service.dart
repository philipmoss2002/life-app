import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/Document.dart';
import '../models/FileAttachment.dart';
import '../models/model_extensions.dart';
import 'sync_identifier_service.dart';

/// Local document representation for database operations
class LocalDocument {
  final int? id;
  final String? syncId;
  final String title;
  final String category;
  final List<String> filePaths;
  final DateTime? renewalDate;
  final String? notes;
  final DateTime createdAt;
  final String? userId;
  final DateTime lastModified;
  final int version;
  final String syncState;
  final String? conflictId;

  LocalDocument({
    this.id,
    this.syncId,
    required this.title,
    required this.category,
    this.filePaths = const [],
    this.renewalDate,
    this.notes,
    required this.createdAt,
    this.userId,
    required this.lastModified,
    this.version = 1,
    this.syncState = 'notSynced',
    this.conflictId,
  });

  factory LocalDocument.fromMap(Map<String, dynamic> map,
      {List<String>? filePaths}) {
    return LocalDocument(
      syncId: map['syncId'] as String?,
      title: map['title'] as String,
      category: map['category'] as String,
      filePaths: filePaths ?? [],
      renewalDate: map['renewalDate'] != null
          ? DateTime.parse(map['renewalDate'] as String)
          : null,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      userId: map['userId'] as String?,
      lastModified: map['lastModified'] != null
          ? DateTime.parse(map['lastModified'] as String)
          : DateTime.now(),
      version: map['version'] as int? ?? 1,
      syncState: map['syncState'] as String? ?? 'notSynced',
      conflictId: map['conflictId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'syncId': syncId,
      'title': title,
      'category': category,
      'filePath': filePaths.isNotEmpty ? filePaths.first : null,
      'renewalDate': renewalDate?.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'userId': userId,
      'lastModified': lastModified.toIso8601String(),
      'version': version,
      'syncState': syncState,
      'conflictId': conflictId,
    };
  }
}

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('household_docs.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        syncId TEXT UNIQUE,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        filePath TEXT,
        renewalDate TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        userId TEXT,
        lastModified TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        syncState TEXT NOT NULL DEFAULT 'notSynced',
        conflictId TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE file_attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        documentId INTEGER NOT NULL,
        syncId TEXT,
        documentSyncId TEXT,
        userId TEXT,
        filePath TEXT NOT NULL,
        fileName TEXT NOT NULL,
        label TEXT,
        addedAt TEXT NOT NULL,
        fileSize INTEGER,
        s3Key TEXT,
        contentType TEXT,
        checksum TEXT,
        FOREIGN KEY (documentId) REFERENCES documents (id) ON DELETE CASCADE,
        FOREIGN KEY (syncId) REFERENCES documents (syncId) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE document_tombstones (
        syncId TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        deletedAt TEXT NOT NULL,
        deletedBy TEXT NOT NULL,
        reason TEXT NOT NULL DEFAULT 'user'
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_documents_syncId ON documents(syncId)');
    await db.execute('CREATE INDEX idx_documents_userId ON documents(userId)');
    await db.execute(
        'CREATE INDEX idx_file_attachments_syncId ON file_attachments(syncId)');
    await db.execute(
        'CREATE INDEX idx_tombstones_userId ON document_tombstones(userId)');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE file_attachments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          documentId INTEGER NOT NULL,
          filePath TEXT NOT NULL,
          fileName TEXT NOT NULL,
          label TEXT,
          addedAt TEXT NOT NULL,
          FOREIGN KEY (documentId) REFERENCES documents (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add label column to existing file_attachments table (if it doesn't exist)
      try {
        await db.execute('''
          ALTER TABLE file_attachments ADD COLUMN label TEXT
        ''');
      } catch (e) {
        // Column might already exist, ignore error
        debugPrint('Label column might already exist: $e');
      }
    }
    if (oldVersion < 4) {
      // Add cloud sync columns to documents table (with error handling)
      try {
        await db.execute('''
          ALTER TABLE documents ADD COLUMN userId TEXT
        ''');
      } catch (e) {
        debugPrint('userId column might already exist: $e');
      }

      try {
        await db.execute('''
          ALTER TABLE documents ADD COLUMN lastModified TEXT NOT NULL DEFAULT '${DateTime.now().toIso8601String()}'
        ''');
      } catch (e) {
        debugPrint('lastModified column might already exist: $e');
      }

      try {
        await db.execute('''
          ALTER TABLE documents ADD COLUMN version INTEGER NOT NULL DEFAULT 1
        ''');
      } catch (e) {
        debugPrint('version column might already exist: $e');
      }

      try {
        await db.execute('''
          ALTER TABLE documents ADD COLUMN syncState TEXT NOT NULL DEFAULT 'notSynced'
        ''');
      } catch (e) {
        debugPrint('syncState column might already exist: $e');
      }

      try {
        await db.execute('''
          ALTER TABLE documents ADD COLUMN conflictId TEXT
        ''');
      } catch (e) {
        debugPrint('conflictId column might already exist: $e');
      }
    }
    if (oldVersion < 5) {
      // Add syncId column to documents table
      try {
        await db.execute('''
          ALTER TABLE documents ADD COLUMN syncId TEXT
        ''');
      } catch (e) {
        debugPrint('syncId column might already exist: $e');
      }

      // Add sync identifier related columns to file_attachments table
      try {
        await db.execute('''
          ALTER TABLE file_attachments ADD COLUMN syncId TEXT
        ''');
      } catch (e) {
        debugPrint('syncId column in file_attachments might already exist: $e');
      }

      try {
        await db.execute('''
          ALTER TABLE file_attachments ADD COLUMN fileSize INTEGER
        ''');
      } catch (e) {
        debugPrint('fileSize column might already exist: $e');
      }

      try {
        await db.execute('''
          ALTER TABLE file_attachments ADD COLUMN s3Key TEXT
        ''');
      } catch (e) {
        debugPrint('s3Key column might already exist: $e');
      }

      try {
        await db.execute('''
          ALTER TABLE file_attachments ADD COLUMN contentType TEXT
        ''');
      } catch (e) {
        debugPrint('contentType column might already exist: $e');
      }

      try {
        await db.execute('''
          ALTER TABLE file_attachments ADD COLUMN checksum TEXT
        ''');
      } catch (e) {
        debugPrint('checksum column might already exist: $e');
      }

      // Create document_tombstones table
      try {
        await db.execute('''
          CREATE TABLE document_tombstones (
            syncId TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            deletedAt TEXT NOT NULL,
            deletedBy TEXT NOT NULL,
            reason TEXT NOT NULL DEFAULT 'user'
          )
        ''');
      } catch (e) {
        debugPrint('document_tombstones table might already exist: $e');
      }

      // Create indexes for better performance
      try {
        await db
            .execute('CREATE INDEX idx_documents_syncId ON documents(syncId)');
      } catch (e) {
        debugPrint('Index idx_documents_syncId might already exist: $e');
      }

      try {
        await db
            .execute('CREATE INDEX idx_documents_userId ON documents(userId)');
      } catch (e) {
        debugPrint('Index idx_documents_userId might already exist: $e');
      }

      try {
        await db.execute(
            'CREATE INDEX idx_file_attachments_syncId ON file_attachments(syncId)');
      } catch (e) {
        debugPrint('Index idx_file_attachments_syncId might already exist: $e');
      }

      try {
        await db.execute(
            'CREATE INDEX idx_tombstones_userId ON document_tombstones(userId)');
      } catch (e) {
        debugPrint('Index idx_tombstones_userId might already exist: $e');
      }

      // Create unique index on syncId for documents (if not null)
      try {
        await db.execute(
            'CREATE UNIQUE INDEX idx_documents_syncId_unique ON documents(syncId) WHERE syncId IS NOT NULL');
      } catch (e) {
        debugPrint('Unique index on syncId might already exist: $e');
      }
    }
    if (oldVersion < 6) {
      // Add userId and documentSyncId columns to file_attachments table for proper authorization
      try {
        await db.execute('''
          ALTER TABLE file_attachments ADD COLUMN userId TEXT
        ''');
      } catch (e) {
        debugPrint('userId column in file_attachments might already exist: $e');
      }

      try {
        await db.execute('''
          ALTER TABLE file_attachments ADD COLUMN documentSyncId TEXT
        ''');
      } catch (e) {
        debugPrint(
            'documentSyncId column in file_attachments might already exist: $e');
      }

      // Update existing file_attachments with userId and documentSyncId from their parent documents
      try {
        await db.execute('''
          UPDATE file_attachments 
          SET userId = (
            SELECT d.userId 
            FROM documents d 
            WHERE d.id = file_attachments.documentId
          ),
          documentSyncId = (
            SELECT d.syncId 
            FROM documents d 
            WHERE d.id = file_attachments.documentId
          )
          WHERE userId IS NULL OR documentSyncId IS NULL
        ''');
      } catch (e) {
        debugPrint(
            'Error updating existing file_attachments with userId and documentSyncId: $e');
      }
    }
  }

  Future<int> createDocument(dynamic document) async {
    // Validate document before creation
    await _validateDocumentForStorage(document, operation: 'document creation');

    final db = await database;
    final documentMap = document is LocalDocument
        ? document.toMap()
        : DocumentExtensions(document).toMap();
    final id = await db.insert('documents', documentMap);

    // Insert file attachments
    if (document.filePaths != null && document.filePaths.isNotEmpty) {
      for (final filePath in document.filePaths) {
        // Don't pass document.syncId as FileAttachment syncId - let _addFileAttachment generate unique ones
        await _addFileAttachment(id, filePath, null);
      }
    }

    return id;
  }

  Future<int> createDocumentWithLabels(
      Document document, Map<String, String?> fileLabels) async {
    // Validate document before creation
    await _validateDocumentForStorage(document,
        operation: 'document creation with labels');

    final db = await database;
    final id =
        await db.insert('documents', DocumentExtensions(document).toMap());

    // Insert file attachments with labels
    if (document.filePaths.isNotEmpty) {
      for (final filePath in document.filePaths) {
        final label = fileLabels[filePath];
        // Don't pass document.syncId as FileAttachment syncId - let _addFileAttachment generate unique ones
        await _addFileAttachment(id, filePath, label);
      }
    }

    return id;
  }

  Future<List<Document>> getAllDocuments([String? userId]) async {
    final db = await database;

    // Build where clause to exclude documents pending deletion
    String whereClause = "syncState != 'pendingDeletion'";
    List<dynamic> whereArgs = [];

    if (userId != null) {
      whereClause += ' AND userId = ?';
      whereArgs.add(userId);
    }

    final result = await db.query(
      'documents',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'createdAt DESC',
    );

    final documents = <Document>[];
    for (final map in result) {
      final filePaths = await _getFileAttachments(map['id'] as int);
      // Convert to Amplify Document model
      final documentMap = Map<String, dynamic>.from(map);
      documentMap['filePaths'] = filePaths;

      // Ensure document has a sync identifier - assign one if missing
      if (documentMap['syncId'] == null ||
          documentMap['syncId'].toString().isEmpty) {
        final syncId = SyncIdentifierService.generateValidated();
        documentMap['syncId'] = syncId;

        // Update the database with the new sync identifier
        await db.update(
          'documents',
          {'syncId': syncId},
          where: 'id = ?',
          whereArgs: [map['id']],
        );

        debugPrint(
            '🔄 Assigned sync ID $syncId to existing document ${map['id']}: ${map['title']}');
      }

      final document = DocumentExtensions.fromMap(documentMap);
      documents.add(document);
    }
    return documents;
  }

  Future<List<Document>> getDocumentsByCategory(String category,
      [String? userId]) async {
    final db = await database;

    // Build where clause to exclude documents pending deletion
    String whereClause = "category = ? AND syncState != 'pendingDeletion'";
    List<dynamic> whereArgs = [category];

    if (userId != null) {
      whereClause += ' AND userId = ?';
      whereArgs.add(userId);
    }

    final result = await db.query(
      'documents',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'createdAt DESC',
    );

    final documents = <Document>[];
    for (final map in result) {
      final filePaths = await _getFileAttachments(map['id'] as int);
      // Convert to Amplify Document model
      final documentMap = Map<String, dynamic>.from(map);
      documentMap['filePaths'] = filePaths;

      // Ensure document has a sync identifier - assign one if missing
      if (documentMap['syncId'] == null ||
          documentMap['syncId'].toString().isEmpty) {
        final syncId = SyncIdentifierService.generateValidated();
        documentMap['syncId'] = syncId;

        // Update the database with the new sync identifier
        await db.update(
          'documents',
          {'syncId': syncId},
          where: 'id = ?',
          whereArgs: [map['id']],
        );

        debugPrint(
            '🔄 Assigned sync ID $syncId to existing document ${map['id']}: ${map['title']}');
      }

      final document = DocumentExtensions.fromMap(documentMap);
      documents.add(document);
    }
    return documents;
  }

  /// Get all documents for a specific user
  Future<List<Document>> getUserDocuments(String userId) async {
    return await getAllDocuments(userId);
  }

  /// Get documents by category for a specific user
  Future<List<Document>> getUserDocumentsByCategory(
      String userId, String category) async {
    return await getDocumentsByCategory(category, userId);
  }

  /// Clear all data for a specific user (for sign out)
  Future<void> clearUserData(String userId) async {
    final db = await database;

    // Get all documents for this user
    final userDocuments = await db.query(
      'documents',
      where: 'userId = ?',
      whereArgs: [userId],
    );

    // Delete file attachments for user's documents
    for (final doc in userDocuments) {
      await db.delete(
        'file_attachments',
        where: 'documentId = ?',
        whereArgs: [doc['id']],
      );
    }

    // Delete user's documents
    await db.delete(
      'documents',
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }

  /// Clear all data (for complete reset)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('file_attachments');
    await db.delete('documents');
  }

  /// Get documents that are pending deletion (for sync processing)
  Future<List<Document>> getDocumentsPendingDeletion([String? userId]) async {
    final db = await database;

    // Build where clause to get only documents pending deletion
    String whereClause = "syncState = 'pendingDeletion'";
    List<dynamic> whereArgs = [];

    if (userId != null) {
      whereClause += ' AND userId = ?';
      whereArgs.add(userId);
    }

    final result = await db.query(
      'documents',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'lastModified ASC', // Process oldest deletions first
    );

    final documents = <Document>[];
    for (final map in result) {
      final filePaths = await _getFileAttachments(map['id'] as int);
      // Convert to Amplify Document model
      final documentMap = Map<String, dynamic>.from(map);
      documentMap['filePaths'] = filePaths;
      final document = DocumentExtensions.fromMap(documentMap);
      documents.add(document);
    }
    return documents;
  }

  /// Migrate documents with placeholder user IDs to actual user ID
  /// This fixes documents created before user isolation was implemented
  Future<int> migrateDocumentsToUser(String actualUserId) async {
    final db = await database;

    // Update documents with placeholder user IDs
    final placeholderUserIds = ['current_user', 'placeholder', '', 'null'];
    int totalUpdated = 0;

    for (final placeholderId in placeholderUserIds) {
      final updated = await db.update(
        'documents',
        {'userId': actualUserId},
        where: 'userId = ? OR userId IS NULL',
        whereArgs: [placeholderId],
      );
      totalUpdated += updated;
    }

    debugPrint('Migrated $totalUpdated documents to user $actualUserId');
    return totalUpdated;
  }

  /// Get count of documents with placeholder user IDs
  Future<int> getPlaceholderDocumentCount() async {
    final db = await database;

    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM documents 
      WHERE userId IN ('current_user', 'placeholder', '') 
         OR userId IS NULL
    ''');

    return result.first['count'] as int;
  }

  Future<void> _addFileAttachment(
      int documentId, String filePath, String? label,
      {String? syncId, String? s3Key}) async {
    final db = await database;
    final fileName = filePath.split('/').last;

    // Get the userId and syncId from the parent document
    final docResult = await db.query(
      'documents',
      columns: ['userId', 'syncId'],
      where: 'id = ?',
      whereArgs: [documentId],
    );

    final userId =
        docResult.isNotEmpty ? docResult.first['userId'] as String? : null;
    final documentSyncId =
        docResult.isNotEmpty ? docResult.first['syncId'] as String? : null;

    // Generate a unique syncId for this FileAttachment (NOT the document's syncId)
    final fileAttachmentSyncId =
        syncId ?? SyncIdentifierService.generateValidated();

    await db.insert('file_attachments', {
      'documentId': documentId,
      'syncId': fileAttachmentSyncId, // Unique syncId for this FileAttachment
      'documentSyncId': documentSyncId, // Reference to parent document
      'userId': userId,
      'filePath': filePath,
      'fileName': fileName,
      'label': label,
      's3Key': s3Key,
      'addedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<String>> _getFileAttachments(int documentId) async {
    final db = await database;
    final result = await db.query(
      'file_attachments',
      where: 'documentId = ?',
      whereArgs: [documentId],
      orderBy: 'addedAt ASC',
    );
    return result.map((map) => map['filePath'] as String).toList();
  }

  Future<List<FileAttachment>> getFileAttachmentsWithLabels(
      int documentId) async {
    final db = await database;
    final result = await db.query(
      'file_attachments',
      where: 'documentId = ?',
      whereArgs: [documentId],
      orderBy: 'addedAt ASC',
    );
    return result.map((map) => FileAttachmentExtensions.fromMap(map)).toList();
  }

  Future<void> addFileToDocument(int documentId, String filePath, String? label,
      {String? syncId}) async {
    await _addFileAttachment(documentId, filePath, label, syncId: syncId);
  }

  /// Add file attachment using sync identifier
  Future<void> addFileToDocumentBySyncId(
      String documentSyncId, String filePath, String? label,
      {String? s3Key, String? fileAttachmentSyncId}) async {
    // Validate sync identifier
    _validateSyncId(documentSyncId,
        context: 'file attachment by document sync ID');

    // Validate required fields
    if (filePath.isEmpty) {
      throw ArgumentError('File path cannot be empty for file attachment');
    }

    final db = await database;

    // Get the document ID from document sync ID
    final docResult = await db.query(
      'documents',
      columns: ['id'],
      where: 'syncId = ?',
      whereArgs: [documentSyncId],
      limit: 1,
    );

    if (docResult.isEmpty) {
      throw ArgumentError(
          'Document with syncId "$documentSyncId" not found for file attachment');
    }

    final documentId = docResult.first['id'] as int;
    // Pass the FileAttachment syncId to _addFileAttachment
    await _addFileAttachment(documentId, filePath, label,
        syncId: fileAttachmentSyncId, s3Key: s3Key);
  }

  /// Get file attachments by sync identifier
  Future<List<FileAttachment>> getFileAttachmentsBySyncId(String syncId) async {
    // Validate sync identifier
    _validateSyncId(syncId, context: 'file attachments retrieval by sync ID');

    final db = await database;
    final result = await db.query(
      'file_attachments',
      where: 'syncId = ?',
      whereArgs: [syncId],
      orderBy: 'addedAt ASC',
    );
    return result.map((map) => FileAttachmentExtensions.fromMap(map)).toList();
  }

  /// Get file attachments by document sync identifier
  Future<List<FileAttachment>> getFileAttachmentsByDocumentSyncId(
      String documentSyncId) async {
    // Validate sync identifier
    _validateSyncId(documentSyncId,
        context: 'file attachments retrieval by document sync ID');

    final db = await database;
    final result = await db.query(
      'file_attachments',
      where: 'documentSyncId = ?',
      whereArgs: [documentSyncId],
      orderBy: 'addedAt ASC',
    );
    return result.map((map) => FileAttachmentExtensions.fromMap(map)).toList();
  }

  Future<int> updateFileLabel(
      int documentId, String filePath, String? label) async {
    final db = await database;
    final rowsAffected = await db.update(
      'file_attachments',
      {'label': label},
      where: 'documentId = ? AND filePath = ?',
      whereArgs: [documentId, filePath],
    );
    return rowsAffected;
  }

  Future<int> updateFilePathInAttachments(
      int documentId, String oldFilePath, String newFilePath) async {
    final db = await database;
    final rowsAffected = await db.update(
      'file_attachments',
      {'filePath': newFilePath},
      where: 'documentId = ? AND filePath = ?',
      whereArgs: [documentId, oldFilePath],
    );
    return rowsAffected;
  }

  Future<void> removeFileFromDocument(int documentId, String filePath) async {
    final db = await database;
    await db.delete(
      'file_attachments',
      where: 'documentId = ? AND filePath = ?',
      whereArgs: [documentId, filePath],
    );
  }

  /// Remove file attachment using document sync identifier and file path
  Future<void> removeFileFromDocumentBySyncId(
      String documentSyncId, String filePath) async {
    // Validate sync identifier
    _validateSyncId(documentSyncId,
        context: 'file removal by document sync ID');

    final db = await database;
    await db.delete(
      'file_attachments',
      where: 'documentSyncId = ? AND filePath = ?',
      whereArgs: [documentSyncId, filePath],
    );
  }

  /// Remove file attachment using FileAttachment's own sync identifier
  Future<void> removeFileAttachmentBySyncId(String fileAttachmentSyncId) async {
    // Validate sync identifier
    _validateSyncId(fileAttachmentSyncId,
        context: 'file attachment removal by sync ID');

    final db = await database;
    await db.delete(
      'file_attachments',
      where: 'syncId = ?',
      whereArgs: [fileAttachmentSyncId],
    );
  }

  /// Get file attachments with labels using document sync identifier
  Future<List<FileAttachment>> getFileAttachmentsWithLabelsBySyncId(
      String documentSyncId) async {
    // Validate sync identifier
    _validateSyncId(documentSyncId,
        context: 'file attachments with labels retrieval by document sync ID');

    final db = await database;
    final result = await db.query(
      'file_attachments',
      where: 'documentSyncId = ?',
      whereArgs: [documentSyncId],
      orderBy: 'addedAt ASC',
    );
    return result.map((map) => FileAttachmentExtensions.fromMap(map)).toList();
  }

  /// Update file label using document sync identifier and file path
  Future<int> updateFileLabelBySyncId(
      String documentSyncId, String filePath, String? label) async {
    // Validate sync identifier
    _validateSyncId(documentSyncId,
        context: 'file label update by document sync ID');

    final db = await database;
    final rowsAffected = await db.update(
      'file_attachments',
      {'label': label},
      where: 'documentSyncId = ? AND filePath = ?',
      whereArgs: [documentSyncId, filePath],
    );
    return rowsAffected;
  }

  Future<void> replaceFileAttachmentsForDocument(
      int documentId, List<FileAttachment> attachments) async {
    final db = await database;

    // Start a transaction to ensure consistency
    await db.transaction((txn) async {
      // First, delete all existing file attachments for this document
      await txn.delete(
        'file_attachments',
        where: 'documentId = ?',
        whereArgs: [documentId],
      );

      // Then, insert the new file attachments
      for (final attachment in attachments) {
        await txn.insert('file_attachments', {
          'documentId': documentId,
          'filePath': attachment.s3Key.isNotEmpty
              ? attachment.s3Key
              : attachment.filePath,
          'fileName': attachment.fileName,
          'label': attachment.label,
          'addedAt': attachment.addedAt.getDateTimeInUtc().toIso8601String(),
        });
      }
    });
  }

  /// Update document by sync identifier (preferred method for sync operations)
  Future<int> updateDocumentBySyncId(
      String syncId, Map<String, dynamic> updates) async {
    // Validate sync identifier
    _validateSyncId(syncId, context: 'document update by syncId');

    final db = await database;

    // Ensure we don't allow syncId to be changed in updates
    if (updates.containsKey('syncId') && updates['syncId'] != syncId) {
      throw ArgumentError(
          'Cannot change syncId in update operation. syncId is immutable.');
    }

    // Add lastModified timestamp
    updates['lastModified'] = DateTime.now().toIso8601String();

    return await db.update(
      'documents',
      updates,
      where: 'syncId = ?',
      whereArgs: [syncId],
    );
  }

  Future<int> updateDocument(dynamic document) async {
    final db = await database;
    final documentMap = document is LocalDocument
        ? document.toMap()
        : DocumentExtensions(document).toMap();

    // For updates, use syncId to identify the document, not integer ID
    if (document.syncId != null && document.syncId.isNotEmpty) {
      return await db.update(
        'documents',
        documentMap,
        where: 'syncId = ?',
        whereArgs: [document.syncId],
      );
    } else {
      // Fallback for documents without syncId (should be rare)
      throw ArgumentError('Document must have syncId for update operations');
    }
  }

  Future<int> deleteDocument(int id) async {
    final db = await database;
    return await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Create a tombstone for a deleted document
  Future<void> createTombstone(String syncId, String userId, String deletedBy,
      {String reason = 'user'}) async {
    // Validate sync identifier
    _validateSyncId(syncId, context: 'tombstone creation');

    // Validate required fields
    if (userId.isEmpty) {
      throw ArgumentError('User ID cannot be empty for tombstone creation');
    }
    if (deletedBy.isEmpty) {
      throw ArgumentError('DeletedBy cannot be empty for tombstone creation');
    }

    final db = await database;
    await db.insert('document_tombstones', {
      'syncId': syncId,
      'userId': userId,
      'deletedAt': DateTime.now().toIso8601String(),
      'deletedBy': deletedBy,
      'reason': reason,
    });
  }

  /// Check if a document is tombstoned (deleted)
  Future<bool> isTombstoned(String syncId) async {
    // Validate sync identifier
    _validateSyncId(syncId, context: 'tombstone check');

    final db = await database;
    final result = await db.query(
      'document_tombstones',
      where: 'syncId = ?',
      whereArgs: [syncId],
    );
    return result.isNotEmpty;
  }

  /// Get all tombstones for a user
  Future<List<Map<String, dynamic>>> getTombstones(String userId) async {
    final db = await database;
    return await db.query(
      'document_tombstones',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'deletedAt DESC',
    );
  }

  /// Clean up old tombstones (older than 90 days)
  Future<int> cleanupOldTombstones() async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
    return await db.delete(
      'document_tombstones',
      where: 'deletedAt < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  /// Get document by sync identifier
  Future<Document?> getDocumentBySyncId(String syncId, [String? userId]) async {
    final db = await database;

    String whereClause = "syncId = ? AND syncState != 'pendingDeletion'";
    List<dynamic> whereArgs = [syncId];

    if (userId != null) {
      whereClause += ' AND userId = ?';
      whereArgs.add(userId);
    }

    final result = await db.query(
      'documents',
      where: whereClause,
      whereArgs: whereArgs,
    );

    if (result.isEmpty) return null;

    final map = result.first;
    final filePaths = await _getFileAttachments(map['id'] as int);
    final documentMap = Map<String, dynamic>.from(map);
    documentMap['filePaths'] = filePaths;
    return DocumentExtensions.fromMap(documentMap);
  }

  /// Update document sync identifier
  Future<int> updateDocumentSyncId(int documentId, String syncId) async {
    // Validate sync identifier format
    _validateSyncId(syncId, context: 'sync ID update');

    final db = await database;

    // Get the document to check for duplicates
    final docResult = await db.query(
      'documents',
      columns: ['userId', 'syncId'],
      where: 'id = ?',
      whereArgs: [documentId],
    );

    if (docResult.isEmpty) {
      throw ArgumentError(
          'Document with ID $documentId not found for sync ID update');
    }

    final userId = docResult.first['userId'] as String?;
    if (userId != null && userId.isNotEmpty) {
      // Get the current syncId to exclude it from duplicate check
      final currentSyncId = docResult.first['syncId'] as String?;

      // Check for duplicate sync identifiers
      final hasDuplicate = await hasDuplicateSyncId(syncId, userId,
          excludeSyncId: currentSyncId);
      if (hasDuplicate) {
        throw ArgumentError(
            'Duplicate sync identifier "$syncId" found for user $userId in sync ID update. '
            'Sync identifiers must be unique within a user\'s document collection.');
      }
    }

    return await db.update(
      'documents',
      {'syncId': syncId},
      where: 'id = ?',
      whereArgs: [documentId],
    );
  }

  /// Get documents without sync identifiers (for migration)
  Future<List<Document>> getDocumentsWithoutSyncId([String? userId]) async {
    final db = await database;

    String whereClause = "syncId IS NULL AND syncState != 'pendingDeletion'";
    List<dynamic> whereArgs = [];

    if (userId != null) {
      whereClause += ' AND userId = ?';
      whereArgs.add(userId);
    }

    final result = await db.query(
      'documents',
      where: whereClause,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'createdAt DESC',
    );

    final documents = <Document>[];
    for (final map in result) {
      final filePaths = await _getFileAttachments(map['id'] as int);
      final documentMap = Map<String, dynamic>.from(map);
      documentMap['filePaths'] = filePaths;
      final document = DocumentExtensions.fromMap(documentMap);
      documents.add(document);
    }
    return documents;
  }

  /// Update file attachment sync identifier
  Future<int> updateFileAttachmentSyncId(
      int attachmentId, String syncId) async {
    final db = await database;
    return await db.update(
      'file_attachments',
      {'syncId': syncId},
      where: 'id = ?',
      whereArgs: [attachmentId],
    );
  }

  Future close() async {
    final db = await database;
    db.close();
  }

  /// Validate sync identifier before database operations
  /// Throws ArgumentError if sync identifier is invalid
  void _validateSyncId(String? syncId, {String? context}) {
    if (syncId != null && syncId.isNotEmpty) {
      SyncIdentifierService.validateOrThrow(syncId,
          context: context ?? 'database operation');
    }
  }

  /// Check for duplicate sync identifiers within a user's collection
  /// Returns true if duplicate exists, false otherwise
  /// Only checks for actual duplicates, not the same document being updated
  Future<bool> hasDuplicateSyncId(String syncId, String userId,
      {String? excludeSyncId}) async {
    final db = await database;

    // Validate sync identifier format first
    _validateSyncId(syncId, context: 'duplicate check');

    String whereClause = 'syncId = ? AND userId = ?';
    List<dynamic> whereArgs = [syncId, userId];

    // Exclude current document by syncId if updating
    if (excludeSyncId != null && excludeSyncId.isNotEmpty) {
      whereClause += ' AND syncId != ?';
      whereArgs.add(excludeSyncId);
    }

    final result = await db.query(
      'documents',
      columns: ['COUNT(*) as count'],
      where: whereClause,
      whereArgs: whereArgs,
    );

    final count = result.first['count'] as int;
    return count > 0;
  }

  /// Validate document before database operations
  /// Throws ArgumentError if document has validation issues
  Future<void> _validateDocumentForStorage(dynamic document,
      {String? operation}) async {
    final context = operation ?? 'storage';

    if (document is Document) {
      // Validate sync identifier if present
      if (document.syncId.isNotEmpty) {
        _validateSyncId(document.syncId, context: context);

        // Only check for duplicates on CREATE operations, not UPDATE
        // For updates, the document already exists with this syncId
        if (operation == 'document creation' ||
            operation == 'document creation with labels') {
          if (document.userId.isNotEmpty) {
            final hasDuplicate =
                await hasDuplicateSyncId(document.syncId, document.userId);

            if (hasDuplicate) {
              throw ArgumentError(
                  'Duplicate sync identifier "${document.syncId}" found for user ${document.userId} in $context. '
                  'Sync identifiers must be unique within a user\'s document collection.');
            }
          }
        }
      }

      // Validate required fields
      if (document.title.isEmpty) {
        throw ArgumentError('Document title cannot be empty in $context');
      }

      if (document.userId.isEmpty) {
        throw ArgumentError('Document userId cannot be empty in $context');
      }
    } else if (document is LocalDocument) {
      // Validate sync identifier if present
      if (document.syncId != null && document.syncId!.isNotEmpty) {
        _validateSyncId(document.syncId, context: context);

        // Only check for duplicates on CREATE operations
        if (operation == 'document creation' ||
            operation == 'document creation with labels') {
          if (document.userId != null && document.userId!.isNotEmpty) {
            final hasDuplicate =
                await hasDuplicateSyncId(document.syncId!, document.userId!);

            if (hasDuplicate) {
              throw ArgumentError(
                  'Duplicate sync identifier "${document.syncId}" found for user ${document.userId} in $context. '
                  'Sync identifiers must be unique within a user\'s document collection.');
            }
          }
        }
      }

      // Validate required fields
      if (document.title.isEmpty) {
        throw ArgumentError('Document title cannot be empty in $context');
      }
    }
  }

  /// Get all sync identifiers for a user (for validation purposes)
  Future<List<String>> getUserSyncIds(String userId) async {
    final db = await database;

    final result = await db.query(
      'documents',
      columns: ['syncId'],
      where: 'userId = ? AND syncId IS NOT NULL AND syncId != ""',
      whereArgs: [userId],
    );

    return result
        .map((row) => row['syncId'] as String)
        .where((syncId) => syncId.isNotEmpty)
        .toList();
  }

  /// Validate all sync identifiers for a user
  /// Returns validation result with details about any issues
  Future<ValidationResult> validateUserSyncIds(String userId) async {
    final syncIds = await getUserSyncIds(userId);
    return SyncIdentifierService.validateCollection(syncIds);
  }
}
