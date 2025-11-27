import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/document.dart';

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
      version: 1,
      onCreate: _createDB,
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
  }

  Future<int> createDocument(Document document) async {
    final db = await database;
    return await db.insert('documents', document.toMap());
  }

  Future<List<Document>> getAllDocuments() async {
    final db = await database;
    final result = await db.query('documents', orderBy: 'createdAt DESC');
    return result.map((map) => Document.fromMap(map)).toList();
  }

  Future<List<Document>> getDocumentsByCategory(String category) async {
    final db = await database;
    final result = await db.query(
      'documents',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => Document.fromMap(map)).toList();
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
