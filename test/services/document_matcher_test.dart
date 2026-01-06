import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/Document.dart';
import 'package:household_docs_app/services/document_matcher.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';
import 'package:amplify_core/amplify_core.dart';

import '../../lib/services/sync_identifier_service.dart';
void main() {
  group('DocumentMatcher', () {
    group('matchBySyncId', () {
      test('should find document with matching sync identifier', () {
        // Arrange
        final syncId1 = SyncIdentifierService.generateValidated();
        final syncId2 = SyncIdentifierService.generateValidated();
        final syncId3 = SyncIdentifierService.generateValidated();

        final documents = [
          _createTestDocument(syncId: syncId1, title: 'Document 1', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: syncId2, title: 'Document 2', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: syncId3, title: 'Document 3', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
        ];

        // Act
        final result = DocumentMatcher.matchBySyncId(documents, syncId2);

        // Assert
        expect(result, isNotNull);
        expect(result!.syncId, equals(syncId2));
        expect(result.title, equals('Document 2'));
      });

      test('should return null when no matching sync identifier found', () {
        // Arrange
        final syncId1 = SyncIdentifierService.generateValidated();
        final syncId2 = SyncIdentifierService.generateValidated();
        final nonExistentSyncId = SyncIdentifierService.generateValidated();

        final documents = [
          _createTestDocument(syncId: syncId1, title: 'Document 1', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: syncId2, title: 'Document 2', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
        ];

        // Act
        final result =
            DocumentMatcher.matchBySyncId(documents, nonExistentSyncId);

        // Assert
        expect(result, isNull);
      });

      test('should handle case-insensitive matching', () {
        // Arrange
        final syncId = SyncIdentifierService.generateValidated();
        final upperCaseSyncId = syncId.toUpperCase();

        final documents = [
          _createTestDocument(syncId: syncId, title: 'Document 1', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
        ];

        // Act
        final result =
            DocumentMatcher.matchBySyncId(documents, upperCaseSyncId);

        // Assert
        expect(result, isNotNull);
        expect(result!.title, equals('Document 1'));
      });

      test('should throw ArgumentError for invalid sync identifier', () {
        // Arrange
        final documents = [
          _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), title: 'Document 1'),
        ];

        // Act & Assert
        expect(
          () => DocumentMatcher.matchBySyncId(documents, 'invalid-sync-id'),
          throwsArgumentError,
        );
      });

      test('should skip documents without sync identifiers', () {
        // Arrange
        final syncId = SyncIdentifierService.generateValidated();

        final documents = [
          _createTestDocument(syncId: null, title: 'Document without syncId', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: syncId, title: 'Document with syncId', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
        ];

        // Act
        final result = DocumentMatcher.matchBySyncId(documents, syncId);

        // Assert
        expect(result, isNotNull);
        expect(result!.title, equals('Document with syncId'));
      });
    });

    group('calculateContentHash', () {
      test('should generate consistent hash for same content', () {
        // Arrange
        final document1 = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Test Document',
          category: 'Insurance',
          notes: 'Test notes',
          filePaths: ['file1.pdf', 'file2.pdf'],
        );

        final document2 = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), // Different syncId
          title: 'Test Document',
          category: 'Insurance',
          notes: 'Test notes',
          filePaths: ['file1.pdf', 'file2.pdf'],
        );

        // Act
        final hash1 = DocumentMatcher.calculateContentHash(document1);
        final hash2 = DocumentMatcher.calculateContentHash(document2);

        // Assert
        expect(hash1, equals(hash2));
      });

      test('should generate different hash for different content', () {
        // Arrange
        final document1 = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Document 1',
          category: 'Insurance',
        );

        final document2 = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Document 2',
          category: 'Insurance',
        );

        // Act
        final hash1 = DocumentMatcher.calculateContentHash(document1);
        final hash2 = DocumentMatcher.calculateContentHash(document2);

        // Assert
        expect(hash1, isNot(equals(hash2)));
      });

      test('should handle documents with null notes', () {
        // Arrange
        final document = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Test Document',
          category: 'Insurance',
          notes: null,
        );

        // Act & Assert
        expect(() => DocumentMatcher.calculateContentHash(document),
            returnsNormally);
      });

      test('should handle documents with null filePaths', () {
        // Arrange
        final document = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Test Document',
          category: 'Insurance',
          filePaths: null,
        );

        // Act & Assert
        expect(() => DocumentMatcher.calculateContentHash(document),
            returnsNormally);
      });

      test('should generate same hash regardless of filePaths order', () {
        // Arrange
        final document1 = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Test Document',
          category: 'Insurance',
          filePaths: ['file1.pdf', 'file2.pdf', 'file3.pdf'],
        );

        final document2 = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Test Document',
          category: 'Insurance',
          filePaths: ['file3.pdf', 'file1.pdf', 'file2.pdf'],
        );

        // Act
        final hash1 = DocumentMatcher.calculateContentHash(document1);
        final hash2 = DocumentMatcher.calculateContentHash(document2);

        // Assert
        expect(hash1, equals(hash2));
      });
    });

    group('matchByContentHash', () {
      test('should find documents with matching content hash', () {
        // Arrange
        final document1 = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Test Document',
          category: 'Insurance',
        );

        final document2 = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Test Document',
          category: 'Insurance',
        );

        final document3 = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Different Document',
          category: 'Insurance',
        );

        final documents = [document1, document2, document3];
        final targetHash = DocumentMatcher.calculateContentHash(document1);

        // Act
        final matches =
            DocumentMatcher.matchByContentHash(documents, targetHash);

        // Assert
        expect(matches.length, equals(2));
        expect(matches, contains(document1));
        expect(matches, contains(document2));
        expect(matches, isNot(contains(document3)));
      });

      test('should return empty list when no matches found', () {
        // Arrange
        final documents = [
          _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
            title: 'Document 1',
            category: 'Insurance',
          ),
        ];

        final nonMatchingHash = 'nonexistent-hash';

        // Act
        final matches =
            DocumentMatcher.matchByContentHash(documents, nonMatchingHash);

        // Assert
        expect(matches, isEmpty);
      });
    });

    group('haveSameContent', () {
      test('should return true for documents with same content', () {
        // Arrange
        final document1 = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Test Document',
          category: 'Insurance',
          notes: 'Test notes',
        );

        final document2 = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Test Document',
          category: 'Insurance',
          notes: 'Test notes',
        );

        // Act
        final result = DocumentMatcher.haveSameContent(document1, document2);

        // Assert
        expect(result, isTrue);
      });

      test('should return false for documents with different content', () {
        // Arrange
        final document1 = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Document 1',
          category: 'Insurance',
        );

        final document2 = _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Document 2',
          category: 'Insurance',
        );

        // Act
        final result = DocumentMatcher.haveSameContent(document1, document2);

        // Assert
        expect(result, isFalse);
      });
    });

    group('findDocumentsWithoutSyncId', () {
      test('should find documents without sync identifiers', () {
        // Arrange
        final documents = [
          _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), title: 'Doc 1'),
          _createTestDocument(syncId: null, title: 'Doc 2', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: '', title: 'Doc 3', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), title: 'Doc 4'),
        ];

        // Act
        final result = DocumentMatcher.findDocumentsWithoutSyncId(documents);

        // Assert
        expect(result.length, equals(2));
        expect(result.any((doc) => doc.title == 'Doc 2'), isTrue);
        expect(result.any((doc) => doc.title == 'Doc 3'), isTrue);
      });

      test('should return empty list when all documents have sync identifiers',
          () {
        // Arrange
        final documents = [
          _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), title: 'Doc 1'),
          _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), title: 'Doc 2'),
        ];

        // Act
        final result = DocumentMatcher.findDocumentsWithoutSyncId(documents);

        // Assert
        expect(result, isEmpty);
      });
    });

    group('validateUniqueSyncIds', () {
      test('should validate unique sync identifiers', () {
        // Arrange
        final documents = [
          _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), title: 'Doc 1'),
          _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), title: 'Doc 2'),
          _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), title: 'Doc 3'),
        ];

        // Act
        final result = DocumentMatcher.validateUniqueSyncIds(documents);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.duplicates, isEmpty);
        expect(result.documentsWithSyncId, equals(3));
      });

      test('should detect duplicate sync identifiers', () {
        // Arrange
        final duplicateSyncId = SyncIdentifierService.generateValidated();
        final documents = [
          _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), title: 'Doc 1'),
          _createTestDocument(syncId: duplicateSyncId, title: 'Doc 2', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: duplicateSyncId, title: 'Doc 3', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), title: 'Doc 4'),
        ];

        // Act
        final result = DocumentMatcher.validateUniqueSyncIds(documents);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.duplicates.length, equals(2));
        expect(result.duplicates.any((doc) => doc.title == 'Doc 2'), isTrue);
        expect(result.duplicates.any((doc) => doc.title == 'Doc 3'), isTrue);
      });

      test('should handle case-insensitive duplicate detection', () {
        // Arrange
        final syncId = SyncIdentifierService.generateValidated();
        final documents = [
          _createTestDocument(syncId: syncId.toLowerCase(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), title: 'Doc 1'),
          _createTestDocument(syncId: syncId.toUpperCase(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), title: 'Doc 2'),
        ];

        // Act
        final result = DocumentMatcher.validateUniqueSyncIds(documents);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.duplicates.length, equals(2));
      });

      test('should ignore documents without sync identifiers', () {
        // Arrange
        final documents = [
          _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), title: 'Doc 1'),
          _createTestDocument(syncId: null, title: 'Doc 2', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: '', title: 'Doc 3', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
        ];

        // Act
        final result = DocumentMatcher.validateUniqueSyncIds(documents);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.documentsWithSyncId, equals(1));
        expect(result.totalDocuments, equals(3));
      });
    });
  });
}

/// Helper function to create test documents
Document _createTestDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), {,
  String? syncId,
  required String title,
  String category = 'Insurance',
  String? notes,
  List<String>? filePaths,
}) {
  return Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

        syncId: syncId,
    userId: 'test-user-id',
    title: title,
    category: category,
    filePaths: filePaths ?? <String>[],
    notes: notes,
    createdAt: TemporalDateTime.now(),
    lastModified: TemporalDateTime.now(),
    version: 1,
    syncState: 'notSynced',
  );
}
