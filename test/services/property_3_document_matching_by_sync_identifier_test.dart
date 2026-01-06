import 'package:test/test.dart';
import 'package:household_docs_app/models/Document.dart';
import 'package:household_docs_app/services/document_matcher.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';
import 'package:amplify_core/amplify_core.dart';
import 'package:faker/faker.dart';

import '../../lib/services/sync_identifier_service.dart';
/// **Feature: sync-identifier-refactor, Property 3: Document Matching by Sync Identifier**
/// **Validates: Requirements 2.1**
///
/// Property-based test to verify that document matching always uses the sync identifier
/// as the primary criterion. This ensures reliable document identification across
/// local and remote storage systems regardless of other document properties.
void main() {
  group('Property 3: Document Matching by Sync Identifier', () {
    test(
        'document matching should always use sync identifier as primary criterion',
        () {
      // Property: For any document with a sync identifier, matching should
      // always use the sync identifier as the primary criterion

      const numTestCases = 100;
      final faker = Faker();

      for (int i = 0; i < numTestCases; i++) {
        // Generate a target sync identifier
        final targetSyncId = SyncIdentifierService.generateValidated();

        // Create a collection of documents with various properties
        final documents = <Document>[];

        // Add documents with different sync identifiers (should not match)
        for (int j = 0; j < 10; j++) {
          documents.add(_createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
            title: faker.lorem.sentence(),
            category: faker.randomGenerator
                .element(['Insurance', 'Medical', 'Legal', 'Financial']),
            notes: faker.lorem.sentences(3).join(' '),
          ));
        }

        // Add the target document with matching sync identifier
        final targetDocument = _createTestDocument(syncId: targetSyncId, title: faker.lorem.sentence(, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          category: faker.randomGenerator
              .element(['Insurance', 'Medical', 'Legal', 'Financial']),
          notes: faker.lorem.sentences(3).join(' '),
        );
        documents.add(targetDocument);

        // Add more documents with different sync identifiers
        for (int j = 0; j < 10; j++) {
          documents.add(_createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
            title: faker.lorem.sentence(),
            category: faker.randomGenerator
                .element(['Insurance', 'Medical', 'Legal', 'Financial']),
            notes: faker.lorem.sentences(3).join(' '),
          ));
        }

        // Shuffle the documents to ensure order doesn't matter
        documents.shuffle();

        // Act: Match by sync identifier
        final matchedDocument =
            DocumentMatcher.matchBySyncId(documents, targetSyncId);

        // Assert: Should find exactly the target document
        expect(
          matchedDocument,
          isNotNull,
          reason:
              'Should find document with matching sync identifier (test case $i)',
        );

        expect(
          matchedDocument!.syncId,
          equals(targetSyncId),
          reason:
              'Matched document should have the target sync identifier (test case $i)',
        );

        expect(
          matchedDocument.syncId,
          equals(targetDocument.syncId),
          reason: 'Should match the exact target document (test case $i)',
        );
      }
    });

    test('sync identifier matching should be case-insensitive but consistent',
        () {
      // Property: Sync identifier matching should handle case variations consistently

      const numTestCases = 50;
      final faker = Faker();

      for (int i = 0; i < numTestCases; i++) {
        final baseSyncId = SyncIdentifierService.generateValidated();

        // Create documents with different case variations of the same sync identifier
        final documents = <Document>[
          _createTestDocument(syncId: baseSyncId.toLowerCase(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
            title: 'Lowercase Document',
            category: 'Insurance',
          ),
          _createTestDocument(syncId: baseSyncId.toUpperCase(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
            title: 'Uppercase Document',
            category: 'Medical',
          ),
          _createTestDocument(syncId: _createMixedCase(baseSyncId, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
            title: 'Mixed Case Document',
            category: 'Legal',
          ),
        ];

        // Add some documents with completely different sync identifiers
        for (int j = 0; j < 5; j++) {
          documents.add(_createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
            title: faker.lorem.sentence(),
            category: 'Financial',
          ));
        }

        documents.shuffle();

        // Test matching with different case variations
        final testCases = [
          baseSyncId.toLowerCase(),
          baseSyncId.toUpperCase(),
          _createMixedCase(baseSyncId),
        ];

        for (final testSyncId in testCases) {
          final matchedDocument =
              DocumentMatcher.matchBySyncId(documents, testSyncId);

          expect(
            matchedDocument,
            isNotNull,
            reason:
                'Should find document regardless of case variation (test $i, syncId: $testSyncId)',
          );

          // The matched document should have a sync identifier that normalizes to the same value
          final normalizedMatched =
              SyncIdentifierGenerator.normalize(matchedDocument!.syncId!);
          final normalizedTest = SyncIdentifierGenerator.normalize(testSyncId);

          expect(
            normalizedMatched,
            equals(normalizedTest),
            reason:
                'Matched document sync identifier should normalize to same value (test $i)',
          );
        }
      }
    });

    test('sync identifier matching should ignore content differences', () {
      // Property: Documents with the same sync identifier should match
      // regardless of content differences (title, category, notes, etc.)

      const numTestCases = 50;
      final faker = Faker();

      for (int i = 0; i < numTestCases; i++) {
        final sharedSyncId = SyncIdentifierService.generateValidated();

        // Create documents with same sync identifier but different content
        final documents = <Document>[
          _createTestDocument(syncId: sharedSyncId, title: 'Original Title', category: 'Insurance', notes: 'Original notes', filePaths: ['file1.pdf'], userId: "test-user", createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: sharedSyncId, title: 'Completely Different Title', category: 'Medical', notes: 'Completely different notes with more content', filePaths: ['different_file.pdf', 'another_file.jpg'], userId: "test-user", createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          _createTestDocument(syncId: sharedSyncId, title: faker.lorem.sentence(, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
            category: faker.randomGenerator
                .element(['Legal', 'Financial', 'Personal']),
            notes: faker.lorem.sentences(5).join(' '),
            filePaths: List.generate(3, (_) => '${faker.lorem.word()}.pdf'),
          ),
        ];

        // Add documents with different sync identifiers
        for (int j = 0; j < 10; j++) {
          documents.add(_createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
            title: faker.lorem.sentence(),
            category: faker.randomGenerator
                .element(['Insurance', 'Medical', 'Legal']),
          ));
        }

        documents.shuffle();

        // Match by the shared sync identifier
        final matchedDocument =
            DocumentMatcher.matchBySyncId(documents, sharedSyncId);

        expect(
          matchedDocument,
          isNotNull,
          reason:
              'Should find document with matching sync identifier regardless of content (test $i)',
        );

        expect(
          matchedDocument!.syncId,
          equals(sharedSyncId),
          reason:
              'Matched document should have the target sync identifier (test $i)',
        );

        // The matched document should be one of the documents with the shared sync identifier
        final documentsWithSharedSyncId =
            documents.where((doc) => doc.syncId == sharedSyncId).toList();
        expect(
          documentsWithSharedSyncId,
          contains(matchedDocument),
          reason:
              'Matched document should be one of the documents with the shared sync identifier (test $i)',
        );
      }
    });

    test(
        'sync identifier matching should handle documents without sync identifiers',
        () {
      // Property: When searching for a sync identifier, documents without
      // sync identifiers should be ignored

      const numTestCases = 50;
      final faker = Faker();

      for (int i = 0; i < numTestCases; i++) {
        final targetSyncId = SyncIdentifierService.generateValidated();

        final documents = <Document>[];

        // Add documents without sync identifiers
        for (int j = 0; j < 10; j++) {
          documents.add(_createTestDocument(syncId: null, title: faker.lorem.sentence(, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
            category: 'Insurance',
          ));
        }

        // Add documents with empty sync identifiers
        for (int j = 0; j < 5; j++) {
          documents.add(_createTestDocument(syncId: '', title: faker.lorem.sentence(, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
            category: 'Medical',
          ));
        }

        // Add the target document
        final targetDocument = _createTestDocument(syncId: targetSyncId, title: 'Target Document', category: 'Legal', userId: "test-user", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending");
        documents.add(targetDocument);

        // Add more documents with different sync identifiers
        for (int j = 0; j < 10; j++) {
          documents.add(_createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
            title: faker.lorem.sentence(),
            category: 'Financial',
          ));
        }

        documents.shuffle();

        // Match by sync identifier
        final matchedDocument =
            DocumentMatcher.matchBySyncId(documents, targetSyncId);

        expect(
          matchedDocument,
          isNotNull,
          reason:
              'Should find target document despite presence of documents without sync identifiers (test $i)',
        );

        expect(
          matchedDocument!.syncId,
          equals(targetSyncId),
          reason:
              'Should match the target document with correct sync identifier (test $i)',
        );

        expect(
          matchedDocument.syncId,
          equals(targetDocument.syncId),
          reason: 'Should match the exact target document (test $i)',
        );
      }
    });

    test(
        'sync identifier matching should return null for non-existent identifiers',
        () {
      // Property: When searching for a sync identifier that doesn't exist
      // in the collection, the result should be null

      const numTestCases = 50;
      final faker = Faker();

      for (int i = 0; i < numTestCases; i++) {
        final documents = <Document>[];

        // Create a collection of documents with various sync identifiers
        final usedSyncIds = <String>{};
        for (int j = 0; j < 20; j++) {
          final syncId = SyncIdentifierService.generateValidated();
          usedSyncIds.add(syncId);
          documents.add(_createTestDocument(syncId: syncId, title: faker.lorem.sentence(, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
            category: faker.randomGenerator
                .element(['Insurance', 'Medical', 'Legal', 'Financial']),
          ));
        }

        // Generate a sync identifier that's guaranteed not to be in the collection
        String nonExistentSyncId;
        do {
          nonExistentSyncId = SyncIdentifierService.generateValidated();
        } while (usedSyncIds.contains(nonExistentSyncId));

        documents.shuffle();

        // Try to match the non-existent sync identifier
        final matchedDocument =
            DocumentMatcher.matchBySyncId(documents, nonExistentSyncId);

        expect(
          matchedDocument,
          isNull,
          reason:
              'Should return null when sync identifier is not found in collection (test $i)',
        );
      }
    });

    test('sync identifier matching should be deterministic and consistent', () {
      // Property: Multiple calls to match the same sync identifier should
      // return the same result consistently

      const numTestCases = 30;
      final faker = Faker();

      for (int i = 0; i < numTestCases; i++) {
        final targetSyncId = SyncIdentifierService.generateValidated();

        // Create a collection of documents
        final documents = <Document>[];

        for (int j = 0; j < 15; j++) {
          documents.add(_createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
            title: faker.lorem.sentence(),
            category: faker.randomGenerator
                .element(['Insurance', 'Medical', 'Legal']),
          ));
        }

        // Add the target document
        final targetDocument = _createTestDocument(syncId: targetSyncId, title: 'Target Document', category: 'Financial', userId: "test-user", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending");
        documents.add(targetDocument);

        // Perform multiple matches
        const numMatches = 10;
        final results = <Document?>[];

        for (int k = 0; k < numMatches; k++) {
          final result = DocumentMatcher.matchBySyncId(documents, targetSyncId);
          results.add(result);
        }

        // All results should be identical
        for (int k = 0; k < numMatches; k++) {
          expect(
            results[k],
            isNotNull,
            reason:
                'All match attempts should find the document (test $i, attempt $k)',
          );

          expect(
            results[k]!.id,
            equals(targetDocument.syncId),
            reason:
                'All match attempts should return the same document (test $i, attempt $k)',
          );

          expect(
            results[k]!.syncId,
            equals(targetSyncId),
            reason:
                'All match attempts should return document with correct sync identifier (test $i, attempt $k)',
          );
        }
      }
    });

    test('sync identifier validation should be enforced during matching', () {
      // Property: Invalid sync identifiers should be rejected during matching

      final documents = <Document>[
        _createTestDocument(syncId: SyncIdentifierGenerator.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),
          title: 'Valid Document',
          category: 'Insurance',
        ),
      ];

      // Test various invalid sync identifier formats
      final invalidSyncIds = [
        'not-a-uuid',
        '12345',
        'invalid-format-here',
        'too-short',
        'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx', // wrong format
        '550e8400-e29b-41d4-a716', // too short
        '550e8400-e29b-41d4-a716-446655440000-extra', // too long
        '', // empty string
        '   ', // whitespace only
      ];

      for (final invalidSyncId in invalidSyncIds) {
        expect(
          () => DocumentMatcher.matchBySyncId(documents, invalidSyncId),
          throwsArgumentError,
          reason:
              'Should throw ArgumentError for invalid sync identifier: "$invalidSyncId"',
        );
      }
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

/// Helper function to create mixed case version of a sync identifier
String _createMixedCase(String syncId) {
  final chars = syncId.split('');
  for (int i = 0; i < chars.length; i += 2) {
    if (chars[i] != '-') {
      chars[i] = chars[i].toUpperCase();
    }
  }
  return chars.join('');
}
