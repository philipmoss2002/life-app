import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/repositories/document_repository.dart';

// Alias to avoid conflict with sqflite's DatabaseException
import 'package:household_docs_app/repositories/document_repository.dart'
    as repo;

void main() {
  group('DocumentRepository', () {
    late DocumentRepository repository;

    setUp(() {
      repository = DocumentRepository();
    });

    test('should be a singleton', () {
      final instance1 = DocumentRepository();
      final instance2 = DocumentRepository();
      expect(instance1, same(instance2));
    });

    group('DatabaseException', () {
      test('should create exception with message', () {
        final exception = repo.DatabaseException('Test error');
        expect(exception.message, equals('Test error'));
        expect(exception.toString(), equals('DatabaseException: Test error'));
      });
    });

    group('Method signatures', () {
      test('createDocument should have correct signature', () {
        expect(
          repository.createDocument,
          isA<Function>(),
        );
      });

      test('getDocument should have correct signature', () {
        expect(
          repository.getDocument,
          isA<Function>(),
        );
      });

      test('getAllDocuments should have correct signature', () {
        expect(
          repository.getAllDocuments,
          isA<Function>(),
        );
      });

      test('updateDocument should have correct signature', () {
        expect(
          repository.updateDocument,
          isA<Function>(),
        );
      });

      test('deleteDocument should have correct signature', () {
        expect(
          repository.deleteDocument,
          isA<Function>(),
        );
      });

      test('addFileAttachment should have correct signature', () {
        expect(
          repository.addFileAttachment,
          isA<Function>(),
        );
      });

      test('updateFileS3Key should have correct signature', () {
        expect(
          repository.updateFileS3Key,
          isA<Function>(),
        );
      });

      test('updateFileLocalPath should have correct signature', () {
        expect(
          repository.updateFileLocalPath,
          isA<Function>(),
        );
      });

      test('getFileAttachments should have correct signature', () {
        expect(
          repository.getFileAttachments,
          isA<Function>(),
        );
      });

      test('deleteFileAttachment should have correct signature', () {
        expect(
          repository.deleteFileAttachment,
          isA<Function>(),
        );
      });

      test('updateSyncState should have correct signature', () {
        expect(
          repository.updateSyncState,
          isA<Function>(),
        );
      });

      test('getDocumentsBySyncState should have correct signature', () {
        expect(
          repository.getDocumentsBySyncState,
          isA<Function>(),
        );
      });

      test('getDocumentsNeedingUpload should have correct signature', () {
        expect(
          repository.getDocumentsNeedingUpload,
          isA<Function>(),
        );
      });

      test('getDocumentsNeedingDownload should have correct signature', () {
        expect(
          repository.getDocumentsNeedingDownload,
          isA<Function>(),
        );
      });

      test('getDocumentCount should have correct signature', () {
        expect(
          repository.getDocumentCount,
          isA<Function>(),
        );
      });

      test('getDocumentCountsBySyncState should have correct signature', () {
        expect(
          repository.getDocumentCountsBySyncState,
          isA<Function>(),
        );
      });
    });
  });
}
