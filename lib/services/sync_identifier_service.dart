import '../utils/sync_identifier_generator.dart';

/// Service for managing sync identifier operations and validation
///
/// This service provides higher-level operations for sync identifiers,
/// including validation, duplicate detection, and error handling.
class SyncIdentifierService {
  /// Validate sync identifier and throw exception if invalid
  ///
  /// Throws [ArgumentError] if the sync identifier is invalid.
  /// This method should be used when validation failure should stop execution.
  static void validateOrThrow(String syncId, {String? context}) {
    if (!SyncIdentifierGenerator.isValid(syncId)) {
      final contextMsg = context != null ? ' in $context' : '';
      throw ArgumentError(
          'Invalid sync identifier format: "$syncId"$contextMsg. '
          'Expected UUID v4 format (e.g., "550e8400-e29b-41d4-a716-446655440000")');
    }
  }

  /// Generate a new sync identifier with validation
  ///
  /// Generates a new UUID v4 sync identifier and validates it before returning.
  /// This provides an extra safety check to ensure generated IDs are valid.
  static String generateValidated() {
    final syncId = SyncIdentifierGenerator.generate();
    validateOrThrow(syncId, context: 'generation');
    return syncId;
  }

  /// Check if sync identifier is in the correct format for storage
  ///
  /// Returns true if the sync identifier is valid and normalized (lowercase).
  /// This method can be used before storing sync identifiers to ensure consistency.
  static bool isStorageReady(String syncId) {
    return SyncIdentifierGenerator.isValid(syncId) &&
        syncId == SyncIdentifierGenerator.normalize(syncId);
  }

  /// Prepare sync identifier for storage
  ///
  /// Validates and normalizes the sync identifier for storage.
  /// Returns the normalized sync identifier if valid.
  /// Throws [ArgumentError] if the sync identifier is invalid.
  static String prepareForStorage(String syncId, {String? context}) {
    final normalized = SyncIdentifierGenerator.validateAndNormalize(syncId);
    if (normalized == null) {
      final contextMsg = context != null ? ' in $context' : '';
      throw ArgumentError(
          'Invalid sync identifier format: "$syncId"$contextMsg. '
          'Expected UUID v4 format (e.g., "550e8400-e29b-41d4-a716-446655440000")');
    }
    return normalized;
  }

  /// Validate a collection of sync identifiers
  ///
  /// Checks if all sync identifiers in the collection are valid and unique.
  /// Returns a [ValidationResult] with details about any issues found.
  static ValidationResult validateCollection(List<String> syncIds) {
    final List<String> invalid = [];
    final List<String> duplicates = [];
    final Set<String> seen = {};
    int validCount = 0;

    for (final syncId in syncIds) {
      if (!SyncIdentifierGenerator.isValid(syncId)) {
        invalid.add(syncId);
        continue;
      }

      final normalized = SyncIdentifierGenerator.normalize(syncId);
      if (seen.contains(normalized)) {
        duplicates.add(syncId);
      } else {
        seen.add(normalized);
        validCount++; // Only count as valid if it's not a duplicate
      }
    }

    return ValidationResult(
      isValid: invalid.isEmpty && duplicates.isEmpty,
      invalidIds: invalid,
      duplicateIds: duplicates,
      totalCount: syncIds.length,
      validCount: validCount,
    );
  }
}

/// Result of sync identifier collection validation
class ValidationResult {
  final bool isValid;
  final List<String> invalidIds;
  final List<String> duplicateIds;
  final int totalCount;
  final int validCount;

  const ValidationResult({
    required this.isValid,
    required this.invalidIds,
    required this.duplicateIds,
    required this.totalCount,
    required this.validCount,
  });

  /// Get a human-readable summary of validation results
  String get summary {
    if (isValid) {
      return 'All $totalCount sync identifiers are valid and unique';
    }

    final issues = <String>[];
    if (invalidIds.isNotEmpty) {
      issues.add('${invalidIds.length} invalid format(s)');
    }
    if (duplicateIds.isNotEmpty) {
      issues.add('${duplicateIds.length} duplicate(s)');
    }

    return 'Found issues in $totalCount sync identifiers: ${issues.join(', ')}. '
        '$validCount are valid.';
  }

  @override
  String toString() => summary;
}
