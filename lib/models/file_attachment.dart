import 'sync_state.dart';

class FileAttachment {
  final int? id;
  final String? documentId; // Reference to parent document
  final String filePath;
  final String fileName;
  final String? label;
  final int fileSize; // File size in bytes
  final String? s3Key; // S3 storage key for cloud sync
  final String? localPath; // Local cache path
  final DateTime addedAt;
  final SyncState syncState; // Current synchronization state

  FileAttachment({
    this.id,
    this.documentId,
    required this.filePath,
    required this.fileName,
    this.label,
    int? fileSize,
    this.s3Key,
    this.localPath,
    DateTime? addedAt,
    SyncState? syncState,
  })  : fileSize = fileSize ?? 0,
        addedAt = addedAt ?? DateTime.now(),
        syncState = syncState ?? SyncState.notSynced;

  String get displayName => label ?? fileName;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentId': documentId,
      'filePath': filePath,
      'fileName': fileName,
      'label': label,
      'fileSize': fileSize,
      's3Key': s3Key,
      'localPath': localPath,
      'addedAt': addedAt.toIso8601String(),
      'syncState': syncState.toJson(),
    };
  }

  factory FileAttachment.fromMap(Map<String, dynamic> map) {
    return FileAttachment(
      id: map['id'] as int?,
      documentId: map['documentId']?.toString(),
      filePath: map['filePath'] as String,
      fileName: map['fileName'] as String,
      label: map['label'] as String?,
      fileSize: map['fileSize'] as int? ?? 0,
      s3Key: map['s3Key'] as String?,
      localPath: map['localPath'] as String?,
      addedAt: map['addedAt'] != null
          ? DateTime.parse(map['addedAt'] as String)
          : DateTime.now(),
      syncState: map['syncState'] != null
          ? SyncState.fromJson(map['syncState'] as String)
          : SyncState.notSynced,
    );
  }

  FileAttachment copyWith({
    int? id,
    String? documentId,
    String? filePath,
    String? fileName,
    String? label,
    int? fileSize,
    String? s3Key,
    String? localPath,
    DateTime? addedAt,
    SyncState? syncState,
  }) {
    return FileAttachment(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      label: label ?? this.label,
      fileSize: fileSize ?? this.fileSize,
      s3Key: s3Key ?? this.s3Key,
      localPath: localPath ?? this.localPath,
      addedAt: addedAt ?? this.addedAt,
      syncState: syncState ?? this.syncState,
    );
  }
}
