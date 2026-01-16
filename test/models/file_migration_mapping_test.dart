import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/file_migration_mapping.dart';

void main() {
  group('FileMigrationMapping Model Tests', () {
    const validUserSub = '12345678-1234-1234-1234-123456789012';
    const legacyPath = 'protected/username/documents/sync_123/test.pdf';
    const newPath =
        'private/$validUserSub/documents/sync_123/1640995200000-test.pdf';
    const syncId = 'sync_123';
    const fileName = 'test.pdf';

    group('Creation', () {
      test('should create FileMigrationMapping with required fields', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: newPath,
          userSub: validUserSub,
        );

        expect(mapping.legacyPath, equals(legacyPath));
        expect(mapping.newPath, equals(newPath));
        expect(mapping.userSub, equals(validUserSub));
        expect(mapping.verified, isFalse);
        expect(mapping.id, isNotEmpty);
        expect(mapping.migratedAt, isNotNull);
      });

      test('should create FileMigrationMapping with optional fields', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: newPath,
          userSub: validUserSub,
          syncId: syncId,
          fileName: fileName,
          verified: true,
        );

        expect(mapping.syncId, equals(syncId));
        expect(mapping.fileName, equals(fileName));
        expect(mapping.verified, isTrue);
      });
    });

    group('Status Management', () {
      test('should mark as verified', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: newPath,
          userSub: validUserSub,
        );

        final verifiedMapping = mapping.markAsVerified();

        expect(verifiedMapping.verified, isTrue);
        expect(verifiedMapping.errorMessage, isNull);
        expect(verifiedMapping.isSuccessful, isTrue);
        expect(verifiedMapping.status, equals('verified'));
      });

      test('should mark as failed with error message', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: newPath,
          userSub: validUserSub,
        );

        const errorMessage = 'Migration failed: File not found';
        final failedMapping = mapping.markAsFailed(errorMessage);

        expect(failedMapping.verified, isFalse);
        expect(failedMapping.errorMessage, equals(errorMessage));
        expect(failedMapping.isFailed, isTrue);
        expect(failedMapping.status, equals('failed'));
      });

      test('should have pending status by default', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: newPath,
          userSub: validUserSub,
        );

        expect(mapping.status, equals('pending'));
        expect(mapping.isSuccessful, isFalse);
        expect(mapping.isFailed, isFalse);
      });
    });

    group('Path Extraction', () {
      test('should extract sync ID from legacy path', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: 'protected/username/documents/sync_abc123/file.pdf',
          newPath: newPath,
          userSub: validUserSub,
        );

        final extractedSyncId = mapping.extractSyncIdFromLegacyPath();
        expect(extractedSyncId, equals('sync_abc123'));
      });

      test('should return null for invalid legacy path format', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: 'invalid/path/format',
          newPath: newPath,
          userSub: validUserSub,
        );

        final extractedSyncId = mapping.extractSyncIdFromLegacyPath();
        expect(extractedSyncId, isNull);
      });

      test('should extract file name from legacy path', () {
        final mapping = FileMigrationMapping.create(
          legacyPath:
              'protected/username/documents/sync_123/1640995200000-document.pdf',
          newPath: newPath,
          userSub: validUserSub,
        );

        final extractedFileName = mapping.extractFileNameFromLegacyPath();
        expect(extractedFileName, equals('document.pdf'));
      });

      test('should extract file name without timestamp', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: 'protected/username/documents/sync_123/document.pdf',
          newPath: newPath,
          userSub: validUserSub,
        );

        final extractedFileName = mapping.extractFileNameFromLegacyPath();
        expect(extractedFileName, equals('document.pdf'));
      });
    });

    group('Validation', () {
      test('should validate correct mapping', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: newPath,
          userSub: validUserSub,
        );

        expect(mapping.validate(), isTrue);
      });

      test('should fail validation for empty legacy path', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: '',
          newPath: newPath,
          userSub: validUserSub,
        );

        expect(mapping.validate(), isFalse);
      });

      test('should fail validation for empty new path', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: '',
          userSub: validUserSub,
        );

        expect(mapping.validate(), isFalse);
      });

      test('should fail validation for empty user sub', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: newPath,
          userSub: '',
        );

        expect(mapping.validate(), isFalse);
      });

      test('should fail validation for non-private new path', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: 'public/$validUserSub/documents/sync_123/test.pdf',
          userSub: validUserSub,
        );

        expect(mapping.validate(), isFalse);
      });

      test('should fail validation when new path does not contain user sub',
          () {
        final mapping = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: 'private/different-user/documents/sync_123/test.pdf',
          userSub: validUserSub,
        );

        expect(mapping.validate(), isFalse);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: newPath,
          userSub: validUserSub,
          syncId: syncId,
          fileName: fileName,
        );

        final json = mapping.toJson();

        expect(json['legacyPath'], equals(legacyPath));
        expect(json['newPath'], equals(newPath));
        expect(json['userSub'], equals(validUserSub));
        expect(json['syncId'], equals(syncId));
        expect(json['fileName'], equals(fileName));
        expect(json['verified'], isFalse);
        expect(json['id'], isNotEmpty);
        expect(json['migratedAt'], isNotNull);
      });

      test('should deserialize from JSON correctly', () {
        final originalMapping = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: newPath,
          userSub: validUserSub,
          syncId: syncId,
          fileName: fileName,
        );

        final json = originalMapping.toJson();
        final deserializedMapping = FileMigrationMapping.fromJson(json);

        expect(
            deserializedMapping.legacyPath, equals(originalMapping.legacyPath));
        expect(deserializedMapping.newPath, equals(originalMapping.newPath));
        expect(deserializedMapping.userSub, equals(originalMapping.userSub));
        expect(deserializedMapping.syncId, equals(originalMapping.syncId));
        expect(deserializedMapping.fileName, equals(originalMapping.fileName));
        expect(deserializedMapping.verified, equals(originalMapping.verified));
      });
    });

    group('Database Serialization', () {
      test('should convert to database map correctly', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: newPath,
          userSub: validUserSub,
          syncId: syncId,
          fileName: fileName,
          verified: true,
        );

        final dbMap = mapping.toDatabaseMap();

        expect(dbMap['legacy_path'], equals(legacyPath));
        expect(dbMap['new_path'], equals(newPath));
        expect(dbMap['user_sub'], equals(validUserSub));
        expect(dbMap['sync_id'], equals(syncId));
        expect(dbMap['file_name'], equals(fileName));
        expect(dbMap['verified'], equals(1)); // Boolean as integer
        expect(dbMap['id'], isNotEmpty);
        expect(dbMap['migrated_at'], isNotNull);
      });

      test('should create from database map correctly', () {
        final dbMap = {
          'id': 'test_id',
          'legacy_path': legacyPath,
          'new_path': newPath,
          'user_sub': validUserSub,
          'sync_id': syncId,
          'file_name': fileName,
          'verified': 1,
          'migrated_at': '2024-01-01T10:00:00.000Z',
          'error_message': null,
        };

        final mapping = FileMigrationMapping.fromDatabaseMap(dbMap);

        expect(mapping.id, equals('test_id'));
        expect(mapping.legacyPath, equals(legacyPath));
        expect(mapping.newPath, equals(newPath));
        expect(mapping.userSub, equals(validUserSub));
        expect(mapping.syncId, equals(syncId));
        expect(mapping.fileName, equals(fileName));
        expect(mapping.verified, isTrue);
        expect(mapping.errorMessage, isNull);
      });
    });

    group('Copy With', () {
      test('should create copy with updated properties', () {
        final originalMapping = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: newPath,
          userSub: validUserSub,
        );

        final copiedMapping = originalMapping.copyWith(
          verified: true,
          syncId: 'new_sync_id',
          errorMessage: 'test error',
        );

        expect(copiedMapping.legacyPath, equals(originalMapping.legacyPath));
        expect(copiedMapping.newPath, equals(originalMapping.newPath));
        expect(copiedMapping.userSub, equals(originalMapping.userSub));
        expect(copiedMapping.verified, isTrue);
        expect(copiedMapping.syncId, equals('new_sync_id'));
        expect(copiedMapping.errorMessage, equals('test error'));
      });
    });

    group('Equality and Hashing', () {
      test('should be equal when core properties match', () {
        final mapping1 = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: newPath,
          userSub: validUserSub,
        );

        final mapping2 = FileMigrationMapping(
          id: mapping1.id,
          legacyPath: legacyPath,
          newPath: newPath,
          userSub: validUserSub,
          migratedAt: mapping1.migratedAt,
          verified: false,
        );

        expect(mapping1, equals(mapping2));
        expect(mapping1.hashCode, equals(mapping2.hashCode));
      });

      test('should not be equal when properties differ', () {
        final mapping1 = FileMigrationMapping.create(
          legacyPath: legacyPath,
          newPath: newPath,
          userSub: validUserSub,
        );

        final mapping2 = FileMigrationMapping.create(
          legacyPath: 'different/legacy/path',
          newPath: newPath,
          userSub: validUserSub,
        );

        expect(mapping1, isNot(equals(mapping2)));
      });
    });
  });
}
