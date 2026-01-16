import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/file_path.dart';
import '../models/file_migration_mapping.dart';
import 'user_pool_sub_validator.dart';
import '../services/log_service.dart' as app_log;

/// Comprehensive data integrity validator for persistent file access system
/// Validates User Pool sub format, file paths, and performs cleanup operations
class DataIntegrityValidator {
  static final DataIntegrityValidator _instance =
      DataIntegrityValidator._internal();
  factory DataIntegrityValidator() => _instance;
  DataIntegrityValidator._internal();

  final app_log.LogService _logService = app_log.LogService();

  // Helper methods for logging
  void _logInfo(String message) =>
      _logService.log(message, level: app_log.LogLevel.info);

  /// Validate User Pool sub format and consistency
  /// Checks if the User Pool sub follows the expected format and is consistent
  ///
  /// [userPoolSub] - The User Pool sub to validate
  ///
  /// Returns ValidationResult with details about the validation
  ValidationResult validateUserPoolSub(String userPoolSub) {
    _logInfo('🔍 DataIntegrityValidator: Validating User Pool sub format');

    final issues = <ValidationIssue>[];

    // Check if User Pool sub is empty
    if (userPoolSub.isEmpty) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.critical,
        field: 'userPoolSub',
        message: 'User Pool sub cannot be empty',
        suggestedFix: 'Re-authenticate user to obtain valid User Pool sub',
      ));
      return ValidationResult(isValid: false, issues: issues);
    }

    // Check User Pool sub format using existing validator
    if (!UserPoolSubValidator.isValidFormat(userPoolSub)) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.critical,
        field: 'userPoolSub',
        message: 'User Pool sub format is invalid: $userPoolSub',
        suggestedFix: 'Re-authenticate user to obtain valid User Pool sub',
      ));
    }

    // Check for suspicious characters or patterns
    if (userPoolSub.contains('..') || userPoolSub.contains('/')) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.security,
        field: 'userPoolSub',
        message: 'User Pool sub contains suspicious characters: $userPoolSub',
        suggestedFix: 'Reject this User Pool sub and re-authenticate',
      ));
    }

    // Check length constraints
    if (userPoolSub.length < 10) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.warning,
        field: 'userPoolSub',
        message:
            'User Pool sub is unusually short: ${userPoolSub.length} characters',
        suggestedFix: 'Verify User Pool sub authenticity',
      ));
    }

    if (userPoolSub.length > 100) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.warning,
        field: 'userPoolSub',
        message:
            'User Pool sub is unusually long: ${userPoolSub.length} characters',
        suggestedFix: 'Verify User Pool sub authenticity',
      ));
    }

    final isValid = issues
        .where((i) =>
            i.type == ValidationIssueType.critical ||
            i.type == ValidationIssueType.security)
        .isEmpty;

    _logInfo(isValid
        ? '✅ User Pool sub validation passed'
        : '❌ User Pool sub validation failed');
    return ValidationResult(isValid: isValid, issues: issues);
  }

  /// Validate file path format and structure
  /// Checks if the file path follows the expected S3 private access pattern
  ///
  /// [filePath] - The FilePath object to validate
  ///
  /// Returns ValidationResult with details about the validation
  ValidationResult validateFilePath(FilePath filePath) {
    _logInfo('🔍 DataIntegrityValidator: Validating file path structure');

    final issues = <ValidationIssue>[];

    // Validate User Pool sub in the path
    final userPoolSubResult = validateUserPoolSub(filePath.userSub);
    issues.addAll(userPoolSubResult.issues);

    // Check S3 key format
    if (!filePath.fullPath.startsWith('private/')) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.critical,
        field: 's3Key',
        message: 'S3 key must start with "private/" for private access level',
        suggestedFix: 'Regenerate S3 key with correct private access format',
      ));
    }

    // Check path structure: private/{userSub}/documents/{syncId}/{fileName}
    final pathParts = filePath.fullPath.split('/');
    if (pathParts.length != 5) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.critical,
        field: 's3Key',
        message:
            'S3 key has incorrect structure. Expected: private/{userSub}/documents/{syncId}/{fileName}',
        suggestedFix: 'Regenerate S3 key with correct structure',
      ));
    } else {
      // Validate each part
      if (pathParts[0] != 'private') {
        issues.add(ValidationIssue(
          type: ValidationIssueType.critical,
          field: 's3Key',
          message: 'S3 key must start with "private"',
          suggestedFix: 'Use private access level for S3 operations',
        ));
      }

      if (pathParts[2] != 'documents') {
        issues.add(ValidationIssue(
          type: ValidationIssueType.critical,
          field: 's3Key',
          message: 'S3 key must contain "documents" segment',
          suggestedFix: 'Use correct document path structure',
        ));
      }

      // Validate sync ID
      if (pathParts[3].isEmpty) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.critical,
          field: 'syncId',
          message: 'Sync ID cannot be empty',
          suggestedFix: 'Provide valid sync ID for file organization',
        ));
      }

      // Validate file name
      if (pathParts[4].isEmpty) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.critical,
          field: 'fileName',
          message: 'File name cannot be empty',
          suggestedFix: 'Provide valid file name',
        ));
      }
    }

    // Check for directory traversal attempts
    if (filePath.fullPath.contains('..')) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.security,
        field: 's3Key',
        message: 'S3 key contains directory traversal attempt',
        suggestedFix: 'Reject this path and regenerate with safe characters',
      ));
    }

    // Check for invalid characters
    final invalidChars = RegExp(r'[<>:"|?*\x00-\x1f]');
    if (invalidChars.hasMatch(filePath.fileName)) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.warning,
        field: 'fileName',
        message: 'File name contains invalid characters',
        suggestedFix: 'Sanitize file name by removing invalid characters',
      ));
    }

    final isValid = issues
        .where((i) =>
            i.type == ValidationIssueType.critical ||
            i.type == ValidationIssueType.security)
        .isEmpty;

    _logInfo(isValid
        ? '✅ File path validation passed'
        : '❌ File path validation failed');
    return ValidationResult(isValid: isValid, issues: issues);
  }

  /// Validate and correct file path if possible
  /// Attempts to fix common issues in file paths
  ///
  /// [filePath] - The FilePath object to validate and correct
  ///
  /// Returns CorrectionResult with the corrected path or error details
  CorrectionResult validateAndCorrectFilePath(FilePath filePath) {
    _logInfo('🔧 DataIntegrityValidator: Validating and correcting file path');

    final validationResult = validateFilePath(filePath);

    if (validationResult.isValid) {
      return CorrectionResult(
        isValid: true,
        correctedPath: filePath,
        appliedFixes: [],
      );
    }

    final appliedFixes = <String>[];
    var correctedPath = filePath;

    // Try to fix critical issues
    for (final issue in validationResult.issues) {
      if (issue.type == ValidationIssueType.critical ||
          issue.type == ValidationIssueType.security) {
        switch (issue.field) {
          case 'fileName':
            if (issue.message.contains('invalid characters')) {
              // Sanitize file name
              final sanitizedName = _sanitizeFileName(filePath.fileName);
              correctedPath = FilePath.create(
                userSub: correctedPath.userSub,
                syncId: correctedPath.syncId,
                fileName: sanitizedName,
                timestamp: correctedPath.timestamp,
              );
              appliedFixes.add(
                  'Sanitized file name: ${filePath.fileName} -> $sanitizedName');
            }
            break;

          case 's3Key':
            if (issue.message.contains('directory traversal')) {
              // Remove directory traversal attempts
              final safePath = filePath.fullPath.replaceAll('..', '');
              try {
                correctedPath = FilePath.fromS3Key(safePath);
                appliedFixes
                    .add('Removed directory traversal attempts from S3 key');
              } catch (e) {
                // If parsing fails, we can't correct this path
                return CorrectionResult(
                  isValid: false,
                  correctedPath: filePath,
                  appliedFixes: appliedFixes,
                  error:
                      'Cannot correct S3 key with directory traversal: ${e.toString()}',
                );
              }
            }
            break;
        }
      }
    }

    // Re-validate the corrected path
    final correctedValidation = validateFilePath(correctedPath);

    return CorrectionResult(
      isValid: correctedValidation.isValid,
      correctedPath: correctedPath,
      appliedFixes: appliedFixes,
      error: correctedValidation.isValid
          ? null
          : 'Could not correct all validation issues',
    );
  }

  /// Validate migration mapping for consistency
  /// Ensures migration mappings are valid and consistent
  ///
  /// [mapping] - The FileMigrationMapping to validate
  ///
  /// Returns ValidationResult with details about the validation
  ValidationResult validateMigrationMapping(FileMigrationMapping mapping) {
    _logInfo('🔍 DataIntegrityValidator: Validating migration mapping');

    final issues = <ValidationIssue>[];

    // Validate User Pool sub
    final userPoolSubResult = validateUserPoolSub(mapping.userSub);
    issues.addAll(userPoolSubResult.issues);

    // Validate legacy path format
    if (mapping.legacyPath.isEmpty) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.critical,
        field: 'legacyPath',
        message: 'Legacy path cannot be empty',
        suggestedFix: 'Provide valid legacy path for migration',
      ));
    }

    // Validate new path format
    try {
      final newFilePath = FilePath.fromS3Key(mapping.newPath);
      final newPathResult = validateFilePath(newFilePath);
      issues.addAll(newPathResult.issues);
    } catch (e) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.critical,
        field: 'newPath',
        message: 'New path format is invalid: ${e.toString()}',
        suggestedFix: 'Regenerate new path with correct format',
      ));
    }

    // Check consistency between file names
    final legacyFileName = mapping.legacyPath.split('/').last;
    if (legacyFileName != mapping.fileName) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.warning,
        field: 'fileName',
        message: 'File name inconsistency between legacy path and mapping',
        suggestedFix: 'Ensure file name matches across legacy and new paths',
      ));
    }

    final isValid = issues
        .where((i) =>
            i.type == ValidationIssueType.critical ||
            i.type == ValidationIssueType.security)
        .isEmpty;

    _logInfo(isValid
        ? '✅ Migration mapping validation passed'
        : '❌ Migration mapping validation failed');
    return ValidationResult(isValid: isValid, issues: issues);
  }

  /// Perform automatic cleanup of invalid file references
  /// Identifies and removes invalid file references from the system
  ///
  /// [fileReferences] - List of file paths to validate and clean up
  ///
  /// Returns CleanupResult with details about the cleanup operation
  Future<CleanupResult> performAutomaticCleanup(
      List<String> fileReferences) async {
    _logInfo(
        '🧹 DataIntegrityValidator: Starting automatic cleanup of ${fileReferences.length} file references');

    final validReferences = <String>[];
    final invalidReferences = <String>[];
    final cleanupActions = <String>[];

    for (final reference in fileReferences) {
      try {
        // Try to parse as FilePath
        final filePath = FilePath.fromS3Key(reference);
        final validationResult = validateFilePath(filePath);

        if (validationResult.isValid) {
          validReferences.add(reference);
        } else {
          // Check if we can correct the path
          final correctionResult = validateAndCorrectFilePath(filePath);

          if (correctionResult.isValid) {
            validReferences.add(correctionResult.correctedPath.fullPath);
            cleanupActions.add(
                'Corrected path: $reference -> ${correctionResult.correctedPath.fullPath}');
          } else {
            invalidReferences.add(reference);
            cleanupActions.add(
                'Marked for removal: $reference (${correctionResult.error ?? 'validation failed'})');
          }
        }
      } catch (e) {
        invalidReferences.add(reference);
        cleanupActions.add(
            'Marked for removal: $reference (parsing failed: ${e.toString()})');
      }
    }

    _logInfo(
        '🧹 Cleanup completed: ${validReferences.length} valid, ${invalidReferences.length} invalid');

    return CleanupResult(
      totalReferences: fileReferences.length,
      validReferences: validReferences,
      invalidReferences: invalidReferences,
      cleanupActions: cleanupActions,
    );
  }

  /// Sanitize file name by removing invalid characters
  String _sanitizeFileName(String fileName) {
    // Remove invalid characters and replace with underscores
    final invalidChars = RegExp(r'[<>:"|?*\x00-\x1f/\\]');
    var sanitized = fileName.replaceAll(invalidChars, '_');

    // Remove multiple consecutive underscores
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');

    // Remove leading/trailing underscores
    sanitized = sanitized.replaceAll(RegExp(r'^_+|_+$'), '');

    // Ensure we have a valid file name
    if (sanitized.isEmpty) {
      sanitized = 'sanitized_file';
    }

    return sanitized;
  }

  /// Validate current user's authentication state and User Pool sub consistency
  /// Checks if the current user's authentication is valid and consistent
  ///
  /// Returns ValidationResult with authentication validation details
  Future<ValidationResult> validateCurrentUserAuthentication() async {
    _logInfo(
        '🔍 DataIntegrityValidator: Validating current user authentication');

    final issues = <ValidationIssue>[];

    try {
      // Get current authenticated user
      final user = await Amplify.Auth.getCurrentUser();
      final userPoolSub = user.userId;

      // Validate User Pool sub
      final userPoolSubResult = validateUserPoolSub(userPoolSub);
      issues.addAll(userPoolSubResult.issues);

      // Check if user attributes are consistent
      try {
        final attributes = await Amplify.Auth.fetchUserAttributes();
        final subAttribute = attributes.firstWhere(
          (attr) => attr.userAttributeKey == AuthUserAttributeKey.sub,
          orElse: () => throw Exception('Sub attribute not found'),
        );

        if (subAttribute.value != userPoolSub) {
          issues.add(ValidationIssue(
            type: ValidationIssueType.critical,
            field: 'userAuthentication',
            message:
                'User Pool sub inconsistency between user ID and attributes',
            suggestedFix: 'Re-authenticate user to resolve inconsistency',
          ));
        }
      } catch (e) {
        issues.add(ValidationIssue(
          type: ValidationIssueType.warning,
          field: 'userAttributes',
          message:
              'Could not fetch user attributes for validation: ${e.toString()}',
          suggestedFix: 'Check network connectivity and user permissions',
        ));
      }
    } on AuthException catch (e) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.critical,
        field: 'userAuthentication',
        message: 'User authentication failed: ${e.message}',
        suggestedFix: 'Re-authenticate user',
      ));
    } catch (e) {
      issues.add(ValidationIssue(
        type: ValidationIssueType.critical,
        field: 'userAuthentication',
        message: 'Authentication validation error: ${e.toString()}',
        suggestedFix:
            'Check authentication state and re-authenticate if needed',
      ));
    }

    final isValid = issues
        .where((i) =>
            i.type == ValidationIssueType.critical ||
            i.type == ValidationIssueType.security)
        .isEmpty;

    _logInfo(isValid
        ? '✅ User authentication validation passed'
        : '❌ User authentication validation failed');
    return ValidationResult(isValid: isValid, issues: issues);
  }
}

