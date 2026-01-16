/// Utility class for validating User Pool sub identifiers
/// Provides validation methods for AWS Cognito User Pool sub format
class UserPoolSubValidator {
  /// Validate User Pool sub format
  /// User Pool sub should be a UUID format (36 characters with hyphens)
  /// Example: 12345678-1234-1234-1234-123456789012
  static bool isValidFormat(String userSub) {
    if (userSub.isEmpty) return false;

    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(userSub);
  }

  /// Validate and sanitize User Pool sub
  /// Returns the sub if valid, throws exception if invalid
  static String validateAndSanitize(String userSub) {
    final trimmed = userSub.trim();

    if (!isValidFormat(trimmed)) {
      throw ArgumentError('Invalid User Pool sub format: $userSub');
    }

    return trimmed.toLowerCase(); // Normalize to lowercase
  }

  /// Check if User Pool sub is safe for use in S3 paths
  /// Ensures no path traversal or injection attacks
  static bool isSafeForS3Path(String userSub) {
    if (!isValidFormat(userSub)) return false;

    // Check for path traversal attempts
    if (userSub.contains('..') ||
        userSub.contains('/') ||
        userSub.contains('\\')) {
      return false;
    }

    return true;
  }

  /// Extract User Pool sub from S3 path
  /// Returns null if path doesn't contain a valid User Pool sub
  static String? extractFromS3Path(String s3Path) {
    final parts = s3Path.split('/');

    // Expected format: private/{userSub}/documents/...
    if (parts.length >= 2 && parts[0] == 'private') {
      final potentialSub = parts[1];
      return isValidFormat(potentialSub) ? potentialSub : null;
    }

    return null;
  }

  /// Generate a mock User Pool sub for testing
  /// DO NOT use in production - only for testing purposes
  static String generateMockSub() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '12345678-1234-1234-1234-${timestamp.toString().padLeft(12, '0').substring(0, 12)}';
  }
}
