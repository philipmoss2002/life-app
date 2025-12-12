import 'file_attachment.dart';
import 'sync_state.dart';

class Document {
  final int? id;
  final String? userId; // User ID from AWS Cognito
  final String title;
  final String category;
  final String? filePath; // Kept for backward compatibility
  final List<String> filePaths; // New: multiple file paths
  final List<FileAttachment> fileAttachments; // With labels
  final DateTime? renewalDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime lastModified; // Last modification timestamp
  final int version; // Version number for conflict detection
  final SyncState syncState; // Current synchronization state
  final String? conflictId; // ID of conflict if one exists

  Document({
    this.id,
    this.userId,
    required this.title,
    required this.category,
    this.filePath,
    List<String>? filePaths,
    List<FileAttachment>? fileAttachments,
    this.renewalDate,
    this.notes,
    DateTime? createdAt,
    DateTime? lastModified,
    int? version,
    SyncState? syncState,
    this.conflictId,
  })  : filePaths = filePaths ?? (filePath != null ? [filePath] : []),
        fileAttachments = fileAttachments ?? [],
        createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now(),
        version = version ?? 1,
        syncState = syncState ?? SyncState.notSynced;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'category': category,
      'filePath': filePaths.isNotEmpty
          ? filePaths.first
          : null, // For backward compatibility
      'renewalDate': renewalDate?.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
      'version': version,
      'syncState': syncState.toJson(),
      'conflictId': conflictId,
    };
  }

  factory Document.fromMap(Map<String, dynamic> map,
      {List<String>? filePaths, List<FileAttachment>? fileAttachments}) {
    return Document(
      id: map['id'],
      userId: map['userId'],
      title: map['title'],
      category: map['category'],
      filePath: map['filePath'],
      filePaths: filePaths,
      fileAttachments: fileAttachments,
      renewalDate: map['renewalDate'] != null
          ? DateTime.parse(map['renewalDate'])
          : null,
      notes: map['notes'],
      createdAt: DateTime.parse(map['createdAt']),
      lastModified: map['lastModified'] != null
          ? DateTime.parse(map['lastModified'])
          : DateTime.parse(
              map['createdAt']), // Fallback for backward compatibility
      version: map['version'] ?? 1,
      syncState: map['syncState'] != null
          ? SyncState.fromJson(map['syncState'])
          : SyncState.notSynced,
      conflictId: map['conflictId'],
    );
  }

  Document copyWith({
    int? id,
    String? userId,
    String? title,
    String? category,
    String? filePath,
    List<String>? filePaths,
    List<FileAttachment>? fileAttachments,
    DateTime? renewalDate,
    String? notes,
    DateTime? createdAt,
    DateTime? lastModified,
    int? version,
    SyncState? syncState,
    String? conflictId,
  }) {
    return Document(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      category: category ?? this.category,
      filePath: filePath ?? this.filePath,
      filePaths: filePaths ?? this.filePaths,
      fileAttachments: fileAttachments ?? this.fileAttachments,
      renewalDate: renewalDate ?? this.renewalDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      version: version ?? this.version,
      syncState: syncState ?? this.syncState,
      conflictId: conflictId ?? this.conflictId,
    );
  }

  /// Increment version and update lastModified timestamp
  Document incrementVersion() {
    return copyWith(
      version: version + 1,
      lastModified: DateTime.now(),
    );
  }
}
