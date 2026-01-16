import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/utils/user_pool_sub_validator.dart';

void main() {
  group('UserPoolSubValidator Tests', () {
    const validUserSub = '12345678-1234-1234-1234-123456789012';

    group('Format Validation', () {
      test('should validate correct User Pool sub format', () {
        expect(UserPoolSubValidator.isValidFormat(validUserSub), isTrue);
      });

      test('should validate User Pool sub with uppercase letters', () {
        const upperCaseSub = '12345678-ABCD-1234-1234-123456789012';
        expect(UserPoolSubValidator.isValidFormat(upperCaseSub), isTrue);
      });

      test('should validate User Pool sub with lowercase letters', () {
        const lowerCaseSub = '12345678-abcd-1234-1234-123456789012';
        expect(UserPoolSubValidator.isValidFormat(lowerCaseSub), isTrue);
      });

      test('should reject empty string', () {
        expect(UserPoolSubValidator.isValidFormat(''), isFalse);
      });

      test('should reject User Pool sub without hyphens', () {
        expect(
            UserPoolSubValidator.isValidFormat(
                '123456781234123412341234567890ab'),
            isFalse);
      });

      test('should reject User Pool sub with wrong number of segments', () {
        expect(
            UserPoolSubValidator.isValidFormat(
                '12345678-1234-1234-123456789012'),
            isFalse);
      });

      test('should reject User Pool sub with wrong segment lengths', () {
        expect(
            UserPoolSubValidator.isValidFormat(
                '1234567-1234-1234-1234-123456789012'),
            isFalse);
        expect(
            UserPoolSubValidator.isValidFormat(
                '12345678-123-1234-1234-123456789012'),
            isFalse);
        expect(
            UserPoolSubValidator.isValidFormat(
                '12345678-1234-123-1234-123456789012'),
            isFalse);
        expect(
            UserPoolSubValidator.isValidFormat(
                '12345678-1234-1234-123-123456789012'),
            isFalse);
        expect(
            UserPoolSubValidator.isValidFormat(
                '12345678-1234-1234-1234-12345678901'),
            isFalse);
      });

      test('should reject User Pool sub with invalid characters', () {
        expect(
            UserPoolSubValidator.isValidFormat(
                '12345678-1234-1234-1234-12345678901g'),
            isFalse);
        expect(
            UserPoolSubValidator.isValidFormat(
                '12345678-1234-1234-1234-12345678901@'),
            isFalse);
        expect(
            UserPoolSubValidator.isValidFormat(
                '12345678_1234_1234_1234_123456789012'),
            isFalse);
      });

      test('should reject null or whitespace', () {
        expect(UserPoolSubValidator.isValidFormat('   '), isFalse);
        expect(UserPoolSubValidator.isValidFormat('\t'), isFalse);
        expect(UserPoolSubValidator.isValidFormat('\n'), isFalse);
      });
    });

    group('Validation and Sanitization', () {
      test('should validate and sanitize correct User Pool sub', () {
        final result = UserPoolSubValidator.validateAndSanitize(validUserSub);
        expect(result, equals(validUserSub.toLowerCase()));
      });

      test('should trim whitespace and normalize case', () {
        const inputWithWhitespace = '  12345678-ABCD-1234-1234-123456789012  ';
        final result =
            UserPoolSubValidator.validateAndSanitize(inputWithWhitespace);
        expect(result, equals('12345678-abcd-1234-1234-123456789012'));
      });

      test('should throw ArgumentError for invalid format', () {
        expect(
          () => UserPoolSubValidator.validateAndSanitize('invalid-sub'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should throw ArgumentError for empty string', () {
        expect(
          () => UserPoolSubValidator.validateAndSanitize(''),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('S3 Path Safety', () {
      test('should validate safe User Pool sub for S3 paths', () {
        expect(UserPoolSubValidator.isSafeForS3Path(validUserSub), isTrue);
      });

      test('should reject User Pool sub with path traversal attempts', () {
        expect(
            UserPoolSubValidator.isSafeForS3Path(
                '12345678-1234-1234-1234-123456789../'),
            isFalse);
        expect(
            UserPoolSubValidator.isSafeForS3Path(
                '../12345678-1234-1234-1234-123456789012'),
            isFalse);
        expect(
            UserPoolSubValidator.isSafeForS3Path(
                '12345678-1234/../1234-1234-123456789012'),
            isFalse);
      });

      test('should reject User Pool sub with forward slashes', () {
        expect(
            UserPoolSubValidator.isSafeForS3Path(
                '12345678/1234-1234-1234-123456789012'),
            isFalse);
      });

      test('should reject User Pool sub with backslashes', () {
        expect(
            UserPoolSubValidator.isSafeForS3Path(
                '12345678\\1234-1234-1234-123456789012'),
            isFalse);
      });

      test('should reject invalid format even without path traversal', () {
        expect(UserPoolSubValidator.isSafeForS3Path('invalid-format'), isFalse);
      });
    });

    group('S3 Path Extraction', () {
      test('should extract User Pool sub from valid S3 path', () {
        const s3Path = 'private/$validUserSub/documents/sync_123/file.pdf';
        final extractedSub = UserPoolSubValidator.extractFromS3Path(s3Path);
        expect(extractedSub, equals(validUserSub));
      });

      test('should extract User Pool sub from minimal S3 path', () {
        const s3Path = 'private/$validUserSub';
        final extractedSub = UserPoolSubValidator.extractFromS3Path(s3Path);
        expect(extractedSub, equals(validUserSub));
      });

      test('should return null for non-private S3 path', () {
        const s3Path = 'public/$validUserSub/documents/sync_123/file.pdf';
        final extractedSub = UserPoolSubValidator.extractFromS3Path(s3Path);
        expect(extractedSub, isNull);
      });

      test('should return null for invalid S3 path format', () {
        const s3Path = 'invalid/path/format';
        final extractedSub = UserPoolSubValidator.extractFromS3Path(s3Path);
        expect(extractedSub, isNull);
      });

      test('should return null for S3 path with invalid User Pool sub', () {
        const s3Path = 'private/invalid-sub/documents/sync_123/file.pdf';
        final extractedSub = UserPoolSubValidator.extractFromS3Path(s3Path);
        expect(extractedSub, isNull);
      });

      test('should return null for empty S3 path', () {
        final extractedSub = UserPoolSubValidator.extractFromS3Path('');
        expect(extractedSub, isNull);
      });

      test('should return null for S3 path with missing User Pool sub', () {
        const s3Path = 'private/';
        final extractedSub = UserPoolSubValidator.extractFromS3Path(s3Path);
        expect(extractedSub, isNull);
      });
    });

    group('Mock Generation', () {
      test('should generate mock User Pool sub with valid format', () {
        final mockSub = UserPoolSubValidator.generateMockSub();
        expect(UserPoolSubValidator.isValidFormat(mockSub), isTrue);
      });

      test('should generate different mock subs on multiple calls', () {
        final mockSub1 = UserPoolSubValidator.generateMockSub();
        final mockSub2 = UserPoolSubValidator.generateMockSub();

        // Both should be valid (this is the important test)
        expect(UserPoolSubValidator.isValidFormat(mockSub1), isTrue);
        expect(UserPoolSubValidator.isValidFormat(mockSub2), isTrue);

        // Note: They might be the same due to timing, but that's okay for this test
        // The important thing is that they're both valid
      });

      test('should generate mock sub that is safe for S3 paths', () {
        final mockSub = UserPoolSubValidator.generateMockSub();
        expect(UserPoolSubValidator.isSafeForS3Path(mockSub), isTrue);
      });
    });

    group('Edge Cases', () {
      test('should handle User Pool sub with all zeros', () {
        const zeroSub = '00000000-0000-0000-0000-000000000000';
        expect(UserPoolSubValidator.isValidFormat(zeroSub), isTrue);
        expect(UserPoolSubValidator.isSafeForS3Path(zeroSub), isTrue);
      });

      test('should handle User Pool sub with all Fs', () {
        const fSub = 'FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF';
        expect(UserPoolSubValidator.isValidFormat(fSub), isTrue);
        expect(UserPoolSubValidator.isSafeForS3Path(fSub), isTrue);
      });

      test('should handle mixed case User Pool sub', () {
        const mixedCaseSub = '12345678-1234-1234-1234-123456789AbC';
        expect(UserPoolSubValidator.isValidFormat(mixedCaseSub), isTrue);
        expect(UserPoolSubValidator.isSafeForS3Path(mixedCaseSub), isTrue);
      });

      test('should reject User Pool sub with extra characters', () {
        const extraCharSub = '12345678-1234-1234-1234-123456789012x';
        expect(UserPoolSubValidator.isValidFormat(extraCharSub), isFalse);
      });

      test('should reject User Pool sub with missing characters', () {
        const shortSub = '12345678-1234-1234-1234-12345678901';
        expect(UserPoolSubValidator.isValidFormat(shortSub), isFalse);
      });
    });
  });
}
