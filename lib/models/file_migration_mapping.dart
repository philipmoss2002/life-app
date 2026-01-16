import 'package:amplify_core/amplify_core.dart' as amplify_core;

/// Model representing a mapping between legacy file paths and new User Pool sub-based paths
/// Used during migration to track which files have been moved to the new structure
class FileMigrationMapping {
  final String id;
  final String legacyPath;
  final String newPath;
  final String userSub;
  final amplify_core.TemporalDateTime migratedAt;
  final bool verified;
  final String? syncId;
  final String? fileName;
  final String? errorMessage;

  FileMigrationMapping({
    required this.id,
    required this.legacyPath,
    required this.newPath,
    required this.userSub,
    required this.migratedAt,
    this.verified = false,
    this.syncId,
    this.fileName,
    this.errorMessage,
  });

  /// Create a new migration mapping
  factory FileMigrationMapping.create({
    required String legacyPath,
    required String newPath,
    required String userSub,
    String? syncId,
    String? fileName,
    bool verified = false,
  }) {
    return FileMigrationMapping(
      id: _generateId(),
      legacyPath: legacyPath,
      newPath: newPath,
      userSub: userSub,
      migratedAt: amplify_core.TemporalDateTime.now(),
      verified: verified,
      syncId: syncId,
      fileName: fileName,
    );
  }

  /// Create FileMigrationMapping from JSON
  factory FileMigrationMapping.fromJson(Map<String, dynamic> json) {
    return FileMigrationMapping(
      id: json['id'] as String,
      legacyPath: json['legacyPath'] as String,
      newPath: json['newPath'] as String,
      userSub: json['userSub'] as String,
      migratedAt: amplify_core.TemporalDateTime.fromString(
          json['migratedAt'] as String),
      verified: json['verified'] as bool? ?? false,
      syncId: json['syncId'] as String?,
      fileName: json['fileName'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  /// Convert FileMigrationMapping to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'legacyPath': legacyPath,
      'newPath': newPath,
      'userSub': userSub,
      'migratedAt': migratedAt.format(),
      'verified': verified,
      if (syncId != null) 'syncId': syncId,
      if (fileName != null) 'fileName': fileName,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  /// Convert to database map for SQLite storage
  Map<String, dynamic> toDatabaseMap() {
    return {
      'id': id,
      'user_sub': userSub,
      'legacy_path': legacyPath,
      'new_path': newPath,
      'migrated_at': migratedAt.format(),
      'verified': verified ? 1 : 0,
      'sync_id': syncId,
      'file_name': fileName,
      'error_message': errorMessage,
    };
  }

  /// Create from database map
  factory FileMigrationMapping.fromDatabaseMap(Map<String, dynamic> map) {
    return FileMigrationMapping(
      id: map['id'] as String,
      legacyPath: map['legacy_path'] as String,
      newPath: map['new_path'] as String,
      userSub: map['user_sub'] as String,
      migratedAt: amplify_core.TemporalDateTime.fromString(
          map['migrated_at'] as String),
      verified: (map['verified'] as int) == 1,
      syncId: map['sync_id'] as String?,
      fileName: map['file_name'] as String?,
      errorMessage: map['error_message'] as String?,
    );
  }

  /// Create a copy with updated fields
  FileMigrationMapping copyWith({
    String? id,
    String? legacyPath,
    String? newPath,
    String? userSub,
    amplify_core.TemporalDateTime? migratedAt,
    bool? verified,
    String? syncId,
    String? fileName,
    String? errorMessage,
  }) {
    return FileMigrationMapping(
      id: id ?? this.id,
      legacyPath: legacyPath ?? this.legacyPath,
      newPath: newPath ?? this.newPath,
      userSub: userSub ?? this.userSub,
      migratedAt: migratedAt ?? this.migratedAt,
      verified: verified ?? this.verified,
      syncId: syncId ?? this.syncId,
      fileName: fileName ?? this.fileName,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Mark as verified
  FileMigrationMapping markAsVerified() {
    return copyWith(verified: true);
  }

  /// Mark as failed with error message
  FileMigrationMapping markAsFailed(String error) {
    return copyWith(errorMessage: error, verified: false);
  }

  /// Check if migration was successful
  bool get isSuccessful => verified && errorMessage == null;

  /// Check if migration failed
  bool get isFailed => errorMessage != null;

  /// Get migration status as string
  String get status {
    if (isFailed) return 'failed';
    if (verified) return 'verified';
    return 'pending';
  }

  /// Extract sync ID from legacy path if possible
  String? extractSyncIdFromLegacyPath() {
    // Try to extract sync ID from various legacy path formats
    // Format: protected/{username}/documents/{syncId}/{filename}
    final parts = legacyPath.split('/');
    if (parts.length >= 4 && parts[2] == 'documents') {
      return parts[3];
    }
    return null;
  }

  /// Extract filename from legacy path
  String? extractFileNameFromLegacyPath() {
    final parts = legacyPath.split('/');
    if (parts.isNotEmpty) {
      final lastPart = parts.last;
      // Remove timestamp prefix if present
      final timestampMatch = RegExp(r'^\d+-(.+)$').firstMatch(lastPart);
      return timestampMatch?.group(1) ?? lastPart;
    }
    return null;
  }

  /// Validate the mapping
  bool validate() {
    // Check required fields
    if (id.isEmpty ||
        legacyPath.isEmpty ||
        newPath.isEmpty ||
        userSub.isEmpty) {
      return false;
    }

    // Check that new path uses private access level
    if (!newPath.startsWith('private/')) {
      return false;
    }

    // Check that new path contains the user sub
    if (!newPath.contains(userSub)) {
      return false;
    }

    return true;
  }

  /// Generate a unique ID for the mapping
  static String _generateId() {
    return 'migration_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  @override
  String toString() {
    return 'FileMigrationMapping(id: $id, legacyPath: $legacyPath, '
        'newPath: $newPath, userSub: $userSub, verified: $verified, '
        'status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FileMigrationMapping &&
        other.id == id &&
        other.legacyPath == legacyPath &&
        other.newPath == newPath &&
        other.userSub == userSub &&
        other.verified == verified;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      legacyPath,
      newPath,
      userSub,
      verified,
    );
  }
}
