import 'package:test/test.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';
import 'package:household_docs_app/services/sync_identifier_service.dart';

/// **Feature: sync-identifier-refactor, Property 10: Validation Rejection**
/// **Validates: Requirements 9.2**
///
/// Property-based test to verify that invalid sync identifier formats
/// are consistently rejected by the system and do not get stored.
/// This ensures data integrity by preventing invalid identifiers from
/// entering the system.
void main() {
  group('Property 10: Validation Rejection', () {
    test('validation methods should reject invalid sync identifiers', () {
      // Property: For any invalid sync identifier format,
      // validation methods should consistently reject the invalid identifier

      final invalidFormats = _generateInvalidSyncIdentifiers();

      for (final invalidSyncId in invalidFormats) {
        // Test SyncIdentifierGenerator.isValid
        expect(
          SyncIdentifierGenerator.isValid(invalidSyncId),
          isFalse,
          reason:
              'SyncIdentifierGenerator.isValid should reject invalid format: "$invalidSyncId"',
        );

        // Test SyncIdentifierService.validateOrThrow
        expect(
          () => SyncIdentifierService.validateOrThrow(invalidSyncId),
          throwsArgumentError,
          reason:
              'SyncIdentifierService.validateOrThrow should throw for invalid format: "$invalidSyncId"',
        );

        // Test SyncIdentifierService.prepareForStorage
        expect(
          () => SyncIdentifierService.prepareForStorage(invalidSyncId),
          throwsArgumentError,
          reason:
              'SyncIdentifierService.prepareForStorage should throw for invalid format: "$invalidSyncId"',
        );

        // Test SyncIdentifierService.isStorageReady
        expect(
          SyncIdentifierService.isStorageReady(invalidSyncId),
          isFalse,
          reason:
              'SyncIdentifierService.isStorageReady should reject invalid format: "$invalidSyncId"',
        );

        // Test SyncIdentifierGenerator.validateAndNormalize
        expect(
          SyncIdentifierGenerator.validateAndNormalize(invalidSyncId),
          isNull,
          reason:
              'SyncIdentifierGenerator.validateAndNormalize should return null for invalid format: "$invalidSyncId"',
        );
      }
    });

    test('validation collection should identify all invalid sync identifiers',
        () {
      // Property: Collection validation should identify all invalid sync identifiers
      // and not mark them as valid

      final invalidFormats = _generateInvalidSyncIdentifiers();
      final validSyncIds =
          List.generate(5, (_) => SyncIdentifierService.generateValidated());

      // Mix valid and invalid sync identifiers
      final mixedCollection = [...validSyncIds, ...invalidFormats];

      final result = SyncIdentifierService.validateCollection(mixedCollection);

      // Should not be valid overall
      expect(
        result.isValid,
        isFalse,
        reason:
            'Collection with invalid sync identifiers should not be marked as valid',
      );

      // Should identify all invalid formats
      expect(
        result.invalidIds.length,
        equals(invalidFormats.length),
        reason:
            'Should identify all ${invalidFormats.length} invalid sync identifiers',
      );

      // Should only count valid ones
      expect(
        result.validCount,
        equals(validSyncIds.length),
        reason:
            'Should only count ${validSyncIds.length} valid sync identifiers',
      );

      // All invalid formats should be in the invalid list
      for (final invalidSyncId in invalidFormats) {
        expect(
          result.invalidIds,
          contains(invalidSyncId),
          reason:
              'Invalid sync identifier "$invalidSyncId" should be in invalid list',
        );
      }
    });

    test('error messages should contain context for invalid sync identifiers',
        () {
      // Property: When rejecting invalid sync identifiers, error messages should
      // provide context about what was invalid and where it occurred

      final invalidFormats = _generateInvalidSyncIdentifiers();

      for (final invalidSyncId in invalidFormats) {
        // Test error message contains the invalid sync identifier
        try {
          SyncIdentifierService.validateOrThrow(invalidSyncId,
              context: 'test operation');
          fail(
              'Should have thrown ArgumentError for invalid sync identifier: "$invalidSyncId"');
        } catch (e) {
          expect(e, isA<ArgumentError>());
          expect(e.toString(), contains(invalidSyncId));
          expect(e.toString(), contains('test operation'));
          expect(e.toString(), contains('UUID v4'));
        }
      }
    });

    test('rejection should be consistent across multiple validation attempts',
        () {
      // Property: Invalid sync identifiers should be consistently rejected
      // across multiple validation attempts (no flaky behavior)

      final invalidFormats = _generateInvalidSyncIdentifiers();
      const numAttempts = 100;

      for (final invalidSyncId in invalidFormats) {
        for (int attempt = 0; attempt < numAttempts; attempt++) {
          // Should consistently return false
          expect(
            SyncIdentifierGenerator.isValid(invalidSyncId),
            isFalse,
            reason:
                'Invalid sync identifier "$invalidSyncId" should be consistently rejected on attempt $attempt',
          );

          // Should consistently throw
          expect(
            () => SyncIdentifierService.validateOrThrow(invalidSyncId),
            throwsArgumentError,
            reason:
                'Invalid sync identifier "$invalidSyncId" should consistently throw on attempt $attempt',
          );

          // Should consistently return null
          expect(
            SyncIdentifierGenerator.validateAndNormalize(invalidSyncId),
            isNull,
            reason:
                'Invalid sync identifier "$invalidSyncId" should consistently return null on attempt $attempt',
          );
        }
      }
    });

    test('edge case invalid formats should be rejected', () {
      // Property: Edge cases and boundary conditions for invalid formats
      // should be consistently rejected

      final edgeCaseInvalids = _generateEdgeCaseInvalidSyncIdentifiers();

      for (final invalidSyncId in edgeCaseInvalids) {
        expect(
          SyncIdentifierGenerator.isValid(invalidSyncId),
          isFalse,
          reason:
              'Edge case invalid sync identifier should be rejected: "$invalidSyncId"',
        );

        expect(
          () => SyncIdentifierService.validateOrThrow(invalidSyncId),
          throwsArgumentError,
          reason:
              'Edge case invalid sync identifier should throw: "$invalidSyncId"',
        );
      }
    });

    test('valid sync identifiers should not be rejected', () {
      // Property: Valid sync identifiers should pass all validation methods
      // This ensures our validation is not overly strict

      const numValidTests = 100;

      for (int i = 0; i < numValidTests; i++) {
        final validSyncId = SyncIdentifierService.generateValidated();

        // Should pass all validation methods
        expect(
          SyncIdentifierGenerator.isValid(validSyncId),
          isTrue,
          reason:
              'Valid sync identifier should pass validation: "$validSyncId"',
        );

        expect(
          () => SyncIdentifierService.validateOrThrow(validSyncId),
          returnsNormally,
          reason: 'Valid sync identifier should not throw: "$validSyncId"',
        );

        expect(
          SyncIdentifierService.isStorageReady(validSyncId),
          isTrue,
          reason:
              'Valid sync identifier should be storage ready: "$validSyncId"',
        );

        expect(
          SyncIdentifierGenerator.validateAndNormalize(validSyncId),
          isNotNull,
          reason:
              'Valid sync identifier should normalize successfully: "$validSyncId"',
        );
      }
    });

    test('boundary between valid and invalid should be clear', () {
      // Property: There should be a clear boundary between valid and invalid formats
      // No sync identifier should be sometimes valid and sometimes invalid

      final testCases = [
        // Valid UUID v4 examples
        '550e8400-e29b-41d4-a716-446655440000',
        '6ba7b810-9dad-41d1-80b4-00c04fd430c8',
        '6ba7b811-9dad-41d1-80b4-00c04fd430c8',

        // Invalid examples (wrong version)
        '550e8400-e29b-11d4-a716-446655440000', // Version 1
        '550e8400-e29b-21d4-a716-446655440000', // Version 2
        '550e8400-e29b-31d4-a716-446655440000', // Version 3
        '550e8400-e29b-51d4-a716-446655440000', // Version 5

        // Invalid examples (wrong variant)
        '550e8400-e29b-41d4-0716-446655440000', // Wrong variant
        '550e8400-e29b-41d4-1716-446655440000', // Wrong variant
        '550e8400-e29b-41d4-c716-446655440000', // Wrong variant
        '550e8400-e29b-41d4-f716-446655440000', // Wrong variant
      ];

      for (final testCase in testCases) {
        final isValid = SyncIdentifierGenerator.isValid(testCase);

        // Test consistency across multiple calls
        for (int i = 0; i < 10; i++) {
          expect(
            SyncIdentifierGenerator.isValid(testCase),
            equals(isValid),
            reason: 'Validation result should be consistent for: "$testCase"',
          );
        }
      }
    });
  });
}

