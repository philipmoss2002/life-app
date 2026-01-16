import 'package:flutter_test/flutter_test.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'package:household_docs_app/utils/data_integrity_validator.dart';
import 'package:household_docs_app/models/file_path.dart';
import 'package:household_docs_app/models/file_migration_mapping.dart';

void main() {
  group('DataIntegrityValidator', () {
    late DataIntegrityValidator validator;

    setUp(() {
      validator = DataIntegrityValidator();
    });

    group('validateUserPoolSub', () {
      test('should validate correct User Pool sub format', () {
        const validUserPoolSub = '12345678-1234-1234-1234-123456789012';

        final result = validator.validateUserPoolSub(validUserPoolSub);

        expect(result.isValid, isTrue);
        expect(result.issues, isEmpty);
      });

      test('should reject empty User Pool sub', () {
        const emptyUserPoolSub = '';

        final result = validator.validateUserPoolSub(emptyUserPoolSub);

        expect(result.isValid, isFalse);
        expect(result.issues, hasLength(1));
        expect(result.issues.first.type, equals(ValidationIssueType.critical));
        expect(result.issues.first.message, contains('cannot be empty'));
      });

      test('should reject User Pool sub with suspicious characters', () {
        const suspiciousUserPoolSub =
            '12345678-1234/../malicious-1234-123456789012';

        final result = validator.validateUserPoolSub(suspiciousUserPoolSub);

        expect(result.isValid, isFalse);
        expect(result.hasCriticalIssues, isTrue);
        final securityIssues =
            result.getIssuesByType(ValidationIssueType.security);
        expect(securityIssues, isNotEmpty);
        expect(securityIssues.first.message, contains('suspicious characters'));
      });

      test('should warn about unusually short User Pool sub', () {
        const shortUserPoolSub = 'short';

        final result = validator.validateUserPoolSub(shortUserPoolSub);

        expect(result.isValid, isTrue); // Warnings don't make it invalid
        final warnings = result.getIssuesByType(ValidationIssueType.warning);
        expect(warnings, isNotEmpty);
        expect(warnings.first.message, contains('unusually short'));
      });

      test('should warn about unusually long User Pool sub', () {
        final longUserPoolSub = 'a' * 150;

        final result = validator.validateUserPoolSub(longUserPoolSub);

        expect(result.isValid, isTrue); // Warnings don't make it invalid
        final warnings = result.getIssuesByType(ValidationIssueType.warning);
        expect(warnings, isNotEmpty);
        expect(warnings.first.message, contains('unusually long'));
      });
    });

    group('validateFilePath', () {
      test('should validate correct file path structure', () {
        final filePath = FilePath.create(
          userSub: '12345678-1234-1234-1234-123456789012',
          syncId: 'test-sync-id',
          fileName: 'test-file.pdf',
        );

        final result = validator.validateFilePath(filePath);

        expect(result.isValid, isTrue);
        expect(result.issues, isEmpty);
      });

      test('should reject file path with invalid S3 key structure', () {
        final filePath = FilePath(
          userSub: '12345678-1234-1234-1234-123456789012',
          syncId: 'test-sync-id',
          fileName: 'test-file.pdf',
          fullPath: 'invalid/structure/path',
          createdAt: amplify_core.TemporalDateTime.now(),
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );

        final result = validator.validateFilePath(filePath);

        expect(result.isValid, isFalse);
        expect(result.hasCriticalIssues, isTrue);
        final criticalIssues =
            result.getIssuesByType(ValidationIssueType.critical);
        expect(
            criticalIssues
                .any((i) => i.message.contains('must start with "private/"')),
            isTrue);
      });

      test('should detect directory traversal attempts', () {
        final filePath = FilePath(
          userSub: '12345678-1234-1234-1234-123456789012',
          syncId: 'test-sync-id',
          fileName: 'test-file.pdf',
          fullPath: 'private/user/documents/../../../malicious/file.pdf',
          createdAt: amplify_core.TemporalDateTime.now(),
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );

        final result = validator.validateFilePath(filePath);

        expect(result.isValid, isFalse);
        expect(result.hasCriticalIssues, isTrue);
        final securityIssues =
            result.getIssuesByType(ValidationIssueType.security);
        expect(
            securityIssues
                .any((i) => i.message.contains('directory traversal')),
            isTrue);
      });

      test('should warn about invalid characters in file name', () {
        final filePath = FilePath.create(
          userSub: '12345678-1234-1234-1234-123456789012',
          syncId: 'test-sync-id',
          fileName: 'test<file>with|invalid*chars.pdf',
        );

        final result = validator.validateFilePath(filePath);

        expect(result.isValid, isTrue); // Warnings don't make it invalid
        final warnings = result.getIssuesByType(ValidationIssueType.warning);
        expect(warnings.any((i) => i.message.contains('invalid characters')),
            isTrue);
      });
    });

    group('validateAndCorrectFilePath', () {
      test('should return valid path unchanged', () {
        final filePath = FilePath.create(
          userSub: '12345678-1234-1234-1234-123456789012',
          syncId: 'test-sync-id',
          fileName: 'test-file.pdf',
        );

        final result = validator.validateAndCorrectFilePath(filePath);

        expect(result.isValid, isTrue);
        expect(result.correctedPath.fullPath, equals(filePath.fullPath));
        expect(result.appliedFixes, isEmpty);
      });

      test('should sanitize file name with invalid characters', () {
        final filePath = FilePath.create(
          userSub: '12345678-1234-1234-1234-123456789012',
          syncId: 'test-sync-id',
          fileName: 'test<file>with|invalid*chars.pdf',
        );

        final result = validator.validateAndCorrectFilePath(filePath);

        expect(result.isValid, isTrue);
        expect(result.correctedPath.fileName,
            equals('test_file_with_invalid_chars.pdf'));
        expect(result.appliedFixes, isNotEmpty);
        expect(result.appliedFixes.first, contains('Sanitized file name'));
      });
    });

    group('validateMigrationMapping', () {
      test('should validate correct migration mapping', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: 'protected/username/documents/sync-id/test-file.pdf',
          newPath:
              'private/12345678-1234-1234-1234-123456789012/documents/sync-id/test-file.pdf',
          userSub: '12345678-1234-1234-1234-123456789012',
          syncId: 'sync-id',
          fileName: 'test-file.pdf',
        );

        final result = validator.validateMigrationMapping(mapping);

        expect(result.isValid, isTrue);
        expect(result.issues, isEmpty);
      });

      test('should reject mapping with empty legacy path', () {
        final mapping = FileMigrationMapping.create(
          legacyPath: '',
          newPath:
              'private/12345678-1234-1234-1234-123456789012/documents/sync-id/test-file.pdf',
          userSub: '12345678-1234-1234-1234-123456789012',
          syncId: 'sync-id',
          fileName: 'test-file.pdf',
        );

        final result = validator.validateMigrationMapping(mapping);

        expect(result.isValid, isFalse);
        expect(result.hasCriticalIssues, isTrue);
        final criticalIssues =
            result.getIssuesByType(ValidationIssueType.critical);
        expect(
            criticalIssues
                .any((i) => i.message.contains('Legacy path cannot be empty')),
            isTrue);
      });
    });

    group('performAutomaticCleanup', () {
      test('should identify valid and invalid file references', () async {
        final fileReferences = [
          'private/12345678-1234-1234-1234-123456789012/documents/sync-id/valid-file.pdf',
          'invalid/structure/file.pdf',
          'private/12345678-1234-1234-1234-123456789012/documents/sync-id/another-valid.pdf',
          'malformed-path',
        ];

        final result = await validator.performAutomaticCleanup(fileReferences);

        expect(result.totalReferences, equals(4));
        expect(result.validReferences, hasLength(2));
        expect(result.invalidReferences, hasLength(2));
        expect(result.cleanupActions, hasLength(4));
        expect(result.summary, contains('2 valid, 2 invalid'));
      });

      test('should handle empty file references list', () async {
        final result = await validator.performAutomaticCleanup([]);

        expect(result.totalReferences, equals(0));
        expect(result.validReferences, isEmpty);
        expect(result.invalidReferences, isEmpty);
        expect(result.cleanupActions, isEmpty);
      });
    });
  });
}
