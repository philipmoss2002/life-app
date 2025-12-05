import 'document.dart';

/// Types of conflicts that can occur during synchronization
enum ConflictType {
  /// Document modified on multiple devices
  documentModified,

  /// Document deleted on one device, modified on another
  deleteModify,

  /// File attachment conflict
  fileConflict,
}

/// Represents a synchronization conflict between local and remote versions
class Conflict {
  final String id;
  final String documentId;
  final Document localVersion;
  final Document remoteVersion;
  final DateTime detectedAt;
  final ConflictType type;

  Conflict({
    required this.id,
    required this.documentId,
    required this.localVersion,
    required this.remoteVersion,
    required this.type,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'documentId': documentId,
      'localVersion': localVersion.toMap(),
      'remoteVersion': remoteVersion.toMap(),
      'detectedAt': detectedAt.toIso8601String(),
      'type': type.name,
    };
  }

  factory Conflict.fromMap(Map<String, dynamic> map) {
    return Conflict(
      id: map['id'],
      documentId: map['documentId'],
      localVersion: Document.fromMap(map['localVersion']),
      remoteVersion: Document.fromMap(map['remoteVersion']),
      detectedAt: DateTime.parse(map['detectedAt']),
      type: ConflictType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => ConflictType.documentModified,
      ),
    );
  }

  Conflict copyWith({
    String? id,
    String? documentId,
    Document? localVersion,
    Document? remoteVersion,
    DateTime? detectedAt,
    ConflictType? type,
  }) {
    return Conflict(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      localVersion: localVersion ?? this.localVersion,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      detectedAt: detectedAt ?? this.detectedAt,
      type: type ?? this.type,
    );
  }
}
