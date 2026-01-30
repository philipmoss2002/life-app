import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/file_service.dart';

void main() {
  group('FileService', () {
    late FileService fileService;

    setUp(() {
      fileService = FileService();
    });

    test('should be a singleton', () {
      final instance1 = FileService();
      final instance2 = FileService();
      expect(instance1, same(instance2));
    });

    group('Custom Exceptions', () {
      test('FileUploadException should create exception with message', () {
        final exception = FileUploadException('Upload failed');
        expect(exception.message, equals('Upload failed'));
        expect(
            exception.toString(), equals('FileUploadException: Upload failed'));
      });

      test('FileDownloadException should create exception with message', () {
        final exception = FileDownloadException('Download failed');
        expect(exception.message, equals('Download failed'));
        expect(exception.toString(),
            equals('FileDownloadException: Download failed'));
      });

      test('FileDeletionException should create exception with message', () {
        final exception = FileDeletionException('Deletion failed');
        expect(exception.message, equals('Deletion failed'));
        expect(exception.toString(),
            equals('FileDeletionException: Deletion failed'));
      });
    });

    group('generateS3Path', () {
      test('should generate correct S3 path', () {
        final path = fileService.generateS3Path(
          identityPoolId: 'us-east-1:12345678-1234-1234-1234-123456789012',
          syncId: 'abc-123',
          fileName: 'test.pdf',
        );

        expect(
          path,
          equals(
              'private/us-east-1:12345678-1234-1234-1234-123456789012/documents/abc-123/test.pdf'),
        );
      });

      test('should generate path with different regions', () {
        final path = fileService.generateS3Path(
          identityPoolId: 'eu-west-1:abcdef12-abcd-abcd-abcd-abcdef123456',
          syncId: 'doc-456',
          fileName: 'document.docx',
        );

        expect(
          path,
          equals(
              'private/eu-west-1:abcdef12-abcd-abcd-abcd-abcdef123456/documents/doc-456/document.docx'),
        );
      });

      test('should throw on invalid Identity Pool ID format', () {
        expect(
          () => fileService.generateS3Path(
            identityPoolId: 'invalid-id',
            syncId: 'abc-123',
            fileName: 'test.pdf',
          ),
          throwsArgumentError,
        );
      });

      test('should throw on empty syncId', () {
        expect(
          () => fileService.generateS3Path(
            identityPoolId: 'us-east-1:12345678-1234-1234-1234-123456789012',
            syncId: '',
            fileName: 'test.pdf',
          ),
          throwsArgumentError,
        );
      });

      test('should throw on empty fileName', () {
        expect(
          () => fileService.generateS3Path(
            identityPoolId: 'us-east-1:12345678-1234-1234-1234-123456789012',
            syncId: 'abc-123',
            fileName: '',
          ),
          throwsArgumentError,
        );
      });

      test('should throw on fileName with path separator', () {
        expect(
          () => fileService.generateS3Path(
            identityPoolId: 'us-east-1:12345678-1234-1234-1234-123456789012',
            syncId: 'abc-123',
            fileName: '../test.pdf',
          ),
          throwsArgumentError,
        );

        expect(
          () => fileService.generateS3Path(
            identityPoolId: 'us-east-1:12345678-1234-1234-1234-123456789012',
            syncId: 'abc-123',
            fileName: 'path/to/test.pdf',
          ),
          throwsArgumentError,
        );
      });

      test('should throw on syncId with path separator', () {
        expect(
          () => fileService.generateS3Path(
            identityPoolId: 'us-east-1:12345678-1234-1234-1234-123456789012',
            syncId: '../malicious',
            fileName: 'test.pdf',
          ),
          throwsArgumentError,
        );
      });
    });

    group('validateS3KeyOwnership', () {
      const identityPoolId = 'us-east-1:12345678-1234-1234-1234-123456789012';

      test('should validate correct ownership', () {
        final s3Key = 'private/$identityPoolId/documents/abc-123/test.pdf';
        expect(
            fileService.validateS3KeyOwnership(s3Key, identityPoolId), isTrue);
      });

      test('should reject key with different Identity Pool ID', () {
        const otherIdentityPoolId =
            'us-east-1:87654321-4321-4321-4321-210987654321';
        final s3Key = 'private/$otherIdentityPoolId/documents/abc-123/test.pdf';
        expect(
            fileService.validateS3KeyOwnership(s3Key, identityPoolId), isFalse);
      });

      test('should reject key without private prefix', () {
        final s3Key = 'public/$identityPoolId/documents/abc-123/test.pdf';
        expect(
            fileService.validateS3KeyOwnership(s3Key, identityPoolId), isFalse);
      });

      test('should reject empty s3Key', () {
        expect(fileService.validateS3KeyOwnership('', identityPoolId), isFalse);
      });

      test('should reject empty identityPoolId', () {
        final s3Key = 'private/$identityPoolId/documents/abc-123/test.pdf';
        expect(fileService.validateS3KeyOwnership(s3Key, ''), isFalse);
      });
    });

    group('Method signatures', () {
      test('uploadFile should have correct signature', () {
        expect(
          fileService.uploadFile,
          isA<Function>(),
        );
      });

      test('downloadFile should have correct signature', () {
        expect(
          fileService.downloadFile,
          isA<Function>(),
        );
      });

      test('deleteFile should have correct signature', () {
        expect(
          fileService.deleteFile,
          isA<Function>(),
        );
      });

      test('deleteDocumentFiles should have correct signature', () {
        expect(
          fileService.deleteDocumentFiles,
          isA<Function>(),
        );
      });

      test('getFileSize should have correct signature', () {
        expect(
          fileService.getFileSize,
          isA<Function>(),
        );
      });

      test('fileExists should have correct signature', () {
        expect(
          fileService.fileExists,
          isA<Function>(),
        );
      });

      test('deleteLocalFile should have correct signature', () {
        expect(
          fileService.deleteLocalFile,
          isA<Function>(),
        );
      });
    });

    group('Identity Pool ID validation', () {
      test('should validate correct Identity Pool ID formats', () {
        final validIds = [
          'us-east-1:12345678-1234-1234-1234-123456789012',
          'eu-west-1:abcdef12-abcd-abcd-abcd-abcdef123456',
          'ap-southeast-2:00000000-0000-0000-0000-000000000000',
        ];

        for (final id in validIds) {
          // Test by using generateS3Path which validates the ID
          expect(
            () => fileService.generateS3Path(
              identityPoolId: id,
              syncId: 'test',
              fileName: 'test.pdf',
            ),
            returnsNormally,
          );
        }
      });

      test('should reject invalid Identity Pool ID formats', () {
        final invalidIds = [
          'invalid-id',
          'us-east-1',
          '12345678-1234-1234-1234-123456789012',
          'us-east-1:',
          ':12345678-1234-1234-1234-123456789012',
          'US-EAST-1:12345678-1234-1234-1234-123456789012', // uppercase
        ];

        for (final id in invalidIds) {
          expect(
            () => fileService.generateS3Path(
              identityPoolId: id,
              syncId: 'test',
              fileName: 'test.pdf',
            ),
            throwsArgumentError,
          );
        }
      });
    });
  });
}
