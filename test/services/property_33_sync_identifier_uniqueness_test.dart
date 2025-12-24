import 'package:test/test.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';
import 'package:household_docs_app/services/sync_identifier_service.dart';

/// **Feature: sync-identifier-refactor, Property 1: Sync Identifier Uniqueness**
/// **Validates: Requirements 9.5**
///
/// Property-based test to verify that sync identifiers are unique within
/// a user's document collection. This test generates collections of sync
/// identifiers and verifies that no duplicates exist.
void main() {
  group('Property 1: Sync Identifier Uniqueness', () {
    test('generated sync identifiers should be unique in any collection', () {
      // Property: For any collection of generated sync identifiers,
      // all identifiers should be unique

      // Test with various collection sizes to ensure uniqueness holds
      final testSizes = [1, 10, 50, 100, 500, 1000];

      for (final size in testSizes) {
        // Generate a collection of sync identifiers
        final syncIds =
            List.generate(size, (_) => SyncIdentifierService.generateValidated());

        // Verify uniqueness by comparing list length with set length
        final uniqueIds = syncIds.toSet();

        expect(
          uniqueIds.length,
          equals(syncIds.length),
          reason: 'All $size generated sync identifiers should be unique. '
              'Found ${syncIds.length - uniqueIds.length} duplicates.',
        );

        // Additional verification using the service validation
        final validationResult =
            SyncIdentifierService.validateCollection(syncIds);
        expect(
          validationResult.isValid,
          isTrue,
          reason: 'Collection validation failed: ${validationResult.summary}',
        );
        expect(
          validationResult.duplicateIds,
          isEmpty,
          reason:
              'Found duplicate sync identifiers: ${validationResult.duplicateIds}',
        );
      }
    });

    test('sync identifiers should remain unique across multiple generations',
        () {
      // Property: Sync identifiers generated across multiple batches
      // should remain unique when combined

      const batchSize = 100;
      const numBatches = 10;
      final allSyncIds = <String>[];

      // Generate multiple batches of sync identifiers
      for (int batch = 0; batch < numBatches; batch++) {
        final batchIds =
            List.generate(batchSize, (_) => SyncIdentifierService.generateValidated());
        allSyncIds.addAll(batchIds);
      }

      // Verify uniqueness across all batches
      final uniqueIds = allSyncIds.toSet();
      expect(
        uniqueIds.length,
        equals(allSyncIds.length),
        reason:
            'All ${allSyncIds.length} sync identifiers across $numBatches batches should be unique. '
            'Found ${allSyncIds.length - uniqueIds.length} duplicates.',
      );

      // Verify using service validation
      final validationResult =
          SyncIdentifierService.validateCollection(allSyncIds);
      expect(
        validationResult.isValid,
        isTrue,
        reason: 'Cross-batch validation failed: ${validationResult.summary}',
      );
    });

    test('sync identifiers should be unique even with concurrent generation',
        () {
      // Property: Sync identifiers generated concurrently should be unique
      // This simulates multiple documents being created simultaneously

      const numConcurrent = 1000;

      // Generate sync identifiers concurrently (simulated)
      final futures = List.generate(
        numConcurrent,
        (_) => Future.value(SyncIdentifierService.generateValidated()),
      );

      return Future.wait(futures).then((syncIds) {
        // Verify uniqueness
        final uniqueIds = syncIds.toSet();
        expect(
          uniqueIds.length,
          equals(syncIds.length),
          reason:
              'All $numConcurrent concurrently generated sync identifiers should be unique. '
              'Found ${syncIds.length - uniqueIds.length} duplicates.',
        );

        // Verify all are valid UUIDs
        for (final syncId in syncIds) {
          expect(
            SyncIdentifierGenerator.isValid(syncId),
            isTrue,
            reason: 'Generated sync identifier should be val          );
        }
      });
    });

    test('sync identifier uniqueness should hold with mixed case normalization',
        () {
      // Property: Even when sync identifiers are normalized to different cases,
      // the underlying uniqueness should be preserved

      const numIds = 100;
      final originalIds =
          List.generate(numIds, (_) => SyncIdentifierService.generateValidated());

      // Create mixed case versions
      final mixedCaseIds = <String>[];
      for (int i = 0; i < originalIds.length; i++) {
        final original = originalIds[i];
        if (i % 2 == 0) {
          // Keep some lowercase
          mixedCaseIds.add(original);
        } else {
          // Make some uppercase
          mixedCaseIds.add(original.toUpperCase());
        }
      }

      // Verify that normalization preserves uniqueness
      final normalizedIds =
          mixedCaseIds.map(SyncIdentifierGenerator.normalize).toList();
      final uniqueNormalized = normalizedIds.toSet();

      expect(
        uniqueNormalized.length,
        equals(normalizedIds.length),
        reason: 'Normalized sync identifiers should maintain uniqueness',
      );

      // Verify using service validation (which handles normalization)
      final validationResult =
          SyncIdentifierService.validateCollection(mixedCaseIds);
      expect(
        validationResult.duplicateIds,
        isEmpty,
        reason:
            'Mixed case sync identifiers should not be detected as duplicates after normalization',
      );
    });

    test('property should hold for edge cases', () {
      // Property: Uniqueness should hold even for edge cases

      // Test with single identifier
      final singleId = [SyncIdentifierService.generateValidated()];
      final singleResult = SyncIdentifierService.validateCollection(singleId);
      expect(singleResult.isValid, isTrue);
      expect(singleResult.duplicateIds, isEmpty);

      // Test with empty collection
      final emptyResult = SyncIdentifierService.validateCollection([]);
      expect(emptyResult.isValid, isTrue);
      expect(emptyResult.duplicateIds, isEmpty);

      // Test with maximum reasonable collection size for a user
      const maxUserDocuments =
          10000; // Reasonable upper bound for user documents
      final largeCollection = List.generate(
          maxUserDocuments, (_) => SyncIdentifierService.generateValidated());
      final largeUniqueIds = largeCollection.toSet();

      expect(
        largeUniqueIds.length,
        equals(largeCollection.length),
        reason: 'Even large collections of sync identifiers should be unique',
      );
    });
  });
}
