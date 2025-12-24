import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';

import '../../lib/services/sync_identifier_service.dart';
void main() {
  group('SyncIdentifierGenerator', () {
    group('generate', () {
      test('should generate valid UUID v4 format', () {
        final syncId = SyncIdentifierService.generateValidated();

        expect(syncId, isNotEmpty);
        expect(SyncIdentifierGenerator.isValid(syncId), isTrue);
        expect(
            syncId,
            matches(RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
      });

      test('should generate lowercase UUIDs', () {
        final syncId = SyncIdentifierService.generateValidated();

        expect(syncId, equals(syncId.toLowerCase()));
      });

      test('should generate unique identifiers', () {
        final syncIds =
            List.generate(100, (_) => SyncIdentifierService.generateValidated());
        final uniqueIds = syncIds.toSet();

        expect(uniqueIds.length, equals(syncIds.length));
      });

      test('should generate UUID v4 (version 4)', () {
        final syncId = SyncIdentifierService.generateValidated();

        // Check that the version field (13th character) is '4'
        expect(syncId[14], equals('4'));
      });

      test('should generate UUID with correct variant bits', () {
        final syncId = SyncIdentifierService.generateValidated();

        // Check that the variant field (17th character) is 8, 9, a, or b
        final variantChar = syncId[19];
        expect(['8', '9', 'a', 'b'], contains(variantChar));
      });
    });

    group('isValid', () {
      test('should return true for valid UUID v4', () {
        const validUuid = '550e8400-e29b-41d4-a716-446655440000';
        expect(SyncIdentifierGenerator.isValid(validUuid), isTrue);
      });

      test('should return true for uppercase UUID v4', () {
        const validUuid = '550E8400-E29B-41D4-A716-446655440000';
        expect(SyncIdentifierGenerator.isValid(validUuid), isTrue);
      });

      test('should return false for empty string', () {
        expect(SyncIdentifierGenerator.isValid(''), isFalse);
      });

      test('should return false for invalid format', () {
        const invalidFormats = [
          'not-a-uuid',
          '550e8400-e29b-41d4-a716',
          '550e8400-e29b-41d4-a716-446655440000-extra',
          '550e8400e29b41d4a716446655440000', // no hyphens
          '550e8400-e29b-31d4-a716-446655440000', // wrong version (3 instead of 4)
          '550e8400-e29b-41d4-c716-446655440000', // wrong variant (c instead of 8,9,a,b)
          'ggge8400-e29b-41d4-a716-446655440000', // invalid hex characters
        ];

        for (final invalid in invalidFormats) {
          expect(SyncIdentifierGenerator.isValid(invalid), isFalse,
              reason: 'Should be inval        }
      });

      test('should return true for generated UUIDs', () {
        for (int i = 0; i < 10; i++) {
          final syncId = SyncIdentifierService.generateValidated();
          expect(SyncIdentifierGenerator.isValid(syncId), isTrue);
        }
      });
    });

    group('normalize', () {
      test('should convert to lowercase', () {
        const upperUuid = '550E8400-E29B-41D4-A716-446655440000';
        const expectedLower = '550e8400-e29b-41d4-a716-446655440000';

        expect(SyncIdentifierGenerator.normalize(upperUuid),
            equals(expectedLower));
      });

      test('should not change already lowercase UUID', () {
        const lowerUuid = '550e8400-e29b-41d4-a716-446655440000';

        expect(SyncIdentifierGenerator.normalize(lowerUuid), equals(lowerUuid));
      });

      test('should handle mixed case', () {
        const mixedUuid = '550E8400-e29b-41D4-A716-446655440000';
        const expectedLower = '550e8400-e29b-41d4-a716-446655440000';

        expect(SyncIdentifierGenerator.normalize(mixedUuid),
            equals(expectedLower));
      });
    });

    group('validateAndNormalize', () {
      test('should return normalized UUID for valid input', () {
        const upperUuid = '550E8400-E29B-41D4-A716-446655440000';
        const expectedLower = '550e8400-e29b-41d4-a716-446655440000';

        expect(SyncIdentifierGenerator.validateAndNormalize(upperUuid),
            equals(expectedLower));
      });

      test('should return null for invalid input', () {
        const invalidUuid = 'not-a-uuid';

        expect(
            SyncIdentifierGenerator.validateAndNormalize(invalidUuid), isNull);
      });

      test('should return null for empty string', () {
        expect(SyncIdentifierGenerator.validateAndNormalize(''), isNull);
      });

      test('should work with generated UUIDs', () {
        final generated = SyncIdentifierService.generateValidated();
        final result = SyncIdentifierGenerator.validateAndNormalize(generated);

        expect(result, equals(generated));
        expect(result, isNotNull);
      });
    });
  });
}
