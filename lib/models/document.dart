import 'file_attachment.dart';

class Document {
  final int? id;
  final String title;
  final String category;
  final String? filePath; // Kept for backward compatibility
  final List<String> filePaths; // New: multiple file paths
  final List<FileAttachment> fileAttachments; // With labels
  final DateTime? renewalDate;
  final String? notes;
  final DateTime createdAt;

  Document({
    this.id,
    required this.title,
    required this.category,
    this.filePath,
    List<String>? filePaths,
    List<FileAttachment>? fileAttachments,
    this.renewalDate,
    this.notes,
    DateTime? createdAt,
  })  : filePaths = filePaths ?? (filePath != null ? [filePath] : []),
        fileAttachments = fileAttachments ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'filePath': filePaths.isNotEmpty
          ? filePaths.first
          : null, // For backward compatibility
      'renewalDate': renewalDate?.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Document.fromMap(Map<String, dynamic> map,
      {List<String>? filePaths, List<FileAttachment>? fileAttachments}) {
    return Document(
      id: map['id'],
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
    );
  }

  Document copyWith({
    int? id,
    String? title,
    String? category,
    String? filePath,
    List<String>? filePaths,
    List<FileAttachment>? fileAttachments,
    DateTime? renewalDate,
    String? notes,
    DateTime? createdAt,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      filePath: filePath ?? this.filePath,
      filePaths: filePaths ?? this.filePaths,
      fileAttachments: fileAttachments ?? this.fileAttachments,
      renewalDate: renewalDate ?? this.renewalDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