/// Types of validation issues
enum ValidationIssueType {
  critical, // Must be fixed for system to work
  security, // Security-related issues
  warning, // Should be addressed but not critical
  info, // Informational only
}

/// Represents a validation issue found during data integrity checks
class ValidationIssue {
  final ValidationIssueType type;
  final String field;
  final String message;
  final String suggestedFix;

  ValidationIssue({
    required this.type,
    required this.field,
    required this.message,
    required this.suggestedFix,
  });

  @override
  String toString() =>
      '${type.name.toUpperCase()}: $field - $message (Fix: $suggestedFix)';
}

/// Result of a validation operation
class ValidationResult {
  final bool isValid;
  final List<ValidationIssue> issues;

  ValidationResult({
    required this.isValid,
    required this.issues,
  });

  /// Get issues by type
  List<ValidationIssue> getIssuesByType(ValidationIssueType type) {
    return issues.where((issue) => issue.type == type).toList();
  }

  /// Check if there are critical issues
  bool get hasCriticalIssues => issues.any((issue) =>
      issue.type == ValidationIssueType.critical ||
      issue.type == ValidationIssueType.security);
}

/// Result of a path correction operation
class CorrectionResult {
  final bool isValid;
  final FilePath correctedPath;
  final List<String> appliedFixes;
  final String? error;

  CorrectionResult({
    required this.isValid,
    required this.correctedPath,
    required this.appliedFixes,
    this.error,
  });
}

/// Result of an automatic cleanup operation
class CleanupResult {
  final int totalReferences;
  final List<String> validReferences;
  final List<String> invalidReferences;
  final List<String> cleanupActions;

  CleanupResult({
    required this.totalReferences,
    required this.validReferences,
    required this.invalidReferences,
    required this.cleanupActions,
  });

  /// Get cleanup summary
  String get summary =>
      'Processed $totalReferences references: ${validReferences.length} valid, ${invalidReferences.length} invalid';
}