/// Generate various invalid sync identifier formats for testing
List<String> _generateInvalidSyncIdentifiers() {
  return [
    // Empty and null-like
    '',
    ' ',
    '   ',

    // Wrong length
    '123',
    '12345678-1234-1234-1234-123456789012345', // Too long
    '12345678-1234-1234-1234-12345678901', // Too short

    // Wrong format
    'not-a-uuid-at-all',
    'invalid-sync-identifier',
    '12345678123412341234123456789012', // No hyphens
    '12345678-1234-1234-1234', // Missing part

    // Wrong UUID version (not v4)
    '550e8400-e29b-11d4-a716-446655440000', // Version 1
    '550e8400-e29b-21d4-a716-446655440000', // Version 2
    '550e8400-e29b-31d4-a716-446655440000', // Version 3
    '550e8400-e29b-51d4-a716-446655440000', // Version 5

    // Wrong variant bits (should be 8, 9, a, or b in position 17)
    '550e8400-e29b-41d4-0716-446655440000', // Wrong variant (0)
    '550e8400-e29b-41d4-1716-446655440000', // Wrong variant (1)
    '550e8400-e29b-41d4-c716-446655440000', // Wrong variant (c)
    '550e8400-e29b-41d4-f716-446655440000', // Wrong variant (f)

    // Invalid characters
    '550g8400-e29b-41d4-a716-446655440000', // 'g' is not hex
    '550e8400-e29z-41d4-a716-446655440000', // 'z' is not hex
    '550e8400-e29b-41d4-a716-44665544000g', // 'g' at end

    // Special characters and symbols
    '550e8400@e29b-41d4-a716-446655440000',
    '550e8400-e29b-41d4-a716-446655440000!',
    '550e8400-e29b-41d4-a716-446655440000 ',
    ' 550e8400-e29b-41d4-a716-446655440000',
  ];
}

