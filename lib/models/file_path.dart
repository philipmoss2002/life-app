import 'package:amplify_core/amplify_core.dart' as amplify_core;

/// Exception thrown when file path validation fails
class FilePathValidationException implements Exception {
  final String message;
  FilePathValidationException(this.message);

  @override
  String toString() => 'FilePathValidationException: $message';
}

/// Model representing a file path with User Pool sub-based structure
/// Follows AWS best practices using S3 private access level
/// Path format: private/{userSub}/documents/{syncId}/{timestamp}-{fileName}
class FilePath {
  final String userSub;
  final String syncId;
  final String fileName;
  final String fullPath;
  final amplify_core.TemporalDateTime createdAt;
  final bool isLegacy;
  final int? timestamp;

  FilePath({
    required this.userSub,
    required this.syncId,
    required this.fileName,
    required this.fullPath,
    required this.createdAt,
    this.isLegacy = false,
    this.timestamp,
  });

  /// Generate S3 key using private access level
  /// Format: private/{userSub}/documents/{syncId}/{timestamp}-{fileName}
  String get s3Key {
    final timestampPrefix = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final sanitizedFileName = _sanitizeFileName(fileName);
    return 'private/$userSub/documents/$syncId/$timestampPrefix-$sanitizedFileName';
  }

  /// Generate S3 key without timestamp (for legacy compatibility)
  String get s3KeyWithoutTimestamp {
    final sanitizedFileName = _sanitizeFileName(fileName);
    return 'private/$userSub/documents/$syncId/$sanitizedFileName';
  }

  /// Get the directory path (without filename)
  String get directoryPath => 'private/$userSub/documents/$syncId';

  /// Check if this is a valid User Pool sub format
  bool get isValidUserPoolSub => _isValidUserPoolSubFormat(userSub);

  /// Create FilePath from S3 key
  /// Parses an existing S3 key to extract components
  factory FilePath.fromS3Key(String s3Key, {bool isLegacy = false}) {
    final parts = s3Key.split('/');

    if (parts.length < 4) {
      throw FilePathValidationException('Invalid S3 key format: $s3Key');
    }

    if (parts[0] != 'private') {
      throw FilePathValidationException(
          'S3 key must use private access level: $s3Key');
    }

    final userSub = parts[1];
    final syncId = parts[3];
    final fileNameWithTimestamp =
        parts.sublist(4).join('/'); // Handle nested paths

    // Extract timestamp and filename
    String fileName;
    int? timestamp;

    final timestampMatch =
        RegExp(r'^(\d+)-(.+)$').firstMatch(fileNameWithTimestamp);
    if (timestampMatch != null) {
      timestamp = int.tryParse(timestampMatch.group(1)!);
      fileName = timestampMatch.group(2)!;
    } else {
      fileName = fileNameWithTimestamp;
    }

    return FilePath(
      userSub: userSub,
      syncId: syncId,
      fileName: fileName,
      fullPath: s3Key,
      createdAt: amplify_core.TemporalDateTime.now(),
      isLegacy: isLegacy,
      timestamp: timestamp,
    );
  }

  /// Create FilePath from components
  factory FilePath.create({
    required String userSub,
    required String syncId,
    required String fileName,
    bool isLegacy = false,
    int? timestamp,
  }) {
    // Validate inputs
    if (!_isValidUserPoolSubFormat(userSub)) {
      throw FilePathValidationException(
          'Invalid User Pool sub format: $userSub');
    }

    if (syncId.isEmpty) {
      throw FilePathValidationException('Sync ID cannot be empty');
    }

    if (fileName.isEmpty) {
      throw FilePathValidationException('File name cannot be empty');
    }

    final timestampValue = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final sanitizedFileName = _sanitizeFileName(fileName);
    final fullPath =
        'private/$userSub/documents/$syncId/$timestampValue-$sanitizedFileName';

    return FilePath(
      userSub: userSub,
      syncId: syncId,
      fileName: fileName,
      fullPath: fullPath,
      createdAt: amplify_core.TemporalDateTime.now(),
      isLegacy: isLegacy,
      timestamp: timestampValue,
    );
  }

  /// Create FilePath from JSON
  factory FilePath.fromJson(Map<String, dynamic> json) {
    return FilePath(
      userSub: json['userSub'] as String,
      syncId: json['syncId'] as String,
      fileName: json['fileName'] as String,
      fullPath: json['fullPath'] as String,
      createdAt:
          amplify_core.TemporalDateTime.fromString(json['createdAt'] as String),
      isLegacy: json['isLegacy'] as bool? ?? false,
      timestamp: json['timestamp'] as int?,
    );
  }

  /// Convert FilePath to JSON
  Map<String, dynamic> toJson() {
    return {
      'userSub': userSub,
      'syncId': syncId,
      'fileName': fileName,
      'fullPath': fullPath,
      'createdAt': createdAt.format(),
      'isLegacy': isLegacy,
      if (timestamp != null) 'timestamp': timestamp,
    };
  }

  /// Create a copy of this FilePath with updated fields
  FilePath copyWith({
    String? userSub,
    String? syncId,
    String? fileName,
    String? fullPath,
    amplify_core.TemporalDateTime? createdAt,
    bool? isLegacy,
    int? timestamp,
  }) {
    return FilePath(
      userSub: userSub ?? this.userSub,
      syncId: syncId ?? this.syncId,
      fileName: fileName ?? this.fileName,
      fullPath: fullPath ?? this.fullPath,
      createdAt: createdAt ?? this.createdAt,
      isLegacy: isLegacy ?? this.isLegacy,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Validate User Pool sub format
  /// User Pool sub should be a UUID format
  static bool _isValidUserPoolSubFormat(String userSub) {
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(userSub);
  }

  /// Sanitize filename to be S3-safe
  /// Removes or replaces characters that could cause issues in S3 keys
  static String _sanitizeFileName(String fileName) {
    // Replace spaces and special characters with underscores
    // Keep alphanumeric, dots, hyphens, and underscores
    return fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  /// Validate the complete file path structure
  bool validate() {
    try {
      // Check User Pool sub format
      if (!isValidUserPoolSub) {
        return false;
      }

      // Check sync ID is not empty
      if (syncId.isEmpty) {
        return false;
      }

      // Check filename is not empty
      if (fileName.isEmpty) {
        return false;
      }

      // Check full path matches expected format
      if (!fullPath.startsWith('private/$userSub/documents/$syncId/')) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  String toString() {
    return 'FilePath(userSub: $userSub, syncId: $syncId, fileName: $fileName, '
        'fullPath: $fullPath, isLegacy: $isLegacy, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilePath &&
        other.userSub == userSub &&
        other.syncId == syncId &&
        other.fileName == fileName &&
        other.fullPath == fullPath &&
        other.isLegacy == isLegacy &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(
      userSub,
      syncId,
      fileName,
      fullPath,
      isLegacy,
      timestamp,
    );
  }
}
