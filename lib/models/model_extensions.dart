import 'Document.dart';
import 'FileAttachment.dart';
import 'sync_state.dart';
import '../services/sync_identifier_service.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;

/// Extension methods to provide compatibility between old and new models
extension DocumentExtensions on Document {
  /// Create Document from Map (compatibility with old database code)
  static Document fromMap(Map<String, dynamic> map) {
    return Document(
      syncId: map['syncId'] ?? SyncIdentifierService.generateValidated(),
      userId: map['userId'] ?? 'unknown',
      title: map['title'] ?? '',
      category: map['category'] ?? '',
      filePaths: (map['filePaths'] as List<dynamic>?)?.cast<String>() ?? [],
      renewalDate: map['renewalDate'] != null
          ? amplify_core.TemporalDateTime(DateTime.parse(map['renewalDate']))
          : null,
      notes: map['notes'],
      createdAt: amplify_core.TemporalDateTime(map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now()),
      lastModified: amplify_core.TemporalDateTime(map['lastModified'] != null
          ? DateTime.parse(map['lastModified'])
          : DateTime.now()),
      version: map['version'] ?? 1,
      syncState: map['syncState'] ?? SyncState.notSynced.toJson(),
      conflictId: map['conflictId'],
      deleted: map['deleted'] ?? false,
      deletedAt: map['deletedAt'] != null
          ? amplify_core.TemporalDateTime(DateTime.parse(map['deletedAt']))
          : null,
    );
  }

  /// Convert Document to Map (compatibility with old database code)
  Map<String, dynamic> toMap() {
    return {
      'syncId': syncId,
      'title': title,
      'category': category,
      'filePath': filePaths.isNotEmpty ? filePaths.first : null,
      'renewalDate': renewalDate?.getDateTimeInUtc().toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.getDateTimeInUtc().toIso8601String(),
      'userId': userId,
      'lastModified': lastModified.getDateTimeInUtc().toIso8601String(),
      'version': version,
      'syncState': syncState,
      'conflictId': conflictId,
    };
  }

  /// Convert TemporalDateTime to DateTime for compatibility
  DateTime? get renewalDateTime => renewalDate?.getDateTimeInUtc();
  DateTime get createdDateTime => createdAt.getDateTimeInUtc();
  DateTime get lastModifiedDateTime => lastModified.getDateTimeInUtc();

  /// Get SyncState enum from string
  SyncState get syncStateEnum => SyncState.fromJson(syncState);
}

extension FileAttachmentExtensions on FileAttachment {
  /// Create FileAttachment from Map (compatibility with old database code)
  static FileAttachment fromMap(Map<String, dynamic> map) {
    return FileAttachment(
      syncId: map['syncId'],
      userId: map['userId'] ?? '', // Add userId field
      filePath: map['filePath'] ?? '',
      fileName: map['fileName'] ?? '',
      label: map['label'],
      fileSize: map['fileSize'] ?? 0,
      s3Key: map['s3Key'] ?? '',
      addedAt: amplify_core.TemporalDateTime(map['addedAt'] != null
          ? DateTime.parse(map['addedAt'])
          : DateTime.now()),
      syncState: map['syncState'] ?? SyncState.notSynced.toJson(),
      contentType: map['contentType'],
      checksum: map['checksum'],
    );
  }

  /// Convert FileAttachment to Map (compatibility with old database code)
  Map<String, dynamic> toMap() {
    return {
      'syncId': syncId,
      'documentSyncId': null, // This will be set by the database layer
      'userId': userId,
      'filePath': filePath,
      'fileName': fileName,
      'label': label,
      'fileSize': fileSize,
      's3Key': s3Key,
      'addedAt': addedAt.getDateTimeInUtc().toIso8601String(),
      'syncState': syncState,
      'contentType': contentType,
      'checksum': checksum,
    };
  }

  /// Convert TemporalDateTime to DateTime for compatibility
  DateTime get addedDateTime => addedAt.getDateTimeInUtc();

  /// Get SyncState enum from string
  SyncState get syncStateEnum => SyncState.fromJson(syncState);
}

/// Helper methods for TemporalDateTime conversion
extension TemporalDateTimeExtensions on amplify_core.TemporalDateTime {
  /// Calculate difference with DateTime (compatibility method)
  Duration difference(DateTime other) {
    return getDateTimeInUtc().difference(other);
  }

  /// Check if this date is after another TemporalDateTime
  bool isAfter(amplify_core.TemporalDateTime other) {
    return getDateTimeInUtc().isAfter(other.getDateTimeInUtc());
  }

  /// Check if this date is before another TemporalDateTime
  bool isBefore(amplify_core.TemporalDateTime other) {
    return getDateTimeInUtc().isBefore(other.getDateTimeInUtc());
  }

  /// Get day component
  int get day => getDateTimeInUtc().day;

  /// Get month component
  int get month => getDateTimeInUtc().month;

  /// Get year component
  int get year => getDateTimeInUtc().year;
}