/// Generate edge case invalid sync identifier formats
List<String> _generateEdgeCaseInvalidSyncIdentifiers() {
  return [
    // Unicode and special characters
    '550e8400-e29b-41d4-a716-44665544000ü',
    '550e8400-e29b-41d4-a716-44665544000€',
    '550e8400-e29b-41d4-a716-44665544000😀',

    // Control characters
    '550e8400-e29b-41d4-a716-44665544000\n',
    '550e8400-e29b-41d4-a716-44665544000\t',
    '550e8400-e29b-41d4-a716-44665544000\r',

    // SQL injection attempts
    "'; DROP TABLE documents; --",
    '550e8400-e29b-41d4-a716-446655440000; DELETE FROM documents;',

    // Very long strings
    'a' * 1000,
    '550e8400-e29b-41d4-a716-446655440000' + 'x' * 500,

    // Null bytes and binary
    '550e8400-e29b-41d4-a716-446655440000\x00',
    '\x00\x01\x02\x03',

    // Mixed valid/invalid patterns
    '550e8400-e29b-41d4-a716-446655440000-extra',
    'prefix-550e8400-e29b-41d4-a716-446655440000',

    // Case variations that should still be invalid due to other issues
    '550E8400-E29B-11D4-A716-446655440000', // Version 1 in uppercase
    '550E8400-E29B-21D4-A716-446655440000', // Version 2 in uppercase
  ];
}
