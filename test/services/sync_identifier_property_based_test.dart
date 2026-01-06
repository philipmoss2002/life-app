import 'package:test/test.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';
import 'package:household_docs_app/services/sync_identifier_service.dart';

/// **Feature: sync-identifier-refactor, Property-Based Tests for Sync Identifier Uniqueness and Format**
/// **Validates: Requirements 15.5**
///
/// Comprehensive property-based tests to verify that sync identifiers maintain
/// uniqueness and proper UUID v4 format across all system operations.
/// These tests use property-based testing principles to validate correctness
/// across a wide range of inputs and scenarios.
void main() {
  group('Sync Identifier Property-Based Tests', () {
    group('Property: Sync Identifier Uniqueness', () {
      test(
          'generated sync identifiers should be unique across any collection size',
          () {
        // Property: For any collection of generated sync identifiers,
        // all identifiers should be unique regardless of collection size

        final testSizes = [1, 10, 50, 100, 500, 1000, 5000];

        for (final size in testSizes) {
          // Generate collection of sync identifiers
          final syncIds =
              List.generate(size, (_) => SyncIdentifierService.generateValidated());

          // Property: All generated sync identifiers should be unique
          final uniqueIds = syncIds.toSet();
          expect(
            uniqueIds.length,
            equals(syncIds.length),
            reason: 'All $size generated sync identifiers should be unique. '
                'Found ${syncIds.length - uniqueIds.length} duplicates.',
          );

          // Property: All sync identifiers should be valid UUID v4 format
          for (final syncId in syncIds) {
            expect(
              SyncIdentifierGenerator.isValid(syncId),
              isTrue,
              reason:
                  'Generated sync identifier should be valid UUID v4: $syncId',
            );
          }

          // Property: Collection validation should confirm uniqueness
          final validationResult =
              SyncIdentifierService.validateCollection(syncIds);
          expect(
            validationResult.isValid,
            isTrue,
            reason:
                'Collection validation should pass for $size unique sync identifiers',
          );
          expect(
            validationResult.duplicateIds,
            isEmpty,
            reason:
                'No duplicate sync identifiers should be detected in collection of $size',
          );
        }
      });

      test(
          'sync identifier uniqueness should hold across concurrent generation',
          () {
        // Property: Sync identifiers generated concurrently should maintain uniqueness
        // This simulates real-world scenarios where multiple documents are created simultaneously

        const numConcurrent = 10000;
        final syncIds = <String>[];

        // Generate sync identifiers in batches to simulate concurrent creation
        const batchSize = 100;
        final numBatches = numConcurrent ~/ batchSize;

        for (int batch = 0; batch < numBatches; batch++) {
          final batchIds = List.generate(
              batchSize, (_) => SyncIdentifierService.generateValidated());
          syncIds.addAll(batchIds);
        }

        // Property: All concurrently generated sync identifiers should be unique
        final uniqueIds = syncIds.toSet();
        expect(
          uniqueIds.length,
          equals(syncIds.length),
          reason:
              'All $numConcurrent concurrently generated sync identifiers should be unique. '
              'Found ${syncIds.length - uniqueIds.length} duplicates.',
        );

        // Property: All should maintain valid format
        for (final syncId in syncIds) {
          expect(
            SyncIdentifierGenerator.isValid(syncId),
            isTrue,
            reason:
                'Concurrently generated sync identifier should be val          );
        }
      });

      test('sync identifier uniqueness should be preserved under normalization',
          () {
        // Property: Uniqueness should be preserved even when sync identifiers
        // are normalized to different cases

        const numIds = 1000;
        final originalIds =
            List.generate(numIds, (_) => SyncIdentifierService.generateValidated());

        // Create mixed case versions
        final mixedCaseIds = <String>[];
        for (int i = 0; i < originalIds.length; i++) {
          final original = originalIds[i];
          switch (i % 4) {
            case 0:
              mixedCaseIds.add(original); // Keep lowercase
              break;
            case 1:
              mixedCaseIds.add(original.toUpperCase()); // All uppercase
              break;
            case 2:
              mixedCaseIds.add(_createMixedCase(original)); // Mixed case
              break;
            case 3:
              mixedCaseIds.add(original.toUpperCase().substring(0, 18) +
                  original.substring(18)); // Partial uppercase
              break;
          }
        }

        // Property: Normalization should preserve logical uniqueness
        final normalizedIds =
            mixedCaseIds.map(SyncIdentifierGenerator.normalize).toList();
        final uniqueNormalized = normalizedIds.toSet();

        expect(
          uniqueNormalized.length,
          equals(normalizedIds.length),
          reason: 'Normalized sync identifiers should maintain uniqueness',
        );

        // Property: All normalized forms should be valid
        for (final normalizedId in normalizedIds) {
          expect(
            SyncIdentifierGenerator.isValid(normalizedId),
            isTrue,
            reason: 'Normalized sync identifier should be val          );
        }
      });

      test(
          'sync identifier uniqueness should hold for extreme collection sizes',
          () {
        // Property: Uniqueness should hold even for very large collections
        // that might stress the UUID generation algorithm

        const extremeSize = 50000;
        final syncIds = <String>[];

        // Generate in chunks to avoid memory issues
        const chunkSize = 5000;
        final numChunks = extremeSize ~/ chunkSize;

        for (int chunk = 0; chunk < numChunks; chunk++) {
          final chunkIds = List.generate(
              chunkSize, (_) => SyncIdentifierService.generateValidated());
          syncIds.addAll(chunkIds);

          // Verify uniqueness within chunk
          final chunkUnique = chunkIds.toSet();
          expect(
            chunkUnique.length,
            equals(chunkIds.length),
            reason: 'Chunk $chunk should have unique sync identifiers',
          );
        }

        // Property: All sync identifiers across all chunks should be unique
        final allUnique = syncIds.toSet();
        expect(
          allUnique.length,
          equals(syncIds.length),
          reason:
              'All $extremeSize sync identifiers should be unique across chunks. '
              'Found ${syncIds.length - allUnique.length} duplicates.',
        );
      });
    });

    group('Property: Sync Identifier Format Validation', () {
      test('all generated sync identifiers should conform to UUID v4 format',
          () {
        // Property: For any generated sync identifier, it should conform to UUID v4 format
        // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
        // where x is any hexadecimal digit and y is one of 8, 9, a, or b

        const numTests = 10000;
        final uuidV4Pattern = RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

        for (int i = 0; i < numTests; i++) {
          final syncId = SyncIdentifierService.generateValidated();

          // Property: Should match UUID v4 pattern exactly
          expect(
            uuidV4Pattern.hasMatch(syncId),
            isTrue,
            reason:
                'Generated sync identifier should match UUID v4 pattern: $syncId',
          );

          // Property: Should be lowercase
          expect(
            syncId,
            equals(syncId.toLowerCase()),
            reason: 'Generated sync identifier should be lowercase: $syncId',
          );

          // Property: Should have correct length (36 characters)
          expect(
            syncId.length,
            equals(36),
            reason:
                'Generated sync identifier should be 36 characters long: $syncId',
          );

          // Property: Should have hyphens in correct positions
          expect(syncId[8], equals('-'),
              reason: 'Position 8 should be hyphen in: $syncId');
          expect(syncId[13], equals('-'),
              reason: 'Position 13 should be hyphen in: $syncId');
          expect(syncId[18], equals('-'),
              reason: 'Position 18 should be hyphen in: $syncId');
          expect(syncId[23], equals('-'),
              reason: 'Position 23 should be hyphen in: $syncId');

          // Property: Should have version 4 indicator
          expect(
            syncId[14],
            equals('4'),
            reason: 'Position 14 should be "4" for UUID v4: $syncId',
          );

          // Property: Should have correct variant bits (8, 9, a, or b)
          final variantChar = syncId[19];
          expect(
            ['8', '9', 'a', 'b'].contains(variantChar),
            isTrue,
            reason:
                'Position 19 should be 8, 9, a, or b for UUID v4 variant: $syncId',
          );

          // Property: Should pass validation
          expect(
            SyncIdentifierGenerator.isValid(syncId),
            isTrue,
            reason: 'Generated sync identifier should pass validation: $syncId',
          );
        }
      });

      test('format validation should reject all invalid patterns', () {
        // Property: For any invalid sync identifier format,
        // validation should consistently reject it

        final invalidFormats = _generateInvalidFormats();

        for (final invalidFormat in invalidFormats) {
          // Property: Should fail validation
          expect(
            SyncIdentifierGenerator.isValid(invalidFormat),
            isFalse,
            reason: 'Invalid format should be rejected: "$invalidFormat"',
          );

          // Property: Should throw when validated strictly
          expect(
            () => SyncIdentifierService.validateOrThrow(invalidFormat),
            throwsArgumentError,
            reason:
                'Invalid format should throw ArgumentError: "$invalidFormat"',
          );

          // Property: Should not be storage ready
          expect(
            SyncIdentifierService.isStorageReady(invalidFormat),
            isFalse,
            reason:
                'Invalid format should not be storage ready: "$invalidFormat"',
          );

          // Property: Should return null when attempting to normalize
          expect(
            SyncIdentifierGenerator.validateAndNormalize(invalidFormat),
            isNull,
            reason:
                'Invalid format should return null when normalizing: "$invalidFormat"',
          );
        }
      });

      test('format validation should be consistent across multiple attempts',
          () {
        // Property: Validation results should be deterministic and consistent
        // regardless of how many times validation is performed

        final testCases = [
          // Valid cases
          SyncIdentifierService.generateValidated(),
          SyncIdentifierService.generateValidated(),
          SyncIdentifierService.generateValidated(),
          // Invalid cases
          'invalid-sync-id',
          '12345',
          '',
          '550e8400-e29b-31d4-a716-446655440000', // Wrong version
        ];

        const numAttempts = 100;

        for (final testCase in testCases) {
          final expectedResult = SyncIdentifierGenerator.isValid(testCase);

          // Property: Validation should return same result every time
          for (int attempt = 0; attempt < numAttempts; attempt++) {
            expect(
              SyncIdentifierGenerator.isValid(testCase),
              equals(expectedResult),
              reason:
                  'Validation should be consistent for "$testCase" on attempt $attempt',
            );
          }
        }
      });

      test('format validation should handle edge cases correctly', () {
        // Property: Edge cases should be handled consistently and correctly

        final edgeCases = _generateEdgeCaseFormats();

        for (final edgeCase in edgeCases) {
          // Property: Edge cases should have deterministic validation results
          final isValid = SyncIdentifierGenerator.isValid(edgeCase);

          // Property: Validation should be consistent
          expect(
            SyncIdentifierGenerator.isValid(edgeCase),
            equals(isValid),
            reason: 'Edge case validation should be consistent: "$edgeCase"',
          );

          // Property: If invalid, should be rejected by all validation methods
          if (!isValid) {
            expect(
              () => SyncIdentifierService.validateOrThrow(edgeCase),
              throwsArgumentError,
              reason: 'Invalid edge case should throw: "$edgeCase"',
            );

            expect(
              SyncIdentifierService.isStorageReady(edgeCase),
              isFalse,
              reason:
                  'Invalid edge case should not be storage ready: "$edgeCase"',
            );
          }
        }
      });

      test('format normalization should preserve validity', () {
        // Property: Normalizing a valid sync identifier should preserve its validity
        // and normalizing an invalid one should not make it valid

        const numTests = 1000;

        for (int i = 0; i < numTests; i++) {
          final originalSyncId = SyncIdentifierService.generateValidated();

          // Create case variations
          final variations = [
            originalSyncId,
            originalSyncId.toUpperCase(),
            _createMixedCase(originalSyncId),
          ];

          for (final variation in variations) {
            final normalized = SyncIdentifierGenerator.normalize(variation);

            // Property: Normalized form should be valid if original was valid
            expect(
              SyncIdentifierGenerator.isValid(normalized),
              isTrue,
              reason:
                  'Normalized sync identifier should be val            );

            // Property: Normalized form should be lowercase
            expect(
              normalized,
              equals(normalized.toLowerCase()),
              reason:
                  'Normalized sync identifier should be lowercase: "$normalized"',
            );

            // Property: All variations should normalize to the same value
            expect(
              normalized,
              equals(originalSyncId),
              reason:
                  'All variations should normalize to original: "$variation" -> "$normalized"',
            );
          }
        }
      });
    });

    group('Property: Combined Uniqueness and Format Validation', () {
      test(
          'large collections should maintain both uniqueness and format validity',
          () {
        // Property: For any large collection of generated sync identifiers,
        // all should be unique AND all should have valid format

        const collectionSize = 25000;
        final syncIds = List.generate(
            collectionSize, (_) => SyncIdentifierService.generateValidated());

        // Property: All should be unique
        final uniqueIds = syncIds.toSet();
        expect(
          uniqueIds.length,
          equals(syncIds.length),
          reason: 'All $collectionSize sync identifiers should be unique',
        );

        // Property: All should have valid format
        for (int i = 0; i < syncIds.length; i++) {
          final syncId = syncIds[i];
          expect(
            SyncIdentifierGenerator.isValid(syncId),
            isTrue,
            reason: 'Sync identifier at index $i should be val          );
        }

        // Property: Collection validation should pass
        final validationResult =
            SyncIdentifierService.validateCollection(syncIds);
        expect(
          validationResult.isValid,
          isTrue,
          reason: 'Large collection validation should pass',
        );
        expect(
          validationResult.validCount,
          equals(collectionSize),
          reason: 'All sync identifiers in large collection should be valid',
        );
        expect(
          validationResult.duplicateIds,
          isEmpty,
          reason: 'Large collection should have no duplicates',
        );
      });

      test('mixed valid and invalid collections should be properly categorized',
          () {
        // Property: Collections with mixed valid/invalid sync identifiers
        // should be properly categorized by validation

        const numValid = 100;
        final validSyncIds =
            List.generate(numValid, (_) => SyncIdentifierService.generateValidated());
        final invalidSyncIds = _generateInvalidFormats();
        final numInvalid = invalidSyncIds.length;
        final mixedCollection = [...validSyncIds, ...invalidSyncIds];

        // Shuffle to ensure order doesn't matter
        mixedCollection.shuffle();

        final validationResult =
            SyncIdentifierService.validateCollection(mixedCollection);

        // Property: Should correctly identify valid count
        expect(
          validationResult.validCount,
          equals(numValid),
          reason: 'Should identify exactly $numValid valid sync identifiers',
        );

        // Property: Should correctly identify invalid count
        expect(
          validationResult.invalidIds.length,
          equals(numInvalid),
          reason:
              'Should identify exactly $numInvalid invalid sync identifiers. '
              'Generated ${invalidSyncIds.length} invalid formats, '
              'but validation found ${validationResult.invalidIds.length}',
        );

        // Property: Should not be marked as valid overall
        expect(
          validationResult.isValid,
          isFalse,
          reason:
              'Mixed collection with invalid sync identifiers should not be valid',
        );

        // Property: Total count should match
        expect(
          validationResult.totalCount,
          equals(numValid + numInvalid),
          reason: 'Total count should match collection size',
        );
      });
    });
  });
}

/// Generate various invalid sync identifier formats for testing
List<String> _generateInvalidFormats() {
  return [
    // Empty and whitespace
    '',
    ' ',
    '   ',
    '\t',
    '\n',

    // Wrong length
    '123',
    '12345678-1234-1234-1234-123456789012345', // Too long
    '12345678-1234-1234-1234-12345678901', // Too short

    // Wrong format structure
    'not-a-uuid-at-all',
    'invalid-sync-identifier',
    '12345678123412341234123456789012', // No hyphens
    '12345678-1234-1234-1234', // Missing part
    '12345678-1234-1234-1234-', // Trailing hyphen
    '-12345678-1234-1234-1234-123456789012', // Leading hyphen

    // Wrong UUID version (not v4)
    '550e8400-e29b-11d4-a716-446655440000', // Version 1
    '550e8400-e29b-21d4-a716-446655440000', // Version 2
    '550e8400-e29b-31d4-a716-446655440000', // Version 3
    '550e8400-e29b-51d4-a716-446655440000', // Version 5
    '550e8400-e29b-61d4-a716-446655440000', // Version 6

    // Wrong variant bits (should be 8, 9, a, or b in position 19)
    '550e8400-e29b-41d4-0716-446655440000', // Wrong variant (0)
    '550e8400-e29b-41d4-1716-446655440000', // Wrong variant (1)
    '550e8400-e29b-41d4-2716-446655440000', // Wrong variant (2)
    '550e8400-e29b-41d4-c716-446655440000', // Wrong variant (c)
    '550e8400-e29b-41d4-f716-446655440000', // Wrong variant (f)

    // Invalid hexadecimal characters
    '550g8400-e29b-41d4-a716-446655440000', // 'g' is not hex
    '550e8400-e29z-41d4-a716-446655440000', // 'z' is not hex
    '550e8400-e29b-41d4-a716-44665544000g', // 'g' at end
    '550e8400-e29b-41d4-a716-44665544000G', // 'G' (uppercase invalid)

    // Special characters and symbols
    '550e8400@e29b-41d4-a716-446655440000',
    '550e8400-e29b-41d4-a716-446655440000!',
    '550e8400-e29b-41d4-a716-446655440000#',
    '550e8400-e29b-41d4-a716-446655440000 ', // Trailing space
    ' 550e8400-e29b-41d4-a716-446655440000', // Leading space

    // Wrong hyphen positions
    '550e8400e29b-41d4-a716-446655440000', // Missing first hyphen
    '550e8400-e29b41d4-a716-446655440000', // Missing second hyphen
    '550e8400-e29b-41d4a716-446655440000', // Missing third hyphen
    '550e8400-e29b-41d4-a716446655440000', // Missing fourth hyphen
  ];
}

/// Generate edge case formats for testing
List<String> _generateEdgeCaseFormats() {
  return [
    // Unicode characters
    '550e8400-e29b-41d4-a716-44665544000ü',
    '550e8400-e29b-41d4-a716-44665544000€',
    '550e8400-e29b-41d4-a716-44665544000😀',

    // Control characters
    '550e8400-e29b-41d4-a716-44665544000\n',
    '550e8400-e29b-41d4-a716-44665544000\t',
    '550e8400-e29b-41d4-a716-44665544000\r',
    '550e8400-e29b-41d4-a716-44665544000\0',

    // Very long strings
    'a' * 1000,
    '550e8400-e29b-41d4-a716-446655440000${'x' * 500}',

    // Mixed valid/invalid patterns
    '550e8400-e29b-41d4-a716-446655440000-extra',
    'prefix-550e8400-e29b-41d4-a716-446655440000',

    // Boundary cases
    '00000000-0000-4000-8000-000000000000', // All zeros (valid v4)
    'ffffffff-ffff-4fff-bfff-ffffffffffff', // All f's (valid v4)
    '00000000-0000-4000-8000-000000000001', // Minimal increment
    'fffffffe-ffff-4fff-bfff-ffffffffffff', // Maximal decrement
  ];
}

/// Create a mixed case version of a sync identifier
String _createMixedCase(String syncId) {
  final chars = syncId.split('');
  for (int i = 0; i < chars.length; i += 2) {
    if (chars[i] != '-') {
      chars[i] = chars[i].toUpperCase();
    }
  }
  return chars.join('');
}
