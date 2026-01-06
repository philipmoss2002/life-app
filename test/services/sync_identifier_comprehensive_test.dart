import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/sync_identifier_service.dart';
import 'package:household_docs_app/services/document_matcher.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';
import 'package:household_docs_app/models/Document.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import '../test_helpers.dart';

/// Comprehensive unit test suite for sync identifier functionality
///
/// **Feature: sync-identifier-refactor, Task 17: Write unit tests for comprehensive coverage**
///
/// This test suite provides comprehensive coverage for:
/// 1. Sync identifier generation and validation
/// 2. Document matching using sync identifiers
/// 3. Sync operations with sync identifiers
///
/// Requirements: 15.1, 15.4
void main() {
  group('Sync Identifier Comprehensive Tests', () {
    setUpAll(() {
      setupTestDatabase();
    });

    group('Sync Identifier Generation and Validation', () {
      test('should generate valid UUID v4 sync identifiers', () {
        for (int i = 0; i < 10; i++) {
          final syncId = SyncIdentifierService.generateValidated();

          expect(syncId, isNotEmpty);
          expect(SyncIdentifierGenerator.isValid(syncId), isTrue);
          expect(
              syncId,
              matches(RegExp(
                  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
          expect(syncId, equals(syncId.toLowerCase()));
        }
      });

      test('should validate sync identifier format correctly', () {
        // Valid sync identifiers
        final validSyncId = SyncIdentifierService.generateValidated();
        expect(() => SyncIdentifierService.validateOrThrow(validSyncId),
            returnsNormally);

        // Invalid sync identifiers
        const invalidFormats = [
          'invalid-sync-id',
          '12345',
          '',
          'not-a-uuid-at-all',
          '550e8400-e29b-31d4-a716-446655440000', // Wrong version (3 instead of 4)
        ];

        for (final invalid in invalidFormats) {
          expect(
            () => SyncIdentifierService.validateOrThrow(invalid),
            throwsArgumentError,
            reason: 'Should reject invalid format: $invalid',
          );
        }
      });

      test('should normalize sync identifiers to lowercase', () {
        const upperCaseSyncId = '550E8400-E29B-41D4-A716-446655440000';
        const expectedLower = '550e8400-e29b-41d4-a716-446655440000';

        final normalized = SyncIdentifierGenerator.normalize(upperCaseSyncId);
        expect(normalized, equals(expectedLower));

        final prepared =
            SyncIdentifierService.prepareForStorage(upperCaseSyncId);
        expect(prepared, equals(expectedLower));
      });

      test('should validate collections of sync identifiers', () {
        final validSyncIds =
            List.generate(5, (_) => SyncIdentifierService.generateValidated());
        final result = SyncIdentifierService.validateCollection(validSyncIds);

        expect(result.isValid, isTrue);
        expect(result.invalidIds, isEmpty);
        expect(result.duplicateIds, isEmpty);
        expect(result.validCount, equals(5));
        expect(result.totalCount, equals(5));
      });

      test(
          'should detect invalid and duplicate sync identifiers in collections',
          () {
        final syncId1 = SyncIdentifierService.generateValidated();
        final syncIds = [
          syncId1,
          'invalid-uuid',
          syncId1, // Duplicate
          'another-invalid',
        ];

        final result = SyncIdentifierService.validateCollection(syncIds);

        expect(result.isValid, isFalse);
        expect(result.invalidIds.length, equals(2));
        expect(result.duplicateIds.length, equals(1));
        expect(result.validCount, equals(1));
        expect(result.totalCount, equals(4));
      });
    });

    group('Document Matching with Sync Identifiers', () {
      test('should match documents by sync identifier', () {
        final syncId1 = SyncIdentifierService.generateValidated();
        final syncId2 = SyncIdentifierService.generateValidated();
        final syncId3 = SyncIdentifierService.generateValidated();

        final documents = [
          _createTestDocument(syncId: syncId1, title: 'Document 1', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: syncId2, title: 'Document 2', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: syncId3, title: 'Document 3', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
        ];

        final result = DocumentMatcher.matchBySyncId(documents, syncId2);

        expect(result, isNotNull);
        expect(result!.syncId, equals(syncId2));
        expect(result.title, equals('Document 2'));
      });

      test('should handle case-insensitive sync identifier matching', () {
        final syncId = SyncIdentifierService.generateValidated();
        final upperCaseSyncId = syncId.toUpperCase();

        final documents = [
          _createTestDocument(syncId: syncId, title: 'Test Document', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
        ];

        final result =
            DocumentMatcher.matchBySyncId(documents, upperCaseSyncId);

        expect(result, isNotNull);
        expect(result!.title, equals('Test Document'));
      });

      test('should return null when no matching sync identifier found', () {
        final syncId1 = SyncIdentifierService.generateValidated();
        final syncId2 = SyncIdentifierService.generateValidated();
        final nonExistentSyncId = SyncIdentifierService.generateValidated();

        final documents = [
          _createTestDocument(syncId: syncId1, title: 'Document 1', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: syncId2, title: 'Document 2', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
        ];

        final result =
            DocumentMatcher.matchBySyncId(documents, nonExistentSyncId);

        expect(result, isNull);
      });

      test('should validate unique sync identifiers in document collections',
          () {
        final syncId1 = SyncIdentifierService.generateValidated();
        final syncId2 = SyncIdentifierService.generateValidated();
        final duplicateSyncId = SyncIdentifierService.generateValidated();

        final documents = [
          _createTestDocument(syncId: syncId1, title: 'Doc 1', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: syncId2, title: 'Doc 2', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: duplicateSyncId, title: 'Doc 3', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: duplicateSyncId, title: 'Doc 4', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), // Duplicate
        ];

        final result = DocumentMatcher.validateUniqueSyncIds(documents);

        expect(result.isValid, isFalse);
        expect(result.duplicates.length, equals(2));
        expect(result.documentsWithSyncId, equals(4));
        expect(result.totalDocuments, equals(4));
      });

      test('should find documents without sync identifiers', () {
        final syncId = SyncIdentifierService.generateValidated();
        final documents = [
          _createTestDocument(syncId: syncId, title: 'Doc with syncId', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: null, title: 'Doc without syncId', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: '', title: 'Doc with empty syncId', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
        ];

        final result = DocumentMatcher.findDocumentsWithoutSyncId(documents);

        expect(result.length, equals(2));
        expect(result.any((doc) => doc.title == 'Doc without syncId'), isTrue);
        expect(
            result.any((doc) => doc.title == 'Doc with empty syncId'), isTrue);
      });
    });

    group('Sync Operations with Sync Identifiers', () {
      test('should generate unique sync identifiers for concurrent operations',
          () {
        final syncIds = <String>{};

        // Generate sync identifiers concurrently
        for (int i = 0; i < 100; i++) {
          final syncId = SyncIdentifierService.generateValidated();
          expect(syncIds.contains(syncId), isFalse,
              reason: 'Generated duplicate sync identifier: $syncId');
          syncIds.add(syncId);
        }

        expect(syncIds.length, equals(100));
      });

      test('should maintain sync identifier consistency across operations', () {
        final originalSyncId = SyncIdentifierService.generateValidated();

        // Test normalization consistency
        final normalized1 = SyncIdentifierGenerator.normalize(originalSyncId);
        final normalized2 =
            SyncIdentifierGenerator.normalize(originalSyncId.toUpperCase());

        expect(normalized1, equals(normalized2));
        expect(normalized1, equals(originalSyncId.toLowerCase()));
      });

      test('should validate sync identifiers before storage operations', () {
        final validSyncId = SyncIdentifierService.generateValidated();
        const invalidSyncId = 'invalid-sync-id';

        // Valid sync identifier should be storage ready
        expect(SyncIdentifierService.isStorageReady(validSyncId), isTrue);

        // Invalid sync identifier should not be storage ready
        expect(SyncIdentifierService.isStorageReady(invalidSyncId), isFalse);

        // Preparing valid sync identifier should succeed
        final prepared = SyncIdentifierService.prepareForStorage(validSyncId);
        expect(prepared, equals(validSyncId));

        // Preparing invalid sync identifier should throw
        expect(
          () => SyncIdentifierService.prepareForStorage(invalidSyncId),
          throwsArgumentError,
        );
      });

      test('should handle sync identifier validation in batch operations', () {
        final validSyncIds =
            List.generate(5, (_) => SyncIdentifierService.generateValidated());
        final mixedSyncIds = [
          ...validSyncIds.take(3),
          'invalid-1',
          'invalid-2',
        ];

        // Valid collection should pass validation
        final validResult =
            SyncIdentifierService.validateCollection(validSyncIds);
        expect(validResult.isValid, isTrue);
        expect(validResult.validCount, equals(5));

        // Mixed collection should fail validation
        final mixedResult =
            SyncIdentifierService.validateCollection(mixedSyncIds);
        expect(mixedResult.isValid, isFalse);
        expect(mixedResult.validCount, equals(3));
        expect(mixedResult.invalidIds.length, equals(2));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle empty collections gracefully', () {
        final result = SyncIdentifierService.validateCollection([]);

        expect(result.isValid, isTrue);
        expect(result.totalCount, equals(0));
        expect(result.validCount, equals(0));
        expect(result.invalidIds, isEmpty);
        expect(result.duplicateIds, isEmpty);
      });

      test('should handle null and empty sync identifiers', () {
        expect(SyncIdentifierGenerator.isValid(''), isFalse);
        expect(SyncIdentifierService.isStorageReady(''), isFalse);

        expect(
          () => SyncIdentifierService.validateOrThrow(''),
          throwsArgumentError,
        );
      });

      test('should provide descriptive error messages', () {
        const invalidSyncId = 'invalid-sync-id';
        const context = 'test operation';

        try {
          SyncIdentifierService.validateOrThrow(invalidSyncId,
              context: context);
          fail('Should have thrown ArgumentError');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          expect(e.toString(), contains(invalidSyncId));
          expect(e.toString(), contains(context));
          expect(e.toString(), contains('UUID v4'));
        }
      });

      test('should handle case-insensitive duplicate detection', () {
        final syncId = SyncIdentifierService.generateValidated();
        final syncIds = [
          syncId,
          syncId.toUpperCase(),
        ];

        final result = SyncIdentifierService.validateCollection(syncIds);

        expect(result.isValid, isFalse);
        expect(result.duplicateIds.length, equals(1));
        expect(result.validCount, equals(1));
      });
    });
  });
}

/// Helper function to create test documents
Document _createTestDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), {,
  String? syncId,
  required String title,
  String category = 'Test',
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
    createdAt: amplify_core.TemporalDateTime.now(),
    lastModified: amplify_core.TemporalDateTime.now(),
    version: 1,
    syncState: 'notSynced',
  );
}
