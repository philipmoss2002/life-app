import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/database_service.dart';
import 'package:household_docs_app/models/Document.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';
import '../../lib/services/sync_identifier_service.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import '../test_helpers.dart';

/// Test suite for database service validation and error handling
///
/// **Feature: sync-identifier-refactor, Task 11: Database Validation**
///
/// This test suite verifies that:
/// 1. Database operations validate sync identifiers
/// 2. Duplicate sync identifiers are prevented
/// 3. Error messages are descriptive and reference sync identifiers
/// 4. Validation works for all database operations
void main() {
  group('Database Service Validation', () {
    late DatabaseService databaseService;

    setUpAll(() {
      setupTestDatabase();
    });

    setUp(() {
      databaseService = DatabaseService.instance;
    });

    test('should validate sync identifier format in hasDuplicateSyncId',
        () async {
      const invalidSyncId = 'invalid-sync-id';
      const userId = 'test-user';

      expect(
        () => databaseService.hasDuplicateSyncId(invalidSyncId, userId),
        throwsArgumentError,
      );
    });

    test('should validate sync identifier format in createTombstone', () async {
      const invalidSyncId = 'invalid-sync-id';
      const userId = 'test-user';
      const deletedBy = 'test-device';

      expect(
        () => databaseService.createTombstone(invalidSyncId, userId, deletedBy),
        throwsArgumentError,
      );
    });

    test('should validate required fields in createTombstone', () async {
      final validSyncId = SyncIdentifierService.generateValidated();

      // Empty userId
      expect(
        () => databaseService.createTombstone(validSyncId, '', 'test-device'),
        throwsArgumentError,
      );

      // Empty deletedBy
      expect(
        () => databaseService.createTombstone(validSyncId, 'test-user', ''),
        throwsArgumentError,
      );
    });

    test('should validate sync identifier format in isTombstoned', () async {
      const invalidSyncId = 'invalid-sync-id';

      expect(
        () => databaseService.isTombstoned(invalidSyncId),
        throwsArgumentError,
      );
    });

    test('should validate sync identifier format in addFileToDocumentBySyncId',
        () async {
      const invalidSyncId = 'invalid-sync-id';
      const filePath = '/test/file.pdf';

      expect(
        () => databaseService.addFileToDocumentBySyncId(
            invalidSyncId, filePath, null),
        throwsArgumentError,
      );
    });

    test('should validate required fields in addFileToDocumentBySyncId',
        () async {
      final validSyncId = SyncIdentifierService.generateValidated();

      // Empty file path
      expect(
        () => databaseService.addFileToDocumentBySyncId(validSyncId, '', null),
        throwsArgumentError,
      );
    });

    test('should validate sync identifier format in getFileAttachmentsBySyncId',
        () async {
      const invalidSyncId = 'invalid-sync-id';

      expect(
        () => databaseService.getFileAttachmentsBySyncId(invalidSyncId),
        throwsArgumentError,
      );
    });

    test('should validate sync identifier format in updateDocumentSyncId',
        () async {
      const documentId = 1;
      const invalidSyncId = 'invalid-sync-id';

      expect(
        () => databaseService.updateDocumentSyncId(documentId, invalidSyncId),
        throwsArgumentError,
      );
    });

    test('should validate collection of sync identifiers', () async {
      const userId = 'test-user';

      // This should not throw even if no documents exist
      final result = await databaseService.validateUserSyncIds(userId);
      expect(result, isNotNull);
      expect(result.isValid, isTrue); // Empty collection is valid
    });

    test('should get user sync identifiers', () async {
      const userId = 'test-user';

      // This should not throw even if no documents exist
      final syncIds = await databaseService.getUserSyncIds(userId);
      expect(syncIds, isNotNull);
      expect(syncIds, isA<List<String>>());
    });
  });

  group('Document Validation', () {
    late DatabaseService databaseService;

    setUp(() {
      databaseService = DatabaseService.instance;
    });

    test('should create document with valid sync identifier', () async {
      final document = Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

        userId: 'test-user',
        title: 'Test Document',
        category: 'test',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: 'notSynced',
        syncId: SyncIdentifierService.generateValidated(),
      );

      // This should not throw
      expect(
        () => databaseService.createDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), document),
        returnsNormally,
      );
    });

    test('should reject document with invalid sync identifier', () async {
      final document = Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

        userId: 'test-user',
        title: 'Test Document',
        category: 'test',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: 'notSynced',
        syncId: 'invalid-sync-id',
      );

      expect(
        () => databaseService.createDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), document),
        throwsArgumentError,
      );
    });

    test('should reject document with empty title', () async {
      final document = Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

        userId: 'test-user',
        title: '', // Empty title
        category: 'test',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: 'notSynced',
        syncId: SyncIdentifierService.generateValidated(),
      );

      expect(
        () => databaseService.createDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), document),
        throwsArgumentError,
      );
    });

    test('should reject document with empty userId', () async {
      final document = Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

        userId: '', // Empty userId
        title: 'Test Document',
        category: 'test',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: 'notSynced',
        syncId: SyncIdentifierService.generateValidated(),
      );

      expect(
        () => databaseService.createDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"), document),
        throwsArgumentError,
      );
    });
  });

  group('Error Message Quality', () {
    late DatabaseService databaseService;

    setUp(() {
      databaseService = DatabaseService.instance;
    });

    test('should provide descriptive error messages with context', () async {
      const invalidSyncId = 'invalid-sync-id';
      const userId = 'test-user';

      try {
        await databaseService.hasDuplicateSyncId(invalidSyncId, userId);
        fail('Should have thrown ArgumentError');
      } catch (e) {
        expect(e, isA<ArgumentError>());
        expect(e.toString(), contains(invalidSyncId));
        expect(e.toString(), contains('duplicate check'));
        expect(e.toString(), contains('UUID v4'));
      }
    });

    test('should provide context-specific error messages', () async {
      const invalidSyncId = 'invalid-sync-id';

      try {
        await databaseService.isTombstoned(invalidSyncId);
        fail('Should have thrown ArgumentError');
      } catch (e) {
        expect(e, isA<ArgumentError>());
        expect(e.toString(), contains('tombstone check'));
      }
    });

    test('should provide descriptive error for missing document', () async {
      final nonExistentSyncId = SyncIdentifierService.generateValidated();
      const filePath = '/test/file.pdf';

      try {
        await databaseService.addFileToDocumentBySyncId(
            nonExistentSyncId, filePath, null);
        fail('Should have thrown ArgumentError');
      } catch (e) {
        expect(e, isA<ArgumentError>());
        expect(e.toString(), contains(nonExistentSyncId));
        expect(e.toString(), contains('not found'));
      }
    });
  });
}
