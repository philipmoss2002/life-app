import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';

/// Utility class for debugging database issues
class DatabaseDebug {
  static Future<void> printDatabaseInfo() async {
    final db = await DatabaseService.instance.database;

    print('=== DATABASE DEBUG INFO ===');
    print('Database path: ${db.path}');
    print('Database version: ${await db.getVersion()}');
    print('');

    // Check documents table schema
    print('--- DOCUMENTS TABLE SCHEMA ---');
    final documentsSchema = await db.rawQuery('PRAGMA table_info(documents)');
    for (final column in documentsSchema) {
      print(
          '  ${column['name']}: ${column['type']} (nullable: ${column['notnull'] == 0})');
    }
    print('');

    // Check file_attachments table schema
    print('--- FILE_ATTACHMENTS TABLE SCHEMA ---');
    final attachmentsSchema =
        await db.rawQuery('PRAGMA table_info(file_attachments)');
    for (final column in attachmentsSchema) {
      print(
          '  ${column['name']}: ${column['type']} (nullable: ${column['notnull'] == 0})');
    }
    print('');

    // Count records
    final docCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM documents'),
    );
    final attachmentCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM file_attachments'),
    );

    print('--- RECORD COUNTS ---');
    print('Documents: $docCount');
    print('File attachments: $attachmentCount');
    print('');

    // Show all file attachments with labels
    print('--- ALL FILE ATTACHMENTS ---');
    final attachments = await db.query('file_attachments');
    for (final attachment in attachments) {
      print('  ID: ${attachment['id']}');
      print('    Document ID: ${attachment['documentId']}');
      print('    File: ${attachment['fileName']}');
      print('    Label: ${attachment['label'] ?? "(null)"}');
      print('    Path: ${attachment['filePath']}');
      print('');
    }

    print('=== END DEBUG INFO ===');
  }

  static Future<void> testLabelUpdate(
      int documentId, String filePath, String label) async {
    final db = await DatabaseService.instance.database;

    print('=== TESTING LABEL UPDATE ===');
    print('Document ID: $documentId');
    print('File path: $filePath');
    print('New label: $label');
    print('');

    // Check if the file attachment exists
    final existing = await db.query(
      'file_attachments',
      where: 'documentId = ? AND filePath = ?',
      whereArgs: [documentId, filePath],
    );

    print('Existing records found: ${existing.length}');
    if (existing.isNotEmpty) {
      print('Current label: ${existing.first['label']}');
    }
    print('');

    // Try the update
    final rowsAffected = await db.update(
      'file_attachments',
      {'label': label},
      where: 'documentId = ? AND filePath = ?',
      whereArgs: [documentId, filePath],
    );

    print('Rows affected: $rowsAffected');

    // Verify the update
    final updated = await db.query(
      'file_attachments',
      where: 'documentId = ? AND filePath = ?',
      whereArgs: [documentId, filePath],
    );

    if (updated.isNotEmpty) {
      print('Updated label: ${updated.first['label']}');
    }

    print('=== END TEST ===');
  }
}
