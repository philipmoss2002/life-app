import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/Document.dart';
import '../models/FileAttachment.dart';
import '../models/model_extensions.dart';

/// Local document representation for database operations
class LocalDocument {
  final int? id;
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
      id: map['id'] as int?,
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
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        filePath TEXT NOT NULL,
        fileName TEXT NOT NULL,
        label TEXT,
        addedAt TEXT NOT NULL,
        FOREIGN KEY (documentId) REFERENCES documents (id) ON DELETE CASCADE
      )
    ''');
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
  }

  Future<int> createDocument(dynamic document) async {
    final db = await database;
    final documentMap = document is LocalDocument
        ? document.toMap()
        : DocumentExtensions(document).toMap();
    final id = await db.insert('documents', documentMap);

    // Insert file attachments
    if (document.filePaths != null && document.filePaths.isNotEmpty) {
      for (final filePath in document.filePaths) {
        await _addFileAttachment(id, filePath, null);
      }
    }

    return id;
  }

  Future<int> createDocumentWithLabels(
      Document document, Map<String, String?> fileLabels) async {
    final db = await database;
    final id =
        await db.insert('documents', DocumentExtensions(document).toMap());

    // Insert file attachments with labels
    if (document.filePaths.isNotEmpty) {
      for (final filePath in document.filePaths) {
        final label = fileLabels[filePath];
        await _addFileAttachment(id, filePath, label);
      }
    }

    return id;
  }

  Future<List<Document>> getAllDocuments([String? userId]) async {
    final db = await database;

    // If userId is provided, filter by user; otherwise get all documents
    final result = userId != null
        ? await db.query(
            'documents',
            where: 'userId = ?',
            whereArgs: [userId],
            orderBy: 'createdAt DESC',
          )
        : await db.query('documents', orderBy: 'createdAt DESC');

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

  Future<List<Document>> getDocumentsByCategory(String category,
      [String? userId]) async {
    final db = await database;

    // Build where clause and args based on whether userId is provided
    String whereClause = 'category = ?';
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
      int documentId, String filePath, String? label) async {
    final db = await database;
    final fileName = filePath.split('/').last;
    await db.insert('file_attachments', {
      'documentId': documentId,
      'filePath': filePath,
      'fileName': fileName,
      'label': label,
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

  Future<void> addFileToDocument(
      int documentId, String filePath, String? label) async {
    await _addFileAttachment(documentId, filePath, label);
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

  Future<void> removeFileFromDocument(int documentId, String filePath) async {
    final db = await database;
    await db.delete(
      'file_attachments',
      where: 'documentId = ? AND filePath = ?',
      whereArgs: [documentId, filePath],
    );
  }

  Future<int> updateDocument(dynamic document) async {
    final db = await database;
    final documentMap = document is LocalDocument
        ? document.toMap()
        : DocumentExtensions(document).toMap();
    return await db.update(
      'documents',
      documentMap,
      where: 'id = ?',
      whereArgs: [document.id],
    );
  }

  Future<int> deleteDocument(int id) async {
    final db = await database;
    return await db.delete(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
