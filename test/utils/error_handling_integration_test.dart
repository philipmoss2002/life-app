import 'package:flutter_test/flutter_test.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'package:household_docs_app/utils/data_integrity_validator.dart';
import 'package:household_docs_app/models/file_path.dart';
import 'package:household_docs_app/models/file_migration_mapping.dart';

void main() {
  group('Error Handling Integration Tests', () {
    late DataIntegrityValidator validator;

    setUp(() {
      validator = DataIntegrityValidator();
    });

    group('Data Integrity Validation Error Recovery', () {
      test('should recover from invalid User Pool sub format', () {
        // Test various invalid formats
        final invalidSubs = [
          '', // Empty
          'invalid-format', // Wrong format
          'us-east-1:short', // Too short
          'us-east-1:12345678/../malicious', // Directory traversal
          'a' * 150, // Too long
        ];

        for (final invalidSub in invalidSubs) {
          final result = validator.validateUserPoolSub(invalidSub);

          expect(result.isValid, isFalse);
          expect(result.issues, isNotEmpty);

          // Check that appropriate issue types are identified
          final criticalIssues =
              result.getIssuesByType(ValidationIssueType.critical);
          final securityIssues =
              result.getIssuesByType(ValidationIssueType.security);

          if (invalidSub.isEmpty || invalidSub == 'invalid-format') {
            expect(criticalIssues, isNotEmpty);
          }

          if (invalidSub.contains('../')) {
            expect(securityIssues, isNotEmpty);
          }
        }
      });

      test('should provide recovery suggestions for validation failures', () {
        const invalidUserPoolSub = '';

        final result = validator.validateUserPoolSub(invalidUserPoolSub);

        expect(result.isValid, isFalse);
        expect(result.issues, hasLength(1));

        final issue = result.issues.first;
        expect(issue.type, equals(ValidationIssueType.critical));
        expect(issue.suggestedFix, contains('Re-authenticate'));
      });

      test('should handle file path validation errors gracefully', () {
        final invalidFilePath = FilePath(
          userSub: 'invalid-sub',
          syncId: '',
          fileName: 'test<file>with|invalid*chars.pdf',
          fullPath: 'invalid/structure/../malicious/path',
          createdAt: amplify_core.TemporalDateTime.now(),
        );

        final result = validator.validateFilePath(invalidFilePath);

        expect(result.isValid, isFalse);
        expect(result.hasCriticalIssues, isTrue);

        // Should have multiple types of issues
        final criticalIssues =
            result.getIssuesByType(ValidationIssueType.critical);
        final securityIssues =
            result.getIssuesByType(ValidationIssueType.security);
        final warnings = result.getIssuesByType(ValidationIssueType.warning);

        expect(criticalIssues, isNotEmpty); // Invalid structure, empty sync ID
        expect(securityIssues, isNotEmpty); // Directory traversal
        expect(warnings, isNotEmpty); // Invalid characters in filename
      });

      test('should attempt automatic path correction', () {
        final problematicFilePath = FilePath.create(
          userSub: 'us-east-1:12345678-1234-1234-1234-123456789012',
          syncId: 'test-sync-id',
          fileName: 'test<file>with|invalid*chars?.pdf',
        );

        final correctionResult =
            validator.validateAndCorrectFilePath(problematicFilePath);

        expect(correctionResult.isValid, isTrue);
        expect(correctionResult.appliedFixes, isNotEmpty);
        expect(correctionResult.appliedFixes.first,
            contains('Sanitized file name'));
        expect(correctionResult.correctedPath.fileName,
            equals('test_file_with_invalid_chars_.pdf'));
      });

      test('should handle uncorrectable path errors', () {
        final uncorrectableFilePath = FilePath(
          userSub: 'us-east-1:12345678-1234-1234-1234-123456789012',
          syncId: 'test-sync-id',
          fileName: 'test-file.pdf',
          fullPath: 'completely/wrong/structure/that/cannot/be/fixed',
          createdAt: amplify_core.TemporalDateTime.now(),
        );

        final correctionResult =
            validator.validateAndCorrectFilePath(uncorrectableFilePath);

        expect(correctionResult.isValid, isFalse);
        expect(correctionResult.error, isNotNull);
        expect(correctionResult.error,
            contains('Could not correct all validation issues'));
      });
    });

    group('Migration Mapping Error Handling', () {
      test('should validate migration mapping consistency', () {
        final invalidMapping = FileMigrationMapping.create(
          legacyPath: '', // Invalid: empty path
          newPath: 'invalid/new/path/structure',
          userSub: 'invalid-sub-format',
          syncId: 'test-sync',
          fileName: 'test-file.pdf',
        );

        final result = validator.validateMigrationMapping(invalidMapping);

        expect(result.isValid, isFalse);
        expect(result.hasCriticalIssues, isTrue);

        final criticalIssues =
            result.getIssuesByType(ValidationIssueType.critical);
        expect(criticalIssues.length,
            greaterThanOrEqualTo(2)); // Empty legacy path + invalid new path
      });

      test('should detect filename inconsistencies in migration mapping', () {
        final inconsistentMapping = FileMigrationMapping.create(
          legacyPath: 'protected/username/documents/sync-id/original-file.pdf',
          newPath:
              'private/us-east-1:12345678-1234-1234-1234-123456789012/documents/sync-id/different-file.pdf',
          userSub: 'us-east-1:12345678-1234-1234-1234-123456789012',
          syncId: 'sync-id',
          fileName: 'yet-another-file.pdf', // Inconsistent with both paths
        );

        final result = validator.validateMigrationMapping(inconsistentMapping);

        expect(result.isValid, isTrue); // Warnings don't make it invalid
        final warnings = result.getIssuesByType(ValidationIssueType.warning);
        expect(
            warnings.any((w) => w.message.contains('File name inconsistency')),
            isTrue);
      });
    });

    group('Cleanup Operation Error Handling', () {
      test('should handle mixed valid and invalid file references', () async {
        final mixedReferences = [
          'private/us-east-1:12345678-1234-1234-1234-123456789012/documents/sync1/valid1.pdf',
          'invalid/structure/file.pdf',
          'private/us-east-1:12345678-1234-1234-1234-123456789012/documents/sync2/valid2.pdf',
          'malformed-reference',
          'private/invalid-sub/documents/sync3/invalid-sub.pdf',
          'private/us-east-1:12345678-1234-1234-1234-123456789012/documents/../traversal.pdf',
        ];

        final cleanupResult =
            await validator.performAutomaticCleanup(mixedReferences);

        expect(cleanupResult.totalReferences, equals(6));
        expect(cleanupResult.validReferences.length, greaterThan(0));
        expect(cleanupResult.invalidReferences.length, greaterThan(0));
        expect(cleanupResult.cleanupActions, hasLength(6));

        // Verify that valid references are properly identified
        expect(
            cleanupResult.validReferences,
            contains(
                'private/us-east-1:12345678-1234-1234-1234-123456789012/documents/sync1/valid1.pdf'));
        expect(
            cleanupResult.validReferences,
            contains(
                'private/us-east-1:12345678-1234-1234-1234-123456789012/documents/sync2/valid2.pdf'));

        // Verify that invalid references are properly identified
        expect(cleanupResult.invalidReferences,
            contains('invalid/structure/file.pdf'));
        expect(
            cleanupResult.invalidReferences, contains('malformed-reference'));
      });

      test('should handle empty cleanup gracefully', () async {
        final cleanupResult = await validator.performAutomaticCleanup([]);

        expect(cleanupResult.totalReferences, equals(0));
        expect(cleanupResult.validReferences, isEmpty);
        expect(cleanupResult.invalidReferences, isEmpty);
        expect(cleanupResult.cleanupActions, isEmpty);
        expect(cleanupResult.summary, contains('0 valid, 0 invalid'));
      });

      test('should provide detailed cleanup actions', () async {
        final problematicReferences = [
          'private/us-east-1:12345678-1234-1234-1234-123456789012/documents/sync1/file<with>invalid|chars.pdf',
          'completely/invalid/structure',
        ];

        final cleanupResult =
            await validator.performAutomaticCleanup(problematicReferences);

        expect(cleanupResult.cleanupActions, hasLength(2));

        // First reference should be corrected
        expect(
            cleanupResult.cleanupActions.any((action) =>
                action.contains('Corrected path') &&
                action.contains('file_with_invalid_chars.pdf')),
            isTrue);

        // Second reference should be marked for removal
        expect(
            cleanupResult.cleanupActions.any((action) =>
                action.contains('Marked for removal') &&
                action.contains('completely/invalid/structure')),
            isTrue);
      });
    });

    group('Error Propagation and Handling', () {
      test(
          'should properly propagate validation errors through correction process',
          () {
        final severelyInvalidPath = FilePath(
          userSub: '', // Critical: empty
          syncId: '', // Critical: empty
          fileName: '', // Critical: empty
          fullPath: '../../../malicious/path', // Security: directory traversal
          createdAt: amplify_core.TemporalDateTime.now(),
        );

        final correctionResult =
            validator.validateAndCorrectFilePath(severelyInvalidPath);

        expect(correctionResult.isValid, isFalse);
        expect(correctionResult.error, isNotNull);
        expect(correctionResult.appliedFixes,
            isEmpty); // No fixes possible for such severe issues
      });

      test('should handle validation exceptions gracefully', () {
        // Test with null or malformed data that might cause exceptions
        expect(() => validator.validateUserPoolSub(''), returnsNormally);

        final malformedPath = FilePath(
          userSub: 'us-east-1:12345678-1234-1234-1234-123456789012',
          syncId: 'test',
          fileName: 'test.pdf',
          fullPath: '', // Empty path might cause issues
          createdAt: amplify_core.TemporalDateTime.now(),
        );

        expect(
            () => validator.validateFilePath(malformedPath), returnsNormally);
      });
    });

    group('Performance Under Error Conditions', () {
      test('should handle large numbers of validation errors efficiently', () {
        final startTime = DateTime.now();

        // Generate many invalid User Pool subs
        final invalidSubs = List.generate(1000, (i) => 'invalid-sub-$i');

        for (final sub in invalidSubs) {
          final result = validator.validateUserPoolSub(sub);
          expect(result.isValid, isFalse);
        }

        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        // Should complete within reasonable time (less than 5 seconds for 1000 validations)
        expect(duration.inSeconds, lessThan(5));
      });

      test('should handle large cleanup operations efficiently', () async {
        final startTime = DateTime.now();

        // Generate many invalid file references
        final invalidReferences =
            List.generate(500, (i) => 'invalid/reference/$i');

        final cleanupResult =
            await validator.performAutomaticCleanup(invalidReferences);

        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        expect(cleanupResult.totalReferences, equals(500));
        expect(cleanupResult.invalidReferences, hasLength(500));

        // Should complete within reasonable time (less than 10 seconds for 500 references)
        expect(duration.inSeconds, lessThan(10));
      });
    });

    group('Error Recovery Strategies', () {
      test(
          'should provide appropriate recovery strategies for different error types',
          () {
        final testCases = [
          {
            'userSub': '',
            'expectedSuggestion':
                'Re-authenticate user to obtain valid User Pool sub',
          },
          {
            'userSub': 'us-east-1:12345678/../malicious',
            'expectedSuggestion':
                'Reject this User Pool sub and re-authenticate',
          },
          {
            'userSub': 'short',
            'expectedSuggestion': 'Verify User Pool sub authenticity',
          },
        ];

        for (final testCase in testCases) {
          final result =
              validator.validateUserPoolSub(testCase['userSub'] as String);

          expect(result.isValid, isFalse);
          expect(result.issues, isNotEmpty);

          final relevantIssue = result.issues.first;
          expect(relevantIssue.suggestedFix,
              equals(testCase['expectedSuggestion']));
        }
      });

      test('should prioritize security issues over other types', () {
        final securityThreatPath = FilePath(
          userSub: 'us-east-1:12345678/../malicious', // Security issue
          syncId: '', // Critical issue
          fileName: 'test.pdf',
          fullPath:
              'private/user/documents/../../../etc/passwd', // Security issue
          createdAt: amplify_core.TemporalDateTime.now(),
        );

        final result = validator.validateFilePath(securityThreatPath);

        expect(result.isValid, isFalse);
        expect(result.hasCriticalIssues, isTrue);

        final securityIssues =
            result.getIssuesByType(ValidationIssueType.security);
        final criticalIssues =
            result.getIssuesByType(ValidationIssueType.critical);

        expect(securityIssues, isNotEmpty);
        expect(criticalIssues, isNotEmpty);

        // Security issues should be present and properly identified
        expect(
            securityIssues.any((issue) =>
                issue.message.contains('suspicious characters') ||
                issue.message.contains('directory traversal')),
            isTrue);
      });
    });
  });
}
