import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Clean database service for authentication and sync rewrite
///
/// This service implements a simplified schema with only three tables:
/// - documents: Document metadata with syncId as primary key
/// - file_attachments: File attachments linked to documents
/// - logs: Application logs for debugging
///
/// Key design principles:
/// - syncId (UUID) is the primary identifier for documents
/// - Clean separation of concerns
/// - No legacy migration code
/// - Simple, maintainable schema
class NewDatabaseService {
  static final NewDatabaseService instance = NewDatabaseService._init();
  static Database? _database;

  NewDatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('household_docs_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Use getApplicationSupportDirectory() to ensure app-internal storage
    // This guarantees the database is removed on app uninstall
    final appDir = await getApplicationSupportDirectory();
    final dbDir = Directory(join(appDir.path, 'databases'));

    // Ensure database directory exists
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    final path = join(dbDir.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Documents table - stores document metadata
    await db.execute('''
      CREATE TABLE documents (
        sync_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        labels TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        sync_state TEXT NOT NULL DEFAULT 'pendingUpload'
      )
    ''');

    // File attachments table - stores file references
    await db.execute('''
      CREATE TABLE file_attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT NOT NULL,
        file_name TEXT NOT NULL,
        local_path TEXT,
        s3_key TEXT,
        file_size INTEGER,
        added_at INTEGER NOT NULL,
        FOREIGN KEY (sync_id) REFERENCES documents(sync_id) ON DELETE CASCADE
      )
    ''');

    // Logs table - stores application logs
    await db.execute('''
      CREATE TABLE logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        level TEXT NOT NULL,
        message TEXT NOT NULL,
        error_details TEXT,
        stack_trace TEXT
      )
    ''');

    // Create indexes for better performance
    await db.execute(
        'CREATE INDEX idx_documents_sync_state ON documents(sync_state)');
    await db.execute(
        'CREATE INDEX idx_file_attachments_sync_id ON file_attachments(sync_id)');
    await db.execute('CREATE INDEX idx_logs_timestamp ON logs(timestamp)');
    await db.execute('CREATE INDEX idx_logs_level ON logs(level)');

    debugPrint('✅ Database schema created successfully');
  }

  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Clear all data from the database (for testing)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('file_attachments');
    await db.delete('documents');
    await db.delete('logs');
    debugPrint('✅ All database data cleared');
  }

  /// Get database statistics
  Future<Map<String, int>> getStats() async {
    final db = await database;

    final docResult =
        await db.rawQuery('SELECT COUNT(*) as count FROM documents');
    final fileResult =
        await db.rawQuery('SELECT COUNT(*) as count FROM file_attachments');
    final logResult = await db.rawQuery('SELECT COUNT(*) as count FROM logs');

    return {
      'documents': docResult.first['count'] as int,
      'file_attachments': fileResult.first['count'] as int,
      'logs': logResult.first['count'] as int,
    };
  }
}
