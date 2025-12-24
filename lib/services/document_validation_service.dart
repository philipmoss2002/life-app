import '../models/Document.dart';
import '../constants/document_categories.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

import 'package:amplify_core/amplify_core.dart' as amplify_core;

/// Exception thrown when document validation fails
class DocumentValidationException implements Exception {
  final String message;
  final List<String> validationErrors;

  DocumentValidationException({
    required this.message,
    required this.validationErrors,
  });

  @override
  String toString() =>
      'DocumentValidationException: $message\nErrors: ${validationErrors.join(', ')}';
}

/// Service for validating document data before upload/update operations
/// Ensures data integrity and prevents invalid data from being stored
class DocumentValidationService {
  static final DocumentValidationService _instance =
      DocumentValidationService._internal();
  factory DocumentValidationService() => _instance;
  DocumentValidationService._internal();

  // Field length limits
  static const int maxTitleLength = 255;
  static const int maxCategoryLength = 100;
  static const int maxNotesLength = 10000;
  static const int maxFilePathLength = 500;
  static const int maxFilePathsCount = 50;
  static const int maxUserIdLength = 255;

  /// Validate a document before upload
  /// Throws DocumentValidationException if validation fails
  void validateDocumentForUpload(Document document) {
    final errors = <String>[];

    // Validate required fields
    errors.addAll(_validateRequiredFields(document));

    // Validate data types and formats
    errors.addAll(_validateDataTypes(document));

    // Validate field lengths
    errors.addAll(_validateFieldLengths(document));

    // Validate business rules
    errors.addAll(_validateBusinessRules(document));

    if (errors.isNotEmpty) {
      throw DocumentValidationException(
        message: 'Document validation failed for upload',
        validationErrors: errors,
      );
    }
  }

  /// Validate a document before update
  /// Throws DocumentValidationException if validation fails
  void validateDocumentForUpdate(Document document) {
    final errors = <String>[];

    // Validate required fields (including ID for updates)
    errors.addAll(_validateRequiredFields(document, isUpdate: true));

    // Validate data types and formats
    errors.addAll(_validateDataTypes(document));

    // Validate field lengths
    errors.addAll(_validateFieldLengths(document));

    // Validate business rules
    errors.addAll(_validateBusinessRules(document));

    // Validate update-specific rules
    errors.addAll(_validateUpdateRules(document));

    if (errors.isNotEmpty) {
      throw DocumentValidationException(
        message: 'Document validation failed for update',
        validationErrors: errors,
      );
    }
  }

  /// Validate required fields are present and not empty
  List<String> _validateRequiredFields(Document document,
      {bool isUpdate = false}) {
    final errors = <String>[];

    // ID is required for updates
    if (isUpdate && document.syncId.isEmpty) {
      errors.add('Document ID is required for updates');
    }

    // UserId is always required
    if (document.userId.isEmpty) {
      errors.add('User ID is required');
    }

    // Title is required
    if (document.title.isEmpty) {
      errors.add('Title is required');
    }

    // Category is required
    if (document.category.isEmpty) {
      errors.add('Category is required');
    }

    // FilePaths is required (can be empty list but not null)
    try {
      final filePaths = document.filePaths;
      // Just accessing it to trigger the null check
    } catch (e) {
      errors.add('File paths list is required');
    }

    // CreatedAt is required
    try {
      final createdAt = document.createdAt;
      // Just accessing it to trigger the null check
    } catch (e) {
      errors.add('Created date is required');
    }

    // LastModified is required
    try {
      final lastModified = document.lastModified;
      // Just accessing it to trigger the null check
    } catch (e) {
      errors.add('Last modified date is required');
    }

    // Version is required
    try {
      final version = document.version;
      // Just accessing it to trigger the null check
    } catch (e) {
      errors.add('Version is required');
    }

    // SyncState is required
    if (document.syncState.isEmpty) {
      errors.add('Sync state is required');
    }

    return errors;
  }

  /// Validate data types and formats
  List<String> _validateDataTypes(Document document) {
    final errors = <String>[];

    // Validate version is non-negative
    try {
      if (document.version < 0) {
        errors.add('Version must be non-negative');
      }
    } catch (e) {
      // Already handled in required fields validation
    }

    // Validate dates are not in the future (except renewalDate)
    try {
      final now = amplify_core.TemporalDateTime.now();
      if (document.createdAt.compareTo(now) > 0) {
        errors.add('Created date cannot be in the future');
      }
      if (document.lastModified.compareTo(now) > 0) {
        errors.add('Last modified date cannot be in the future');
      }
    } catch (e) {
      // Date validation errors
      errors.add('Invalid date format detected');
    }

    // Validate lastModified is not before createdAt
    try {
      if (document.lastModified.compareTo(document.createdAt) < 0) {
        errors.add('Last modified date cannot be before created date');
      }
    } catch (e) {
      // Already handled above
    }

    // Validate file paths format
    try {
      for (final filePath in document.filePaths) {
        if (filePath.isEmpty) {
          errors.add('File paths cannot contain empty strings');
          break;
        }
        // Basic path validation - no null bytes or control characters
        if (filePath.contains('\x00') ||
            filePath.contains('\n') ||
            filePath.contains('\r')) {
          errors.add('File paths contain invalid characters');
          break;
        }
      }
    } catch (e) {
      // Already handled in required fields validation
    }

    return errors;
  }

