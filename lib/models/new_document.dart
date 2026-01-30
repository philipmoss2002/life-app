import 'package:uuid/uuid.dart';
import 'file_attachment.dart';
import 'sync_state.dart';

/// Document category enum
enum DocumentCategory {
  carInsurance('Car Insurance'),
  homeInsurance('Home Insurance'),
  holiday('Holiday'),
  expenses('Expenses'),
  other('Other');

  final String displayName;
  const DocumentCategory(this.displayName);

  /// Get date field label based on category
  String get dateLabel {
    switch (this) {
      case DocumentCategory.carInsurance:
      case DocumentCategory.homeInsurance:
        return 'Renewal Date';
      case DocumentCategory.holiday:
        return 'Payment Due';
      case DocumentCategory.expenses:
      case DocumentCategory.other:
        return 'Date';
    }
  }
}

/// Document model for authentication and sync rewrite
///
/// Represents a document with metadata and file attachments.
/// Uses UUID-based syncId as the primary identifier.
class Document {
  final String syncId;
  final String title;
  final DocumentCategory category;
  final DateTime? date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncState syncState;
  final List<FileAttachment> files;

  Document({
    required this.syncId,
    required this.title,
    required this.category,
    this.date,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.syncState,
    this.files = const [],
  });

  /// Create a new document with generated UUID
  factory Document.create({
    required String title,
    required DocumentCategory category,
    DateTime? date,
    String? notes,
  }) {
    final now = DateTime.now();
    return Document(
      syncId: const Uuid().v4(),
      title: title,
      category: category,
      date: date,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      syncState: SyncState.pendingUpload,
      files: [],
    );
  }

  /// Create a copy with updated fields
  Document copyWith({
    String? syncId,
    String? title,
    DocumentCategory? category,
    DateTime? date,
    bool clearDate = false,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    SyncState? syncState,
    List<FileAttachment>? files,
  }) {
    return Document(
      syncId: syncId ?? this.syncId,
      title: title ?? this.title,
      category: category ?? this.category,
      date: clearDate ? null : (date ?? this.date),
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncState: syncState ?? this.syncState,
      files: files ?? this.files,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'syncId': syncId,
      'title': title,
      'category': category.name,
      'date': date?.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'syncState': syncState.name,
      'files': files.map((f) => f.toJson()).toList(),
    };
  }

  /// Create from JSON map
  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      syncId: json['syncId'] as String,
      title: json['title'] as String,
      category: DocumentCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => DocumentCategory.other,
      ),
      date:
          json['date'] != null ? DateTime.parse(json['date'] as String) : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      syncState: SyncState.values.firstWhere(
        (e) => e.name == json['syncState'],
        orElse: () => SyncState.pendingUpload,
      ),
      files: (json['files'] as List<dynamic>?)
              ?.map((e) => FileAttachment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convert to database map (for SQLite)
  Map<String, dynamic> toDatabase() {
    return {
      'sync_id': syncId,
      'title': title,
      'category': category.name,
      'date': date?.millisecondsSinceEpoch,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'sync_state': syncState.name,
    };
  }

  /// Create from database map (from SQLite)
  factory Document.fromDatabase(Map<String, dynamic> map) {
    return Document(
      syncId: map['sync_id'] as String,
      title: map['title'] as String,
      category: DocumentCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => DocumentCategory.other,
      ),
      date: map['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date'] as int)
          : null,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      syncState: SyncState.values.firstWhere(
        (e) => e.name == map['sync_state'],
        orElse: () => SyncState.pendingUpload,
      ),
      files: [], // Files loaded separately from file_attachments table
    );
  }

  /// Validate document fields
  /// Throws ArgumentError if validation fails
  void validate() {
    if (syncId.isEmpty) {
      throw ArgumentError('Document syncId cannot be empty');
    }

    if (title.isEmpty) {
      throw ArgumentError('Document title cannot be empty');
    }

    // Validate UUID format
    try {
      Uuid.parse(syncId);
    } catch (e) {
      throw ArgumentError('Document syncId must be a valid UUID: $syncId');
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Document &&
        other.syncId == syncId &&
        other.title == title &&
        other.category == category &&
        other.date == date &&
        other.notes == notes &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.syncState == syncState &&
        _listEquals(other.files, files);
  }

  @override
  int get hashCode {
    return syncId.hashCode ^
        title.hashCode ^
        category.hashCode ^
        date.hashCode ^
        notes.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        syncState.hashCode ^
        files.hashCode;
  }

  @override
  String toString() {
    return 'Document(syncId: $syncId, title: $title, category: ${category.displayName}, syncState: ${syncState.name}, files: ${files.length})';
  }

  /// Helper method to compare lists
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
