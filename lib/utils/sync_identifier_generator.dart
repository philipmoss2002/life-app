import 'package:uuid/uuid.dart';

/// Generator and validator for universal sync identifiers
///
/// This class provides methods to generate UUID v4 sync identifiers
/// and validate their format. Sync identifiers are used to uniquely
/// identify documents across local and remote storage systems.
class SyncIdentifierGenerator {
  static const Uuid _uuid = Uuid();

  /// Regular expression for validating UUID v4 format
  /// Matches lowercase UUID v4 with hyphens
  static final RegExp _uuidV4Regex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  /// Generate a new UUID v4 sync identifier
  ///
  /// Returns a cryptographically secure UUID v4 string in lowercase
  /// format with hyphens (e.g., "550e8400-e29b-41d4-a716-446655440000")
  static String generate() {
    return _uuid.v4().toLowerCase();
  }

  /// Validate sync identifier format
  ///
  /// Checks if the provided [syncId] is a valid UUID v4 format.
  /// Returns true if valid, false otherwise.
  ///
  /// Example:
  /// ```dart
  /// bool valid = SyncIdentifierGenerator.isValid("550e8400-e29b-41d4-a716-446655440000");
  /// // valid == true
  /// ```
  static bool isValid(String syncId) {
    if (syncId.isEmpty) return false;
    return _uuidV4Regex.hasMatch(syncId.toLowerCase());
  }

  /// Normalize sync identifier format
  ///
  /// Converts the sync identifier to lowercase format.
  /// This ensures consistent storage and comparison of sync identifiers.
  ///
  /// Example:
  /// ```dart
  /// String normalized = SyncIdentifierGenerator.normalize("550E8400-E29B-41D4-A716-446655440000");
  /// // normalized == "550e8400-e29b-41d4-a716-446655440000"
  /// ```
  static String normalize(String syncId) {
    return syncId.toLowerCase();
  }

  /// Validate and normalize sync identifier
  ///
  /// Combines validation and normalization in a single operation.
  /// Returns the normalized sync identifier if valid, null otherwise.
  ///
  /// Example:
  /// ```dart
  /// String? result = SyncIdentifierGenerator.validateAndNormalize("550E8400-E29B-41D4-A716-446655440000");
  /// // result == "550e8400-e29b-41d4-a716-446655440000"
  /// ```
  static String? validateAndNormalize(String syncId) {
    final normalized = normalize(syncId);
    return isValid(normalized) ? normalized : null;
  }
}