  /// Validate field lengths
  List<String> _validateFieldLengths(Document document) {
    final errors = <String>[];

    // Validate title length
    if (document.title.length > maxTitleLength) {
      errors.add('Title exceeds maximum length of $maxTitleLength characters');
    }

    // Validate category length
    if (document.category.length > maxCategoryLength) {
      errors.add(
          'Category exceeds maximum length of $maxCategoryLength characters');
    }

    // Validate userId length
    if (document.userId.length > maxUserIdLength) {
      errors
          .add('User ID exceeds maximum length of $maxUserIdLength characters');
    }

    // Validate notes length (if present)
    final notes = document.notes;
    if (notes != null && notes.length > maxNotesLength) {
      errors.add('Notes exceed maximum length of $maxNotesLength characters');
    }

    // Validate file paths count and individual lengths
    try {
      final filePaths = document.filePaths;
      if (filePaths.length > maxFilePathsCount) {
        errors.add('Too many file paths (maximum $maxFilePathsCount allowed)');
      }

      for (final filePath in filePaths) {
        if (filePath.length > maxFilePathLength) {
          errors.add(
              'File path exceeds maximum length of $maxFilePathLength characters');
          break;
        }
      }
    } catch (e) {
      // Already handled in required fields validation
    }

    return errors;
  }

  /// Validate business rules
  List<String> _validateBusinessRules(Document document) {
    final errors = <String>[];

    // Validate category is from allowed list
    if (!DocumentCategories.isValid(document.category)) {
      errors
          .add('Category must be one of: ${DocumentCategories.all.join(', ')}');
    }

    // Validate renewal date is in the future (if present)
    final renewalDate = document.renewalDate;
    if (renewalDate != null) {
      final now = amplify_core.TemporalDateTime.now();
      if (renewalDate.compareTo(now) <= 0) {
        errors.add('Renewal date must be in the future');
      }
    }

    // Validate deleted flag consistency
    final deleted = document.deleted;
    final deletedAt = document.deletedAt;

    if (deleted == true && deletedAt == null) {
      errors.add('Deleted documents must have a deletion timestamp');
    }

    if (deleted != true && deletedAt != null) {
      errors.add('Non-deleted documents cannot have a deletion timestamp');
    }

    return errors;
  }

  /// Validate update-specific rules
  List<String> _validateUpdateRules(Document document) {
    final errors = <String>[];

    // Version must be positive for updates
    try {
      if (document.version <= 0) {
        errors.add('Version must be positive for document updates');
      }
    } catch (e) {
      // Already handled in required fields validation
    }

    return errors;
  }

  /// Sanitize user input to prevent XSS and injection attacks
  String sanitizeTextInput(String input) {
    if (input.isEmpty) return input;

    // Remove null bytes and control characters except newlines and tabs
    String sanitized =
        input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

    // Trim whitespace
    sanitized = sanitized.trim();

    // Basic HTML entity encoding for common XSS vectors
    sanitized = sanitized
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;')
        .replaceAll('/', '&#x2F;');

    return sanitized;
  }

  /// Sanitize a document's text fields
  Document sanitizeDocument(Document document) {
    return document.copyWith(
      title: sanitizeTextInput(document.title),
      category: sanitizeTextInput(document.category),
      notes: document.notes != null ? sanitizeTextInput(document.notes!) : null,
      filePaths:
          document.filePaths.map((path) => sanitizeTextInput(path)).toList(),
    );
  }

  /// Validate downloaded document structure
  /// Ensures received data matches expected format
  void validateDownloadedDocument(Map<String, dynamic> data) {
    final errors = <String>[];

    // Check required fields exist
    final requiredFields = [
      'userId',
      'title',
      'category',
      'filePaths',
      'createdAt',
      'lastModified',
      'version',
      'syncState'
    ];

    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field] == null) {
        errors.add('Missing required field: $field');
      }
    }

    // Validate data types
    if (data.containsKey('version') && data['version'] is! int) {
      errors.add('Version must be an integer');
    }

    if (data.containsKey('filePaths') && data['filePaths'] is! List) {
      errors.add('FilePaths must be a list');
    }

    if (data.containsKey('deleted') &&
        data['deleted'] != null &&
        data['deleted'] is! bool) {
      errors.add('Deleted flag must be a boolean');
    }

    // Validate date formats
    final dateFields = [
      'createdAt',
      'lastModified',
      'renewalDate',
      'deletedAt'
    ];
    for (final field in dateFields) {
      if (data.containsKey(field) && data[field] != null) {
        try {
          amplify_core.TemporalDateTime.fromString(data[field]);
        } catch (e) {
          errors.add('Invalid date format for field: $field');
        }
      }
    }

    if (errors.isNotEmpty) {
      throw DocumentValidationException(
        message: 'Downloaded document validation failed',
        validationErrors: errors,
      );
    }
  }
}
