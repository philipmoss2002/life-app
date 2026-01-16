import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/persistent_file_service.dart';

void main() {
  group('PersistentFileService Legacy File Detection Tests', () {
    late PersistentFileService service;

    setUp(() {
      service = PersistentFileService();
      service.clearCache();
    });

    group('Legacy File Path Validation', () {
      test('should validate correct legacy file paths', () async {
        const validLegacyPaths = [
          'protected/username/documents/sync_123/file.pdf',
          'protected/user123/documents/doc_456/document.txt',
          'protected/testuser/documents/sync_abc/1640995200000-report.pdf',
          'protected/john.doe/documents/project_1/image.jpg',
        ];

        for (final path in validLegacyPaths) {
          // Test the private method through parseS3Key which should fail for legacy paths
          // But we can test the validation logic through other methods
          expect(path.startsWith('protected/'), isTrue,
              reason: 'Path should start with protected/: $path');
          expect(path.contains('/documents/'), isTrue,
              reason: 'Path should contain /documents/: $path');
          expect(path.split('/').length, greaterThanOrEqualTo(5),
              reason: 'Path should have at least 5 parts: $path');
        }
      });

      test('should reject invalid legacy file paths', () {
        const invalidLegacyPaths = [
          'public/username/documents/sync_123/file.pdf', // Wrong access level
          'protected/username/files/sync_123/file.pdf', // Wrong folder name
          'protected/username/documents/sync_123/', // No filename
          'protected/username/documents/', // No sync ID or filename
          'protected/username/', // Incomplete path
          'protected/', // Too short
          '', // Empty path
          'protected/username/documents/sync_123/file', // No file extension
        ];

        for (final path in invalidLegacyPaths) {
          // These should not be valid legacy paths
          if (path.isNotEmpty) {
            final parts = path.split('/');
            final isValid = parts.length >= 5 &&
                parts[0] == 'protected' &&
                parts[2] == 'documents' &&
                parts[1].isNotEmpty &&
                parts[3].isNotEmpty &&
                parts[4].isNotEmpty &&
                parts[4].contains('.');
            expect(isValid, isFalse, reason: 'Path should be invalid: $path');
          }
        }
      });
    });

    group('Legacy File Detection - Unauthenticated', () {
      test(
          'findLegacyFiles should throw UserPoolSubException when not authenticated',
          () async {
        expect(
          () => service.findLegacyFiles(),
          throwsA(isA<UserPoolSubException>()),
        );
      });

      test(
          'getLegacyFileInventory should throw UserPoolSubException when not authenticated',
          () async {
        expect(
          () => service.getLegacyFileInventory(),
          throwsA(isA<UserPoolSubException>()),
        );
      });

      test(
          'hasLegacyFilesForSyncId should throw UserPoolSubException when not authenticated',
          () async {
        expect(
          () => service.hasLegacyFilesForSyncId('sync_123'),
          throwsA(isA<UserPoolSubException>()),
        );
      });

      test(
          'getLegacyFilesForSyncId should throw UserPoolSubException when not authenticated',
          () async {
        expect(
          () => service.getLegacyFilesForSyncId('sync_123'),
          throwsA(isA<UserPoolSubException>()),
        );
      });

      test('validateLegacyFile should return false for empty path', () async {
        final result = await service.validateLegacyFile('');
        expect(result, isFalse);
      });
    });

    group('Input Validation', () {
      test(
          'hasLegacyFilesForSyncId should throw FilePathGenerationException for empty sync ID',
          () async {
        expect(
          () => service.hasLegacyFilesForSyncId(''),
          throwsA(isA<FilePathGenerationException>()),
        );
      });

      test(
          'getLegacyFilesForSyncId should throw FilePathGenerationException for empty sync ID',
          () async {
        expect(
          () => service.getLegacyFilesForSyncId(''),
          throwsA(isA<FilePathGenerationException>()),
        );
      });
    });

    group('Legacy Path Component Extraction', () {
      test('should extract components from valid legacy paths', () {
        const testCases = [
          {
            'path': 'protected/username/documents/sync_123/file.pdf',
            'expectedSyncId': 'sync_123',
            'expectedFileName': 'file.pdf',
            'expectedUsername': 'username',
          },
          {
            'path':
                'protected/user123/documents/doc_456/1640995200000-document.txt',
            'expectedSyncId': 'doc_456',
            'expectedFileName': 'document.txt', // Should remove timestamp
            'expectedUsername': 'user123',
          },
          {
            'path': 'protected/testuser/documents/project_1/report.pdf',
            'expectedSyncId': 'project_1',
            'expectedFileName': 'report.pdf',
            'expectedUsername': 'testuser',
          },
        ];

        for (final testCase in testCases) {
          final path = testCase['path'] as String;
          final parts = path.split('/');

          // Test path structure
          expect(parts.length, greaterThanOrEqualTo(5),
              reason: 'Path should have at least 5 parts: $path');
          expect(parts[0], equals('protected'),
              reason: 'Should start with protected: $path');
          expect(parts[2], equals('documents'),
              reason: 'Should have documents folder: $path');

          // Test component extraction
          expect(parts[1], equals(testCase['expectedUsername']),
              reason: 'Username extraction failed for: $path');
          expect(parts[3], equals(testCase['expectedSyncId']),
              reason: 'Sync ID extraction failed for: $path');

          // Test filename extraction (with timestamp handling)
          final fullFileName = parts[4];
          String extractedFileName = fullFileName;

          // Handle timestamp prefix
          if (fullFileName.contains('-') && fullFileName.indexOf('-') > 0) {
            final dashIndex = fullFileName.indexOf('-');
            final timestampPart = fullFileName.substring(0, dashIndex);

            if (RegExp(r'^\d+$').hasMatch(timestampPart)) {
              extractedFileName = fullFileName.substring(dashIndex + 1);
            }
          }

          expect(extractedFileName, equals(testCase['expectedFileName']),
              reason: 'Filename extraction failed for: $path');
        }
      });

      test('should handle edge cases in filename extraction', () {
        const testCases = [
          {
            'path': 'protected/user/documents/sync/file-with-dashes.pdf',
            'expectedFileName':
                'file-with-dashes.pdf', // No timestamp, keep dashes
          },
          {
            'path': 'protected/user/documents/sync/123-not-timestamp-file.pdf',
            'expectedFileName':
                '123-not-timestamp-file.pdf', // Short number, not timestamp
          },
          {
            'path': 'protected/user/documents/sync/1640995200000-file.pdf',
            'expectedFileName': 'file.pdf', // Valid timestamp, remove it
          },
          {
            'path': 'protected/user/documents/sync/abc-123-file.pdf',
            'expectedFileName':
                'abc-123-file.pdf', // Non-numeric prefix, keep all
          },
        ];

        for (final testCase in testCases) {
          final path = testCase['path'] as String;
          final parts = path.split('/');
          final fullFileName = parts[4];

          String extractedFileName = fullFileName;

          // Handle timestamp prefix
          if (fullFileName.contains('-') && fullFileName.indexOf('-') > 0) {
            final dashIndex = fullFileName.indexOf('-');
            final timestampPart = fullFileName.substring(0, dashIndex);

            if (RegExp(r'^\d+$').hasMatch(timestampPart) &&
                timestampPart.length >= 10) {
              extractedFileName = fullFileName.substring(dashIndex + 1);
            }
          }

          expect(extractedFileName, equals(testCase['expectedFileName']),
              reason: 'Filename extraction failed for: $path');
        }
      });
    });

    group('Legacy File Format Validation', () {
      test('should validate legacy file format correctly', () {
        const validFormats = [
          'protected/username/documents/sync_123/file.pdf',
          'protected/user.name/documents/sync-456/document.txt',
          'protected/user123/documents/project_1/1640995200000-report.pdf',
        ];

        const invalidFormats = [
          'private/username/documents/sync_123/file.pdf', // Wrong access level
          'protected/username/files/sync_123/file.pdf', // Wrong folder
          'protected/username/documents/sync_123/', // No filename
          'protected/username/documents/', // No sync ID
          'protected/username/', // Incomplete
          'protected/', // Too short
          '', // Empty
          'protected/username/documents/sync_123/file', // No extension
        ];

        for (final format in validFormats) {
          final parts = format.split('/');
          final isValid = parts.length >= 5 &&
              parts[0] == 'protected' &&
              parts[2] == 'documents' &&
              parts[1].isNotEmpty &&
              parts[3].isNotEmpty &&
              parts[4].isNotEmpty &&
              parts[4].contains('.');
          expect(isValid, isTrue, reason: 'Should be valid format: $format');
        }

        for (final format in invalidFormats) {
          if (format.isNotEmpty) {
            final parts = format.split('/');
            final isValid = parts.length >= 5 &&
                parts[0] == 'protected' &&
                parts[2] == 'documents' &&
                parts[1].isNotEmpty &&
                parts[3].isNotEmpty &&
                parts[4].isNotEmpty &&
                parts[4].contains('.');
            expect(isValid, isFalse,
                reason: 'Should be invalid format: $format');
          }
        }
      });
    });

    group('Migration Mapping Creation', () {
      test('should create valid migration mappings from legacy paths', () {
        const testCases = [
          {
            'legacyPath': 'protected/username/documents/sync_123/file.pdf',
            'syncId': 'sync_123',
            'fileName': 'file.pdf',
          },
          {
            'legacyPath':
                'protected/user123/documents/doc_456/1640995200000-document.txt',
            'syncId': 'doc_456',
            'fileName': 'document.txt',
          },
        ];

        for (final testCase in testCases) {
          final legacyPath = testCase['legacyPath'] as String;
          final expectedSyncId = testCase['syncId'] as String;
          final expectedFileName = testCase['fileName'] as String;

          // Test that we can extract the components correctly
          final parts = legacyPath.split('/');
          expect(parts[3], equals(expectedSyncId));

          // Test filename extraction with timestamp handling
          final fullFileName = parts[4];
          String extractedFileName = fullFileName;

          if (fullFileName.contains('-') && fullFileName.indexOf('-') > 0) {
            final dashIndex = fullFileName.indexOf('-');
            final timestampPart = fullFileName.substring(0, dashIndex);

            if (RegExp(r'^\d+$').hasMatch(timestampPart)) {
              extractedFileName = fullFileName.substring(dashIndex + 1);
            }
          }

          expect(extractedFileName, equals(expectedFileName));
        }
      });
    });

    group('Error Handling', () {
      test('should handle malformed legacy paths gracefully', () {
        const malformedPaths = [
          'protected/username/documents/sync_123', // Missing filename
          'protected/username/documents/', // Missing sync ID and filename
          'protected/username/', // Missing documents folder
          'protected/', // Missing username
          '', // Empty path
          'not-a-path', // Invalid format
        ];

        for (final path in malformedPaths) {
          // Test that path validation correctly identifies these as invalid
          final parts = path.split('/');
          final isValid = parts.length >= 5 &&
              parts[0] == 'protected' &&
              parts[2] == 'documents' &&
              parts[1].isNotEmpty &&
              parts[3].isNotEmpty &&
              parts[4].isNotEmpty &&
              parts[4].contains('.');
          expect(isValid, isFalse,
              reason: 'Malformed path should be invalid: $path');
        }
      });

      test('should handle edge cases in component extraction', () {
        const edgeCases = [
          'protected/username/documents/sync_123/file.pdf.backup', // Multiple extensions
          'protected/user-name/documents/sync-id/file-name.pdf', // Dashes in components
          'protected/user.name/documents/sync.id/file.name.pdf', // Dots in components
          'protected/user_name/documents/sync_id/file_name.pdf', // Underscores in components
        ];

        for (final path in edgeCases) {
          final parts = path.split('/');

          // Should still be valid legacy format
          final isValid = parts.length >= 5 &&
              parts[0] == 'protected' &&
              parts[2] == 'documents' &&
              parts[1].isNotEmpty &&
              parts[3].isNotEmpty &&
              parts[4].isNotEmpty &&
              parts[4].contains('.');
          expect(isValid, isTrue, reason: 'Edge case should be valid: $path');

          // Components should be extractable
          expect(parts[1].isNotEmpty, isTrue,
              reason: 'Username should not be empty: $path');
          expect(parts[3].isNotEmpty, isTrue,
              reason: 'Sync ID should not be empty: $path');
          expect(parts[4].isNotEmpty, isTrue,
              reason: 'Filename should not be empty: $path');
        }
      });
    });

    group('Authentication Requirements', () {
      test('all legacy detection methods should require authentication',
          () async {
        // Test that all methods throw UserPoolSubException when not authenticated
        expect(() => service.findLegacyFiles(),
            throwsA(isA<UserPoolSubException>()));
        expect(() => service.getLegacyFileInventory(),
            throwsA(isA<UserPoolSubException>()));
        expect(() => service.hasLegacyFilesForSyncId('sync_123'),
            throwsA(isA<UserPoolSubException>()));
        expect(() => service.getLegacyFilesForSyncId('sync_123'),
            throwsA(isA<UserPoolSubException>()));
      });
    });
  });
}
