/// File attachment model for authentication and sync rewrite
///
/// Represents a file attached to a document.
class FileAttachment {
  final String fileName;
  final String? localPath;
  final String? s3Key;
  final int? fileSize;
  final DateTime addedAt;

  FileAttachment({
    required this.fileName,
    this.localPath,
    this.s3Key,
    this.fileSize,
    required this.addedAt,
  });

  /// Create a copy with updated fields
  FileAttachment copyWith({
    String? fileName,
    String? localPath,
    String? s3Key,
    int? fileSize,
    DateTime? addedAt,
  }) {
    return FileAttachment(
      fileName: fileName ?? this.fileName,
      localPath: localPath ?? this.localPath,
      s3Key: s3Key ?? this.s3Key,
      fileSize: fileSize ?? this.fileSize,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'localPath': localPath,
      's3Key': s3Key,
      'fileSize': fileSize,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  /// Create from JSON map
  factory FileAttachment.fromJson(Map<String, dynamic> json) {
    return FileAttachment(
      fileName: json['fileName'] as String,
      localPath: json['localPath'] as String?,
      s3Key: json['s3Key'] as String?,
      fileSize: json['fileSize'] as int?,
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }

  /// Convert to database map (for SQLite)
  Map<String, dynamic> toDatabase(String syncId) {
    return {
      'sync_id': syncId,
      'file_name': fileName,
      'local_path': localPath,
      's3_key': s3Key,
      'file_size': fileSize,
      'added_at': addedAt.millisecondsSinceEpoch,
    };
  }

  /// Create from database map (from SQLite)
  factory FileAttachment.fromDatabase(Map<String, dynamic> map) {
    return FileAttachment(
      fileName: map['file_name'] as String,
      localPath: map['local_path'] as String?,
      s3Key: map['s3_key'] as String?,
      fileSize: map['file_size'] as int?,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['added_at'] as int),
    );
  }

  /// Validate file attachment fields
  /// Throws ArgumentError if validation fails
  void validate() {
    if (fileName.isEmpty) {
      throw ArgumentError('FileAttachment fileName cannot be empty');
    }
  }

  /// Check if file is downloaded locally
  bool get isDownloaded => localPath != null && localPath!.isNotEmpty;

  /// Check if file is uploaded to S3
  bool get isUploaded => s3Key != null && s3Key!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FileAttachment &&
        other.fileName == fileName &&
        other.localPath == localPath &&
        other.s3Key == s3Key &&
        other.fileSize == fileSize &&
        other.addedAt == addedAt;
  }

  @override
  int get hashCode {
    return fileName.hashCode ^
        localPath.hashCode ^
        s3Key.hashCode ^
        fileSize.hashCode ^
        addedAt.hashCode;
  }

  @override
  String toString() {
    return 'FileAttachment(fileName: $fileName, localPath: $localPath, s3Key: $s3Key, fileSize: $fileSize)';
  }
}
