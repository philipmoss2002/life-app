import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/persistent_file_service.dart';
import 'package:household_docs_app/models/file_path.dart';

void main() {
  group('PersistentFileService Tests', () {
    late PersistentFileService service;

    const validUserSub = '12345678-1234-1234-1234-123456789012';
    const validSyncId = 'sync_test_123';

    setUp(() {
      service = PersistentFileService();
      service.clearCache();
    });

    tearDown(() {
      service.dispose();
    });

    group('Service Initialization', () {
      test('should create singleton instance', () {
        final service1 = PersistentFileService();
        final service2 = PersistentFileService();
        expect(identical(service1, service2), isTrue);
      });

      test('should have initial service status', () {
        final status = service.getServiceStatus();
        expect(status['hasCachedUserPoolSub'], isFalse);
        expect(status['cacheAge'], isNull);
        expect(status['cacheValid'], isFalse);
      });
    });

    group('Cache Management', () {
      test('should clear cache correctly', () {
        service.clearCache();
        expect(service.getServiceStatus()['hasCachedUserPoolSub'], isFalse);
      });

      test('should dispose service correctly', () {
        service.dispose();
        final statusAfterDispose = service.getServiceStatus();
        expect(statusAfterDispose['hasCachedUserPoolSub'], isFalse);
      });
    });

    group('S3 Key Parsing', () {
      test('should parse valid S3 key successfully', () {
        const s3Key =
            'private/$validUserSub/documents/$validSyncId/1640995200000-test.pdf';

        final filePath = service.parseS3Key(s3Key);

        expect(filePath.userSub, equals(validUserSub));
        expect(filePath.syncId, equals(validSyncId));
        expect(filePath.fileName, equals('test.pdf'));
        expect(filePath.timestamp, equals(1640995200000));
      });

      test('should parse S3 key without timestamp', () {
        const s3Key = 'private/$validUserSub/documents/$validSyncId/test.pdf';

        final filePath = service.parseS3Key(s3Key);

        expect(filePath.userSub, equals(validUserSub));
        expect(filePath.syncId, equals(validSyncId));
        expect(filePath.fileName, equals('test.pdf'));
        expect(filePath.timestamp, isNull);
      });

      test('should throw exception for invalid S3 key format', () {
        expect(
          () => service.parseS3Key('invalid/s3/key'),
          throwsA(isA<FilePathGenerationException>()),
        );
      });

      test('should throw exception for non-private S3 key', () {
        expect(
          () => service.parseS3Key(
              'public/$validUserSub/documents/$validSyncId/test.pdf'),
          throwsA(isA<FilePathGenerationException>()),
        );
      });
    });

    group('Error Handling', () {
      test('should handle malformed S3 keys gracefully', () {
        const malformedKeys = [
          '',
          'private',
          'private/',
          'private/invalid-user-sub',
          'private/$validUserSub',
          'private/$validUserSub/documents',
          'private/$validUserSub/documents/',
        ];

        for (final key in malformedKeys) {
          expect(
            () => service.parseS3Key(key),
            throwsA(isA<FilePathValidationException>()),
            reason: 'Should throw for malformed key: $key',
          );
        }
      });

      test('should provide descriptive error messages', () {
        try {
          service.parseS3Key('invalid/path');
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e, isA<FilePathGenerationException>());
          expect(e.toString(), contains('FilePathGenerationException'));
        }
      });
    });

    group('Service Status', () {
      test('should provide comprehensive service status', () {
        final status = service.getServiceStatus();

        expect(status, isA<Map<String, dynamic>>());
        expect(status.containsKey('hasCachedUserPoolSub'), isTrue);
        expect(status.containsKey('cacheAge'), isTrue);
        expect(status.containsKey('cacheValid'), isTrue);
        expect(status.containsKey('cachedUserPoolSubPreview'), isTrue);
      });
    });

    group('Security Validation', () {
      test('should validate User Pool sub format in S3 keys', () {
        const invalidUserSubKeys = [
          'private/invalid-format/documents/$validSyncId/test.pdf',
          'private/12345678-1234-1234-1234/documents/$validSyncId/test.pdf',
          'private/12345678_1234_1234_1234_123456789012/documents/$validSyncId/test.pdf',
        ];

        for (final key in invalidUserSubKeys) {
          expect(
            () => service.parseS3Key(key),
            throwsA(isA<FilePathValidationException>()),
            reason: 'Should reject invalid User Pool sub in key: $key',
          );
        }
      });
    });
  });
}
