import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/sync_identifier_service.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';

/// Test suite for sync identifier validation and error handling
///
/// **Feature: sync-identifier-refactor, Task 11: Validation and Error Handling**
///
/// This test suite verifies that:
/// 1. Sync identifier validation works correctly throughout the system
/// 2. Error handling for invalid sync identifiers is consistent
/// 3. Validation for duplicate sync identifiers prevents data corruption
/// 4. Error messages reference sync identifiers appropriately
void main() {
  group('Sync Identifier Validation', () {
    test('should validate correct UUID v4 format', () {
      final validSyncId = SyncIdentifierService.generateValidated();
      expect(SyncIdentifierGenerator.isValid(validSyncId), isTrue);

      // Should not throw
      expect(
        () => SyncIdentifierService.validateOrThrow(validSyncId),
        returnsNormally,
      );
    });

    test('should reject invalid sync identifier formats', () {
      final invalidFormats = [
        '',
        'invalid-uuid',
        '12345',
        'not-a-uuid-at-all',
        '12345678-1234-1234-1234-123456789012', // Not v4
        '550e8400-e29b-11d4-a716-446655440000', // Not v4 (version 1)
      ];

      for (final invalid in invalidFormats) {
        expect(
          SyncIdentifierGenerator.isValid(invalid),
          isFalse,
          reason: 'Should reject invalid format: $invalid',
        );

        expect(
          () => SyncIdentifierService.validateOrThrow(invalid),
          throwsArgumentError,
          reason: 'Should throw ArgumentError for invalid format: $invalid',
        );
      }
    });

    test('should provide context in error messages', () {
      const invalidSyncId = 'invalid-sync-id';
      const context = 'test operation';

      try {
        SyncIdentifierService.validateOrThrow(invalidSyncId, context: context);
        fail('Should have thrown ArgumentError');
      } catch (e) {
        expect(e, isA<ArgumentError>());
        expect(e.toString(), contains(invalidSyncId));
        expect(e.toString(), contains(context));
        expect(e.toString(), contains('UUID v4'));
      }
    });

    test('should normalize sync identifiers to lowercase', () {
      const upperCaseSyncId = '550E8400-E29B-41D4-A716-446655440000';
      final normalized = SyncIdentifierGenerator.normalize(upperCaseSyncId);

      expect(normalized, equals('550e8400-e29b-41d4-a716-446655440000'));
      expect(SyncIdentifierGenerator.isValid(normalized), isTrue);
    });

    test('should validate and normalize in one operation', () {
      const upperCaseSyncId = '550E8400-E29B-41D4-A716-446655440000';
      final result =
          SyncIdentifierGenerator.validateAndNormalize(upperCaseSyncId);

      expect(result, isNotNull);
      expect(result, equals('550e8400-e29b-41d4-a716-446655440000'));
    });

    test(
        'should return null for invalid sync identifier in validateAndNormalize',
        () {
      const invalidSyncId = 'invalid-uuid';
      final result =
          SyncIdentifierGenerator.validateAndNormalize(invalidSyncId);

      expect(result, isNull);
    });

    test('should check if sync identifier is storage ready', () {
      final validLowercase = SyncIdentifierService.generateValidated();
      expect(SyncIdentifierService.isStorageReady(validLowercase), isTrue);

      const validUppercase = '550E8400-E29B-41D4-A716-446655440000';
      expect(SyncIdentifierService.isStorageReady(validUppercase), isFalse);

      const invalid = 'invalid-uuid';
      expect(SyncIdentifierService.isStorageReady(invalid), isFalse);
    });

    test('should prepare sync identifier for storage', () {
      const upperCaseSyncId = '550E8400-E29B-41D4-A716-446655440000';
      final prepared = SyncIdentifierService.prepareForStorage(upperCaseSyncId);

      expect(prepared, equals('550e8400-e29b-41d4-a716-446655440000'));
      expect(SyncIdentifierService.isStorageReady(prepared), isTrue);
    });

    test('should throw when preparing invalid sync identifier for storage', () {
      const invalidSyncId = 'invalid-uuid';

      expect(
        () => SyncIdentifierService.prepareForStorage(invalidSyncId),
        throwsArgumentError,
      );
    });
  });

  group('Sync Identifier Collection Validation', () {
    test('should validate collection of valid sync identifiers', () {
      final syncIds =
          List.generate(5, (_) => SyncIdentifierService.generateValidated());
      final result = SyncIdentifierService.validateCollection(syncIds);

      expect(result.isValid, isTrue);
      expect(result.invalidIds, isEmpty);
      expect(result.duplicateIds, isEmpty);
      expect(result.validCount, equals(5));
      expect(result.totalCount, equals(5));
    });

    test('should detect invalid sync identifiers in collection', () {
      final syncIds = [
        SyncIdentifierService.generateValidated(),
        'invalid-uuid',
        SyncIdentifierService.generateValidated(),
        'another-invalid',
      ];

      final result = SyncIdentifierService.validateCollection(syncIds);

      expect(result.isValid, isFalse);
      expect(result.invalidIds.length, equals(2));
      expect(result.invalidIds, contains('invalid-uuid'));
      expect(result.invalidIds, contains('another-invalid'));
      expect(result.validCount, equals(2));
      expect(result.totalCount, equals(4));
    });

    test('should detect duplicate sync identifiers in collection', () {
      final syncId1 = SyncIdentifierService.generateValidated();
      final syncId2 = SyncIdentifierService.generateValidated();

      final syncIds = [
        syncId1,
        syncId2,
        syncId1, // Duplicate
        syncId2, // Duplicate
      ];

      final result = SyncIdentifierService.validateCollection(syncIds);

      expect(result.isValid, isFalse);
      expect(result.duplicateIds.length, equals(2));
      expect(result.validCount, equals(2)); // Only unique valid ones
      expect(result.totalCount, equals(4));
    });

    test('should detect both invalid and duplicate sync identifiers', () {
      final syncId = SyncIdentifierService.generateValidated();

      final syncIds = [
        syncId,
        'invalid-uuid',
        syncId, // Duplicate
        'another-invalid',
      ];

      final result = SyncIdentifierService.validateCollection(syncIds);

      expect(result.isValid, isFalse);
      expect(result.invalidIds.length, equals(2));
      expect(result.duplicateIds.length, equals(1));
      expect(result.validCount, equals(1)); // Only one unique valid
      expect(result.totalCount, equals(4));
    });

    test('should provide human-readable summary', () {
      final syncIds = [
        SyncIdentifierService.generateValidated(),
        'invalid-uuid',
        SyncIdentifierService.generateValidated(),
      ];

      final result = SyncIdentifierService.validateCollection(syncIds);
      final summary = result.summary;

      expect(summary, contains('invalid format'));
      expect(summary, contains('2 are valid'));
    });

    test('should handle empty collection', () {
      final result = SyncIdentifierService.validateCollection([]);

      expect(result.isValid, isTrue);
      expect(result.totalCount, equals(0));
      expect(result.validCount, equals(0));
    });

    test('should handle case-insensitive duplicate detection', () {
      const syncId = '550e8400-e29b-41d4-a716-446655440000';
      const syncIdUpper = '550E8400-E29B-41D4-A716-446655440000';

      final syncIds = [syncId, syncIdUpper];
      final result = SyncIdentifierService.validateCollection(syncIds);

      expect(result.isValid, isFalse);
      expect(result.duplicateIds.length, equals(1));
      expect(result.validCount, equals(1)); // Only one unique
    });
  });

  group('Generated Sync Identifier Validation', () {
    test('should generate valid sync identifiers', () {
      for (int i = 0; i < 100; i++) {
        final syncId = SyncIdentifierService.generateValidated();
        expect(SyncIdentifierGenerator.isValid(syncId), isTrue);
      }
    });

    test('should generate unique sync identifiers', () {
      final syncIds = <String>{};
      for (int i = 0; i < 1000; i++) {
        final syncId = SyncIdentifierService.generateValidated();
        expect(syncIds.contains(syncId), isFalse,
            reason: 'Generated duplicate sync identifier: $syncId');
        syncIds.add(syncId);
      }
    });

    test('should generate validated sync identifiers', () {
      final syncId = SyncIdentifierService.generateValidated();
      expect(SyncIdentifierGenerator.isValid(syncId), isTrue);
      expect(SyncIdentifierService.isStorageReady(syncId), isTrue);
    });
  });
}
