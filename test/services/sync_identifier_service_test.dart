import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/sync_identifier_service.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';

void main() {
  group('SyncIdentifierService', () {
    group('validateOrThrow', () {
      test('should not throw for valid UUID', () {
        const validUuid = '550e8400-e29b-41d4-a716-446655440000';

        expect(() => SyncIdentifierService.validateOrThrow(validUuid),
            returnsNormally);
      });

      test('should throw ArgumentError for invalid UUID', () {
        const invalidUuid = 'not-a-uuid';

        expect(
          () => SyncIdentifierService.validateOrThrow(invalidUuid),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Invalid sync identifier format'),
          )),
        );
      });

      test('should include context in error message', () {
        const invalidUuid = 'not-a-uuid';
        const context = 'document creation';

        expect(
          () => SyncIdentifierService.validateOrThrow(invalidUuid,
              context: context),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('in $context'),
          )),
        );
      });

      test('should not throw for uppercase UUID', () {
        const upperUuid = '550E8400-E29B-41D4-A716-446655440000';

        expect(() => SyncIdentifierService.validateOrThrow(upperUuid),
            returnsNormally);
      });
    });

    group('generateValidated', () {
      test('should generate valid UUID', () {
        final syncId = SyncIdentifierService.generateValidated();

        expect(SyncIdentifierGenerator.isValid(syncId), isTrue);
      });

      test('should generate unique UUIDs', () {
        final syncIds =
            List.generate(10, (_) => SyncIdentifierService.generateValidated());
        final uniqueIds = syncIds.toSet();

        expect(uniqueIds.length, equals(syncIds.length));
      });

      test('should generate lowercase UUIDs', () {
        final syncId = SyncIdentifierService.generateValidated();

        expect(syncId, equals(syncId.toLowerCase()));
      });
    });

    group('isStorageReady', () {
      test('should return true for valid lowercase UUID', () {
        const validUuid = '550e8400-e29b-41d4-a716-446655440000';

        expect(SyncIdentifierService.isStorageReady(validUuid), isTrue);
      });

      test('should return false for valid uppercase UUID', () {
        const upperUuid = '550E8400-E29B-41D4-A716-446655440000';

        expect(SyncIdentifierService.isStorageReady(upperUuid), isFalse);
      });

      test('should return false for invalid UUID', () {
        const invalidUuid = 'not-a-uuid';

        expect(SyncIdentifierService.isStorageReady(invalidUuid), isFalse);
      });

      test('should return true for generated UUIDs', () {
        final syncId = SyncIdentifierService.generateValidated();

        expect(SyncIdentifierService.isStorageReady(syncId), isTrue);
      });
    });

    group('prepareForStorage', () {
      test('should return normalized UUID for valid input', () {
        const upperUuid = '550E8400-E29B-41D4-A716-446655440000';
        const expectedLower = '550e8400-e29b-41d4-a716-446655440000';

        final result = SyncIdentifierService.prepareForStorage(upperUuid);
        expect(result, equals(expectedLower));
      });

      test('should throw ArgumentError for invalid UUID', () {
        const invalidUuid = 'not-a-uuid';

        expect(
          () => SyncIdentifierService.prepareForStorage(invalidUuid),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Invalid sync identifier format'),
          )),
        );
      });

      test('should include context in error message', () {
        const invalidUuid = 'not-a-uuid';
        const context = 'document update';

        expect(
          () => SyncIdentifierService.prepareForStorage(invalidUuid,
              context: context),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('in $context'),
          )),
        );
      });

      test('should return same value for already normalized UUID', () {
        const normalizedUuid = '550e8400-e29b-41d4-a716-446655440000';

        final result = SyncIdentifierService.prepareForStorage(normalizedUuid);
        expect(result, equals(normalizedUuid));
      });
    });

    group('validateCollection', () {
      test('should return valid result for empty collection', () {
        final result = SyncIdentifierService.validateCollection([]);

        expect(result.isValid, isTrue);
        expect(result.totalCount, equals(0));
        expect(result.validCount, equals(0));
        expect(result.invalidIds, isEmpty);
        expect(result.duplicateIds, isEmpty);
      });

      test('should return valid result for collection of valid unique UUIDs',
          () {
        final validUuids = [
          '550e8400-e29b-41d4-a716-446655440000',
          '6ba7b810-9dad-41d1-80b4-00c04fd430c8',
          '6ba7b811-9dad-41d1-90b4-00c04fd430c8',
        ];

        final result = SyncIdentifierService.validateCollection(validUuids);

        expect(result.isValid, isTrue);
        expect(result.totalCount, equals(3));
        expect(result.validCount, equals(3));
        expect(result.invalidIds, isEmpty);
        expect(result.duplicateIds, isEmpty);
      });

      test('should detect invalid UUIDs', () {
        final mixedUuids = [
          '550e8400-e29b-41d4-a716-446655440000', // valid
          'not-a-uuid', // invalid
          '6ba7b810-9dad-41d1-80b4-00c04fd430c8', // valid
          'also-invalid', // invalid
        ];

        final result = SyncIdentifierService.validateCollection(mixedUuids);

        expect(result.isValid, isFalse);
        expect(result.totalCount, equals(4));
        expect(result.validCount, equals(2));
        expect(result.invalidIds, equals(['not-a-uuid', 'also-invalid']));
        expect(result.duplicateIds, isEmpty);
      });

      test('should detect duplicate UUIDs', () {
        final duplicateUuids = [
          '550e8400-e29b-41d4-a716-446655440000',
          '6ba7b810-9dad-41d1-80b4-00c04fd430c8',
          '550e8400-e29b-41d4-a716-446655440000', // duplicate
        ];

        final result = SyncIdentifierService.validateCollection(duplicateUuids);

        expect(result.isValid, isFalse);
        expect(result.totalCount, equals(3));
        expect(result.validCount, equals(2));
        expect(result.invalidIds, isEmpty);
        expect(result.duplicateIds,
            equals(['550e8400-e29b-41d4-a716-446655440000']));
      });

      test('should detect case-insensitive duplicates', () {
        final duplicateUuids = [
          '550e8400-e29b-41d4-a716-446655440000',
          '550E8400-E29B-41D4-A716-446655440000', // same UUID, different case
        ];

        final result = SyncIdentifierService.validateCollection(duplicateUuids);

        expect(result.isValid, isFalse);
        expect(result.totalCount, equals(2));
        expect(result.validCount, equals(1));
        expect(result.invalidIds, isEmpty);
        expect(result.duplicateIds,
            equals(['550E8400-E29B-41D4-A716-446655440000']));
      });

      test('should detect both invalid and duplicate UUIDs', () {
        final problematicUuids = [
          '550e8400-e29b-41d4-a716-446655440000', // valid
          'not-a-uuid', // invalid
          '550e8400-e29b-41d4-a716-446655440000', // duplicate
          'also-invalid', // invalid
        ];

        final result =
            SyncIdentifierService.validateCollection(problematicUuids);

        expect(result.isValid, isFalse);
        expect(result.totalCount, equals(4));
        expect(result.validCount, equals(1));
        expect(result.invalidIds, equals(['not-a-uuid', 'also-invalid']));
        expect(result.duplicateIds,
            equals(['550e8400-e29b-41d4-a716-446655440000']));
      });
    });
  });

  group('ValidationResult', () {
    test('should provide correct summary for valid collection', () {
      const result = ValidationResult(isValid: true, isVal        invalidIds: [],
        duplicateIds: [],
        totalCount: 3,
        validCount: 3,
      );

      expect(result.summary,
          equals('All 3 sync identifiers are valid and unique'));
    });

    test('should provide correct summary for invalid collection', () {
      const result = ValidationResult(isValid: true, isVal        invalidIds: ['invalid1', 'invalid2'],
        duplicateIds: ['duplicate1'],
        totalCount: 5,
        validCount: 2,
      );

      expect(result.summary, contains('Found issues in 5 sync identifiers'));
      expect(result.summary, contains('2 invalid format(s)'));
      expect(result.summary, contains('1 duplicate(s)'));
      expect(result.summary, contains('2 are valid'));
    });

    test('should provide correct summary for only invalid IDs', () {
      const result = ValidationResult(isValid: true, isVal        invalidIds: ['invalid1'],
        duplicateIds: [],
        totalCount: 2,
        validCount: 1,
      );

      expect(result.summary, contains('1 invalid format(s)'));
      expect(result.summary, isNot(contains('duplicate')));
    });

    test('should provide correct summary for only duplicate IDs', () {
      const result = ValidationResult(isValid: true, isVal        invalidIds: [],
        duplicateIds: ['duplicate1'],
        totalCount: 2,
        validCount: 1,
      );

      expect(result.summary, contains('1 duplicate(s)'));
      expect(result.summary, isNot(contains('invalid format')));
    });

    test('toString should return summary', () {
      const result = ValidationResult(isValid: true, isVal        invalidIds: [],
        duplicateIds: [],
        totalCount: 1,
        validCount: 1,
      );

      expect(result.toString(), equals(result.summary));
    });
  });
}
