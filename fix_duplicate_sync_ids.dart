import 'dart:async';
import 'package:uuid/uuid.dart';
import 'lib/services/database_service.dart';
import 'lib/services/sync_identifier_service.dart';
import 'lib/models/Document.dart';

/// Script to fix duplicate sync identifiers in the database
class DuplicateSyncIdFixer {
  final DatabaseService _databaseService = DatabaseService.instance;
  final Set<String> _seenSyncIds = <String>{};
  final List<String> _duplicatesSolved = <String>[];

  /// Fix all duplicate sync identifiers in the database
  Future<void> fixDuplicateSyncIds() async {
    print('🔍 Scanning for duplicate sync identifiers...');

    try {
      // Get all documents from the database
      final documents = await _databaseService.getAllDocuments();
      print('📄 Found ${documents.length} documents to check');

      final duplicates = <Document>[];
      final validDocuments = <Document>[];

      // Identify duplicates
      for (final document in documents) {
        if (document.syncId == null || document.syncId!.isEmpty) {
          print(
              '⚠️  Document "${document.title}" has no sync ID - will generate one');
          duplicates.add(document);
          continue;
        }

        if (_seenSyncIds.contains(document.syncId)) {
          print(
              '🔄 Duplicate sync ID found: ${document.syncId} for document "${document.title}"');
          duplicates.add(document);
        } else {
          _seenSyncIds.add(document.syncId!);
          validDocuments.add(document);
        }
      }

      print('✅ Found ${validDocuments.length} documents with unique sync IDs');
      print(
          '❌ Found ${duplicates.length} documents with duplicate or missing sync IDs');

      if (duplicates.isEmpty) {
        print('🎉 No duplicate sync IDs found! Database is clean.');
        return;
      }

      // Fix duplicates
      print('🔧 Fixing duplicate sync identifiers...');

      for (final document in duplicates) {
        await _fixDocumentSyncId(document);
      }

      print('✅ Fixed ${_duplicatesSolved.length} duplicate sync identifiers');
      print('🎯 Duplicates resolved: ${_duplicatesSolved.join(', ')}');
    } catch (e) {
      print('❌ Error fixing duplicate sync IDs: $e');
      rethrow;
    }
  }

  /// Fix sync ID for a single document
  Future<void> _fixDocumentSyncId(Document document) async {
    try {
      // Generate a new unique sync identifier
      String newSyncId;
      int attempts = 0;
      const maxAttempts = 10;

      do {
        newSyncId = SyncIdentifierService.generateValidated();
        attempts++;

        if (attempts >= maxAttempts) {
          throw Exception(
              'Failed to generate unique sync ID after $maxAttempts attempts');
        }
      } while (_seenSyncIds.contains(newSyncId));

      // Add to seen set
      _seenSyncIds.add(newSyncId);

      // Update document with new sync ID
      final updatedDocument = document.copyWith(syncId: newSyncId);

      await _databaseService.updateDocument(updatedDocument);

      _duplicatesSolved.add('${document.syncId ?? 'null'} -> $newSyncId');

      print(
          '✅ Fixed document "${document.title}": ${document.syncId ?? 'null'} -> $newSyncId');
    } catch (e) {
      print('❌ Failed to fix sync ID for document "${document.title}": $e');
      rethrow;
    }
  }

  /// Validate that all sync IDs are now unique
  Future<bool> validateSyncIdUniqueness() async {
    print('🔍 Validating sync ID uniqueness...');

    try {
      final documents = await _databaseService.getAllDocuments();
      final syncIds = <String>{};
      final duplicates = <String>[];

      for (final document in documents) {
        if (document.syncId == null || document.syncId!.isEmpty) {
          print('⚠️  Document "${document.title}" still has no sync ID');
          return false;
        }

        if (syncIds.contains(document.syncId)) {
          duplicates.add(document.syncId!);
        } else {
          syncIds.add(document.syncId!);
        }
      }

      if (duplicates.isNotEmpty) {
        print('❌ Still found duplicate sync IDs: ${duplicates.join(', ')}');
        return false;
      }

      print(
          '✅ All sync IDs are unique! Found ${syncIds.length} unique sync identifiers.');
      return true;
    } catch (e) {
      print('❌ Error validating sync ID uniqueness: $e');
      return false;
    }
  }
}

/// Main function to run the fix
Future<void> main() async {
  print('🚀 Starting duplicate sync ID fix...');

  final fixer = DuplicateSyncIdFixer();

  try {
    await fixer.fixDuplicateSyncIds();

    // Validate the fix
    final isValid = await fixer.validateSyncIdUniqueness();

    if (isValid) {
      print('🎉 Duplicate sync ID fix completed successfully!');
    } else {
      print('❌ Fix validation failed. Some issues may remain.');
    }
  } catch (e) {
    print('💥 Fix failed with error: $e');
  }
}
