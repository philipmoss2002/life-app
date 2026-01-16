import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/file_path.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;

void main() {
  group('FilePath Model Tests', () {
    const validUserSub = '12345678-1234-1234-1234-123456789012';
    const validSyncId = 'sync_test_123';
    const validFileName = 'test_document.pdf';

    group('FilePath Creation', () {
      test('should create FilePath with valid inputs', () {
        final filePath = FilePath.create(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: validFileName,
        );

        expect(filePath.userSub, equals(validUserSub));
        expect(filePath.syncId, equals(validSyncId));
        expect(filePath.fileName, equals(validFileName));
        expect(filePath.isLegacy, isFalse);
        expect(filePath.timestamp, isNotNull);
      });

      test('should create FilePath with custom timestamp', () {
        const customTimestamp = 1640995200000;
        final filePath = FilePath.create(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: validFileName,
          timestamp: customTimestamp,
        );

        expect(filePath.timestamp, equals(customTimestamp));
      });

      test('should create legacy FilePath', () {
        final filePath = FilePath.create(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: validFileName,
          isLegacy: true,
        );

        expect(filePath.isLegacy, isTrue);
      });

      test('should throw exception for invalid User Pool sub', () {
        expect(
          () => FilePath.create(
            userSub: 'invalid-sub',
            syncId: validSyncId,
            fileName: validFileName,
          ),
          throwsA(isA<FilePathValidationException>()),
        );
      });

      test('should throw exception for empty sync ID', () {
        expect(
          () => FilePath.create(
            userSub: validUserSub,
            syncId: '',
            fileName: validFileName,
          ),
          throwsA(isA<FilePathValidationException>()),
        );
      });

      test('should throw exception for empty file name', () {
        expect(
          () => FilePath.create(
            userSub: validUserSub,
            syncId: validSyncId,
            fileName: '',
          ),
          throwsA(isA<FilePathValidationException>()),
        );
      });
    });

    group('S3 Key Generation', () {
      test('should generate correct S3 key format', () {
        final filePath = FilePath.create(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: validFileName,
          timestamp: 1640995200000,
        );

        final expectedS3Key =
            'private/$validUserSub/documents/$validSyncId/1640995200000-test_document.pdf';
        expect(filePath.s3Key, equals(expectedS3Key));
      });

      test('should generate S3 key without timestamp', () {
        final filePath = FilePath.create(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: validFileName,
        );

        final expectedS3Key =
            'private/$validUserSub/documents/$validSyncId/test_document.pdf';
        expect(filePath.s3KeyWithoutTimestamp, equals(expectedS3Key));
      });

      test('should generate correct directory path', () {
        final filePath = FilePath.create(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: validFileName,
        );

        final expectedDirectoryPath =
            'private/$validUserSub/documents/$validSyncId';
        expect(filePath.directoryPath, equals(expectedDirectoryPath));
      });

      test('should sanitize file names with special characters', () {
        final filePath = FilePath.create(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: 'test file with spaces & symbols!.pdf',
          timestamp: 1640995200000,
        );

        expect(
            filePath.s3Key, contains('test_file_with_spaces___symbols_.pdf'));
      });
    });

    group('S3 Key Parsing', () {
      test('should parse valid S3 key correctly', () {
        const s3Key =
            'private/$validUserSub/documents/$validSyncId/1640995200000-test_document.pdf';

        final filePath = FilePath.fromS3Key(s3Key);

        expect(filePath.userSub, equals(validUserSub));
        expect(filePath.syncId, equals(validSyncId));
        expect(filePath.fileName, equals('test_document.pdf'));
        expect(filePath.timestamp, equals(1640995200000));
        expect(filePath.fullPath, equals(s3Key));
      });

      test('should parse S3 key without timestamp', () {
        const s3Key =
            'private/$validUserSub/documents/$validSyncId/test_document.pdf';

        final filePath = FilePath.fromS3Key(s3Key);

        expect(filePath.userSub, equals(validUserSub));
        expect(filePath.syncId, equals(validSyncId));
        expect(filePath.fileName, equals('test_document.pdf'));
        expect(filePath.timestamp, isNull);
      });

      test('should throw exception for invalid S3 key format', () {
        expect(
          () => FilePath.fromS3Key('invalid/path'),
          throwsA(isA<FilePathValidationException>()),
        );
      });

      test('should throw exception for non-private S3 key', () {
        expect(
          () => FilePath.fromS3Key(
              'public/$validUserSub/documents/$validSyncId/test.pdf'),
          throwsA(isA<FilePathValidationException>()),
        );
      });
    });

    group('Validation', () {
      test('should validate correct FilePath', () {
        final filePath = FilePath.create(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: validFileName,
        );

        expect(filePath.validate(), isTrue);
        expect(filePath.isValidUserPoolSub, isTrue);
      });

      test('should detect invalid User Pool sub format', () {
        final filePath = FilePath(
          userSub: 'invalid-sub',
          syncId: validSyncId,
          fileName: validFileName,
          fullPath: 'private/invalid-sub/documents/$validSyncId/test.pdf',
          createdAt: amplify_core.TemporalDateTime.now(),
        );

        expect(filePath.validate(), isFalse);
        expect(filePath.isValidUserPoolSub, isFalse);
      });

      test('should detect empty sync ID', () {
        final filePath = FilePath(
          userSub: validUserSub,
          syncId: '',
          fileName: validFileName,
          fullPath: 'private/$validUserSub/documents//test.pdf',
          createdAt: amplify_core.TemporalDateTime.now(),
        );

        expect(filePath.validate(), isFalse);
      });

      test('should detect empty file name', () {
        final filePath = FilePath(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: '',
          fullPath: 'private/$validUserSub/documents/$validSyncId/',
          createdAt: amplify_core.TemporalDateTime.now(),
        );

        expect(filePath.validate(), isFalse);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final filePath = FilePath.create(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: validFileName,
          timestamp: 1640995200000,
        );

        final json = filePath.toJson();

        expect(json['userSub'], equals(validUserSub));
        expect(json['syncId'], equals(validSyncId));
        expect(json['fileName'], equals(validFileName));
        expect(json['timestamp'], equals(1640995200000));
        expect(json['isLegacy'], isFalse);
        expect(json['fullPath'], isNotNull);
        expect(json['createdAt'], isNotNull);
      });

      test('should deserialize from JSON correctly', () {
        final originalFilePath = FilePath.create(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: validFileName,
          timestamp: 1640995200000,
        );

        final json = originalFilePath.toJson();
        final deserializedFilePath = FilePath.fromJson(json);

        expect(deserializedFilePath.userSub, equals(originalFilePath.userSub));
        expect(deserializedFilePath.syncId, equals(originalFilePath.syncId));
        expect(
            deserializedFilePath.fileName, equals(originalFilePath.fileName));
        expect(
            deserializedFilePath.timestamp, equals(originalFilePath.timestamp));
        expect(
            deserializedFilePath.isLegacy, equals(originalFilePath.isLegacy));
      });
    });

    group('Equality and Hashing', () {
      test('should be equal when all properties match', () {
        final filePath1 = FilePath.create(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: validFileName,
          timestamp: 1640995200000,
        );

        final filePath2 = FilePath.create(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: validFileName,
          timestamp: 1640995200000,
        );

        expect(filePath1, equals(filePath2));
        expect(filePath1.hashCode, equals(filePath2.hashCode));
      });

      test('should not be equal when properties differ', () {
        final filePath1 = FilePath.create(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: validFileName,
        );

        final filePath2 = FilePath.create(
          userSub: validUserSub,
          syncId: 'different_sync_id',
          fileName: validFileName,
        );

        expect(filePath1, isNot(equals(filePath2)));
      });
    });

    group('Copy With', () {
      test('should create copy with updated properties', () {
        final originalFilePath = FilePath.create(
          userSub: validUserSub,
          syncId: validSyncId,
          fileName: validFileName,
        );

        final copiedFilePath = originalFilePath.copyWith(
          syncId: 'new_sync_id',
          isLegacy: true,
        );

        expect(copiedFilePath.userSub, equals(originalFilePath.userSub));
        expect(copiedFilePath.syncId, equals('new_sync_id'));
        expect(copiedFilePath.fileName, equals(originalFilePath.fileName));
        expect(copiedFilePath.isLegacy, isTrue);
      });
    });
  });
}
