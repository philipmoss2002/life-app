import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/document.dart';
import '../models/file_attachment.dart';

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
      version: 3,
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
        createdAt TEXT NOT NULL
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
      // Add label column to existing file_attachments table
      await db.execute('''
        ALTER TABLE file_attachments ADD COLUMN label TEXT
      ''');
    }
  }

  Future<int> createDocument(Document document) async {
    final db = await database;
    final id = await db.insert('documents', document.toMap());

    // Insert file attachments
    if (document.filePaths.isNotEmpty) {
      for (final filePath in document.filePaths) {
        await _addFileAttachment(id, filePath, null);
      }
    }

    return id;
  }

  Future<List<Document>> getAllDocuments() async {
    final db = await database;
    final result = await db.query('documents', orderBy: 'createdAt DESC');

    final documents = <Document>[];
    for (final map in result) {
      final filePaths = await _getFileAttachments(map['id'] as int);
      documents.add(Document.fromMap(map, filePaths: filePaths));
    }
    return documents;
  }

  Future<List<Document>> getDocumentsByCategory(String category) async {
    final db = await database;
    final result = await db.query(
      'documents',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'createdAt DESC',
    );

    final documents = <Document>[];
    for (final map in result) {
      final filePaths = await _getFileAttachments(map['id'] as int);
      documents.add(Document.fromMap(map, filePaths: filePaths));
    }
    return documents;
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
    return result.map((map) => FileAttachment.fromMap(map)).toList();
  }

  Future<void> addFileToDocument(
      int documentId, String filePath, String? label) async {
    await _addFileAttachment(documentId, filePath, label);
  }

  Future<void> updateFileLabel(
      int documentId, String filePath, String? label) async {
    final db = await database;
    await db.update(
      'file_attachments',
      {'label': label},
      where: 'documentId = ? AND filePath = ?',
      whereArgs: [documentId, filePath],
    );
  }

  Future<void> removeFileFromDocument(int documentId, String filePath) async {
    final db = await database;
    await db.delete(
      'file_attachments',
      where: 'documentId = ? AND filePath = ?',
      whereArgs: [documentId, filePath],
    );
  }

  Future<int> updateDocument(Document document) async {
    final db = await database;
    return await db.update(
      'documents',
      document.toMap(),
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
